defmodule App.Communities.Attendances do
  @moduledoc """
  Confirms that a member attended an activity, as an admin would: the
  registration is marked attended and the member is asked for a review.
  """

  alias App.Communities.Registration
  alias App.Communities.Registrations.Query
  alias App.Repo
  alias App.Workers.AskForReview
  alias Ecto.Multi

  @doc """
  Marks the member's registration to the activity as attended and asks them
  for a review. Returns `{:ok, registration}`; a registration already attended
  is returned unchanged, and a member with no registration gives
  `{:ok, :not_registered}`.
  """
  def confirm_attendance(activity_id, user_id) when is_binary(activity_id) and is_binary(user_id) do
    Registration
    |> Query.with_activity_id(activity_id)
    |> Query.with_user_id(user_id)
    |> Repo.one()
    |> attend()
  end

  defp attend(nil), do: {:ok, :not_registered}
  defp attend(%Registration{attended_at: %DateTime{}} = registration), do: {:ok, registration}

  defp attend(%Registration{} = registration) do
    Multi.new()
    |> Multi.update(:registration, Registration.attend_changeset(registration))
    |> Oban.insert(:ask_for_review, fn %{registration: attended} -> AskForReview.new(%{registration_id: attended.id}) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{registration: attended}} -> {:ok, attended}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end
end
