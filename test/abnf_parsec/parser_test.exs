defmodule AbnfParsec.ParserTest do
  use ExUnit.Case, async: true

  alias AbnfParsec.Parser

  test "parse core rules" do
    "ALPHA DIGIT HEXDIG DQUOTE SP HTAB WSP LWSP VCHAR CHAR OCTET CTL CR LF CRLF BIT"
    |> String.split()
    |> Enum.each(fn rule ->
      assert {:ok, [core: ^rule], "", %{}, {1, 0}, _} = Parser.core_rule(rule)
    end)

    assert {:error, _, _, _, _, _} = Parser.core_rule("CHAR8")
    assert {:error, _, _, _, _, _} = Parser.core_rule("ALPHA-")
    assert {:error, _, _, _, _, _} = Parser.core_rule("DIGITTT")
  end

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
                {:core, "CHAR"},
                "A",
                {:core, "DQUOTE"},
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
                {:comment, "a = 1"},
                {:comment, "b does not exist"}
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
end
