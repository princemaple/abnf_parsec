defmodule AbnfParsec do
  alias AbnfParsec.{Parser, Generator}

  defmacro __using__(opts) do
    abnf =
      case Keyword.fetch(opts, :abnf_file) do
        {:ok, filepath} -> File.read!(filepath)
        :error -> Keyword.fetch!(opts, :abnf)
      end

    debug? = Keyword.get(opts, :debug, false)

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
    end
  end
end
