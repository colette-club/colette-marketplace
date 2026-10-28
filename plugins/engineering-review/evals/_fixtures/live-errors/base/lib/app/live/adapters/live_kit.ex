defmodule App.Live.Adapters.LiveKit do
  @moduledoc """
  LiveKit as the media server of the live rooms. Reads `api_key` and
  `api_secret` from `config :app, App.Live.Adapters.LiveKit`.
  """
  @behaviour App.Live.Adapter

  alias App.Config
  alias App.Live.Adapters.LiveKit.Webhook

  @impl true
  def verify_webhook(token, body), do: Webhook.verify(token, body, build_credentials())

  defp build_credentials do
    settings = Config.fetch_env!(:app, __MODULE__)
    %{api_key: Keyword.fetch!(settings, :api_key), api_secret: Keyword.fetch!(settings, :api_secret)}
  end
end
