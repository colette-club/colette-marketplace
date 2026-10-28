import Config

if config_env() == :prod do
  database_url = System.get_env("DATABASE_URL") || raise "environment variable DATABASE_URL is missing."

  config :app, App.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  config :app, :tokens,
    session_validity_in_days: String.to_integer(System.get_env("SESSION_TOKEN_VALIDITY_IN_DAYS") || "30"),
    password_reset_validity_in_minutes:
      String.to_integer(System.get_env("PASSWORD_RESET_VALIDITY_IN_MINUTES") || "15")

  config :app, App.Live.Adapters.LiveKit,
    url: System.get_env("LIVEKIT_URL") || raise("environment variable LIVEKIT_URL is missing."),
    api_key: System.get_env("LIVEKIT_API_KEY") || raise("environment variable LIVEKIT_API_KEY is missing."),
    api_secret: System.get_env("LIVEKIT_API_SECRET") || raise("environment variable LIVEKIT_API_SECRET is missing.")
end
