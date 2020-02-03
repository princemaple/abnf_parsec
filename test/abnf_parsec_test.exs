defmodule AbnfParsecTest do
  use ExUnit.Case

  defmodule T do
    use AbnfParsec,
      abnf: """
      my-sp = SP
      my-alpha = ALPHA
      my-lwsp = LWSP
      my-my-sp = my-sp
      abc-string = "abc"
      a-num-literal = %d65
      a-num-literal-binary = %b1000001
      abc-num-range = %x41-43
      a-e-x-num-sequence = %x41.45.58
      concat-a-a-1 = %x41 %x41
      concat-a-a-2 = a-num-literal a-num-literal
      concat-range-sequence = abc-num-range a-e-x-num-sequence
      a-or-b = %x41 / %x42
      three-a = 3%x41
      zero-or-more-a = *%x41
      min-3-a = 3*%x41
      max-3-a = *3%x41
      min-1-max-2-a = 1*2%x41
      a-comment = %x41 ; a comment
      a-multi-line-comment = %x41
        ; multi line comment
        ; multi line comment
        ; multi line comment
      a-optional-b = %x41 [%x42]

      part-1 = *2(%x41 [3"B"])
      complex = part-1 SP part-2; do not blow up
      part-2 = 1*("C" / "D")
      """
  end

  test "core" do
    assert {:ok, [my_sp: [" "]], "", %{}, {1, 0}, 1} = T.my_sp(" ")
    assert {:ok, [my_my_sp: [my_sp: [" "]]], "", %{}, {1, 0}, 1} = T.my_my_sp(" ")
    assert {:ok, [my_alpha: 'a'], "", %{}, {1, 0}, 1} = T.my_alpha("a")
    assert {:ok, [my_lwsp: '    '], "", %{}, {1, 0}, 4} = T.my_lwsp("    ")
  end

  test "char_val" do
    assert {:ok, [abc_string: ["abc"]], "", %{}, {1, 0}, 3} = T.abc_string("abc")
  end

  test "num_val" do
    assert {:ok, [a_num_literal: 'A'], "", %{}, {1, 0}, 1} = T.a_num_literal("A")
    assert {:error, _, _, _, _, _} = T.a_num_literal("B")

    assert {:ok, [a_num_literal_binary: 'A'], "", %{}, {1, 0}, 1} = T.a_num_literal_binary("A")

    assert {:ok, [abc_num_range: 'A'], "", %{}, {1, 0}, 1} = T.abc_num_range("A")
    assert {:ok, [abc_num_range: 'B'], "", %{}, {1, 0}, 1} = T.abc_num_range("B")
    assert {:ok, [abc_num_range: 'C'], "", %{}, {1, 0}, 1} = T.abc_num_range("C")
    assert {:error, _, _, _, _, _} = T.abc_num_range("D")

    assert {:ok, [a_e_x_num_sequence: ["AEX"]], "", %{}, {1, 0}, 3} = T.a_e_x_num_sequence("AEX")
  end

  test "concatenation" do
    assert {:ok, [concat_a_a_1: 'AA'], "", %{}, {1, 0}, 2} = T.concat_a_a_1("AA")

    assert {:ok, [concat_a_a_2: [a_num_literal: 'A', a_num_literal: 'A']], "", %{}, {1, 0}, 2} =
             T.concat_a_a_2("AA")

    assert {:ok,
            [
              concat_range_sequence: [
                abc_num_range: 'A',
                a_e_x_num_sequence: ["AEX"]
              ]
            ], "", %{}, {1, 0}, 4} = T.concat_range_sequence("AAEX")

    assert {:ok,
            [
              concat_range_sequence: [
                abc_num_range: 'B',
                a_e_x_num_sequence: ["AEX"]
              ]
            ], "", %{}, {1, 0}, 4} = T.concat_range_sequence("BAEX")
  end

  test "alternation" do
    assert {:ok, [a_or_b: 'A'], "", %{}, {1, 0}, 1} = T.a_or_b("A")
    assert {:ok, [a_or_b: 'B'], "", %{}, {1, 0}, 1} = T.a_or_b("B")
  end

  test "repetition" do
    assert {:ok, [three_a: 'AAA'], "", %{}, {1, 0}, 3} = T.three_a("AAA")

    assert {:ok, [zero_or_more_a: 'AAAA'], "", %{}, {1, 0}, 4} = T.zero_or_more_a("AAAA")
    assert {:ok, [zero_or_more_a: ''], "", %{}, {1, 0}, 0} = T.zero_or_more_a("")

    assert {:ok, [min_3_a: 'AAA'], "", %{}, {1, 0}, 3} = T.min_3_a("AAA")
    assert {:ok, [min_3_a: 'AAAA'], "", %{}, {1, 0}, 4} = T.min_3_a("AAAA")
    assert {:error, _, _, _, _, _} = T.min_3_a("AA")

    assert {:ok, [max_3_a: 'AAA'], "", %{}, {1, 0}, 3} = T.max_3_a("AAA")
    assert {:ok, [max_3_a: 'AA'], "", %{}, {1, 0}, 2} = T.max_3_a("AA")
    assert {:ok, [max_3_a: 'AAA'], "A", %{}, {1, 0}, 3} = T.max_3_a("AAAA")

    assert {:ok, [min_1_max_2_a: 'A'], "", %{}, {1, 0}, 1} = T.min_1_max_2_a("A")
    assert {:ok, [min_1_max_2_a: 'AA'], "", %{}, {1, 0}, 2} = T.min_1_max_2_a("AA")
    assert {:error, _, _, _, _, _} = T.min_1_max_2_a("")
    assert {:ok, [min_1_max_2_a: 'AA'], "A", %{}, {1, 0}, 2} = T.min_1_max_2_a("AAA")
  end

  test "comment" do
    assert {:ok, [a_comment: 'A'], "", %{}, {1, 0}, 1} = T.a_comment("A")
    assert {:ok, [a_multi_line_comment: 'A'], "", %{}, {1, 0}, 1} = T.a_multi_line_comment("A")
  end

  test "option" do
    assert {:ok, [a_optional_b: 'AB'], "", %{}, {1, 0}, 2} = T.a_optional_b("AB")
    assert {:ok, [a_optional_b: 'A'], "", %{}, {1, 0}, 1} = T.a_optional_b("A")
  end

  test "generate" do
    assert {:ok,
            [
              complex: [
                {:part_1, [65, "B", "B", "B"]},
                " ",
                {:part_2, ["C", "C", "C", "D", "D"]}
              ]
            ], "", %{}, {1, 0}, 10} = T.complex("ABBB CCCDD")

    assert {:ok,
            [
              complex: [
                {:part_1, [65, "B", "B", "B", 65, "B", "B", "B"]},
                " ",
                {:part_2, ["C", "D", "D", "D", "D"]}
              ]
            ], "", %{}, {1, 0}, 14} = T.complex("ABBBABBB CDDDD")
  end

  test "parser module" do
    defmodule J do
      use AbnfParsec,
        abnf_file: "test/fixture/json.abnf",
        parse: :json_text,
        transform: %{
          "string" => {:reduce, {List, :to_string, []}},
          "int" => {:reduce, {List, :to_string, []}},
          "frac" => {:reduce, {List, :to_string, []}}
        },
        untag: ["member"],
        unwrap: ["null", "true", "false", "int", "frac"],
        unbox: ["JSON-text", "digit1-9", "decimal-point", "escape", "unescaped", "char"],
        ignore: [
          "name-separator",
          "value-separator",
          "quotation-mark",
          "begin-object",
          "end-object",
          "begin-array",
          "end-array"
        ]
    end

    assert {:ok,
            [
              object: [
                [
                  string: ["a"],
                  value: [
                    object: [
                      [string: ["b"], value: [number: [int: "1", frac: ".2"]]],
                      [string: ["c"], value: [array: [value: [true: "true"]]]]
                    ]
                  ]
                ],
                [string: ["d"], value: [null: "null"]],
                [string: ["e"], value: [string: ["e\\te"]]]
              ]
            ], "", %{}, {2, 55},
            55} =
             J.object("""
             {"a": {"b": 1.2, "c": [true]}, "d": null, "e": "e\\te"}
             """)

    assert {:ok, _, _, _, _, _} =
             J.object("""
             {
               "data": [
                 {"name": "Jane", "age": 45, "role": "teacher", "married": true},
                 {"name": "John", "age": 12, "role": "student",
                  "classes": ["math", "english", "PE"], "graduated_at": null, "extra": {}}
               ]
             }
             """)
  end
end
