defmodule App.Payments.PaymentEvent do
  @moduledoc "A payment's outcome, as the payment adapter reports it."

  @enforce_keys [:payment_intent_id, :outcome]
  defstruct [:payment_intent_id, :outcome]

  @type t :: %__MODULE__{payment_intent_id: String.t(), outcome: :succeeded | :failed}
end
