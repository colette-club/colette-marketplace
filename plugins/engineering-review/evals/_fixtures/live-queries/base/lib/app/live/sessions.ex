defmodule App.Live.Sessions do
  @moduledoc "The runs of an activity's live."

  alias App.Communities.Activity
  alias App.Errors
  alias App.Live.Session
  alias App.Repo

  @doc "The run with this id, or `NotFoundError`."
  @spec fetch_session(binary()) :: {:ok, Session.t()} | {:error, Errors.NotFoundError.t()}
  def fetch_session(id) when is_binary(id) do
    Session
    |> Repo.get(id)
    |> found()
  end

  @doc "Opens a new run of the activity's live, waiting for its host."
  @spec open_session(Activity.t()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def open_session(%Activity{id: activity_id}) do
    %{activity_id: activity_id}
    |> Session.open_changeset()
    |> Repo.insert()
  end

  @doc "The host starts the run."
  @spec start_live(Session.t()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def start_live(%Session{status: "waiting"} = session) do
    session
    |> Session.status_changeset("live")
    |> Repo.update()
  end

  @doc "The host ends the run."
  @spec end_live(Session.t()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def end_live(%Session{status: "live"} = session) do
    session
    |> Session.status_changeset("ended")
    |> Repo.update()
  end

  defp found(%Session{} = session), do: {:ok, session}
  defp found(nil), do: {:error, Errors.NotFoundError.new(resource_type: "LiveSession")}
end
