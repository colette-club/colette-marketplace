defmodule App.Live.Participations do
  @moduledoc "Who joined each run of a live as a viewer."

  alias App.Live.Events
  alias App.Live.Participation
  alias App.Live.Session
  alias App.Repo

  @doc """
  Records the viewer's first connection to the run and publishes
  `LiveParticipationRecorded`, once per viewer and run. A later connection of
  the same viewer returns `{:ok, :already_recorded}`.
  """
  def record_participation(%Session{id: session_id, activity_id: activity_id}, user_id, opts \\ [])
      when is_binary(user_id) do
    first_joined_at = DateTime.utc_now()

    %{activity_id: activity_id, session_id: session_id, user_id: user_id, first_joined_at: first_joined_at}
    |> Participation.create_changeset()
    |> Repo.insert(success_event: Events.LiveParticipationRecorded, event_opts: opts)
    |> case do
      {:ok, %Participation{} = participation} ->
        {:ok, participation}

      {:error, %Ecto.Changeset{errors: [{:session_id, {_message, [constraint: :unique, constraint_name: _]}} | _]}} ->
        {:ok, :already_recorded}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end
end
