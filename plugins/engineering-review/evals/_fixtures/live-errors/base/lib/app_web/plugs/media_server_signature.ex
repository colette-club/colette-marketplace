defmodule AppWeb.Plugs.MediaServerSignature do
  @moduledoc """
  Accepts a media server webhook only when the media server signed it. Assigns
  the reported `:connection`, or nothing for an event that is not a
  connection; answers 401 otherwise.
  """
  @behaviour Plug

  alias App.Live
  alias AppWeb.Support.RawBody

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{} = conn, _opts) do
    token = conn |> Plug.Conn.get_req_header("authorization") |> List.first()
    body = RawBody.read(conn)

    conn
    |> verified(Live.verify_webhook(token, body))
  end

  defp verified(conn, {:ok, %Live.Connection{} = connection}), do: Plug.Conn.assign(conn, :connection, connection)
  defp verified(conn, {:ok, :ignored}), do: conn

  defp verified(conn, {:error, :invalid_signature}) do
    conn
    |> Plug.Conn.send_resp(401, "")
    |> Plug.Conn.halt()
  end
end
