defmodule App.Live.WindowTest do
  use ExUnit.Case, async: true

  alias App.Communities.Activity
  alias App.Live.Window

  describe "open?/2" do
    test "when it is exactly 15 minutes before the start" do
      activity = %Activity{starts_at: ~U[2026-11-02 18:00:00Z]}

      assert Window.open?(activity, ~U[2026-11-02 17:45:00Z])
    end

    test "when it is 16 minutes before the start" do
      activity = %Activity{starts_at: ~U[2026-11-02 18:00:00Z]}

      refute Window.open?(activity, ~U[2026-11-02 17:44:00Z])
    end

    test "when the activity has started" do
      activity = %Activity{starts_at: ~U[2026-11-02 18:00:00Z]}

      assert Window.open?(activity, ~U[2026-11-02 18:30:00Z])
    end
  end
end
