defmodule AbnfParsec do
  import NimbleParsec

  @moduledoc """
  Documentation for AbnfParsec.
  """
  alpha = string("ALPHA") |> tag(:core)
  digit = string("DIGIT") |> tag(:core)
  hexdig = string("HEXDIG") |> tag(:core)
  dquote = string("DQUOTE") |> tag(:core)
  sp = string("SP") |> tag(:core)
  htab = string("HTAB") |> tag(:core)
  wsp = string("WSP") |> tag(:core)
  lwsp = string("LWSP") |> tag(:core)
  vchar = string("VCHAR") |> tag(:core)
  char = string("CHAR") |> tag(:core)
  octet = string("OCTET") |> tag(:core)
  ctl = string("CTL") |> tag(:core)
  crlf = string("CRLF") |> tag(:core)
  cr = string("CR") |> tag(:core)
  lf = string("LF") |> tag(:core)
  bit = string("BIT") |> tag(:core)

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
    times(
      ignore(string(";"))
      |> optional(ignore(ascii_string([?\ ], min: 1)))
      |> repeat_while(ascii_char([]), {:not_cr_lf, []})
      |> optional(ignore(string("\r\n")))
      |> reduce({List, :to_string, []}),
      min: 1
    )
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
    |> ascii_char([?b, ?d, ?x])
    |> unwrap_and_tag(:base)
    |> concat(number)

  numeric_range =
    numeric
    |> ignore(string("-"))
    |> concat(number)
    |> tag(:numeric_range)

  numeric_sequence =
    numeric
    |> times(ignore(string(".")) |> concat(number), min: 1)
    |> tag(:numeric_sequence)

  numeric_expr = choice([numeric_range, numeric_sequence, numeric])

  repetition_expr =
    optional(integer(min: 1) |> unwrap_and_tag(:min))
    |> ignore(string("*"))
    |> optional(integer(min: 1) |> unwrap_and_tag(:max))
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
    parsec(:expr_x)
    |> times(
      ignore(ascii_char([?\ ]))
      |> concat(parsec(:expr_x)),
      min: 1
    )
    |> tag(:concatenation)

  alternative =
    parsec(:expr_x)
    |> times(
      ignore(string(" / "))
      |> concat(parsec(:expr_x)),
      min: 1
    )
    |> tag(:alternative)

  defp not_cr_lf(<<"\r\n", _::binary>>, context, _, _), do: {:halt, context}
  defp not_cr_lf(_, context, _, _), do: {:cont, context}

  defparsec :expr,
            choice([
              alternative,
              concatenation,
              group,
              optional_expr,
              repetition_expr,
              comment,
              numeric_expr,
              string_expr,
              rule,
              core_rule
            ])

  defparsec :expr_x,
            choice([
              group,
              optional_expr,
              repetition_expr,
              comment,
              numeric_expr,
              string_expr,
              rule,
              core_rule
            ])

  # for unit tests
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
