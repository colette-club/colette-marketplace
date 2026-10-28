import Config

fetch_env! = fn name ->
  case System.get_env(name) do
    blank when blank in [nil, ""] -> raise "environment variable #{name} is missing or empty"
    value -> value
  end
end

payments_adapter = :app |> Application.fetch_env!(:payments) |> Keyword.fetch!(:adapter)
live_adapter = :app |> Application.fetch_env!(:live) |> Keyword.fetch!(:adapter)

# Each adapter's settings are required wherever that adapter is the configured one.
if payments_adapter == App.Payments.Adapters.Stripe do
  config :app, App.Payments.Adapters.Stripe,
    api_key: fetch_env!.("STRIPE_API_KEY"),
    webhook_secret: fetch_env!.("STRIPE_WEBHOOK_SECRET")
end

if live_adapter == App.Live.Adapters.LiveKit do
  config :app, App.Live.Adapters.LiveKit,
    url: fetch_env!.("LIVEKIT_URL"),
    api_key: fetch_env!.("LIVEKIT_API_KEY"),
    api_secret: fetch_env!.("LIVEKIT_API_SECRET")
end

if config_env() == :prod do
  config :app, App.Repo, url: fetch_env!.("DATABASE_URL")

  config :app, :live, livekit_webhook_secret: System.get_env("LIVEKIT_WEBHOOK_SECRET")
end
