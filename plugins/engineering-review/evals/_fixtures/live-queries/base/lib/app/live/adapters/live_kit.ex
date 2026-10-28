defmodule App.Live.Adapters.LiveKit do
  @moduledoc """
  LiveKit as the media server of the live rooms. Reads `url`, `api_key` and
  `api_secret` from `config :app, App.Live.Adapters.LiveKit`.
  """

  @behaviour App.Live.Adapter

  alias App.Config

  @impl true
  def get_server_url, do: fetch_setting!(:url)

  defp fetch_setting!(key) do
    :app
    |> Config.fetch_env!(__MODULE__)
    |> Keyword.fetch!(key)
  end
end
