defmodule App.FormattingTest do
  use ExUnit.Case, async: true

  alias App.Formatting

  describe "format_date/1" do
    test "when given a date" do
      assert Formatting.format_date(~D[2026-09-29]) == "29/09/2026"
    end
  end
end
