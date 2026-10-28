defmodule App.Live.WindowTest do
  use ExUnit.Case, async: false

  alias App.Communities.Activity
  alias App.Live.Window

  setup do
    live = Application.fetch_env!(:app, :live)
    on_exit(fn -> Application.put_env(:app, :live, live) end)
  end

  describe "open?/2" do
    test "when the room opens 15 minutes before the start and it is 15 minutes before" do
      Application.put_env(:app, :live, adapter: App.Live.AdapterMock, opens_before_minutes: 15)
      activity = %Activity{starts_at: ~U[2026-11-02 18:00:00Z]}

      assert Window.open?(activity, ~U[2026-11-02 17:45:00Z])
    end

    test "when the room opens 15 minutes before the start and it is 16 minutes before" do
      Application.put_env(:app, :live, adapter: App.Live.AdapterMock, opens_before_minutes: 15)
      activity = %Activity{starts_at: ~U[2026-11-02 18:00:00Z]}

      refute Window.open?(activity, ~U[2026-11-02 17:44:00Z])
    end

    test "when the room opens 30 minutes before the start and it is 20 minutes before" do
      Application.put_env(:app, :live, adapter: App.Live.AdapterMock, opens_before_minutes: 30)
      activity = %Activity{starts_at: ~U[2026-11-02 18:00:00Z]}

      assert Window.open?(activity, ~U[2026-11-02 17:40:00Z])
    end
  end
end
