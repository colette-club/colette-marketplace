defmodule App.Accounts.Events do
  @moduledoc "Events published by the Accounts context."
  use ExEventBus.Event

  defevents([ReferralCreated])
end
