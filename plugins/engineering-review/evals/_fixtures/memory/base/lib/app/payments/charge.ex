defmodule App.Payments.Charge do
  @moduledoc "Charges a member's saved card."

  require Logger

  alias App.Payments.StripeClient

  @doc "Charges the member for an amount in cents."
  def run(member, amount_cents) do
    StripeClient.create_charge(member.stripe_customer_id, amount_cents)
  end
end
