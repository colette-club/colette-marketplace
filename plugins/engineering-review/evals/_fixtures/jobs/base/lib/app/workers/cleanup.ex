defmodule App.Workers.Cleanup do
  @moduledoc "Deletes expired sessions once an hour."

  use Oban.Worker, queue: :maintenance, max_attempts: 5, unique: [period: 3600]

  alias App.Sessions

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Sessions.delete_expired()
    :ok
  end
end
