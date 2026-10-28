defmodule App.Live.SessionsTest do
  use App.DataCase, async: true

  alias App.Errors
  alias App.Live
  alias App.Live.Session

  describe "get_session/1" do
    test "when the activity has several runs" do
      activity = insert(:activity)
      insert(:live_session, activity: activity, inserted_at: ~U[2026-10-01 10:00:00.000000Z])
      latest = insert(:live_session, activity: activity, inserted_at: ~U[2026-10-01 11:00:00.000000Z])
      latest_id = latest.id

      assert {:ok, %Session{id: ^latest_id}} = Live.get_session(activity.id)
    end

    test "when another activity has a later run" do
      activity = insert(:activity)
      own = insert(:live_session, activity: activity, inserted_at: ~U[2026-10-01 10:00:00.000000Z])
      insert(:live_session, inserted_at: ~U[2026-10-01 11:00:00.000000Z])
      own_id = own.id

      assert {:ok, %Session{id: ^own_id}} = Live.get_session(activity.id)
    end

    test "when the activity has no run" do
      activity = insert(:activity)

      assert {:error, %Errors.NotFoundError{resource_type: "LiveSession"}} = Live.get_session(activity.id)
    end
  end
end
