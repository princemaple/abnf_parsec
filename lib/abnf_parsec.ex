defmodule AbnfParsec do
  def parse(text) do
    AbnfParsec.Parser.parse(text)
  end

  def parse!(text) do
    AbnfParsec.Parser.parse!(text)
  end
end
