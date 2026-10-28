import Config

config :app, :live, adapter: App.Live.AdapterMock
config :app, Oban, testing: :manual
