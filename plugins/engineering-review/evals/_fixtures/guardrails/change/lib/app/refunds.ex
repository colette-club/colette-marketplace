defmodule App.Refunds do
  @moduledoc "Refunds payments."

  alias App.Payments

  @doc "Refunds the whole amount of `payment`."
  def refund(%{id: id, amount: amount}), do: Payments.refund(id, amount)

  @doc "Refunds `amount` cents of `payment`, at most its whole amount."
  # credo:disable-for-next-line Credo.Check.Refactor.Nesting
  def partial_refund(%{id: id, amount: total}, amount) do
    if amount > 0 do
      if amount <= total do
        Payments.refund(id, amount)
      else
        {:error, :exceeds_payment}
      end
    else
      {:error, :invalid_amount}
    end
  end
end
