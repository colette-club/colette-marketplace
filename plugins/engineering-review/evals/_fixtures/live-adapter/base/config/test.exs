import Config

config :app, App.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :app, :payments, adapter: App.Payments.AdapterMock
config :app, :live, adapter: App.Live.AdapterMock
