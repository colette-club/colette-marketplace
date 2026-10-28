defmodule AppWeb.Webhooks.PaymentsController do
  @moduledoc "Receives the payment provider's events. Every signed event is answered 200; a failure to record is logged."
  use AppWeb, :controller

  alias App.Payments

  require Logger

  def create(%Plug.Conn{assigns: %{payment_event: event}} = conn, _params) do
    event
    |> Payments.record_payment_event()
    |> log_failure()

    json(conn, %{status: "ok"})
  end

  defp log_failure({:ok, _recorded}), do: :ok
  defp log_failure({:error, reason}), do: Logger.warning("Payment event not recorded: #{inspect(reason)}")
end
