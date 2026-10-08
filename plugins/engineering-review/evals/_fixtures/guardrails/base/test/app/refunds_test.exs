defmodule App.RefundsTest do
  use ExUnit.Case, async: true

  alias App.Refunds

  describe "refund/1" do
    test "when the payment has an amount" do
      assert {:ok, %{id: "p1", refunded: 500}} = Refunds.refund(%{id: "p1", amount: 500})
    end
  end
end
