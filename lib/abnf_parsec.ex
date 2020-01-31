defmodule AbnfParsec do
  alias AbnfParsec.{Parser, Generator}

  defmacro __using__(opts) do
    abnf =
      case Keyword.fetch(opts, :abnf_file) do
        {:ok, filepath} -> File.read!(filepath)
        :error -> Keyword.fetch!(opts, :abnf)
      end

    debug? = Keyword.get(opts, :debug, false)

    parse = Keyword.get(opts, :parse)

    code =
      abnf
      |> Parser.parse!()
      |> Generator.generate(Enum.into(opts, %{}))

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
