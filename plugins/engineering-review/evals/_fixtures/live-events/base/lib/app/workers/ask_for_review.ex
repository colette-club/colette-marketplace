defmodule App.Workers.AskForReview do
  @moduledoc "Emails a member who attended an activity to ask for a review."
  use Oban.Worker, queue: :notifications, max_attempts: 5

  alias App.Notifications

  @impl true
  def perform(%Oban.Job{args: %{"registration_id" => registration_id}}) do
    Notifications.send_review_request(registration_id)
  end
end
