defmodule App.Payments do
  @moduledoc "Payments, through the configured payment adapter."

  alias App.Payments.{PaymentEvent, Payments}

  @spec verify_webhook(String.t() | nil, binary()) :: {:ok, PaymentEvent.t() | :ignored} | {:error, :invalid_signature}
  def verify_webhook(signature, body), do: get_adapter().verify_webhook(signature, body)

  defdelegate record_payment_event(event), to: Payments

  defp get_adapter, do: :app |> Application.fetch_env!(:payments) |> Keyword.fetch!(:adapter)
end
