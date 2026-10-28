defmodule App.Repo do
  use Ecto.Repo, otp_app: :app, adapter: Ecto.Adapters.Postgres
  use ExEventBus.EctoRepoWrapper, ex_event_bus: App.EventBus
end
