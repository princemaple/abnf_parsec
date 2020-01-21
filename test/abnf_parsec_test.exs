defmodule AbnfParsecTest do
  use ExUnit.Case
  doctest AbnfParsec

  test "parse core rules" do
    "ALPHA DIGIT HEXDIG DQUOTE SP HTAB WSP LWSP VCHAR CHAR OCTET CTL CR LF CRLF BIT"
    |> String.split()
    |> Enum.each(fn rule ->
      assert {:ok, [core: [^rule]], "", %{}, {1, 0}, _} = AbnfParsec.core_rule(rule)
    end)
  end

  test "parse comments" do
    assert {:ok, [comment: ["some comments"]], "", %{}, {1, 0}, 15} =
             AbnfParsec.comment("; some comments")
  end

  test "parse rule name" do
    assert {:ok, [rule: "a"], "", %{}, {1, 0}, 1} = AbnfParsec.rule("a")
    assert {:ok, [rule: "abc"], "", %{}, {1, 0}, 3} = AbnfParsec.rule("abc")
    assert {:ok, [rule: "a1b2c3"], "", %{}, {1, 0}, 6} = AbnfParsec.rule("a1b2c3")
    assert {:ok, [rule: "a1-b2-c3"], "", %{}, {1, 0}, 8} = AbnfParsec.rule("a1-b2-c3")
    assert {:ok, [rule: "a1-b2-c3"], "", %{}, {1, 0}, 10} = AbnfParsec.rule("<a1-b2-c3>")
  end

  test "parse repetition" do
    assert {:ok, [repetition: [repeat: [min: 1, max: 2], rule: "abc"]], "", %{}, {1, 0}, 6} =
             AbnfParsec.repetition("1*2abc")

    assert {:ok, [repetition: [repeat: [max: 2], rule: "abc"]], "", %{}, {1, 0}, 5} =
             AbnfParsec.repetition("*2abc")

    assert {:ok, [repetition: [repeat: [min: 1], rule: "abc"]], "", %{}, {1, 0}, 5} =
             AbnfParsec.repetition("1*abc")

    assert {:ok, [repetition: [repeat: [], rule: "abc"]], "", %{}, {1, 0}, 4} =
             AbnfParsec.repetition("*abc")

    assert {:ok, [repetition: [repeat: [times: 3], rule: "abc"]], "", %{}, {1, 0}, 4} =
             AbnfParsec.repetition("3abc")
  end

  test "parse optional" do
    assert {:ok, [optional: [rule: "a"]], "", %{}, {1, 0}, 3} = AbnfParsec.optional("[a]")
  end

  test "parse group" do
    assert {:ok, [group: [rule: "a"]], "", %{}, {1, 0}, 3} = AbnfParsec.group("(a)")
  end

  test "parse numeric" do
    assert {:ok, [numeric_literal: [{:base, "x"}, "af"]], "", %{}, {1, 0}, 4} =
             AbnfParsec.numeric("%xaf")

    assert {:ok, [numeric_range: [{:base, "x"}, "31", "39"]], "", %{}, {1, 0}, 7} =
             AbnfParsec.numeric("%x31-39")

    assert {:ok, [numeric_sequence: [{:base, "x"}, "97", "66", "99"]], "", %{}, {1, 0}, 10} =
             AbnfParsec.numeric("%x97.66.99")
  end

  test "parse string" do
    assert {:ok, ["ab cd ef"], "", %{}, {1, 0}, 10} = AbnfParsec.string(~s|"ab cd ef"|)
    assert {:ok, [""], "", %{}, {1, 0}, 2} = AbnfParsec.string(~s|""|)
    assert {:ok, [case_insensitive: "WxYz"], "", %{}, {1, 0}, 8} = AbnfParsec.string(~s|%i"WxYz"|)
    assert {:ok, [case_sensitive: "WxYz"], "", %{}, {1, 0}, 8} = AbnfParsec.string(~s|%s"WxYz"|)
  end

  test "parse concatenation" do
    assert {:ok, [concatenation: [rule: "b"]], "", %{}, {1, 0}, 2} =
             AbnfParsec.concatenation(" b")
  end

  test "parse alternative" do
    assert {:ok, [alternative: [rule: "b"]], "", %{}, {1, 0}, 4} = AbnfParsec.alternative(" / b")
  end

  test "parse expr" do
    assert {:ok, ["abc"], "", %{}, {1, 0}, 5} = AbnfParsec.expr(~s|"abc"|)

    assert {:ok,
            [
              optional: [
                rule: "a",
                concatenation: [rule: "b", concatenation: [rule: "c"]]
              ]
            ], "", %{}, {1, 0}, 7} = AbnfParsec.expr("[a b c]")

    assert {:ok, [rule: "a", alternative: [rule: "b", alternative: [rule: "c"]]], "", %{}, {1, 0},
            9} = AbnfParsec.expr("a / b / c")

    assert {:ok, [rule: "a-b-c"], "", %{}, {1, 0}, 5} = AbnfParsec.expr("a-b-c")

    assert {:ok,
            [
              group: [
                rule: "a",
                concatenation: [rule: "b", concatenation: [rule: "c"]]
              ]
            ], "", %{}, {1, 0}, 7} = AbnfParsec.expr("(a b c)")

    assert {:ok,
            [
              rule: "a",
              concatenation: [
                group: [
                  repetition: [
                    repeat: [times: 3],
                    rule: "b",
                    concatenation: [
                      optional: [rule: "c", concatenation: [rule: "d"]]
                    ]
                  ]
                ],
                alternative: [
                  numeric_literal: [{:base, "x"}, "49"],
                  concatenation: [
                    "x",
                    {:alternative,
                     [
                       numeric_range: [{:base, "x"}, "51", "59"],
                       alternative: [
                         repetition: [
                           repeat: [min: 1, max: 2],
                           group: [rule: "b", alternative: [rule: "c"]]
                         ]
                       ]
                     ]}
                  ]
                ]
              ]
            ], "", %{}, {1, 0},
            46} = AbnfParsec.expr(~s|a (3b [c d]) / %x49 "x" / %x51-59 / 1*2(b / c)|)

    assert {:ok, ["1", {:comment, ["a = 1"]}], "\r\n", %{}, {2, 5}, 13} =
             AbnfParsec.expr(
               AbnfParsec.normalize("""
               "1"
                ; a = 1
               """)
             )
  end

  test "parse" do
    assert {:ok, [definition: ["a", {:numeric_literal, [{:base, "x"}, "1"]}]], "", %{}, {2, 9}, 9} =
             AbnfParsec.parse(AbnfParsec.normalize("a = %x1"))

    assert {:ok,
            [
              definition: [
                "a",
                "a",
                {:alternative, [numeric_literal: [{:base, "x"}, "31"]]}
              ]
            ], "", %{}, {2, 16}, 16} = AbnfParsec.parse(AbnfParsec.normalize(~s{a = "a" / %x31}))

    assert {:ok, [definition: ["a", "1"], definition: ["b", "2"]], "", %{}, {3, 18}, 18} =
             AbnfParsec.parse(
               AbnfParsec.normalize("""
               a = "1"
               b = "2"
               """)
             )

    assert {:ok,
            [
              definition: [
                "a",
                "1",
                {:comment, ["a = 1"]},
                {:comment, ["b does not exist"]}
              ]
            ], "", %{}, {4, 46},
            46} =
             AbnfParsec.parse(
               AbnfParsec.normalize("""
               a = "1"
                   ; a = 1
                   ; b does not exist
               """)
             )
  end

  test "parse!" do
    assert [definition: ["a", {:numeric_literal, [{:base, "x"}, "1"]}]] =
             AbnfParsec.parse!(AbnfParsec.normalize("a = %x1"))

    assert [
             definition: [
               "a",
               "a",
               {:alternative, [numeric_literal: [{:base, "x"}, "31"]]}
             ]
           ] = AbnfParsec.parse!(AbnfParsec.normalize(~s{a = "a" / %x31}))

    assert [definition: ["a", "1"], definition: ["b", "2"]] =
             AbnfParsec.parse!(
               AbnfParsec.normalize("""
               a = "1"

               b = "2"
               """)
             )

    assert_raise AbnfParsec.UnexpectedTokenError, fn ->
      AbnfParsec.parse!(AbnfParsec.normalize("1 = %x1"))
    end

    assert_raise AbnfParsec.LeftoverTokenError, fn -> AbnfParsec.parse!("a = %x1\r\nb = ?") end
  end
end
