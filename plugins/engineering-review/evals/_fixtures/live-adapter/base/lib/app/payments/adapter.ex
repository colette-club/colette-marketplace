defmodule App.Payments.Adapter do
  @moduledoc """
  The payment provider. The module set under `:adapter` of `config :app, :payments`
  implements it and reads its own settings.
  """

  alias App.Payments.PaymentEvent

  @callback create_payment_intent(amount_cents :: pos_integer(), currency :: String.t()) ::
              {:ok, String.t()} | {:error, term()}

  @doc """
  The provider's event, translated, when it signed this body; `:ignored` for an
  event this app does not handle.
  """
  @callback verify_webhook(signature :: String.t() | nil, body :: binary()) ::
              {:ok, PaymentEvent.t() | :ignored} | {:error, :invalid_signature}
end
