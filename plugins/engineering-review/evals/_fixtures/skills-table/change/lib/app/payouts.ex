defmodule App.Payouts do
  @moduledoc "Payouts to the hosts of an activity."

  @doc "Returns the sum, in cents, of the given payouts."
  @spec total([integer()]) :: integer()
  def total(amounts), do: Enum.sum(amounts)

  def split(total, hosts) do
    share = Float.round(total / hosts, 2)
    List.duplicate(share, hosts)
  end
end
