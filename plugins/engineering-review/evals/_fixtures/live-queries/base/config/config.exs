import Config

config :app, ecto_repos: [App.Repo]

config :app, :tokens, session_validity_in_days: 30, password_reset_validity_in_minutes: 15

config :app, :live, adapter: App.Live.Adapters.LiveKit
