defmodule App.Payments.Charge do
  @moduledoc "Charges a member's saved card."

  require Logger

  alias App.Payments.StripeClient

  @doc "Charges the member for an amount in cents and logs the result."
  def run(member, amount_cents) do
    result = StripeClient.create_charge(member.stripe_customer_id, amount_cents)
    Logger.info("charge #{inspect(result)} for card #{member.card_last4}")
    result
  end
end
