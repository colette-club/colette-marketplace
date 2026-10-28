defmodule App.Services.Live.Join do
  @moduledoc """
  Hands a person what they need to enter an activity's live room — a token and
  the media server's address — once the room opens. The host gets one, and so
  does a member holding a validated registration, unless the host has ended
  the current run.
  """

  alias App.{Communities, Errors, Live}
  alias App.Accounts.User
  alias App.Communities.Activity
  alias App.Live.{Enter, Session, Window}

  @spec run(binary(), User.t()) ::
          {:ok, %{token: String.t(), server_url: String.t(), role: Enter.role()}} | {:error, struct()}
  def run(activity_id, %User{} = user) when is_binary(activity_id) do
    now = DateTime.utc_now()

    with {:ok, activity} <- Communities.get_activity(activity_id),
         :ok <- maybe_open(Window.open?(activity, now)),
         {:ok, role} <- Enter.role(activity, user),
         :ok <- not_ended(Live.get_session(activity.id), role) do
      token = mint_token(activity, user, role)
      server_url = Live.get_server_url()
      {:ok, %{token: token, server_url: server_url, role: role}}
    end
  end

  defp maybe_open(true), do: :ok
  defp maybe_open(false), do: {:error, Errors.LiveRoomNotOpenError.new()}

  defp not_ended({:ok, %Session{status: "ended"}}, :viewer), do: {:error, Errors.LiveOverError.new()}
  defp not_ended({:ok, %Session{}}, _role), do: :ok
  defp not_ended({:error, %Errors.NotFoundError{}}, _role), do: :ok

  defp mint_token(%Activity{id: activity_id}, %User{id: user_id, first_name: first_name}, role) do
    room = "activity-" <> activity_id
    Live.mint_participant_token(%{room: room, identity: user_id, name: first_name, role: role})
  end
end
