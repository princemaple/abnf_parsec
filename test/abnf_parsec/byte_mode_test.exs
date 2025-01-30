defmodule AbnfParsec.ByteModeTest do
  use ExUnit.Case, async: true

  test "rfc7405" do
    defmodule ByteMode do
      use AbnfParsec,
        mode: :byte,
        abnf: """
        ; from RFC 5322 + UTF8-non-ascii

        ; added for testing
        text = 1*atext

        atext = ALPHA / DIGIT / "!" / "#" / "$" / "%" / "&" / "'" / "*" / "+" /
          "-" / "/" / "=" / "?" / "^" / "_" / "`" / "{" / "|" / "}" / "~" / UTF8-non-ascii

        ; from RFC 3629
        UTF8-non-ascii  =   UTF8-2 / UTF8-3 / UTF8-4

        UTF8-2      = %xC2-DF UTF8-tail
        UTF8-3      = %xE0 %xA0-BF UTF8-tail / %xE1-EC 2( UTF8-tail ) /
              %xED %x80-9F UTF8-tail / %xEE-EF 2( UTF8-tail )
        UTF8-4      = %xF0 %x90-BF 2( UTF8-tail ) / %xF1-F3 3( UTF8-tail ) /
              %xF4 %x80-8F 2( UTF8-tail )
        UTF8-tail   = %x80-BF
        """
    end

    text = "你好"

    assert {
             :ok,
             [
               text: [
                 atext: [
                   utf8_non_ascii: [utf8_3: [228, {:utf8_tail, [189]}, {:utf8_tail, [160]}]]
                 ],
                 atext: [
                   utf8_non_ascii: [utf8_3: [229, {:utf8_tail, [165]}, {:utf8_tail, [189]}]]
                 ]
               ]
             ],
             "",
             %{},
             {1, 0},
             6
           } = ByteMode.text(text)
  end
end
