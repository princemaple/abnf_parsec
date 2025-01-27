defmodule AbnfParsecTest do
  use ExUnit.Case, async: true

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
      concat-concat = ("x" "x") ("x" "x")
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
      my-c = "C"
      ALPHA-except-A = 1*<any ALPHA except "A">
      ALPHA-except-A-B-C = 1*<any ALPHA except "A" and %x42 and my-c>

      part-1 = *2(%x41 [3"B"])
      complex = part-1 SP part-2; do not blow up
      part-2 = 1*("C" / "D")
      """
  end

  test "core" do
    assert {:ok, [my_sp: [" "]], "", %{}, {1, 0}, 1} = T.my_sp(" ")
    assert {:ok, [my_my_sp: [my_sp: [" "]]], "", %{}, {1, 0}, 1} = T.my_my_sp(" ")
    assert {:ok, [my_alpha: ~c"a"], "", %{}, {1, 0}, 1} = T.my_alpha("a")
    assert {:ok, [my_lwsp: ~c"    "], "", %{}, {1, 0}, 4} = T.my_lwsp("    ")
  end

  test "char_val" do
    assert {:ok, [abc_string: ["abc"]], "", %{}, {1, 0}, 3} = T.abc_string("abc")
  end

  test "num_val" do
    assert {:ok, [a_num_literal: ~c"A"], "", %{}, {1, 0}, 1} = T.a_num_literal("A")
    assert {:error, _, _, _, _, _} = T.a_num_literal("B")

    assert {:ok, [a_num_literal_binary: ~c"A"], "", %{}, {1, 0}, 1} = T.a_num_literal_binary("A")

    assert {:ok, [abc_num_range: ~c"A"], "", %{}, {1, 0}, 1} = T.abc_num_range("A")
    assert {:ok, [abc_num_range: ~c"B"], "", %{}, {1, 0}, 1} = T.abc_num_range("B")
    assert {:ok, [abc_num_range: ~c"C"], "", %{}, {1, 0}, 1} = T.abc_num_range("C")
    assert {:error, _, _, _, _, _} = T.abc_num_range("D")

    assert {:ok, [a_e_x_num_sequence: ["AEX"]], "", %{}, {1, 0}, 3} = T.a_e_x_num_sequence("AEX")
  end

  test "concatenation" do
    assert {:ok, [concat_a_a_1: ~c"AA"], "", %{}, {1, 0}, 2} = T.concat_a_a_1("AA")

    assert {:ok, [concat_a_a_2: [a_num_literal: ~c"A", a_num_literal: ~c"A"]], "", %{}, {1, 0}, 2} =
             T.concat_a_a_2("AA")

    assert {:ok,
            [
              concat_range_sequence: [
                abc_num_range: ~c"A",
                a_e_x_num_sequence: ["AEX"]
              ]
            ], "", %{}, {1, 0}, 4} = T.concat_range_sequence("AAEX")

    assert {:ok,
            [
              concat_range_sequence: [
                abc_num_range: ~c"B",
                a_e_x_num_sequence: ["AEX"]
              ]
            ], "", %{}, {1, 0}, 4} = T.concat_range_sequence("BAEX")

    assert {:ok, [concat_concat: ["x", "x", "x", "x"]], "", %{}, {1, 0}, 4} =
             T.concat_concat("xxxx")
  end

  test "alternation" do
    assert {:ok, [a_or_b: ~c"A"], "", %{}, {1, 0}, 1} = T.a_or_b("A")
    assert {:ok, [a_or_b: ~c"B"], "", %{}, {1, 0}, 1} = T.a_or_b("B")
  end

  test "repetition" do
    assert {:ok, [three_a: ~c"AAA"], "", %{}, {1, 0}, 3} = T.three_a("AAA")

    assert {:ok, [zero_or_more_a: ~c"AAAA"], "", %{}, {1, 0}, 4} = T.zero_or_more_a("AAAA")
    assert {:ok, [zero_or_more_a: ~c""], "", %{}, {1, 0}, 0} = T.zero_or_more_a("")

    assert {:ok, [min_3_a: ~c"AAA"], "", %{}, {1, 0}, 3} = T.min_3_a("AAA")
    assert {:ok, [min_3_a: ~c"AAAA"], "", %{}, {1, 0}, 4} = T.min_3_a("AAAA")
    assert {:error, _, _, _, _, _} = T.min_3_a("AA")

    assert {:ok, [max_3_a: ~c"AAA"], "", %{}, {1, 0}, 3} = T.max_3_a("AAA")
    assert {:ok, [max_3_a: ~c"AA"], "", %{}, {1, 0}, 2} = T.max_3_a("AA")
    assert {:ok, [max_3_a: ~c"AAA"], "A", %{}, {1, 0}, 3} = T.max_3_a("AAAA")

    assert {:ok, [min_1_max_2_a: ~c"A"], "", %{}, {1, 0}, 1} = T.min_1_max_2_a("A")
    assert {:ok, [min_1_max_2_a: ~c"AA"], "", %{}, {1, 0}, 2} = T.min_1_max_2_a("AA")
    assert {:error, _, _, _, _, _} = T.min_1_max_2_a("")
    assert {:ok, [min_1_max_2_a: ~c"AA"], "A", %{}, {1, 0}, 2} = T.min_1_max_2_a("AAA")
  end

  test "comment" do
    assert {:ok, [a_comment: ~c"A"], "", %{}, {1, 0}, 1} = T.a_comment("A")
    assert {:ok, [a_multi_line_comment: ~c"A"], "", %{}, {1, 0}, 1} = T.a_multi_line_comment("A")
  end

  test "option" do
    assert {:ok, [a_optional_b: ~c"AB"], "", %{}, {1, 0}, 2} = T.a_optional_b("AB")
    assert {:ok, [a_optional_b: ~c"A"], "", %{}, {1, 0}, 1} = T.a_optional_b("A")
  end

  test "except" do
    assert {:ok, [alpha_except_a: ~c"BC"], "", %{}, {1, 0}, 2} = T.alpha_except_a("BC")

    assert {:error, "did not expect string \"A\"", "ABC", %{}, {1, 0}, 0} =
             T.alpha_except_a("ABC")

    assert {:ok, [alpha_except_a_b_c: ~c"DEFXYZ"], "", %{}, {1, 0}, 6} =
             T.alpha_except_a_b_c("DEFXYZ")

    assert {:error, "did not expect string \"A\" or utf8 codepoint equal to \"B\" or my_c", "A",
            %{}, {1, 0}, 0} = T.alpha_except_a_b_c("A")

    assert {:error, _, "B", %{}, {1, 0}, 0} = T.alpha_except_a_b_c("B")
    assert {:error, _, "C", %{}, {1, 0}, 0} = T.alpha_except_a_b_c("C")
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
          "int" => [{:reduce, {List, :to_string, []}}, {:map, {String, :to_integer, []}}],
          "frac" => {:reduce, {List, :to_string, []}},
          "null" => {:replace, nil},
          "true" => {:replace, true},
          "false" => {:replace, false}
        },
        untag: ["member"],
        unwrap: ["int", "frac"],
        unbox: [
          "JSON-text",
          "null",
          "true",
          "false",
          "digit1-9",
          "decimal-point",
          "escape",
          "unescaped",
          "char"
        ],
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
                      [string: ["b"], value: [number: [int: 1, frac: ".2"]]],
                      [string: ["c"], value: [array: [value: [true]]]]
                    ]
                  ]
                ],
                [string: ["d"], value: [nil]],
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

  import ExUnit.CaptureIO

  test "skip" do
    assert "[[]]\n" ==
             capture_io(fn ->
               defmodule S do
                 use AbnfParsec,
                   abnf: """
                   a = "a"
                     ; just a
                   """,
                   skip: ["a"],
                   debug: true
               end
             end)
  end

  test "debugging" do
    assert "[defparsec(:a, tag(string(\"a\"), :a))]\n" ==
             capture_io(fn ->
               defmodule D do
                 use AbnfParsec,
                   abnf: """
                   a = "a"
                     ; just a
                   """,
                   debug: true
               end
             end)
  end

  test "customization" do
    defmodule X do
      use AbnfParsec,
        abnf: """
        a = "a"; will be overridden
        """,
        skip: ["a"]

      defparsec :a, string("b")
    end

    assert {:error, "expected string \"b\"", "a", %{}, {1, 0}, 0} = X.a("a")
    assert {:ok, ["b"], "", %{}, {1, 0}, 1} = X.a("b")
  end

  test "pre/post traverse" do
    defmodule Y do
      use AbnfParsec,
        abnf: """
        n = *DIGIT
        d = "-"
        y = n d n d n
        """,
        untag: ["n", "d"],
        transform: %{
          "n" => {:pre_traverse, {:join, []}},
          "y" => {:post_traverse, {:join, []}}
        }

      defp join(rest, args, context, _, _) do
        {rest, [Enum.join(args)], context}
      end
    end

    assert {:ok, [y: ["515049-5049-49"]], "", %{}, {1, 0}, 8} = Y.y("1-12-123")
  end
end
