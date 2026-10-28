import Config

config :app, ecto_repos: [App.Repo]
config :app, :live, adapter: App.Live.Adapters.LiveKit

import_config "#{config_env()}.exs"
