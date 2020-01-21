defmodule AbnfParsec do
  import NimbleParsec

  @moduledoc """
  Documentation for AbnfParsec.
  """

  space = ascii_string([?\ ], min: 1)

  alpha = string("ALPHA") |> unwrap_and_tag(:core)
  digit = string("DIGIT") |> unwrap_and_tag(:core)
  hexdig = string("HEXDIG") |> unwrap_and_tag(:core)
  dquote = string("DQUOTE") |> unwrap_and_tag(:core)
  sp = string("SP") |> unwrap_and_tag(:core)
  htab = string("HTAB") |> unwrap_and_tag(:core)
  wsp = string("WSP") |> unwrap_and_tag(:core)
  lwsp = string("LWSP") |> unwrap_and_tag(:core)
  vchar = string("VCHAR") |> unwrap_and_tag(:core)
  char = string("CHAR") |> unwrap_and_tag(:core)
  octet = string("OCTET") |> unwrap_and_tag(:core)
  ctl = string("CTL") |> unwrap_and_tag(:core)
  crlf = string("CRLF") |> unwrap_and_tag(:core)
  cr = string("CR") |> unwrap_and_tag(:core)
  lf = string("LF") |> unwrap_and_tag(:core)
  bit = string("BIT") |> unwrap_and_tag(:core)

  core_rule =
    choice([
      alpha,
      digit,
      hexdig,
      dquote,
      sp,
      htab,
      wsp,
      lwsp,
      vchar,
      char,
      octet,
      ctl,
      crlf,
      cr,
      lf,
      bit
    ])

  comment =
    repeat(space)
    |> ignore(string(";"))
    |> optional(ignore(space))
    |> repeat_while(ascii_char([]), {:not_cr_lf, []})
    |> reduce({List, :to_string, []})
    |> tag(:comment)

  name =
    ascii_char([?a..?z, ?A..?Z])
    |> repeat(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?-]))
    |> reduce({List, :to_string, []})

  rule =
    choice([
      name,
      ignore(string("<"))
      |> concat(name)
      |> ignore(string(">"))
    ])
    |> unwrap_and_tag(:rule)

  string_literal =
    ignore(string("\""))
    |> ascii_string([{:not, ?"}], min: 0)
    |> ignore(string("\""))

  case_insensitive_string_literal =
    ignore(string("%i"))
    |> concat(string_literal)
    |> unwrap_and_tag(:case_insensitive)

  case_sensitive_string_literal =
    ignore(string("%s"))
    |> concat(string_literal)
    |> unwrap_and_tag(:case_sensitive)

  string_expr =
    choice([
      string_literal,
      case_insensitive_string_literal,
      case_sensitive_string_literal
    ])

  number = ascii_string([?0..?9, ?a..?f], min: 1)

  numeric =
    ignore(string("%"))
    |> (ascii_char('xbd') |> map(:binary_wrap))
    |> unwrap_and_tag(:base)
    |> concat(number)

  numeric_literal =
    numeric
    |> tag(:numeric_literal)

  numeric_range =
    numeric
    |> ignore(string("-"))
    |> concat(number)
    |> tag(:numeric_range)

  numeric_sequence =
    numeric
    |> times(ignore(string(".")) |> concat(number), min: 1)
    |> tag(:numeric_sequence)

  numeric_expr = choice([numeric_range, numeric_sequence, numeric_literal])

  repetition_range =
    optional(integer(min: 1) |> unwrap_and_tag(:min))
    |> ignore(string("*"))
    |> optional(integer(min: 1) |> unwrap_and_tag(:max))

  repetition_exact = integer(min: 1) |> unwrap_and_tag(:times)

  repetition_expr =
    choice([repetition_range, repetition_exact])
    |> tag(:repeat)
    |> concat(parsec(:expr))
    |> tag(:repetition)

  group =
    ignore(string("("))
    |> concat(parsec(:expr))
    |> ignore(string(")"))
    |> tag(:group)

  optional_expr =
    ignore(string("["))
    |> concat(parsec(:expr))
    |> ignore(string("]"))
    |> tag(:optional)

  concatenation =
    ignore(space)
    |> concat(parsec(:expr))
    |> tag(:concatenation)

  alternative =
    ignore(space)
    |> ignore(string("/"))
    |> ignore(space)
    |> concat(parsec(:expr))
    |> tag(:alternative)

  defp not_cr_lf(<<"\r\n", _::binary>>, context, _, _), do: {:halt, context}
  defp not_cr_lf(_, context, _, _), do: {:cont, context}

  defp binary_wrap(code), do: <<code>>

  defparsec :expr,
            times(
              choice([
                core_rule,
                rule,
                string_expr,
                numeric_expr,
                comment,
                repetition_expr,
                optional_expr,
                group,
                concatenation,
                alternative,
                ignore(string("\r\n") |> ascii_string([?\ ], min: 1))
              ]),
              min: 1
            )

  defparsec :parse,
            times(
              name
              |> ignore(space)
              |> ignore(string("="))
              |> ignore(space)
              |> parsec(:expr)
              |> ignore(times(string("\r\n"), min: 1))
              |> tag(:definition),
              min: 1
            )

  def parse!(text) do
    case parse(text) do
      {:ok, syntax, "", _, _, _} -> syntax
      {:ok, _, leftover, _, _, _} -> raise AbnfParsec.LeftoverTokenError, "Leftover: #{leftover}"
      {:error, error, _, _, _, _} -> raise AbnfParsec.UnexpectedTokenError, error
    end
  end

  def normalize(text) do
    text
    |> String.split("\n", trim: true)
    |> Enum.join("\r\n")
    |> Kernel.<>("\r\n")
  end

  defparsec :rule, rule
  defparsec :comment, comment
  defparsec :repetition, repetition_expr
  defparsec :optional, optional_expr
  defparsec :group, group
  defparsec :numeric, numeric_expr
  defparsec :concatenation, concatenation
  defparsec :alternative, alternative
  defparsec :string, string_expr
  defparsec :core_rule, core_rule
end
