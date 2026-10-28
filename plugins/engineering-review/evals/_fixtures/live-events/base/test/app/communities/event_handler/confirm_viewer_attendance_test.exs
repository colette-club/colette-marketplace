defmodule App.Communities.EventHandler.ConfirmViewerAttendanceTest do
  use App.DataCase, async: true
  use ExEventBus.Testing, ex_event_bus: App.EventBus

  alias App.Communities.EventHandler.ConfirmViewerAttendance
  alias App.Live

  describe "handle_event/1" do
    test "when the viewer is registered" do
      viewer = insert(:user)
      activity = insert(:activity)
      registration = insert(:registration, activity: activity, user: viewer, attended_at: nil)
      session = insert(:live_session, activity: activity, status: "live")
      {:ok, _participation} = Live.record_participation(session, viewer.id)

      assert %{success: 1, failure: 0} = execute_events(event_handler: ConfirmViewerAttendance)
      assert %DateTime{} = Repo.reload(registration).attended_at
    end

    test "when the viewer is not registered" do
      viewer = insert(:user)
      session = insert(:live_session, status: "live")
      {:ok, _participation} = Live.record_participation(session, viewer.id)

      assert %{success: 1, failure: 0} = execute_events(event_handler: ConfirmViewerAttendance)
    end
  end
end
