defmodule App.Services.Live.RecordConnectionTest do
  use App.DataCase, async: true

  alias App.Live.Participation
  alias App.Services.Live.RecordConnection

  defp joined(activity_id, identity, metadata) do
    %{
      "event" => "participant_joined",
      "room" => %{"name" => "activity-" <> activity_id},
      "participant" => %{"identity" => identity, "metadata" => metadata}
    }
  end

  describe "run/2" do
    test "when a viewer joins" do
      activity = insert(:activity)
      member = insert(:user)

      assert {:ok, %Participation{role: "viewer"}} = RecordConnection.run(joined(activity.id, member.id, ~s({"role":"viewer"})))
    end

    test "when the host joins" do
      activity = insert(:activity)

      assert {:ok, %Participation{role: "host"}} =
               RecordConnection.run(joined(activity.id, activity.organizer_id, ~s({"role":"host"})))
    end

    test "when the participant has no role" do
      activity = insert(:activity)
      member = insert(:user)

      assert {:ok, :ignored} = RecordConnection.run(joined(activity.id, member.id, "{}"))
    end

    test "when the metadata is not text" do
      activity = insert(:activity)
      member = insert(:user)

      assert {:ok, :ignored} = RecordConnection.run(joined(activity.id, member.id, %{"role" => "viewer"}))
    end

    test "when the room is not an activity's" do
      member = insert(:user)
      event = %{"event" => "participant_joined", "room" => %{"name" => "lobby"}, "participant" => %{"identity" => member.id}}

      assert {:ok, :ignored} = RecordConnection.run(event)
    end

    test "when the event is not a connection" do
      assert {:ok, :ignored} = RecordConnection.run(%{"event" => "room_finished"})
      assert Repo.aggregate(Participation, :count) == 0
    end
  end
end
