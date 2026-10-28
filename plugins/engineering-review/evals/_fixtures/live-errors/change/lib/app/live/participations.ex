defmodule App.Live.Participations do
  @moduledoc "Who connected to each activity's live room, once per person."

  alias App.Live.Events
  alias App.Live.Participation
  alias App.Live.Participations.Query
  alias App.Live.Session
  alias App.Repo

  @doc """
  Records the person's first connection to the room and publishes
  `LiveParticipationRecorded`, which confirms their attendance. A later
  connection, or one that races the first, returns the participation already
  recorded.
  """
  def record_participation(%Session{} = session, user_id) when is_binary(user_id) do
    session.id
    |> get_participation(user_id)
    |> create_unless_found(session, user_id)
  end

  defp get_participation(session_id, user_id) do
    Participation
    |> Query.with_session_id(session_id)
    |> Query.with_user_id(user_id)
    |> Repo.one()
  end

  defp create_unless_found(%Participation{} = participation, _session, _user_id), do: {:ok, participation}

  defp create_unless_found(nil, %Session{id: session_id}, user_id) do
    first_joined_at = DateTime.utc_now()

    %{session_id: session_id, user_id: user_id, first_joined_at: first_joined_at}
    |> Participation.create_changeset()
    |> Repo.insert(success_event: Events.LiveParticipationRecorded)
    |> case do
      {:ok, %Participation{} = participation} ->
        {:ok, participation}

      {:error, %Ecto.Changeset{errors: [{:session_id, {_message, [constraint: :unique, constraint_name: _]}} | _]}} ->
        {:ok, get_participation(session_id, user_id)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end
end
