defmodule AppWeb.Webhooks.LiveKitController do
  @moduledoc """
  Receives LiveKit's events about activity rooms. Every signed event is answered
  200, the ignored ones included, so LiveKit does not send them again; a failure
  to record is logged.
  """
  use AppWeb, :controller

  alias App.Services.Live.RecordConnection

  require Logger

  def create(%Plug.Conn{assigns: %{livekit_event: event}} = conn, _params) do
    event
    |> RecordConnection.run()
    |> log_failure(event)

    json(conn, %{status: "ok"})
  end

  defp log_failure({:ok, _recorded}, _event), do: :ok

  defp log_failure({:error, reason}, event),
    do: Logger.warning("LiveKit event #{inspect(Map.get(event, "event"))} not recorded: #{inspect(reason)}")
end
