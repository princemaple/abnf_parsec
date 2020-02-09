defmodule AbnfParsec.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :abnf_parsec,
      version: @version,
      elixir: "~> 1.9",
      deps: deps(),
      name: "AbnfParsec",
      source_url: "https://github.com/princemaple/abnf_parsec",
      homepage_url: "https://github.com/princemaple/abnf_parsec",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:nimble_parsec, "~> 0.5"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "AbnfParsec",
      canonical: "http://hexdocs.pm/abnf_parsec",
      source_url: "https://github.com/princemaple/abnf_parsec"
    ]
  end
end
