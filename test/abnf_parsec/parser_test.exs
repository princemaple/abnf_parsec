defmodule AbnfParsec.ParserTest do
  use ExUnit.Case, async: true

  alias AbnfParsec.Parser

  test "parse comment" do
    assert {:ok, [comment: "abc"], "", %{}, {2, 7}, 7} = Parser.comment("; abc\r\n")
  end

  test "parse rulename" do
    assert {:ok, [rulename: "a"], "", %{}, {1, 0}, 1} = Parser.rulename("a")

    assert {:ok, [rulename: "abc"], "", %{}, {1, 0}, 3} = Parser.rulename("abc")

    assert {:ok, [rulename: "a1b2c3"], "", %{}, {1, 0}, 6} = Parser.rulename("a1b2c3")

    assert {:ok, [rulename: "a1-b2-c3"], "", %{}, {1, 0}, 8} = Parser.rulename("a1-b2-c3")
  end

  test "parse repetition" do
    assert {:ok, [repetition: [repeat: [min: 1, max: 2], rulename: "abc"]], "", %{}, {1, 0}, 6} =
             Parser.repetition("1*2abc")

    assert {:ok, [repetition: [repeat: [{:max, 2}], rulename: "abc"]], "", %{}, {1, 0}, 5} =
             Parser.repetition("*2abc")

    assert {:ok, [repetition: [repeat: [{:min, 1}], rulename: "abc"]], "", %{}, {1, 0}, 5} =
             Parser.repetition("1*abc")

    assert {:ok, [repetition: [repeat: [], rulename: "abc"]], "", %{}, {1, 0}, 4} =
             Parser.repetition("*abc")

    assert {:ok, [repetition: [repeat: [times: 3], rulename: "abc"]], "", %{}, {1, 0}, 4} =
             Parser.repetition("3abc")

    assert {:ok, [rulename: "abc"], "", %{}, {1, 0}, 3} = Parser.repetition("abc")
  end

  test "parse option" do
    assert {:ok, [option: [rulename: "a"]], "", %{}, {1, 0}, 3} = Parser.option("[a]")
  end

  test "parse group" do
    assert {:ok, [rulename: "a"], "", %{}, {1, 0}, 3} = Parser.group("(a)")
  end

  test "parse num_val" do
    assert {:ok, [num_literal: [{:base, "x"}, "12AF"]], "", %{}, {1, 0}, 6} =
             Parser.num_val("%x12AF")

    assert {:ok, [num_range: [{:base, "x"}, "31", "39"]], "", %{}, {1, 0}, 7} =
             Parser.num_val("%x31-39")

    assert {:ok, [num_sequence: [{:base, "x"}, "97", "66", "99"]], "", %{}, {1, 0}, 10} =
             Parser.num_val("%x97.66.99")
  end

  test "parse char_val" do
    assert {:ok, ["ab cd ef"], "", %{}, {1, 0}, 10} = Parser.char_val(~s|"ab cd ef"|)

    assert {:ok, [""], "", %{}, {1, 0}, 2} = Parser.char_val(~s|""|)

    assert {:ok, [case_insensitive: "WxYz"], "", %{}, {1, 0}, 8} = Parser.char_val(~s|%i"WxYz"|)

    assert {:ok, [case_sensitive: "WxYz"], "", %{}, {1, 0}, 8} = Parser.char_val(~s|%s"WxYz"|)
  end

  test "parse prose_val" do
    assert {:ok, [prose_val: "something"], "", %{}, {1, 0}, 11} = Parser.prose_val("<something>")

    assert {:ok, [prose_val: "as a last resort"], "", %{}, {1, 0}, 18} =
             Parser.prose_val("<as a last resort>")
  end

  test "parse exception" do
    assert {:ok, [exception: [{:rulename, "some-rule"}, "A"]], "", %{}, {1, 0}, 26} =
             Parser.exception(~s|<any some-rule except "A">|)

    assert {:ok,
            [
              exception: [
                {:rulename, "CHAR"},
                "A",
                {:rulename, "DQUOTE"},
                {:num_literal, [{:base, "x"}, "42"]},
                {:rulename, "some-rule"}
              ]
            ], "", %{}, {1, 0},
            55} = Parser.exception(~s|<any CHAR except "A" and DQUOTE and %x42 and some-rule>|)
  end

  test "parse concatenation" do
    assert {:ok, [concatenation: [rulename: "a", rulename: "b"]], "", %{}, {1, 0}, 3} =
             Parser.concatenation("a b")

    assert {:ok, [rulename: "a"], "", %{}, {1, 0}, 1} = Parser.concatenation("a")
  end

  test "parse alternation" do
    assert {:ok, [alternation: [rulename: "a", rulename: "b"]], "", %{}, {1, 0}, 5} =
             Parser.alternation("a / b")

    assert {:ok, [rulename: "a"], "", %{}, {1, 0}, 1} = Parser.alternation("a")
  end

  test "parse element" do
    assert {:ok, ["abc"], "", %{}, {1, 0}, 5} = Parser.element(~s|"abc"|)

    assert {:ok,
            [
              option: [
                concatenation: [rulename: "a", rulename: "b", rulename: "c"]
              ]
            ], "", %{}, {1, 0}, 7} = Parser.element("[a b c]")

    assert {:ok, [rulename: "a-b-c"], "", %{}, {1, 0}, 5} = Parser.element("a-b-c")

    assert {:ok, [concatenation: [rulename: "a", rulename: "b", rulename: "c"]], "", %{}, {1, 0},
            7} = Parser.element("(a b c)")
  end

  test "parse" do
    assert {:ok, [rule: [rulename: "a", num_literal: [{:base, "x"}, "1"]]], "", %{}, {2, 9}, 9} =
             Parser.parse("a = %x1")

    assert {:ok,
            [
              rule: [
                rulename: "a",
                alternation: ["a", {:num_literal, [{:base, "x"}, "31"]}]
              ]
            ], "", %{}, {2, 16}, 16} = Parser.parse(~s{a = "a" / %x31})

    assert {:ok, [rule: [{:rulename, "a"}, "1"], rule: [{:rulename, "b"}, "2"]], "", %{}, {3, 18},
            18} =
             Parser.parse("""
             a = "1"
             b = "2"
             """)

    assert {:ok, [rule: [{:rulename, "a"}, "1", {:comment, "a = 1"}]], "", %{}, {2, 16}, 16} =
             Parser.parse("""
             a = "1"; a = 1
             """)

    assert {:ok,
            [
              rule: [
                {:rulename, "a"},
                "1",
                {:comment, " a = 1"},
                {:comment, " b does not exist"}
              ]
            ], "", %{}, {4, 46},
            46} =
             Parser.parse("""
             a = "1"
                 ; a = 1
                 ; b does not exist
             """)

    assert {:ok,
            [
              rule: [
                rulename: "rule",
                alternation: [
                  concatenation: [
                    rulename: "a",
                    concatenation: [
                      repetition: [repeat: [times: 3], rulename: "b"],
                      option: [concatenation: [rulename: "c", rulename: "d"]]
                    ]
                  ],
                  concatenation: [
                    num_literal: [{:base, "x"}, "49"],
                    repetition: [{:repeat, [times: 5]}, "x"]
                  ],
                  num_range: [{:base, "x"}, "51", "59"],
                  repetition: [
                    repeat: [min: 1, max: 2],
                    alternation: [rulename: "b", rulename: "c"]
                  ]
                ]
              ]
            ], "", %{}, {2, 56},
            56} = Parser.parse(~s|rule = a (3b [c d]) / %x49 5"x" / %x51-59 / 1*2(b / c)|)
  end

  test "parse!" do
    assert [rule: [rulename: "a", num_literal: [{:base, "x"}, "1"]]] =
             Parser.parse!("a = %x1\r\n")

    assert [
             rule: [
               rulename: "a",
               alternation: ["a", {:num_literal, [{:base, "x"}, "31"]}]
             ]
           ] = Parser.parse!(~s{a = "a" / %x31})

    assert [rule: [{:rulename, "a"}, "1"], rule: [{:rulename, "b"}, "2"]] =
             Parser.parse!("""
             a = "1"

             b = "2"
             """)

    assert_raise AbnfParsec.UnexpectedTokenError, fn ->
      Parser.parse!("1 = %x1")
    end

    assert_raise AbnfParsec.LeftoverTokenError, fn ->
      Parser.parse!("a = %x1\r\nb = ?")
    end

    assert Parser.parse!(File.read!("test/fixture/abnf.abnf"))
  end

  describe "RFC 5234 comment and whitespace tests" do
    test "1. comment at the end of a simple rule definition" do
      abnf = "rule1 = %x41 ; This is rule ALPHA\r\n"
      expected_ast = [
        rule: [
          rulename: "rule1",
          num_literal: [{:base, "x"}, "41"],
          comment: " This is rule ALPHA"
        ]
      ]
      assert {:ok, ast, "", %{}, _, _} = Parser.parse(abnf)
      assert ast == expected_ast
    end

    test "2. comment at the end of a rule with alternation" do
      abnf = "rule2 = \"a\" / \"b\" ; choose a or b\r\n"
      expected_ast = [
        rule: [
          rulename: "rule2",
          alternation: ["a", "b"],
          comment: " choose a or b"
        ]
      ]
      assert {:ok, ast, "", %{}, _, _} = Parser.parse(abnf)
      assert ast == expected_ast
    end

    test "3. comment at the end of a rule with concatenation" do
      abnf = "rule3 = \"c\" \"d\" ; c followed by d\r\n"
      expected_ast = [
        rule: [
          rulename: "rule3",
          concatenation: ["c", "d"],
          comment: " c followed by d"
        ]
      ]
      assert {:ok, ast, "", %{}, _, _} = Parser.parse(abnf)
      assert ast == expected_ast
    end

    test "4a. comment at the end of a group" do
      abnf = "rule4 = (\"e\" / \"f\") ; group comment\r\n"
      expected_ast = [
        rule: [
          rulename: "rule4",
          alternation: ["e", "f"],
          comment: " group comment"
        ]
      ]
      assert {:ok, ast, "", %{}, _, _} = Parser.parse(abnf)
      assert ast == expected_ast
    end

    test "4b. comment at the end of a group with preceding defined rules" do
      abnf = """
      ALPHA = %x41
      BETA = %x42
      rule5 = (ALPHA BETA) ; альфа бета
      """
      expected_ast = [
        rule: [rulename: "ALPHA", num_literal: [{:base, "x"}, "41"]],
        rule: [rulename: "BETA", num_literal: [{:base, "x"}, "42"]],
        rule: [
          rulename: "rule5",
          concatenation: [rulename: "ALPHA", rulename: "BETA"],
          comment: " альфа бета"
        ]
      ]
      assert {:ok, ast, "", %{}, _, _} = Parser.parse(abnf)
      assert ast == expected_ast
    end

    test "5a. comment at the end of an option" do
      abnf = "rule6 = [\"g\"] ; optional g\r\n"
      expected_ast = [
        rule: [
          rulename: "rule6",
          option: ["g"],
          comment: " optional g"
        ]
      ]
      assert {:ok, ast, "", %{}, _, _} = Parser.parse(abnf)
      assert ast == expected_ast
    end

    test "5b. comment at the end of an option with preceding defined rules" do
      abnf = """
      ALPHA = %x41
      BETA = %x42
      rule7 = [ALPHA BETA] ; optional alpha beta
      """
      expected_ast = [
        rule: [rulename: "ALPHA", num_literal: [{:base, "x"}, "41"]],
        rule: [rulename: "BETA", num_literal: [{:base, "x"}, "42"]],
        rule: [
          rulename: "rule7",
          option: [concatenation: [rulename: "ALPHA", rulename: "BETA"]],
          comment: " optional alpha beta"
        ]
      ]
      assert {:ok, ast, "", %{}, _, _} = Parser.parse(abnf)
      assert ast == expected_ast
    end

    test "6. multiple comments in a complex rule" do
      # Comments consumed by c_wsp within elements are collected.
      # The final comment is consumed by the rule's trailing c_nl.
      abnf = """
      e1 = %x61
      e2 = %x62
      e3 = %x63
      e4 = %x64
      rComplex = e1 ; c1 for e1 (elem line)
                 e2 / e3 ; c2 for e2/e3 (elem line)
                 e4 ; c3 for e4 (final elem line)
      """
      expected_ast = [
        rule: [rulename: "e1", num_literal: [{:base, "x"}, "61"]],
        rule: [rulename: "e2", num_literal: [{:base, "x"}, "62"]],
        rule: [rulename: "e3", num_literal: [{:base, "x"}, "63"]],
        rule: [rulename: "e4", num_literal: [{:base, "x"}, "64"]],
        rule: [
          rulename: "rComplex",
          # elements contains: e1, then c1, then (e2/e3), then c2, then e4
          # then the rule's final c_nl captures c3
          concatenation: [rulename: "e1", alternation: [rulename: "e2", rulename: "e3"], rulename: "e4"],
          comment: " c1 for e1 (elem line)", # From c_wsp after e1
          comment: " c2 for e2/e3 (elem line)", # From c_wsp after e2/e3
          comment: " c3 for e4 (final elem line)" # From rule's final c_nl
        ]
      ]
      assert {:ok, ast, "", %{}, _, _} = Parser.parse(abnf)
      assert ast == expected_ast
    end

    test "4c. comment between concatenated elements in a group is ignored" do
      abnf = """
      ALPHA = %x41
      BETA = %x42
      rule_group_internal_concat = (ALPHA ; ignored internal comment
        BETA) ; captured final comment
      """
      expected_ast = [
        rule: [rulename: "ALPHA", num_literal: [{:base, "x"}, "41"]],
        rule: [rulename: "BETA", num_literal: [{:base, "x"}, "42"]],
        rule: [
          rulename: "rule_group_internal_concat",
          concatenation: [rulename: "ALPHA", rulename: "BETA"],
          comment: " captured final comment"
        ]
      ]
      assert {:ok, ast, "", %{}, _, _} = Parser.parse(abnf)
      assert ast == expected_ast
    end

    test "4d. comment before slash in group alternation is ignored" do
      abnf = """
      ALPHA = %x41
      BETA = %x42
      rule_group_internal_alt_b4_slash = (ALPHA ; ignored internal comment
        / BETA) ; captured final comment
      """
      expected_ast = [
        rule: [rulename: "ALPHA", num_literal: [{:base, "x"}, "41"]],
        rule: [rulename: "BETA", num_literal: [{:base, "x"}, "42"]],
        rule: [
          rulename: "rule_group_internal_alt_b4_slash",
          alternation: [rulename: "ALPHA", rulename: "BETA"],
          comment: " captured final comment"
        ]
      ]
      assert {:ok, ast, "", %{}, _, _} = Parser.parse(abnf)
      assert ast == expected_ast
    end

    test "4e. comment after slash in group alternation is ignored" do
      abnf = """
      ALPHA = %x41
      BETA = %x42
      rule_group_internal_alt_after_slash = (ALPHA / ; ignored internal comment
        BETA) ; captured final comment
      """
      expected_ast = [
        rule: [rulename: "ALPHA", num_literal: [{:base, "x"}, "41"]],
        rule: [rulename: "BETA", num_literal: [{:base, "x"}, "42"]],
        rule: [
          rulename: "rule_group_internal_alt_after_slash",
          alternation: [rulename: "ALPHA", rulename: "BETA"],
          comment: " captured final comment"
        ]
      ]
      assert {:ok, ast, "", %{}, _, _} = Parser.parse(abnf)
      assert ast == expected_ast
    end

    test "5c. comment between concatenated elements in an option is ignored" do
      abnf = """
      ALPHA = %x41
      BETA = %x42
      rule_opt_internal_concat = [ALPHA ; ignored internal comment
        BETA] ; captured final comment
      """
      expected_ast = [
        rule: [rulename: "ALPHA", num_literal: [{:base, "x"}, "41"]],
        rule: [rulename: "BETA", num_literal: [{:base, "x"}, "42"]],
        rule: [
          rulename: "rule_opt_internal_concat",
          option: [concatenation: [rulename: "ALPHA", rulename: "BETA"]],
          comment: " captured final comment"
        ]
      ]
      assert {:ok, ast, "", %{}, _, _} = Parser.parse(abnf)
      assert ast == expected_ast
    end

    test "5d. comment before slash in option alternation is ignored" do
      abnf = """
      ALPHA = %x41
      BETA = %x42
      rule_opt_internal_alt_b4_slash = [ALPHA ; ignored internal comment
        / BETA] ; captured final comment
      """
      expected_ast = [
        rule: [rulename: "ALPHA", num_literal: [{:base, "x"}, "41"]],
        rule: [rulename: "BETA", num_literal: [{:base, "x"}, "42"]],
        rule: [
          rulename: "rule_opt_internal_alt_b4_slash",
          option: [alternation: [rulename: "ALPHA", rulename: "BETA"]],
          comment: " captured final comment"
        ]
      ]
      assert {:ok, ast, "", %{}, _, _} = Parser.parse(abnf)
      assert ast == expected_ast
    end

    test "5e. comment after slash in option alternation is ignored" do
      abnf = """
      ALPHA = %x41
      BETA = %x42
      rule_opt_internal_alt_after_slash = [ALPHA / ; ignored internal comment
        BETA] ; captured final comment
      """
      expected_ast = [
        rule: [rulename: "ALPHA", num_literal: [{:base, "x"}, "41"]],
        rule: [rulename: "BETA", num_literal: [{:base, "x"}, "42"]],
        rule: [
          rulename: "rule_opt_internal_alt_after_slash",
          option: [alternation: [rulename: "ALPHA", rulename: "BETA"]],
          comment: " captured final comment"
        ]
      ]
      assert {:ok, ast, "", %{}, _, _} = Parser.parse(abnf)
      assert ast == expected_ast
    end

    test "7. comment-only lines between rules" do
      abnf = """
      rule9 = "x"
      ; this is a comment line
      ; and another one
      rule10 = "y"
      """
      # Comments between rules are captured as separate items in the rulelist
      expected_ast = [
        rule: [rulename: "rule9", "x"],
        comment: " this is a comment line",
        comment: " and another one",
        rule: [rulename: "rule10", "y"]
      ]
      assert {:ok, ast, "", %{}, _, _} = Parser.parse(abnf)
      assert ast == expected_ast
    end
  end

  describe "parse errors for comments and whitespace" do
    test "8. CNL alone is not 1*c-wsp for concatenation" do
      # This rule is malformed because "b" needs leading WSP on its line
      # if the preceding line was a comment-newline (CNL) for correct concatenation.
      abnf = "malformed = \"a\" ; comment\r\n\"b\"\r\n"
      assert {:error, %AbnfParsec.UnexpectedTokenError{token: "\"b\"", line: 2}, _, _, _, _} =
               Parser.parse(abnf)

      abnf2 = "malformed2 = \"a\" ; comment\n\"b\"\n"
      assert {:error, %AbnfParsec.UnexpectedTokenError{token: "\"b\"", line: 2}, _, _, _, _} =
               Parser.parse(abnf2)

      # This one should be OK because there's WSP after CNL
      good_abnf = "still_good = \"a\" ; comment\r\n \"b\"\r\n"
      expected_ast_good = [
        rule: [
          rulename: "still_good",
          concatenation: ["a", "b"],
          comment: " comment" # The comment from the CNL WSP part
        ]
      ]
      assert {:ok, ast_good, "", %{}, _, _} = Parser.parse(good_abnf)
      assert ast_good == expected_ast_good
    end
  end

  test "extra utf8 range" do
    assert Application.get_env(:abnf_parsec, :extra_utf8_range) == [0x2190..0x21FF]

    assert [
             comment: " U+219x  ←   ↑   →   ↓   ↔   ↕   ↖   ↗   ↘   ↙   ↚   ↛   ↜   ↝   ↞   ↟",
             comment: " U+21Ax  ↠   ↡   ↢   ↣   ↤   ↥   ↦   ↧   ↨   ↩   ↪   ↫   ↬   ↭   ↮   ↯",
             comment: " U+21Bx  ↰   ↱   ↲   ↳   ↴   ↵   ↶   ↷   ↸   ↹   ↺   ↻   ↼   ↽   ↾   ↿",
             comment: " U+21Cx  ⇀   ⇁   ⇂   ⇃   ⇄   ⇅   ⇆   ⇇   ⇈   ⇉   ⇊   ⇋   ⇌   ⇍   ⇎   ⇏",
             comment: " U+21Dx  ⇐   ⇑   ⇒   ⇓   ⇔   ⇕   ⇖   ⇗   ⇘   ⇙   ⇚   ⇛   ⇜   ⇝   ⇞   ⇟",
             comment: " U+21Ex  ⇠   ⇡   ⇢   ⇣   ⇤   ⇥   ⇦   ⇧   ⇨   ⇩   ⇪   ⇫   ⇬   ⇭   ⇮   ⇯",
             comment: " U+21Fx  ⇰   ⇱   ⇲   ⇳   ⇴   ⇵   ⇶   ⇷   ⇸   ⇹   ⇺   ⇻   ⇼   ⇽   ⇾   ⇿",
             rule: [{:rulename, "a"}, "a"]
           ] =
             Parser.parse!("""
             ; U+219x  ←   ↑   →   ↓   ↔   ↕   ↖   ↗   ↘   ↙   ↚   ↛   ↜   ↝   ↞   ↟
             ; U+21Ax  ↠   ↡   ↢   ↣   ↤   ↥   ↦   ↧   ↨   ↩   ↪   ↫   ↬   ↭   ↮   ↯
             ; U+21Bx  ↰   ↱   ↲   ↳   ↴   ↵   ↶   ↷   ↸   ↹   ↺   ↻   ↼   ↽   ↾   ↿
             ; U+21Cx  ⇀   ⇁   ⇂   ⇃   ⇄   ⇅   ⇆   ⇇   ⇈   ⇉   ⇊   ⇋   ⇌   ⇍   ⇎   ⇏
             ; U+21Dx  ⇐   ⇑   ⇒   ⇓   ⇔   ⇕   ⇖   ⇗   ⇘   ⇙   ⇚   ⇛   ⇜   ⇝   ⇞   ⇟
             ; U+21Ex  ⇠   ⇡   ⇢   ⇣   ⇤   ⇥   ⇦   ⇧   ⇨   ⇩   ⇪   ⇫   ⇬   ⇭   ⇮   ⇯
             ; U+21Fx  ⇰   ⇱   ⇲   ⇳   ⇴   ⇵   ⇶   ⇷   ⇸   ⇹   ⇺   ⇻   ⇼   ⇽   ⇾   ⇿
             a = "a"
             """)
  end
end
