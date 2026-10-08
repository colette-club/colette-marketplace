defmodule App.MixProject do
  use Mix.Project

  def project, do: [app: :app, version: "0.1.0", elixir: "~> 1.18", deps: deps(), aliases: aliases()]

  defp deps, do: [{:credo, "~> 1.7", only: [:dev, :test], runtime: false}]

  defp aliases do
    [precommit: ["compile --warnings-as-errors", "format", "credo --strict", "test --warnings-as-errors"]]
  end
end
