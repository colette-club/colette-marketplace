defmodule App.Live.Adapters.LiveKitTest do
  use ExUnit.Case, async: true

  alias App.Config
  alias App.Live.Adapters.LiveKit

  @secret "test-secret-that-is-long-enough-for-hs256"

  describe "mint_participant_token/1" do
    test "when the participant is the host" do
      Config.put_env(:app, LiveKit, url: "wss://live.test", api_key: "test-key", api_secret: @secret)

      token = LiveKit.mint_participant_token(%{room: "activity-1", identity: "user-1", name: "Ada", role: :host})

      assert {true, %JOSE.JWT{fields: claims}, _jws} = JOSE.JWT.verify_strict(JOSE.JWK.from_oct(@secret), ["HS256"], token)
      assert %{"iss" => "test-key", "sub" => "user-1", "name" => "Ada"} = claims
      assert %{"room" => "activity-1", "roomJoin" => true, "canPublish" => true} = claims["video"]
      assert %{"role" => "host"} = JSON.decode!(claims["metadata"])
    end

    test "when the participant is a viewer" do
      Config.put_env(:app, LiveKit, url: "wss://live.test", api_key: "test-key", api_secret: @secret)

      token = LiveKit.mint_participant_token(%{room: "activity-1", identity: "user-2", name: "Bo", role: :viewer})

      assert {true, %JOSE.JWT{fields: claims}, _jws} = JOSE.JWT.verify_strict(JOSE.JWK.from_oct(@secret), ["HS256"], token)
      assert %{"canPublish" => false, "canSubscribe" => true} = claims["video"]
      assert %{"role" => "viewer"} = JSON.decode!(claims["metadata"])
    end
  end
end
