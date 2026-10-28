import Config

config :app, App.Repo, database: "app_test", pool: Ecto.Adapters.SQL.Sandbox

config :app, :live, adapter: App.Live.AdapterMock
