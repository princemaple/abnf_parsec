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

    assert {:ok, [comment: ["1st line", "2nd line"]], "", %{}, {3, 24}, 24} =
             AbnfParsec.comment("; 1st line\r\n; 2nd line\r\n")

    assert {:ok, [comment: ["1st line", "2nd line"]], "", %{}, {2, 12}, 22} =
             AbnfParsec.comment("; 1st line\r\n; 2nd line")
  end

  test "parse rule name" do
    assert {:ok, [rule: "a"], "", %{}, {1, 0}, 1} = AbnfParsec.rule("a")
    assert {:ok, [rule: "abc"], "", %{}, {1, 0}, 3} = AbnfParsec.rule("abc")
    assert {:ok, [rule: "a1b2c3"], "", %{}, {1, 0}, 6} = AbnfParsec.rule("a1b2c3")
    assert {:ok, [rule: "a1-b2-c3"], "", %{}, {1, 0}, 8} = AbnfParsec.rule("a1-b2-c3")
    assert {:ok, [rule: "a1-b2-c3"], "", %{}, {1, 0}, 10} = AbnfParsec.rule("<a1-b2-c3>")
  end

  test "parse repetition" do
    assert {:ok, [repetition: [min: 1, max: 2, rule: "abc"]], "", %{}, {1, 0}, 6} =
             AbnfParsec.repetition("1*2abc")

    assert {:ok, [repetition: [max: 2, rule: "abc"]], "", %{}, {1, 0}, 5} =
             AbnfParsec.repetition("*2abc")

    assert {:ok, [repetition: [min: 1, rule: "abc"]], "", %{}, {1, 0}, 5} =
             AbnfParsec.repetition("1*abc")

    assert {:ok, [repetition: [rule: "abc"]], "", %{}, {1, 0}, 4} = AbnfParsec.repetition("*abc")
  end

  test "parse optional" do
    assert {:ok, [optional: [rule: "a"]], "", %{}, {1, 0}, 3} = AbnfParsec.optional("[a]")
  end

  test "parse group" do
    assert {:ok, [group: [rule: "a"]], "", %{}, {1, 0}, 3} = AbnfParsec.group("(a)")
  end

  test "parse numeric" do
    assert {:ok, [{:base, 120}, "af"], "", %{}, {1, 0}, 4} = AbnfParsec.numeric("%xaf")

    assert {:ok, [numeric_range: [{:base, 120}, "31", "39"]], "", %{}, {1, 0}, 7} =
             AbnfParsec.numeric("%x31-39")

    assert {:ok, [numeric_sequence: [{:base, 120}, "97", "66", "99"]], "", %{}, {1, 0}, 10} =
             AbnfParsec.numeric("%x97.66.99")
  end

  test "parse string" do
    assert {:ok, ["ab cd ef"], "", %{}, {1, 0}, 10} = AbnfParsec.string(~s|"ab cd ef"|)
    assert {:ok, [""], "", %{}, {1, 0}, 2} = AbnfParsec.string(~s|""|)
    assert {:ok, [case_insensitive: "WxYz"], "", %{}, {1, 0}, 8} = AbnfParsec.string(~s|%i"WxYz"|)
    assert {:ok, [case_sensitive: "WxYz"], "", %{}, {1, 0}, 8} = AbnfParsec.string(~s|%s"WxYz"|)
  end

  test "parse concatenation" do
    assert {:ok, [concatenation: [rule: "a", rule: "b", rule: "c"]], "", %{}, {1, 0}, 5} =
             AbnfParsec.concatenation("a b c")
  end

  test "parse alternative" do
    assert {:ok, [alternative: [rule: "a", rule: "b", rule: "c"]], "", %{}, {1, 0}, 9} =
             AbnfParsec.alternative("a / b / c")
  end

  test "parse expr" do
    assert {:ok, ["abc"], "", %{}, {1, 0}, 5} = AbnfParsec.expr(~s|"abc"|)
    assert {:ok, [optional: [rule: "abc"]], "", %{}, {1, 0}, 5} = AbnfParsec.expr("[abc]")

    assert {:ok, [alternative: [rule: "a", rule: "b", rule: "c"]], "", %{}, {1, 0}, 9} =
             AbnfParsec.expr("a / b / c")

    assert {:ok, [rule: "a-b-c"], "", %{}, {1, 0}, 5} = AbnfParsec.expr("a-b-c")

    assert {:ok, [group: [concatenation: [rule: "a", rule: "b", rule: "c"]]], "", %{}, {1, 0}, 7} =
             AbnfParsec.expr("(a b c)")

    assert {:ok,
            [
              alternative: [
                {:rule, "a"},
                {:base, 120},
                "49",
                {:numeric_range, [{:base, 120}, "51", "59"]},
                {:repetition, [min: 1, max: 2, group: [alternative: [rule: "b", rule: "c"]]]}
              ]
            ], "", %{}, {1, 0}, 31} = AbnfParsec.expr(~s|a / %x49 / %x51-59 / 1*2(b / c)|)
  end
end
