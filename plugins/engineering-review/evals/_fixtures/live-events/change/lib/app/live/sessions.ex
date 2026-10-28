defmodule App.Live.Sessions do
  @moduledoc "The runs of an activity's live."

  alias App.Errors
  alias App.Live.Events
  alias App.Live.Session
  alias App.Live.Sessions.Query
  alias App.Repo

  @doc "The activity's latest run, or `NotFoundError` when its room never opened."
  def get_session(activity_id) when is_binary(activity_id) do
    Session
    |> Query.with_activity_id(activity_id)
    |> Query.latest()
    |> Repo.one()
    |> case do
      %Session{} = session -> {:ok, session}
      nil -> {:error, Errors.NotFoundError.new(resource_type: "LiveSession", resource_id: activity_id)}
    end
  end

  @doc "Runs that are live."
  def list_running_sessions do
    Session
    |> Query.with_status("live")
    |> Repo.all()
  end

  @doc "Live runs whose activity is over and whose host has been away for at least `minutes`."
  def list_overrun_sessions(%DateTime{} = now, minutes) when is_integer(minutes) do
    Session
    |> Query.with_status("live")
    |> Query.activity_over(now)
    |> Query.host_absent_for(now, minutes)
    |> Repo.all()
  end

  @doc "Starts the run when the host first connects; a run already started is unchanged."
  def start_live(%Session{} = session) do
    session
    |> Session.start_changeset()
    |> Repo.update()
  end

  @doc "Ends the run."
  def end_live(%Session{} = session) do
    session
    |> Session.end_changeset()
    |> Repo.update()
  end

  @doc """
  Records that the host was seen in the room and publishes `LiveHostSeen`,
  whose handler confirms the host's attendance.
  """
  def mark_host_seen(%Session{} = session, opts \\ []) do
    session
    |> Session.host_seen_changeset()
    |> Repo.update(success_event: Events.LiveHostSeen, event_opts: opts)
  end

  @doc "Records since when the host has been away; a host already away keeps their first absence."
  def mark_host_absent(%Session{} = session) do
    session
    |> Session.host_absent_changeset()
    |> Repo.update()
  end
end
