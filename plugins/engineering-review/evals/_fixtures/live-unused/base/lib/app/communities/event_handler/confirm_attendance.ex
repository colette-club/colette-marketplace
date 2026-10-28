defmodule App.Communities.EventHandler.ConfirmAttendance do
  @moduledoc "Confirms a member's registration as attended once they join the activity's live."
  use ExEventBus.EventHandler,
    ex_event_bus: App.EventBus,
    events: ["Elixir.App.Live.Events.LiveParticipationRecorded"]

  alias App.Communities

  @impl true
  def handle_event(%{aggregate: %{"session_id" => session_id, "user_id" => user_id}}),
    do: Communities.confirm_live_attendance(session_id, user_id)
end
