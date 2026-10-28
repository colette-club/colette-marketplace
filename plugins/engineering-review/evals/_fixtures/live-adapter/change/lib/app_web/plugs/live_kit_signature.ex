defmodule AppWeb.Plugs.LiveKitSignature do
  @moduledoc "Lets through only the LiveKit events signed with the webhook secret, assigned as `:livekit_event`."
  @behaviour Plug

  alias App.Live.LiveKitWebhook
  alias AppWeb.Support.RawBody

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    token = conn |> Plug.Conn.get_req_header("authorization") |> List.first()
    body = RawBody.read(conn)

    case LiveKitWebhook.verify(token, body) do
      {:ok, event} -> Plug.Conn.assign(conn, :livekit_event, event)
      {:error, _reason} -> conn |> Plug.Conn.send_resp(401, "") |> Plug.Conn.halt()
    end
  end
end
