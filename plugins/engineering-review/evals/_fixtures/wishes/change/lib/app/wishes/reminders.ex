defmodule App.Wishes.Reminders do
  @moduledoc "Reminds members about wishes that have had no matching activity for 30 days."

  alias App.Wishes.Wish
  alias App.Workers.WishReminderWorker

  @doc "Schedules a reminder for a wish, 30 days after it was created."
  def schedule_reminder(%Wish{id: wish_id, inserted_at: inserted_at}) do
    %{wish_id: wish_id}
    |> WishReminderWorker.new(scheduled_at: DateTime.add(inserted_at, 30, :day))
    |> Oban.insert()
  end
end
