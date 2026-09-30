defmodule App.MixProject do
  use Mix.Project

  def project, do: [app: :app, version: "0.1.0", elixir: "~> 1.17", deps: deps()]

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:ecto_sql, "~> 3.11"},
      {:oban, "~> 2.17"}
    ]
  end
end
