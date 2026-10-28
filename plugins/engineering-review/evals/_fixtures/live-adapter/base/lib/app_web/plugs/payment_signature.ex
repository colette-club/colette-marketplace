defmodule AppWeb.Plugs.PaymentSignature do
  @moduledoc "Lets through only the payment events the payment adapter verifies, assigned as `:payment_event`."
  @behaviour Plug

  alias App.Payments
  alias AppWeb.Support.RawBody

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    signature = conn |> Plug.Conn.get_req_header("stripe-signature") |> List.first()
    body = RawBody.read(conn)

    case Payments.verify_webhook(signature, body) do
      {:ok, :ignored} -> conn |> Plug.Conn.send_resp(200, "") |> Plug.Conn.halt()
      {:ok, event} -> Plug.Conn.assign(conn, :payment_event, event)
      {:error, :invalid_signature} -> conn |> Plug.Conn.send_resp(401, "") |> Plug.Conn.halt()
    end
  end
end
