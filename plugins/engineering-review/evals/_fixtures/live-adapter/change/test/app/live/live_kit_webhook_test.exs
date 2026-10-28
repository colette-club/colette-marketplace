defmodule App.Live.LiveKitWebhookTest do
  use ExUnit.Case, async: true

  alias App.Live.LiveKitWebhook

  defp sign(body, secret \\ "test-webhook-secret-long-enough-for-hs256") do
    digest = Base.encode64(:crypto.hash(:sha256, body))
    jwk = JOSE.JWK.from_oct(secret)
    {_jws, token} = jwk |> JOSE.JWT.sign(%{"alg" => "HS256"}, %{"sha256" => digest}) |> JOSE.JWS.compact()
    token
  end

  describe "verify/2" do
    test "when LiveKit signed the body" do
      body = ~s({"event":"participant_joined"})

      assert {:ok, %{"event" => "participant_joined"}} = LiveKitWebhook.verify(sign(body), body)
    end

    test "when the body was changed after signing" do
      token = sign(~s({"event":"participant_joined"}))

      assert {:error, :invalid_signature} = LiveKitWebhook.verify(token, ~s({"event":"room_finished"}))
    end

    test "when another secret signed it" do
      body = ~s({"event":"participant_joined"})

      assert {:error, :invalid_signature} = LiveKitWebhook.verify(sign(body, "another-secret-long-enough-for-hs256"), body)
    end

    test "when there is no token" do
      assert {:error, :invalid_signature} = LiveKitWebhook.verify(nil, "{}")
    end

    test "when the signed body is a list" do
      body = "[]"

      assert {:error, :invalid_body} = LiveKitWebhook.verify(sign(body), body)
    end
  end
end
