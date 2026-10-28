defmodule App.Communities.Activities do
  @moduledoc "Reads activities."

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

  defp found(%Activity{} = activity), do: {:ok, activity}
  defp found(nil), do: {:error, Errors.NotFoundError.new(resource_type: "Activity")}
end
