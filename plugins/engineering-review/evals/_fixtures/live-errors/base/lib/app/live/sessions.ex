defmodule App.Live.Sessions do
  @moduledoc "The live room of each online activity."

  alias App.Errors
  alias App.Live.Session
  alias App.Live.Sessions.Query
  alias App.Repo

  @doc "The activity's live room, or `NotFoundError` when it never opened."
  def get_session(activity_id) when is_binary(activity_id) do
    Session
    |> Query.with_activity_id(activity_id)
    |> Repo.one()
    |> case do
      %Session{} = session -> {:ok, session}
      nil -> {:error, Errors.NotFoundError.new(resource_type: "LiveSession", resource_id: activity_id)}
    end
  end

  @doc """
  The activity's live room, opened if needed. Two first connections at once
  open it once: the one that loses the race reads the room the other opened.
  """
  def get_or_create_session(activity_id) when is_binary(activity_id) do
    activity_id
    |> get_session()
    |> create_unless_found(activity_id)
  end

  defp create_unless_found({:ok, %Session{}} = found, _activity_id), do: found

  defp create_unless_found({:error, %Errors.NotFoundError{}}, activity_id) do
    %{activity_id: activity_id}
    |> Session.create_changeset()
    |> Repo.insert()
    |> case do
      {:ok, %Session{} = session} -> {:ok, session}
      {:error, %Ecto.Changeset{errors: [{:activity_id, {_message, [constraint: :unique, constraint_name: _]}} | _]}} -> get_session(activity_id)
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
    end
  end
end
