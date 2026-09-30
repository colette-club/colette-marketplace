defmodule App.Accounts.EventHandler.NotifyReferrer do
  @moduledoc "Tells the referrer that their friend was invited."
  use ExEventBus.EventHandler,
    ex_event_bus: App.EventBus,
    events: ["Elixir.App.Accounts.Events.ReferralCreated"]

  @impl true
  def handle_event(%{aggregate: %{"referrer_id" => referrer_id}}) do
    %{referrer_id: referrer_id}
    |> App.Workers.NotifyReferrerWorker.new()
    |> Oban.insert()
  end
end
