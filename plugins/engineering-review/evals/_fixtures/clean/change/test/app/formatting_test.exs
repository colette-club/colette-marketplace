defmodule App.FormattingTest do
  use ExUnit.Case, async: true

  alias App.Formatting

  describe "format_date/1" do
    test "when given a date" do
      assert Formatting.format_date(~D[2026-09-29]) == "29/09/2026"
    end
  end

  describe "format_price/1" do
    test "when the price is zero" do
      assert Formatting.format_price(0) == "Free"
    end

    test "when the price has cents" do
      assert Formatting.format_price(1250) == "12.50 €"
    end

    test "when the price has fewer than ten cents" do
      assert Formatting.format_price(1205) == "12.05 €"
    end

    test "when the price is negative" do
      assert_raise FunctionClauseError, fn -> Formatting.format_price(-100) end
    end
  end
end
