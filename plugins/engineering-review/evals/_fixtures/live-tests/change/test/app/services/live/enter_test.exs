defmodule App.Services.Live.EnterTest do
  use App.DataCase, async: true

  alias App.Errors
  alias App.Services.Live.Enter

  defp starting_in(minutes), do: DateTime.add(DateTime.utc_now(), minutes * 60, :second) |> DateTime.truncate(:second)

  describe "run/2" do
    test "when the organizer enters once the room is open" do
      organizer = insert(:user)
      activity = insert(:activity, organizer: organizer, starts_at: starting_in(10), ends_at: starting_in(70))

      assert {:ok, :host} = Enter.run(activity.id, organizer.id)
    end

    test "when the creator enters an activity that has no organizer" do
      creator = insert(:user)
      activity = insert(:activity, organizer: nil, creator: creator, starts_at: starting_in(10), ends_at: starting_in(70))

      assert {:ok, :host} = Enter.run(activity.id, creator.id)
    end

    test "when the creator enters an activity that has an organizer" do
      creator = insert(:user)
      activity = insert(:activity, organizer: insert(:user), creator: creator, starts_at: starting_in(10), ends_at: starting_in(70))

      assert {:error, %Errors.NotAnAttendeeError{}} = Enter.run(activity.id, creator.id)
    end

    test "when a registered member enters" do
      member = insert(:user)
      activity = insert(:activity, starts_at: starting_in(10), ends_at: starting_in(70))
      insert(:registration, activity: activity, user: member, status: "validated")

      assert {:ok, :viewer} = Enter.run(activity.id, member.id)
    end

    test "when the member's registration is not validated" do
      member = insert(:user)
      activity = insert(:activity, starts_at: starting_in(10), ends_at: starting_in(70))
      insert(:registration, activity: activity, user: member, status: "pending")

      assert {:error, %Errors.NotAnAttendeeError{}} = Enter.run(activity.id, member.id)
    end

    test "when the room is not open yet" do
      member = insert(:user)
      activity = insert(:activity, starts_at: starting_in(30), ends_at: starting_in(90))
      insert(:registration, activity: activity, user: member, status: "validated")

      assert {:error, %Errors.LiveRoomNotOpenError{}} = Enter.run(activity.id, member.id)
    end

    test "when the activity is archived" do
      organizer = insert(:user)

      activity =
        insert(:activity, organizer: organizer, archived_at: DateTime.utc_now(), starts_at: starting_in(10), ends_at: starting_in(70))

      assert {:error, %Errors.ActivityArchivedError{}} = Enter.run(activity.id, organizer.id)
    end

    test "when the activity is over and its live still runs" do
      member = insert(:user)
      activity = insert(:activity, starts_at: starting_in(-90), ends_at: starting_in(-30))
      insert(:registration, activity: activity, user: member, status: "validated")
      insert(:live_session, activity: activity, status: "live", activity_starts_at: DateTime.to_naive(activity.starts_at))

      assert {:ok, :viewer} = Enter.run(activity.id, member.id)
    end

    test "when the activity is over and has no run" do
      member = insert(:user)
      activity = insert(:activity, starts_at: starting_in(-90), ends_at: starting_in(-30))
      insert(:registration, activity: activity, user: member, status: "validated")

      assert {:error, %Errors.LiveOverError{}} = Enter.run(activity.id, member.id)
    end

    test "when the host has ended the run and a member enters" do
      member = insert(:user)
      activity = insert(:activity, starts_at: starting_in(-10), ends_at: starting_in(50))
      insert(:registration, activity: activity, user: member, status: "validated")
      insert(:live_session, activity: activity, status: "ended", activity_starts_at: DateTime.to_naive(activity.starts_at))

      assert {:error, %Errors.LiveOverError{}} = Enter.run(activity.id, member.id)
    end

    test "when the host has ended the run and enters again before the end" do
      organizer = insert(:user)
      activity = insert(:activity, organizer: organizer, starts_at: starting_in(-10), ends_at: starting_in(50))
      insert(:live_session, activity: activity, status: "ended", activity_starts_at: DateTime.to_naive(activity.starts_at))

      assert {:ok, :host} = Enter.run(activity.id, organizer.id)
    end

    test "when the host has ended the run and the activity is over" do
      organizer = insert(:user)
      activity = insert(:activity, organizer: organizer, starts_at: starting_in(-90), ends_at: starting_in(-30))
      insert(:live_session, activity: activity, status: "ended", activity_starts_at: DateTime.to_naive(activity.starts_at))

      assert {:error, %Errors.LiveOverError{}} = Enter.run(activity.id, organizer.id)
    end
  end
end
