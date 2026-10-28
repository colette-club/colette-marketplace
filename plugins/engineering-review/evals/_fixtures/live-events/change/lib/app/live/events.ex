defmodule App.Live.Events do
  @moduledoc "Events published by the Live context."
  use ExEventBus.Event

  defevents([LiveParticipationRecorded, LiveHostSeen])
end
