defmodule App.PayoutsTest do
  use ExUnit.Case, async: true

  alias App.Payouts

  describe "total/1" do
    test "sums the payouts in cents" do
      assert Payouts.total([1_000, 250]) == 1_250
    end
  end

  describe "split/2" do
    test "splits a total between the hosts" do
      assert Payouts.split(30.0, 3) == [10.0, 10.0, 10.0]
    end
  end
end
