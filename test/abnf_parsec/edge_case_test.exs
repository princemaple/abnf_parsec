defmodule EdgeCaseTest do
  use ExUnit.Case, async: true

  test "0 repeat" do
    defmodule ZeroRepetition do
      use AbnfParsec,
        abnf: """
        path-empty = 0<blah>
        """
    end

    assert {:ok, [path_empty: []], "", %{}, {1, 0}, 0} = ZeroRepetition.path_empty("")
  end
end
