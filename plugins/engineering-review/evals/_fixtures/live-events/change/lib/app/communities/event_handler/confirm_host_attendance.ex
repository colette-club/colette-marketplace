defmodule App.Communities.EventHandler.ConfirmHostAttendance do
  @moduledoc """
  Confirms the host's attendance once they are seen in the activity's live, as
  `ConfirmViewerAttendance` does for a viewer. A host with no registration has
  nothing to confirm.
  """
  use ExEventBus.EventHandler,
    ex_event_bus: App.EventBus,
    events: ["Elixir.App.Live.Events.LiveHostSeen"]

  alias App.Communities
  alias App.Live

  @impl true
  def handle_event(%{aggregate: %{"activity_id" => activity_id}}) do
    with {:ok, activity} <- Communities.get_activity(activity_id) do
      host_id = Live.host_id(activity)
      Communities.confirm_attendance(activity_id, host_id)
    end
  end
end
