defmodule AbnfParsecTest do
  use ExUnit.Case
  doctest AbnfParsec

  test "parse core rules" do
    "ALPHA DIGIT HEXDIG DQUOTE SP HTAB WSP LWSP VCHAR CHAR OCTET CTL CR LF CRLF BIT"
    |> String.split()
    |> Enum.each(fn rule ->
      assert {:ok, [core: ^rule], "", %{}, {1, 0}, _} = AbnfParsec.core_rule(rule)
    end)
  end

  test "parse comment" do
    assert {:ok, [comment: "abc"], "", %{}, {2, 7}, 7} = AbnfParsec.comment("; abc\r\n")
  end

  test "parse rulename" do
    assert {:ok, [rulename: "a"], "", %{}, {1, 0}, 1} = AbnfParsec.rulename("a")

    assert {:ok, [rulename: "abc"], "", %{}, {1, 0}, 3} = AbnfParsec.rulename("abc")

    assert {:ok, [rulename: "a1b2c3"], "", %{}, {1, 0}, 6} = AbnfParsec.rulename("a1b2c3")

    assert {:ok, [rulename: "a1-b2-c3"], "", %{}, {1, 0}, 8} = AbnfParsec.rulename("a1-b2-c3")
  end

  test "parse repetition" do
    assert {:ok, [repetition: [repeat: [min: 1, max: 2], rulename: "abc"]], "", %{}, {1, 0}, 6} =
             AbnfParsec.repetition("1*2abc")

    assert {:ok, [repetition: [repeat: [{:max, 2}], rulename: "abc"]], "", %{}, {1, 0}, 5} =
             AbnfParsec.repetition("*2abc")

    assert {:ok, [repetition: [repeat: [{:min, 1}], rulename: "abc"]], "", %{}, {1, 0}, 5} =
             AbnfParsec.repetition("1*abc")

    assert {:ok, [repetition: [repeat: [], rulename: "abc"]], "", %{}, {1, 0}, 4} =
             AbnfParsec.repetition("*abc")

    assert {:ok, [repetition: [repeat: [times: 3], rulename: "abc"]], "", %{}, {1, 0}, 4} =
             AbnfParsec.repetition("3abc")
  end

  test "parse option" do
    assert {:ok, [option: [rulename: "a"]], "", %{}, {1, 0}, 3} = AbnfParsec.option("[a]")
  end

  test "parse group" do
    assert {:ok, [group: [rulename: "a"]], "", %{}, {1, 0}, 3} = AbnfParsec.group("(a)")
  end

  test "parse num_val" do
    assert {:ok, [num_literal: [{:base, "x"}, "12AF"]], "", %{}, {1, 0}, 6} =
             AbnfParsec.num_val("%x12AF")

    assert {:ok, [num_range: [{:base, "x"}, "31", "39"]], "", %{}, {1, 0}, 7} =
             AbnfParsec.num_val("%x31-39")

    assert {:ok, [num_sequence: [{:base, "x"}, "97", "66", "99"]], "", %{}, {1, 0}, 10} =
             AbnfParsec.num_val("%x97.66.99")
  end

  test "parse char_val" do
    assert {:ok, ["ab cd ef"], "", %{}, {1, 0}, 10} = AbnfParsec.char_val(~s|"ab cd ef"|)

    assert {:ok, [""], "", %{}, {1, 0}, 2} = AbnfParsec.char_val(~s|""|)

    assert {:ok, [case_insensitive: "WxYz"], "", %{}, {1, 0}, 8} =
             AbnfParsec.char_val(~s|%i"WxYz"|)

    assert {:ok, [case_sensitive: "WxYz"], "", %{}, {1, 0}, 8} = AbnfParsec.char_val(~s|%s"WxYz"|)
  end

  test "parse concatenation" do
    assert {:ok, [concatenation: [rulename: "a", rulename: "b"]], "", %{}, {1, 0}, 3} =
             AbnfParsec.concatenation("a b")
  end

  test "parse alternation" do
    assert {:ok, [alternation: [rulename: "a", rulename: "b"]], "", %{}, {1, 0}, 5} =
             AbnfParsec.alternation("a / b")
  end

  test "parse element" do
    assert {:ok, ["abc"], "", %{}, {1, 0}, 5} = AbnfParsec.element(~s|"abc"|)

    assert {:ok,
            [
              option: [
                concatenation: [rulename: "a", rulename: "b", rulename: "c"]
              ]
            ], "", %{}, {1, 0}, 7} = AbnfParsec.element("[a b c]")

    assert {:ok, [rulename: "a-b-c"], "", %{}, {1, 0}, 5} = AbnfParsec.element("a-b-c")

    assert {:ok,
            [
              group: [
                concatenation: [rulename: "a", rulename: "b", rulename: "c"]
              ]
            ], "", %{}, {1, 0}, 7} = AbnfParsec.element("(a b c)")
  end

  test "parse" do
    assert {:ok, [rule: [rulename: "a", num_literal: [{:base, "x"}, "1"]]], "", %{}, {2, 9}, 9} =
             AbnfParsec.parse("a = %x1")

    assert {:ok,
            [
              rule: [
                rulename: "a",
                alternation: ["a", {:num_literal, [{:base, "x"}, "31"]}]
              ]
            ], "", %{}, {2, 16}, 16} = AbnfParsec.parse(~s{a = "a" / %x31})

    assert {:ok, [rule: [{:rulename, "a"}, "1"], rule: [{:rulename, "b"}, "2"]], "", %{}, {3, 18},
            18} =
             AbnfParsec.parse("""
             a = "1"
             b = "2"
             """)

    assert {:ok, [rule: [{:rulename, "a"}, "1", {:comment, "a = 1"}]], "", %{}, {2, 16}, 16} =
             AbnfParsec.parse("""
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
             AbnfParsec.parse("""
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
                    group: [
                      concatenation: [
                        repetition: [repeat: [times: 3], rulename: "b"],
                        option: [concatenation: [rulename: "c", rulename: "d"]]
                      ]
                    ]
                  ],
                  concatenation: [
                    num_literal: [{:base, "x"}, "49"],
                    repetition: [{:repeat, [times: 5]}, "x"]
                  ],
                  num_range: [{:base, "x"}, "51", "59"],
                  repetition: [
                    repeat: [min: 1, max: 2],
                    group: [alternation: [rulename: "b", rulename: "c"]]
                  ]
                ]
              ]
            ], "", %{}, {2, 56},
            56} = AbnfParsec.parse(~s|rule = a (3b [c d]) / %x49 5"x" / %x51-59 / 1*2(b / c)|)
  end

  test "parse!" do
    assert [rule: [rulename: "a", num_literal: [{:base, "x"}, "1"]]] =
             AbnfParsec.parse!("a = %x1\r\n")

    assert [
             rule: [
               rulename: "a",
               alternation: ["a", {:num_literal, [{:base, "x"}, "31"]}]
             ]
           ] = AbnfParsec.parse!(~s{a = "a" / %x31})

    assert [rule: [{:rulename, "a"}, "1"], rule: [{:rulename, "b"}, "2"]] =
             AbnfParsec.parse!("""
             a = "1"

             b = "2"
             """)

    assert_raise AbnfParsec.UnexpectedTokenError, fn ->
      AbnfParsec.parse!("1 = %x1")
    end

    assert_raise AbnfParsec.LeftoverTokenError, fn ->
      AbnfParsec.parse!("a = %x1\r\nb = ?")
    end

    assert AbnfParsec.parse!(File.read!("test/fixture/abnf.abnf"))
  end
end
