defmodule App.RefundsTest do
  use ExUnit.Case, async: true

  alias App.Refunds

  describe "refund/1" do
    test "when the payment has an amount" do
      assert {:ok, %{id: "p1", refunded: 500}} = Refunds.refund(%{id: "p1", amount: 500})
    end
  end

  describe "partial_refund/2" do
    test "when the amount is below the payment's" do
      assert {:ok, %{id: "p1", refunded: 200}} = Refunds.partial_refund(%{id: "p1", amount: 500}, 200)
    end
  end
end
