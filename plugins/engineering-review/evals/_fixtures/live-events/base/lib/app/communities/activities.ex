defmodule App.Communities.Activities do
  @moduledoc "Activities of a community."

  alias App.Communities.Activity
  alias App.Errors
  alias App.Repo

  @doc "The activity, or `NotFoundError`."
  def get_activity(id) when is_binary(id) do
    case Repo.get(Activity, id) do
      %Activity{} = activity -> {:ok, activity}
      nil -> {:error, Errors.NotFoundError.new(resource_type: "Activity", resource_id: id)}
    end
  end

  @doc "Updates an activity; an admin may change its organizer at any time."
  def update_activity(%Activity{} = activity, attrs) do
    activity
    |> Activity.update_changeset(attrs)
    |> Repo.update()
  end
end
