defmodule App.MixProject do
  use Mix.Project

  def project do
    [app: :app, version: "0.1.0", elixir: "~> 1.18", deps: deps()]
  end

  def application, do: [mod: {App.Application, []}, extra_applications: [:logger]]

  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:ecto_sql, "~> 3.13"},
      {:absinthe, "~> 1.7"},
      {:oban, "~> 2.20"}
    ]
  end
end
