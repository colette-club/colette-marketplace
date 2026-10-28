import Config

config :app, ecto_repos: [App.Repo]

config :app, :payments, adapter: App.Payments.Adapters.Stripe
config :app, :live, adapter: App.Live.Adapters.LiveKit, opens_before_minutes: 15

import_config "#{config_env()}.exs"
