defmodule App.Refunds do
  @moduledoc "Refunds payments."

  alias App.Payments

  @doc "Refunds the whole amount of `payment`."
  def refund(%{id: id, amount: amount}), do: Payments.refund(id, amount)
end
