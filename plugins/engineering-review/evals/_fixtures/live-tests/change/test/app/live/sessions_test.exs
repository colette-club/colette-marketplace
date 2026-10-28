defmodule App.Live.SessionsTest do
  use App.DataCase, async: true

  alias App.Errors
  alias App.Live
  alias App.Live.Session

  describe "get_session/1" do
    test "when the activity has runs" do
      activity = insert(:activity)
      insert(:live_session, activity: activity, inserted_at: ~U[2026-10-01 10:00:00.000000Z])
      latest = insert(:live_session, activity: activity, inserted_at: ~U[2026-10-01 11:00:00.000000Z])
      latest_id = latest.id

      assert {:ok, %Session{id: ^latest_id}} = Live.get_session(activity.id)
    end

    test "when the activity has no run" do
      activity = insert(:activity)

      assert {:error, %Errors.NotFoundError{resource_type: "LiveSession"}} = Live.get_session(activity.id)
    end

    test "when the latest run ended and the activity has not moved" do
      activity = insert(:activity, starts_at: ~U[2026-11-02 18:00:00Z])
      ended = insert(:live_session, activity: activity, status: "ended", activity_starts_at: ~N[2026-11-02 18:00:00])
      ended_id = ended.id

      assert {:ok, %Session{id: ^ended_id, status: "ended"}} = Live.get_session(activity.id)
    end

    test "when the latest run ended and the activity has moved since" do
      activity = insert(:activity, starts_at: ~U[2026-11-09 18:00:00Z])
      insert(:live_session, activity: activity, status: "ended", activity_starts_at: ~N[2026-11-02 18:00:00])

      assert {:error, %Errors.NotFoundError{resource_type: "LiveSession"}} = Live.get_session(activity.id)
    end

    test "when the latest run is live and the activity has moved since" do
      activity = insert(:activity, starts_at: ~U[2026-11-09 18:00:00Z])
      live = insert(:live_session, activity: activity, status: "live", activity_starts_at: ~N[2026-11-02 18:00:00])
      live_id = live.id

      assert {:ok, %Session{id: ^live_id}} = Live.get_session(activity.id)
    end
  end

  describe "open_session/1" do
    test "when the activity starts at a given time" do
      activity = insert(:activity, starts_at: ~U[2026-11-02 18:00:00Z])

      assert {:ok, %Session{status: "waiting", activity_starts_at: ~N[2026-11-02 18:00:00]}} =
               Live.open_session(activity)
    end
  end

  describe "start_live/1" do
    test "when the run waits" do
      session = insert(:live_session, status: "waiting")

      assert {:ok, %Session{status: "live"}} = Live.start_live(session)
    end
  end

  describe "end_live/1" do
    test "when the run is live" do
      session = insert(:live_session, status: "live")

      assert {:ok, %Session{status: "ended"}} = Live.end_live(session)
    end
  end
end
