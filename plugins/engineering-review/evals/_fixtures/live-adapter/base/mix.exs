defmodule App.MixProject do
  use Mix.Project

  def project do
    [app: :app, version: "0.1.0", elixir: "~> 1.18", deps: deps()]
  end

  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.20"},
      {:ex_event_bus, "~> 0.6"},
      {:oban, "~> 2.19"},
      {:jose, "~> 1.11"},
      {:mox, "~> 1.2", only: :test}
    ]
  end
end
