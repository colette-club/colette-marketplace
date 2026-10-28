defmodule App.Communities.EventHandler.Supervisor do
  @moduledoc false
  use Supervisor

  alias App.Communities.EventHandler

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(opts) do
    children = [
      {EventHandler.ConfirmViewerAttendance, opts},
      {EventHandler.ConfirmHostAttendance, opts}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
