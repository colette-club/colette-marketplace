defmodule AppWeb.Webhooks.LiveKitControllerTest do
  use AppWeb.ConnCase, async: true

  alias App.Live.Participation

  defp sign(body) do
    digest = Base.encode64(:crypto.hash(:sha256, body))
    jwk = JOSE.JWK.from_oct("test-webhook-secret-long-enough-for-hs256")
    {_jws, token} = jwk |> JOSE.JWT.sign(%{"alg" => "HS256"}, %{"sha256" => digest}) |> JOSE.JWS.compact()
    token
  end

  describe "create/2" do
    test "when LiveKit reports a viewer's connection", %{conn: conn} do
      activity = insert(:activity)
      member = insert(:user)

      body =
        JSON.encode!(%{
          event: "participant_joined",
          room: %{name: "activity-" <> activity.id},
          participant: %{identity: member.id, metadata: ~s({"role":"viewer"})}
        })

      conn =
        conn
        |> put_req_header("authorization", sign(body))
        |> put_req_header("content-type", "application/json")
        |> post("/webhooks/livekit", body)

      assert json_response(conn, 200) == %{"status" => "ok"}
      assert %Participation{role: "viewer"} = Repo.get_by!(Participation, user_id: member.id)
    end

    test "when the signature is wrong", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "not-a-token")
        |> post("/webhooks/livekit", "{}")

      assert response(conn, 401)
    end
  end
end
