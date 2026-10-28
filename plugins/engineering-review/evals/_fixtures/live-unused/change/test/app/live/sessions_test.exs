defmodule App.Live.SessionsTest do
  use App.DataCase, async: true
  use ExEventBus.Testing, ex_event_bus: App.EventBus

  alias App.Live.{Events, Session, Sessions}

  describe "get_or_create_session/2" do
    test "when the room has no run yet" do
      activity = insert(:activity)

      assert {:ok, %Session{activity_id: activity_id, status: "waiting"}} = Sessions.get_or_create_session(activity.id)
      assert activity_id == activity.id
      assert_event_received(Events.LiveSessionCreated)
    end

    test "when the room already has a run" do
      session = insert(:live_session)

      assert {:ok, %Session{id: id}} = Sessions.get_or_create_session(session.activity_id)
      assert id == session.id
      refute_event_received(Events.LiveSessionCreated)
    end
  end

  describe "mark_host_seen/1" do
    test "when the host was away" do
      session = insert(:live_session, host_absent_since: ~U[2026-10-28 09:00:00.000000Z])

      assert {:ok, %Session{host_last_seen_at: %DateTime{}, host_absent_since: nil}} = Sessions.mark_host_seen(session)
    end
  end
end
