defmodule AbnfParsec.Generator do
  core_parsecs =
    quote do
      defparsecp :alpha, ascii_char([?A..?Z, ?a..?z])
      defparsecp :bit, ascii_char([?0, ?1])
      defparsecp :char, ascii_char([0x01..0x7F])
      defparsecp :cr, ascii_char([?\r])
      defparsecp :crlf, string("\r\n")
      defparsecp :ctl, ascii_char([0x00..0x1F])
      defparsecp :digit, ascii_char([0x30..0x39])
      defparsecp :dquote, string("\"")
      defparsecp :hexdig, ascii_char([0x30..0x39, ?A, ?B, ?C, ?D, ?E, ?F])
      defparsecp :htab, string("\t")
      defparsecp :lf, string("\n")
      defparsecp :lwsp, repeat(optional(string("\r\n")) |> ascii_char([?\ , ?\t]))
      defparsecp :octet, ascii_char([0x00..0xFF])
      defparsecp :sp, string(" ")
      defparsecp :vchar, ascii_char([0x21..0x7E])
      defparsecp :wsp, ascii_char([?\ , ?\t])
    end

  @core core_parsecs

  def core do
    @core
  end

  def generate(rulelist) do
    for {:rule, [{:rulename, rulename} | definition]} <- rulelist do
      define(rulename, definition)
    end
  end

  defp define(rulename, definition) when is_binary(rulename) do
    parsec_name = normalize_rulename(rulename)
    definition = expand(definition)

    quote do
      defparsec unquote(parsec_name),
                unquote(definition) |> tag(unquote(parsec_name))
    end
  end

  defp expand(list) when is_list(list) do
    [element] =
      list
      |> Enum.reject(fn
        {:comment, _} -> true
        _ -> false
      end)

    expand(element)
  end

  defp expand({:rulename, rulename}) do
    parsec_name = normalize_rulename(rulename)

    quote do
      parsec(unquote(parsec_name))
    end
  end

  defp expand(string) when is_binary(string) do
    quote do
      string(unquote(string))
    end
  end

  defp expand({:num_literal, [{:base, base}, num]}) do
    num = base_num(num, base)

    quote do
      ascii_char([unquote(num)])
    end
  end

  defp expand({:num_range, [{:base, base}, a, b]}) do
    a = base_num(a, base)
    b = base_num(b, base)

    quote bind_quoted: [a: a, b: b] do
      ascii_char([a..b])
    end
  end

  defp expand({:num_sequence, [{:base, base} | nums]}) do
    nums = Enum.map(nums, &base_num(&1, base))

    quote do
      string(<<unquote_splicing(nums)>>)
    end
  end

  defp expand({:concatenation, elements}) do
    elements
    |> Enum.map(&expand/1)
    |> Enum.map(&Macro.expand(&1, __ENV__))
    |> Enum.reduce(&Macro.pipe(&2, &1, 0))
  end

  defp expand({:alternation, elements}) do
    alternations =
      elements
      |> Enum.map(&expand/1)
      |> Enum.map(&Macro.expand(&1, __ENV__))

    quote do
      choice([unquote_splicing(alternations)])
    end
  end

  defp expand({:repetition, [{:repeat, repeat}, repeated]}) do
    repeated = expand(repeated)

    case repeat do
      [] ->
        quote do
          repeat(unquote(repeated))
        end

      [times: times] ->
        quote do
          times(unquote(repeated), unquote(times))
        end

      repeat ->
        quote do
          times(unquote(repeated), unquote(repeat))
        end
    end
  end

  defp expand({:option, element}) do
    quote do optional(unquote(expand(element))) end
  end

  defp normalize_rulename(rulename) do
    rulename
    |> String.downcase()
    |> String.replace("-", "_")
    |> String.to_atom()
  end

  defp base_num(num, base) do
    String.to_integer(
      num,
      case base do
        "x" -> 16
        "d" -> 10
        "b" -> 2
      end
    )
  end
end
