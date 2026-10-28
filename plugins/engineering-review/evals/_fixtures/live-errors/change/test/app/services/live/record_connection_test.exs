defmodule App.Services.Live.RecordConnectionTest do
  use App.DataCase, async: true

  alias App.Live.Connection
  alias App.Live.Participation
  alias App.Live.Session
  alias App.Services.Live.RecordConnection

  describe "run/1" do
    test "when the room is not open yet" do
      activity = insert(:activity)
      user = insert(:user)

      assert {:ok, %Participation{user_id: user_id}} =
               RecordConnection.run(%Connection{activity_id: activity.id, user_id: user.id, role: :viewer})

      assert user_id == user.id
      assert [%Session{}] = Repo.all(Session)
    end

    test "when the room is open" do
      session = insert(:live_session)
      user = insert(:user)

      assert {:ok, %Participation{session_id: session_id}} =
               RecordConnection.run(%Connection{activity_id: session.activity_id, user_id: user.id, role: :host})

      assert session_id == session.id
    end
  end
end
