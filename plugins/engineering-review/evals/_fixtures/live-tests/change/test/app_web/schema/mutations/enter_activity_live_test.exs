defmodule AppWeb.Schema.Mutations.EnterActivityLiveTest do
  use AppWeb.ConnCase, async: true
  use AppWeb.GqlCase

  @moduletag :gql

  load_gql_file("EnterActivityLive.gql")

  describe "EnterActivityLive.gql" do
    test "when not authenticated" do
      activity = insert(:activity)

      query_data = query_gql(variables: %{"activityId" => activity.id})

      assert nil == get_in(query_data, ["data", "enterActivityLive"])
      assert "UnauthenticatedError" == get_in(query_data, ["errors", Access.at(0), "extensions", "errorCode"])
    end

    test "when a registered member enters an open room" do
      member = insert(:user)
      starts_at = DateTime.add(DateTime.utc_now(), 600, :second) |> DateTime.truncate(:second)
      activity = insert(:activity, starts_at: starts_at, ends_at: DateTime.add(starts_at, 3600, :second))
      insert(:registration, activity: activity, user: member, status: "validated")

      query_data = query_gql(variables: %{"activityId" => activity.id}, current_user: member)

      assert nil == get_in(query_data, ["errors"])
      assert "VIEWER" == get_in(query_data, ["data", "enterActivityLive", "role"])
    end

    test "when a member who is not registered enters" do
      member = insert(:user)
      starts_at = DateTime.add(DateTime.utc_now(), 600, :second) |> DateTime.truncate(:second)
      activity = insert(:activity, starts_at: starts_at, ends_at: DateTime.add(starts_at, 3600, :second))

      query_data = query_gql(variables: %{"activityId" => activity.id}, current_user: member)

      assert "NotAnAttendeeError" == get_in(query_data, ["errors", Access.at(0), "extensions", "errorCode"])
    end
  end
end
