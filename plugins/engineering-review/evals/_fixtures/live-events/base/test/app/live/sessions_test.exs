defmodule App.Live.SessionsTest do
  use App.DataCase, async: true
  use ExEventBus.Testing, ex_event_bus: App.EventBus

  alias App.Live.Session
  alias App.Live.Sessions

  describe "mark_host_seen/1" do
    test "when the host was away" do
      session = insert(:live_session, status: "live", host_absent_since: ~U[2026-10-28 10:00:00.000000Z])

      assert {:ok, %Session{host_last_seen_at: %DateTime{}, host_absent_since: nil}} = Sessions.mark_host_seen(session)
    end
  end

  describe "mark_host_absent/1" do
    test "when the host was in the room" do
      session = insert(:live_session, status: "live", host_absent_since: nil)

      assert {:ok, %Session{host_absent_since: %DateTime{}}} = Sessions.mark_host_absent(session)
    end

    test "when the host was already away" do
      session = insert(:live_session, status: "live", host_absent_since: ~U[2026-10-28 10:00:00.000000Z])

      assert {:ok, %Session{host_absent_since: ~U[2026-10-28 10:00:00.000000Z]}} = Sessions.mark_host_absent(session)
    end
  end

  describe "start_live/1" do
    test "when the run waits" do
      session = insert(:live_session, status: "waiting")

      assert {:ok, %Session{status: "live"}} = Sessions.start_live(session)
    end

    test "when the run is already live" do
      session = insert(:live_session, status: "live")

      assert {:ok, %Session{status: "live"}} = Sessions.start_live(session)
    end
  end
end
