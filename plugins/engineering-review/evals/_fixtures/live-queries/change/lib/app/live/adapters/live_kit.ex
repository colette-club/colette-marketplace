defmodule App.Live.Adapters.LiveKit do
  @moduledoc """
  LiveKit as the media server of the live rooms. Reads `url`, `api_key` and
  `api_secret` from `config :app, App.Live.Adapters.LiveKit`.
  """

  @behaviour App.Live.Adapter

  alias App.Config

  @token_lifetime_seconds 6 * 60 * 60

  @impl true
  def get_server_url, do: fetch_setting!(:url)

  @impl true
  def mint_participant_token(%{room: room, identity: identity, name: name, role: role}) do
    now = System.system_time(:second)
    jwk = JOSE.JWK.from_oct(fetch_setting!(:api_secret))
    metadata = JSON.encode!(%{"role" => Atom.to_string(role)})

    claims = %{
      "iss" => fetch_setting!(:api_key),
      "sub" => identity,
      "name" => name,
      "metadata" => metadata,
      "nbf" => now,
      "exp" => now + @token_lifetime_seconds,
      "video" => %{"room" => room, "roomJoin" => true, "canSubscribe" => true, "canPublish" => role == :host}
    }

    {_jws, token} = jwk |> JOSE.JWT.sign(%{"alg" => "HS256"}, claims) |> JOSE.JWS.compact()
    token
  end

  defp fetch_setting!(key) do
    :app
    |> Config.fetch_env!(__MODULE__)
    |> Keyword.fetch!(key)
  end
end
