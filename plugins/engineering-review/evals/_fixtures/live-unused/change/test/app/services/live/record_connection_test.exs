defmodule App.Services.Live.RecordConnectionTest do
  use App.DataCase, async: true

  alias App.Live.{Connection, Participation, Session}
  alias App.Services.Live.RecordConnection

  describe "run/2" do
    test "when a viewer connects" do
      activity = insert(:activity)
      member = insert(:user)

      assert {:ok, %Participation{role: "viewer"}} =
               RecordConnection.run(%Connection{activity_id: activity.id, user_id: member.id, role: :viewer})
    end

    test "when the host connects" do
      activity = insert(:activity)

      assert {:ok, %Participation{role: "host"}} =
               RecordConnection.run(%Connection{activity_id: activity.id, user_id: activity.organizer_id, role: :host})

      assert %Session{host_last_seen_at: %DateTime{}} = Repo.get_by!(Session, activity_id: activity.id)
    end

    test "when the host has ended the run" do
      session = insert(:live_session, status: "ended")
      member = insert(:user)

      assert {:ok, :ignored} =
               RecordConnection.run(%Connection{activity_id: session.activity_id, user_id: member.id, role: :viewer})

      assert Repo.aggregate(Participation, :count) == 0
    end
  end
end
