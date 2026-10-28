defmodule App.Live.SessionsTest do
  use App.DataCase, async: true

  alias App.Errors
  alias App.Live.Session
  alias App.Live.Sessions

  describe "get_session/1" do
    test "when the room is open" do
      session = insert(:live_session)

      assert {:ok, %Session{id: id}} = Sessions.get_session(session.activity_id)
      assert id == session.id
    end

    test "when the room never opened" do
      activity = insert(:activity)

      assert {:error, %Errors.NotFoundError{resource_type: "LiveSession"}} = Sessions.get_session(activity.id)
    end
  end

  describe "get_or_create_session/1" do
    test "when the room never opened" do
      activity = insert(:activity)

      assert {:ok, %Session{activity_id: activity_id}} = Sessions.get_or_create_session(activity.id)
      assert activity_id == activity.id
    end

    test "when the room is open" do
      session = insert(:live_session)

      assert {:ok, %Session{id: id}} = Sessions.get_or_create_session(session.activity_id)
      assert id == session.id
    end
  end
end
