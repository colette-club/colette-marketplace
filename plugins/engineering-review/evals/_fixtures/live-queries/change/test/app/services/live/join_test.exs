defmodule App.Services.Live.JoinTest do
  use App.DataCase, async: true

  import Mox

  alias App.Errors
  alias App.Live.AdapterMock
  alias App.Services.Live.Join

  setup :verify_on_exit!

  defp starting_in(minutes), do: DateTime.utc_now() |> DateTime.add(minutes * 60, :second) |> DateTime.truncate(:second)

  describe "run/2" do
    test "when the organizer joins once the room is open" do
      organizer = insert(:user, first_name: "Ada")
      activity = insert(:activity, organizer: organizer, starts_at: starting_in(10))
      room = "activity-" <> activity.id
      organizer_id = organizer.id

      expect(AdapterMock, :mint_participant_token, fn %{room: ^room, identity: ^organizer_id, name: "Ada", role: :host} ->
        "host-token"
      end)

      expect(AdapterMock, :get_server_url, fn -> "wss://live.test" end)

      assert {:ok, %{token: "host-token", server_url: "wss://live.test", role: :host}} = Join.run(activity.id, organizer)
    end

    test "when a registered member joins once the room is open" do
      member = insert(:user, first_name: "Bo")
      activity = insert(:activity, starts_at: starting_in(10))
      insert(:registration, activity: activity, user: member, status: "validated")

      expect(AdapterMock, :mint_participant_token, fn %{role: :viewer} -> "viewer-token" end)
      expect(AdapterMock, :get_server_url, fn -> "wss://live.test" end)

      assert {:ok, %{token: "viewer-token", role: :viewer}} = Join.run(activity.id, member)
    end

    test "when the room is not open yet" do
      organizer = insert(:user)
      activity = insert(:activity, organizer: organizer, starts_at: starting_in(30))

      assert {:error, %Errors.LiveRoomNotOpenError{}} = Join.run(activity.id, organizer)
    end

    test "when the member is not registered" do
      activity = insert(:activity, starts_at: starting_in(10))

      assert {:error, %Errors.NotAnAttendeeError{}} = Join.run(activity.id, insert(:user))
    end

    test "when the host has ended the run and a member joins" do
      member = insert(:user)
      activity = insert(:activity, starts_at: starting_in(-10))
      insert(:registration, activity: activity, user: member, status: "validated")
      insert(:live_session, activity: activity, status: "ended")

      assert {:error, %Errors.LiveOverError{}} = Join.run(activity.id, member)
    end

    test "when the host has ended the run and joins again" do
      organizer = insert(:user)
      activity = insert(:activity, organizer: organizer, starts_at: starting_in(-10))
      insert(:live_session, activity: activity, status: "ended")

      expect(AdapterMock, :mint_participant_token, fn %{role: :host} -> "host-token" end)
      expect(AdapterMock, :get_server_url, fn -> "wss://live.test" end)

      assert {:ok, %{token: "host-token", role: :host}} = Join.run(activity.id, organizer)
    end

    test "when the activity does not exist" do
      assert {:error, %Errors.NotFoundError{resource_type: "Activity"}} = Join.run(Ecto.UUID.generate(), insert(:user))
    end
  end
end
