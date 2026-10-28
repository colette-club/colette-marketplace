defmodule App.Live.EnterTest do
  use App.DataCase, async: true

  alias App.Errors
  alias App.Live.Enter

  describe "role/2" do
    test "when the person is the organizer" do
      organizer = insert(:user)
      activity = insert(:activity, organizer: organizer)

      assert {:ok, :host} = Enter.role(activity, organizer)
    end

    test "when the person created an activity that has no organizer" do
      creator = insert(:user)
      activity = insert(:activity, organizer: nil, creator: creator)

      assert {:ok, :host} = Enter.role(activity, creator)
    end

    test "when the person holds a validated registration" do
      member = insert(:user)
      activity = insert(:activity)
      insert(:registration, activity: activity, user: member, status: "validated")

      assert {:ok, :viewer} = Enter.role(activity, member)
    end

    test "when the person is not registered" do
      activity = insert(:activity)

      assert {:error, %Errors.NotAnAttendeeError{}} = Enter.role(activity, insert(:user))
    end
  end
end
