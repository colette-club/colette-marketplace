defmodule App.Live.Participations do
  @moduledoc "Who took part in each run of a live."

  alias App.Live.Events
  alias App.Live.Participation
  alias App.Live.Participations.Query
  alias App.Live.Session
  alias App.Repo

  @doc """
  Records the member's first connection to the run and publishes
  `LiveParticipationRecorded`, once per member and run.
  """
  @spec record_participation(Session.t(), binary(), keyword()) ::
          {:ok, Participation.t() | :already_recorded} | {:error, Ecto.Changeset.t()}
  def record_participation(%Session{id: session_id}, user_id, opts \\ []) when is_binary(user_id) do
    first_joined_at = DateTime.utc_now()

    %{session_id: session_id, user_id: user_id, first_joined_at: first_joined_at}
    |> Participation.create_changeset()
    |> Repo.insert(success_event: Events.LiveParticipationRecorded, event_opts: opts)
    |> case do
      {:ok, participation} -> {:ok, participation}
      {:error, %Ecto.Changeset{errors: [{:session_id, {_, [constraint: :unique, constraint_name: _]}} | _]}} -> {:ok, :already_recorded}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc "How many members took part in the run."
  @spec count_participants(binary()) :: non_neg_integer()
  def count_participants(session_id) when is_binary(session_id) do
    Participation
    |> Query.with_session_id(session_id)
    |> Query.count()
  end
end
