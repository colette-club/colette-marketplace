defmodule App.Live.Adapters.LiveKit do
  @moduledoc """
  LiveKit as the media server of the live rooms. Reads `url`, `api_key` and
  `api_secret` from `config :app, App.Live.Adapters.LiveKit`.
  """

  @behaviour App.Live.Adapter

  @impl true
  def get_server_url, do: fetch_setting!(:url)

  @impl true
  def issue_participant_token(%{room: room, identity: identity, name: name, role: role}) do
    now = System.system_time(:second)
    jwk = JOSE.JWK.from_oct(fetch_setting!(:api_secret))
    metadata = JSON.encode!(%{role: role})

    claims = %{
      "iss" => fetch_setting!(:api_key),
      "sub" => identity,
      "name" => name,
      "metadata" => metadata,
      "nbf" => now,
      "exp" => now + 6 * 3600,
      "video" => %{"room" => room, "roomJoin" => true}
    }

    {_jws, token} = jwk |> JOSE.JWT.sign(%{"alg" => "HS256"}, claims) |> JOSE.JWS.compact()
    token
  end

  defp fetch_setting!(key), do: :app |> Application.fetch_env!(__MODULE__) |> Keyword.fetch!(key)
end
