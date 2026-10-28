defmodule App.Live.Sessions do
  @moduledoc "The runs of an activity's live room."

  alias App.Errors
  alias App.Live.Session
  alias App.Live.Sessions.Query
  alias App.Repo

  @doc "The activity's current run: `{:ok, session}`, or `NotFoundError` when the room never opened."
  @spec get_session(binary()) :: {:ok, Session.t()} | {:error, Errors.NotFoundError.t()}
  def get_session(activity_id) when is_binary(activity_id) do
    Session
    |> Query.current_of_activity(activity_id)
    |> Repo.one()
    |> case do
      %Session{} = session -> {:ok, session}
      nil -> {:error, Errors.NotFoundError.new(resource_type: "LiveSession", resource_id: activity_id)}
    end
  end

  @doc "The activity's current run, opened on the first connection."
  @spec get_or_create_session(binary(), keyword()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def get_or_create_session(activity_id, opts \\ []) when is_binary(activity_id) do
    case get_session(activity_id) do
      {:ok, session} -> {:ok, session}
      {:error, %Errors.NotFoundError{}} -> create_session(activity_id, opts)
    end
  end

  defp create_session(activity_id, _opts) do
    %{activity_id: activity_id}
    |> Session.create_changeset()
    |> Repo.insert()
  end
end
