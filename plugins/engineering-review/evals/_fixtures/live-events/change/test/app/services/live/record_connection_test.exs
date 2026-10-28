defmodule App.Services.Live.RecordConnectionTest do
  use App.DataCase, async: true
  use ExEventBus.Testing, ex_event_bus: App.EventBus

  alias App.Live.Connection
  alias App.Live.Events
  alias App.Live.Participation
  alias App.Live.Session
  alias App.Services.Live.RecordConnection

  describe "run/2" do
    test "when the host connects to a waiting run" do
      organizer = insert(:user)
      activity = insert(:activity, organizer: organizer)
      session = insert(:live_session, activity: activity, status: "waiting")

      assert {:ok, %Session{status: "live", host_last_seen_at: %DateTime{}}} =
               RecordConnection.run(%Connection{activity_id: activity.id, user_id: organizer.id, role: :host})

      assert Repo.reload(session).status == "live"
      assert_event_received(Events.LiveHostSeen)
    end

    test "when a viewer connects" do
      viewer = insert(:user)
      activity = insert(:activity)
      insert(:live_session, activity: activity, status: "live")

      assert {:ok, %Participation{user_id: user_id}} =
               RecordConnection.run(%Connection{activity_id: activity.id, user_id: viewer.id, role: :viewer})

      assert user_id == viewer.id
      assert_event_received(Events.LiveParticipationRecorded)
      refute_event_received(Events.LiveHostSeen)
    end

    test "when the activity has no run" do
      activity = insert(:activity)

      assert {:ok, :ignored} =
               RecordConnection.run(%Connection{activity_id: activity.id, user_id: insert(:user).id, role: :viewer})
    end
  end
end
