defmodule AbnfParsec.RFC7405Test do
  use ExUnit.Case, async: true

  test "rfc7405" do
    defmodule RFC7405 do
      use AbnfParsec,
        abnf: """
        case-sensitive = %s"abc"
        case-insensitive = %i"abc"
        """
    end

    abc = "abc"
    assert {:ok, [case_sensitive: [^abc]], "", %{}, {1, 0}, 3} = RFC7405.case_sensitive(abc)

    assert {:ok, [case_insensitive: ["aBc"]], "D", %{}, {1, 0}, 3} =
             RFC7405.case_insensitive("aBcD")

    assert {:error, _msg, "DBCA", %{}, {1, 0}, 0} = RFC7405.case_insensitive("DBCA")
  end
end
