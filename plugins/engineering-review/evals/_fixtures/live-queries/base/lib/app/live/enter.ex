defmodule App.Live.Enter do
  @moduledoc """
  Who may enter an activity's live room, and as what: its host — the organizer,
  or the creator when there is none — or a viewer holding a validated
  registration.
  """

  alias App.{Communities, Errors}
  alias App.Accounts.User
  alias App.Communities.Activity

  @type role :: :host | :viewer

  @spec role(Activity.t(), User.t()) :: {:ok, role()} | {:error, Errors.NotAnAttendeeError.t()}
  def role(%Activity{organizer_id: nil, creator_id: user_id}, %User{id: user_id}), do: {:ok, :host}
  def role(%Activity{organizer_id: user_id}, %User{id: user_id}), do: {:ok, :host}

  def role(%Activity{id: activity_id}, %User{id: user_id}),
    do: maybe_viewer(Communities.registered?(activity_id, user_id))

  defp maybe_viewer(true), do: {:ok, :viewer}
  defp maybe_viewer(false), do: {:error, Errors.NotAnAttendeeError.new()}
end
