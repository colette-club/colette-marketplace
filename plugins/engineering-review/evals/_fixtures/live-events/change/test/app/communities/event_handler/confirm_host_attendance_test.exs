defmodule App.Communities.EventHandler.ConfirmHostAttendanceTest do
  use App.DataCase, async: true
  use ExEventBus.Testing, ex_event_bus: App.EventBus

  alias App.Communities.EventHandler.ConfirmHostAttendance
  alias App.Live

  describe "handle_event/1" do
    test "when the organizer is registered" do
      organizer = insert(:user)
      activity = insert(:activity, organizer: organizer)
      registration = insert(:registration, activity: activity, user: organizer, attended_at: nil)
      session = insert(:live_session, activity: activity, status: "live")
      {:ok, _seen} = Live.mark_host_seen(session)

      assert %{success: 1, failure: 0} = execute_events(event_handler: ConfirmHostAttendance)
      assert %DateTime{} = Repo.reload(registration).attended_at
    end

    test "when the activity has no organizer and its creator is registered" do
      creator = insert(:user)
      activity = insert(:activity, organizer: nil, creator: creator)
      registration = insert(:registration, activity: activity, user: creator, attended_at: nil)
      session = insert(:live_session, activity: activity, status: "live")
      {:ok, _seen} = Live.mark_host_seen(session)

      assert %{success: 1, failure: 0} = execute_events(event_handler: ConfirmHostAttendance)
      assert %DateTime{} = Repo.reload(registration).attended_at
    end

    test "when the host has no registration" do
      organizer = insert(:user)
      activity = insert(:activity, organizer: organizer)
      session = insert(:live_session, activity: activity, status: "live")
      {:ok, _seen} = Live.mark_host_seen(session)

      assert %{success: 1, failure: 0} = execute_events(event_handler: ConfirmHostAttendance)
    end
  end
end
