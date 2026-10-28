defmodule App.Live.Adapters.LiveKit.Webhook do
  @moduledoc false

  alias App.Live.Connection

  @doc "Verifies LiveKit's signature and turns a `participant_joined` event into a `Connection`."
  def verify(token, body, %{api_key: api_key, api_secret: api_secret}) do
    with {:ok, claims} <- verify_token(token, api_key, api_secret),
         :ok <- verify_body_hash(claims, body),
         {:ok, event} <- JSON.decode(body) do
      to_connection(event)
    else
      _invalid -> {:error, :invalid_signature}
    end
  end

  defp to_connection(%{
         "event" => "participant_joined",
         "room" => %{"name" => "activity-" <> activity_id},
         "participant" => %{"identity" => user_id, "metadata" => metadata}
       }) do
    {:ok, %Connection{activity_id: activity_id, user_id: user_id, role: role(metadata)}}
  end

  defp to_connection(_event), do: {:ok, :ignored}

  defp role(metadata) when is_binary(metadata) do
    case JSON.decode(metadata) do
      {:ok, %{"role" => "host"}} -> :host
      {:ok, _metadata} -> :viewer
      {:error, _reason} -> :viewer
    end
  end

  defp verify_token(nil, _api_key, _api_secret), do: :error

  defp verify_token(token, api_key, api_secret) do
    jwk = JOSE.JWK.from_oct(api_secret)

    case JOSE.JWT.verify_strict(jwk, ["HS256"], token) do
      {true, %JOSE.JWT{fields: %{"iss" => ^api_key} = claims}, _jws} -> {:ok, claims}
      _invalid -> :error
    end
  end

  defp verify_body_hash(%{"sha256" => expected}, body) do
    actual = :sha256 |> :crypto.hash(body) |> Base.encode64()
    if Plug.Crypto.secure_compare(actual, expected), do: :ok, else: :error
  end

  defp verify_body_hash(_claims, _body), do: :error
end
