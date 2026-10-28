defmodule App.Communities.Activities do
  @moduledoc "Reads activities."

  alias App.Communities.Activities.Query
  alias App.Communities.Activity
  alias App.Errors
  alias App.Repo

  @doc "The activity with this id, or `NotFoundError`."
  @spec get_activity(binary()) :: {:ok, Activity.t()} | {:error, Errors.NotFoundError.t()}
  def get_activity(id) when is_binary(id) do
    Activity
    |> Repo.get(id)
    |> found()
  end

  @doc "The upcoming activities the member has not registered to, soonest first."
  @spec list_activities_to_join(binary()) :: [Activity.t()]
  def list_activities_to_join(user_id) when is_binary(user_id) do
    Activity
    |> Query.upcoming(DateTime.utc_now())
    |> Query.without_registration_of(user_id)
    |> Query.ordered_by_start()
    |> Query.paginate(%{first: 50})
    |> Repo.all()
  end

  defp found(%Activity{} = activity), do: {:ok, activity}
  defp found(nil), do: {:error, Errors.NotFoundError.new(resource_type: "Activity")}
end
