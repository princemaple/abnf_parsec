defmodule AbnfParsec.Generator do
  core_parsecs =
    quote do
      defparsecp :core_alpha, ascii_char([?A..?Z, ?a..?z])
      defparsecp :core_bit, ascii_char([?0, ?1])
      defparsecp :core_char, ascii_char([0x01..0x7F])
      defparsecp :core_cr, ascii_char([?\r])
      defparsecp :core_crlf, string("\r\n")
      defparsecp :core_ctl, ascii_char([0x00..0x1F])
      defparsecp :core_digit, ascii_char([0x30..0x39])
      defparsecp :core_dquote, string("\"")
      defparsecp :core_hexdig, ascii_char([0x30..0x39, ?A, ?B, ?C, ?D, ?E, ?F])
      defparsecp :core_htab, string("\t")
      defparsecp :core_lf, string("\n")
      defparsecp :core_lwsp, repeat(optional(string("\r\n")) |> ascii_char([?\ , ?\t]))
      defparsecp :core_octet, ascii_char([0x00..0xFF])
      defparsecp :core_sp, string(" ")
      defparsecp :core_vchar, ascii_char([0x21..0x7E])
      defparsecp :core_wsp, ascii_char([?\ , ?\t])
    end

  @core core_parsecs

  def core do
    @core
  end

  def generate(rulelist, opts) do
    for {:rule, [{:rulename, rulename} | definition]} <- rulelist do
      define(rulename, definition, opts)
    end
  end

  defp define(rulename, definition, opts) do
    parsec_name = normalize_rulename(rulename)
    definition = expand(definition)

    definition =
      case get_in(opts, [:transform, rulename]) do
        {:reduce, mfa} ->
          Macro.pipe(definition, quote(do: reduce(unquote(Macro.escape(mfa)))), 0)

        {:map, mfa} ->
          Macro.pipe(definition, quote(do: map(unquote(Macro.escape(mfa)))), 0)

        {:replace, val} ->
          Macro.pipe(definition, quote(do: replace(unquote(Macro.escape(val)))), 0)

        _ ->
          definition
      end

    definition =
      cond do
        rulename in Map.get(opts, :ignore, []) ->
          Macro.pipe(definition, quote(do: ignore()), 0)

        rulename in Map.get(opts, :unwrap, []) ->
          Macro.pipe(definition, quote(do: unwrap_and_tag(unquote(parsec_name))), 0)

        rulename in Map.get(opts, :untag, []) ->
          Macro.pipe(definition, quote(do: wrap()), 0)

        rulename in Map.get(opts, :unbox, []) ->
          definition

        true ->
          Macro.pipe(definition, quote(do: tag(unquote(parsec_name))), 0)
      end

    quote do
      defparsec unquote(parsec_name), unquote(definition)
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

  defp expand({:core, core_rule}) do
    parsec_name = normalize_rulename("core-" <> core_rule)

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

    quote do
      ascii_char([unquote(a)..unquote(b)])
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
    |> Enum.reduce(&Macro.pipe(&2, &1, 0))
  end

  defp expand({:alternation, elements}) do
    alternations = Enum.map(elements, &expand/1)

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
    quote do
      optional(unquote(expand(element)))
    end
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
