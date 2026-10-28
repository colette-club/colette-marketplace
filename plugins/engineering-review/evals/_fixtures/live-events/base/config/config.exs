import Config

config :app, ecto_repos: [App.Repo]

config :app, :live, adapter: App.Live.Adapters.LiveKit

config :app, Oban,
  repo: App.Repo,
  queues: [default: 10, notifications: 5, live: 5],
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"*/5 * * * *", App.Workers.CheckHostPresence},
       {"*/5 * * * *", App.Workers.CloseOverrunLive}
     ]}
  ]

import_config "#{config_env()}.exs"
