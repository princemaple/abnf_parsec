defmodule AbnfParsec do
  alias AbnfParsec.{Parser, Generator}

  @doc """
  Generates a parser from ABNF definition - text (`:abnf`) or file path (`:abnf_file`)

  An entry rule can be defined by `:parse`. If defined, a `parse/1` function and a
  `parse!/1` function will be generated with the entry rule.

  By default, every chunk defined by a rule is wrapped (in list) and tagged by the
  rulename. Use the options to `:untag`, `:unwrap` or both (`:unbox`).

  Parsed chunks (rules) can be discarded `:ignore`.

  Transformations (`:map`, `:reduce`, `:replace`) can be applied by passing in a
  `:transform` map with keys being rulenames and values being 2-tuples of
  transformation type (`:map`, `:reduce`, `:replace`), and mfa tuple (for `:map` and `reduce`)
  or a literal value (for `:replace`)

  Example usage:

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

      json = ~s| {"a": {"b": 1.2, "c": [true]}, "d": null, "e": "e\\te"} |

      JsonParser.json_text(json)
      # or
      JsonParser.parse(json)
      # => {:ok, ...}
      JsonParser.parse!(json)
      # =>

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
      ]
  """
  defmacro __using__(opts) do
    abnf =
      case Keyword.fetch(opts, :abnf_file) do
        {:ok, filepath} -> File.read!(filepath)
        :error -> Keyword.fetch!(opts, :abnf)
      end

    debug? = Keyword.get(opts, :debug, false)

    parse = Keyword.get(opts, :parse)

    opts =
      opts
      |> Enum.into(%{})
      |> Map.update(:transform, %{}, &elem(Code.eval_quoted(&1), 0))

    code =
      abnf
      |> Parser.parse!()
      |> Generator.generate(opts)

    if debug? do
      code
      |> Macro.to_string()
      |> Code.format_string!()
      |> IO.puts()
    end

    quote do
      import NimbleParsec

      unquote(Generator.core())

      unquote(code)

      if unquote(parse) do
        def parse(text) do
          text |> unquote({parse, [], []})
        end

        def parse!(text) do
          case parse(text) do
            {:ok, syntax, "", _, _, _} ->
              syntax

            {:ok, _, leftover, _, _, _} ->
              raise AbnfParsec.LeftoverTokenError, "Leftover: #{leftover}"

            {:error, error, _, _, _, _} ->
              raise AbnfParsec.UnexpectedTokenError, error
          end
        end
      end
    end
  end
end
