defmodule App.Communities.EventHandler.ConfirmViewerAttendance do
  @moduledoc "Confirms a viewer's attendance once their first connection to a live run is recorded."
  use ExEventBus.EventHandler,
    ex_event_bus: App.EventBus,
    events: ["Elixir.App.Live.Events.LiveParticipationRecorded"]

  alias App.Communities

  @impl true
  def handle_event(%{aggregate: %{"activity_id" => activity_id, "user_id" => user_id}}) do
    Communities.confirm_attendance(activity_id, user_id)
  end
end
