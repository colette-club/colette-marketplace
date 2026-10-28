defmodule App.Communities.Registrations do
  @moduledoc "Members' registrations to activities."

  alias App.Communities.Registration
  alias App.Communities.Registrations.Query
  alias App.Repo

  @doc "Whether the user holds a validated registration to the activity."
  @spec registered?(binary(), binary()) :: boolean()
  def registered?(activity_id, user_id) when is_binary(activity_id) and is_binary(user_id) do
    Registration
    |> Query.with_activity_id(activity_id)
    |> Query.with_user_id(user_id)
    |> Query.validated()
    |> Repo.exists?()
  end
end
