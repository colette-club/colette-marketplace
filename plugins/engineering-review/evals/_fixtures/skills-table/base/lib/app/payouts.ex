defmodule App.Payouts do
  @moduledoc "Payouts to the hosts of an activity. Amounts are in cents."

  @doc "Returns the sum, in cents, of the given payouts."
  @spec total([integer()]) :: integer()
  def total(amounts), do: Enum.sum(amounts)
end
