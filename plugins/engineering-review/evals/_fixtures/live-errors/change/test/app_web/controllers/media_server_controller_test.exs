defmodule AppWeb.MediaServerControllerTest do
  use AppWeb.ConnCase, async: true

  import Mox

  alias App.Live.Connection
  alias App.Live.Participation

  setup :verify_on_exit!

  describe "POST /webhooks/media-server" do
    test "when a person connects", %{conn: conn} do
      activity = insert(:activity)
      user = insert(:user)
      connection = %Connection{activity_id: activity.id, user_id: user.id, role: :viewer}
      expect(App.Live.AdapterMock, :verify_webhook, fn "signed", _body -> {:ok, connection} end)

      conn =
        conn
        |> put_req_header("authorization", "signed")
        |> put_req_header("content-type", "application/json")
        |> post("/webhooks/media-server", "{}")

      assert json_response(conn, 200) == %{"status" => "ok"}
      assert [%Participation{user_id: user_id}] = Repo.all(Participation)
      assert user_id == user.id
    end

    test "when the event is not a connection", %{conn: conn} do
      expect(App.Live.AdapterMock, :verify_webhook, fn "signed", _body -> {:ok, :ignored} end)

      conn =
        conn
        |> put_req_header("authorization", "signed")
        |> put_req_header("content-type", "application/json")
        |> post("/webhooks/media-server", "{}")

      assert json_response(conn, 200) == %{"status" => "ok"}
      assert Repo.all(Participation) == []
    end
  end
end
