defmodule App.Services.Live.Enter do
  @moduledoc """
  Decides whether a person may enter an activity's live room, and as what: its
  host, or a viewer holding a validated registration. The room opens 15 minutes
  before the activity's start and closes once the activity is over, unless its
  live still waits or runs. Once the host has ended the run, a viewer may not
  enter; the host still may, to start again, until the activity is over.
  """

  alias App.{Accounts, Communities, Errors, Live}
  alias App.Accounts.User
  alias App.Communities.Activity
  alias App.Live.{Session, Window}

  @type role :: :host | :viewer

  @spec run(binary(), binary()) :: {:ok, role()} | {:error, struct()}
  def run(activity_id, user_id) when is_binary(activity_id) and is_binary(user_id) do
    now = DateTime.utc_now()

    with {:ok, activity} <- Communities.get_activity(activity_id),
         {:ok, user} <- Accounts.get_user(user_id),
         :ok <- not_archived(activity),
         :ok <- maybe_open(Window.open?(activity, now)),
         {:ok, role} <- role(activity, user) do
      activity.id
      |> Live.get_session()
      |> admit(role, over?(activity, now))
    end
  end

  defp not_archived(%Activity{archived_at: nil}), do: :ok
  defp not_archived(%Activity{}), do: {:error, Errors.ActivityArchivedError.new()}

  defp maybe_open(true), do: :ok
  defp maybe_open(false), do: {:error, Errors.LiveRoomNotOpenError.new()}

  defp role(%Activity{organizer_id: nil, creator_id: user_id}, %User{id: user_id}), do: {:ok, :host}
  defp role(%Activity{organizer_id: user_id}, %User{id: user_id}), do: {:ok, :host}

  defp role(%Activity{id: activity_id}, %User{id: user_id}),
    do: maybe_viewer(Communities.registered?(activity_id, user_id))

  defp maybe_viewer(true), do: {:ok, :viewer}
  defp maybe_viewer(false), do: {:error, Errors.NotAnAttendeeError.new()}

  defp over?(%Activity{ends_at: ends_at}, now), do: DateTime.after?(now, ends_at)

  defp admit({:ok, %Session{status: status}}, role, _over?) when status in ["waiting", "live"],
    do: {:ok, role}

  defp admit({:ok, %Session{status: "ended"}}, :host, false), do: {:ok, :host}
  defp admit({:ok, %Session{status: "ended"}}, _role, _over?), do: {:error, Errors.LiveOverError.new()}
  defp admit({:error, %Errors.NotFoundError{}}, role, false), do: {:ok, role}
  defp admit({:error, %Errors.NotFoundError{}}, _role, true), do: {:error, Errors.LiveOverError.new()}
end
