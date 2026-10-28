defmodule App.Live.LiveKitWebhook do
  @moduledoc """
  Verifies a LiveKit webhook: the `Authorization` header is a JWT signed with the
  webhook secret, whose `sha256` claim is the body's digest.
  """

  @spec verify(String.t() | nil, binary()) :: {:ok, map()} | {:error, :invalid_signature | :invalid_body}
  def verify(token, body) when is_binary(token) do
    jwk = JOSE.JWK.from_oct(webhook_secret())

    case JOSE.JWT.verify_strict(jwk, ["HS256"], token) do
      {true, %JOSE.JWT{fields: %{"sha256" => digest}}, _jws} -> decode_if_signed(digest, body)
      _not_verified -> {:error, :invalid_signature}
    end
  end

  def verify(nil, _body), do: {:error, :invalid_signature}

  defp decode_if_signed(digest, body) do
    case Base.encode64(:crypto.hash(:sha256, body)) do
      ^digest -> decode(body)
      _other -> {:error, :invalid_signature}
    end
  end

  defp decode(body) do
    case JSON.decode(body) do
      {:ok, %{} = event} -> {:ok, event}
      _not_an_object -> {:error, :invalid_body}
    end
  end

  defp webhook_secret, do: :app |> Application.fetch_env!(:live) |> Keyword.fetch!(:livekit_webhook_secret)
end
