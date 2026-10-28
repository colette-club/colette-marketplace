defmodule AppWeb.Schema.Mutations.JoinActivityLiveTest do
  use AppWeb.ConnCase, async: true
  use AppWeb.GqlCase

  import Mox

  alias App.Live.AdapterMock

  @moduletag :gql

  setup :verify_on_exit!

  load_gql_file("JoinActivityLive.gql")

  describe "JoinActivityLive.gql" do
    test "when not authenticated" do
      activity = insert(:activity)

      query_data = query_gql(variables: %{"activityId" => activity.id})

      assert nil == get_in(query_data, ["data", "joinActivityLive"])
      assert "UnauthenticatedError" == get_in(query_data, ["errors", Access.at(0), "extensions", "errorCode"])
    end

    test "when a registered member joins an open room" do
      member = insert(:user)
      starts_at = DateTime.utc_now() |> DateTime.add(600, :second) |> DateTime.truncate(:second)
      activity = insert(:activity, starts_at: starts_at)
      insert(:registration, activity: activity, user: member, status: "validated")

      expect(AdapterMock, :mint_participant_token, fn %{role: :viewer} -> "viewer-token" end)
      expect(AdapterMock, :get_server_url, fn -> "wss://live.test" end)

      query_data = query_gql(variables: %{"activityId" => activity.id}, current_user: member)

      assert nil == get_in(query_data, ["errors"])

      assert %{"token" => "viewer-token", "serverUrl" => "wss://live.test", "role" => "VIEWER"} ==
               get_in(query_data, ["data", "joinActivityLive"])
    end
  end
end
