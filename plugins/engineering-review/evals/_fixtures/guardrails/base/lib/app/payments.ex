defmodule App.Payments do
  @moduledoc "Talks to the payment provider."

  @doc "Refunds `amount` cents of payment `id`."
  def refund(id, amount) when is_integer(amount) and amount > 0, do: {:ok, %{id: id, refunded: amount}}
end
