defmodule AppWeb.Plugs.MediaServerSignatureTest do
  use AppWeb.ConnCase, async: true

  import Mox

  alias App.Live.Connection
  alias AppWeb.Plugs.MediaServerSignature

  setup :verify_on_exit!

  describe "call/2" do
    test "when the media server signed a connection" do
      connection = %Connection{activity_id: Ecto.UUID.generate(), user_id: Ecto.UUID.generate(), role: :viewer}
      expect(App.Live.AdapterMock, :verify_webhook, fn "signed", "{}" -> {:ok, connection} end)

      conn = build_conn(:post, "/", "{}") |> put_req_header("authorization", "signed") |> MediaServerSignature.call([])

      assert conn.assigns.connection == connection
      refute conn.halted
    end

    test "when the event is not a connection" do
      expect(App.Live.AdapterMock, :verify_webhook, fn "signed", "{}" -> {:ok, :ignored} end)

      conn = build_conn(:post, "/", "{}") |> put_req_header("authorization", "signed") |> MediaServerSignature.call([])

      refute Map.has_key?(conn.assigns, :connection)
      refute conn.halted
    end

    test "when the body is not signed" do
      expect(App.Live.AdapterMock, :verify_webhook, fn nil, "{}" -> {:error, :invalid_signature} end)

      conn = build_conn(:post, "/", "{}") |> MediaServerSignature.call([])

      assert conn.status == 401
      assert conn.halted
    end
  end
end
