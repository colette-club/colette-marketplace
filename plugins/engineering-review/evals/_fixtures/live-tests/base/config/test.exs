import Config

config :app, App.Repo,
  database: "app_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  parameters: [timezone: "UTC"]
