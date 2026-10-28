defmodule App.Services.Live.RecordConnectionTest do
  use App.DataCase, async: true

  alias App.Live.{Connection, Participation}
  alias App.Services.Live.RecordConnection

  describe "run/2" do
    test "when a viewer connects" do
      activity = insert(:activity)
      member = insert(:user)

      assert {:ok, %Participation{}} =
               RecordConnection.run(%Connection{activity_id: activity.id, user_id: member.id, role: :viewer})
    end

    test "when the host connects" do
      activity = insert(:activity)

      assert {:ok, :ignored} =
               RecordConnection.run(%Connection{activity_id: activity.id, user_id: activity.organizer_id, role: :host})

      assert Repo.aggregate(Participation, :count) == 0
    end
  end
end
