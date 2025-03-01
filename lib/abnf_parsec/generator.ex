defmodule AbnfParsec.Generator do
  @moduledoc false

  core_parsecs =
    quote do
      defparsecp :core_alpha, ascii_char([?A..?Z, ?a..?z])
      defparsecp :core_bit, ascii_char([?0, ?1])
      defparsecp :core_char, ascii_char([0x01..0x7F])
      defparsecp :core_cr, ascii_char([?\r])
      defparsecp :core_crlf, string("\r\n")
      defparsecp :core_ctl, ascii_char([0x00..0x1F])
      defparsecp :core_digit, ascii_char([?0..?9])
      defparsecp :core_dquote, string("\"")
      defparsecp :core_hexdig, ascii_char([?0..?9, ?A..?F, ?a..?f])
      defparsecp :core_htab, string("\t")
      defparsecp :core_lf, string("\n")
      defparsecp :core_lwsp, repeat(optional(string("\r\n")) |> ascii_char([?\s, ?\t]))
      defparsecp :core_octet, ascii_char([0x00..0xFF])
      defparsecp :core_sp, string(" ")
      defparsecp :core_vchar, ascii_char([0x21..0x7E])
      defparsecp :core_wsp, ascii_char([?\s, ?\t])
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
    definition = expand(definition, opts[:mode] || :text)

    definition = transform(definition, get_in(opts, [:transform, rulename]))

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

    if rulename in Map.get(opts, :skip, []) do
      []
    else
      quote do
        defparsec unquote(parsec_name), unquote(definition)
      end
    end
  end

  defp transform(definition, []) do
    definition
  end

  defp transform(definition, [transformation | more]) do
    definition |> transform(transformation) |> transform(more)
  end

  defp transform(definition, transformation) do
    case transformation do
      {:reduce, mfa} ->
        Macro.pipe(definition, quote(do: reduce(unquote(Macro.escape(mfa)))), 0)

      {:map, mfa} ->
        Macro.pipe(definition, quote(do: map(unquote(Macro.escape(mfa)))), 0)

      {:replace, val} ->
        Macro.pipe(definition, quote(do: replace(unquote(Macro.escape(val)))), 0)

      {:pre_traverse, mfa} ->
        Macro.pipe(definition, quote(do: pre_traverse(unquote(Macro.escape(mfa)))), 0)

      {:post_traverse, mfa} ->
        Macro.pipe(definition, quote(do: post_traverse(unquote(Macro.escape(mfa)))), 0)

      nil ->
        definition
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

  defp pipe(a, b) do
    quote do
      unquote(a) |> unquote(b)
    end
  end

  defp expand(list, mode) when is_list(list) do
    [element] =
      list
      |> Enum.reject(fn
        {:comment, _} -> true
        _ -> false
      end)

    expand(element, mode)
  end

  defp expand({:rulename, rulename}, _mode) do
    parsec_name = normalize_rulename(rulename)

    quote do
      parsec(unquote(parsec_name))
    end
  end

  defp expand({:core, core_rule}, _mode) do
    parsec_name = normalize_rulename("core-" <> core_rule)

    quote do
      parsec(unquote(parsec_name))
    end
  end

  defp expand(<<_::utf8>> = string, mode) do
    expand({:case_sensitive, string}, mode)
  end

  defp expand(string, mode) when is_binary(string) do
    expand({:case_insensitive, string}, mode)
  end

  defp expand({:case_insensitive, string}, mode) when is_binary(string) do
    lower = String.downcase(string)
    upper = String.upcase(string)

    insensitive =
      Enum.zip(String.to_charlist(lower), String.to_charlist(upper))
      |> Enum.map(fn
        {c, c} -> {:case_sensitive, <<c>>}
        {l, u} -> {:alternation, [{:case_sensitive, <<l>>}, {:case_sensitive, <<u>>}]}
      end)

    concat = expand({:concatenation, insensitive}, mode)

    quote do
      reduce(unquote(concat), {Enum, :join, []})
    end
  end

  defp expand({:case_sensitive, string}, _mode) when is_binary(string) do
    quote do
      string(unquote(string))
    end
  end

  defp expand({:num_literal, [{:base, base}, num]}, mode) do
    num = base_num(num, base)

    case mode do
      :text ->
        quote do
          utf8_char([unquote(num)])
        end

      :byte ->
        quote do
          ascii_char([unquote(num)])
        end
    end
  end

  defp expand({:num_range, [{:base, base}, a, b]}, mode) do
    a = base_num(a, base)
    b = base_num(b, base)

    case mode do
      :text ->
        quote do
          utf8_char([unquote(a)..unquote(b)])
        end

      :byte ->
        quote do
          ascii_char([unquote(a)..unquote(b)])
        end
    end
  end

  defp expand({:num_sequence, [{:base, base} | nums]}, mode) do
    nums = Enum.map(nums, &base_num(&1, base))

    case mode do
      :text ->
        str = to_string(nums)

        quote do
          string(unquote(str))
        end

      :byte ->
        quote do
          string(<<unquote_splicing(nums)>>)
        end
    end
  end

  defp expand({:concatenation, elements}, mode) do
    elements
    |> Enum.map(&expand(&1, mode))
    |> Enum.reduce(fn
      {:|>, _, _} = b, a ->
        Enum.reduce(
          [a | b |> Macro.unpipe() |> Enum.map(&elem(&1, 0))],
          &pipe(&2, &1)
        )

      b, a ->
        pipe(a, b)
    end)
  end

  defp expand({:alternation, elements}, mode) do
    alternations = Enum.map(elements, &expand(&1, mode))

    quote do
      choice(unquote(alternations))
    end
  end

  defp expand({:repetition, [{:repeat, repeat}, repeated]}, mode) do
    repeated = expand(repeated, mode)

    case repeat do
      [] ->
        quote do
          repeat(unquote(repeated))
        end

      [times: times] ->
        quote do
          duplicate(unquote(repeated), unquote(times))
        end

      repeat ->
        quote do
          times(unquote(repeated), unquote(repeat))
        end
    end
  end

  defp expand({:option, element}, mode) do
    option = expand(element, mode)

    quote do
      optional(unquote(option))
    end
  end

  defp expand({:prose_val, _}, _mode) do
    quote do
      ascii_string([{:not, ?\r}, {:not, ?\n}], min: 0)
    end
  end

  # Extension: Used in RFC3501

  defp expand({:exception, [range | exceptions]}, mode) do
    except = Enum.map(exceptions, &expand(&1, mode))
    proceed = expand(range, mode)

    lookahead =
      case except do
        [except] ->
          except

        [_ | _] ->
          quote do
            choice(unquote(except))
          end
      end

    quote do
      lookahead_not(unquote(lookahead)) |> unquote(proceed)
    end
  end
end
