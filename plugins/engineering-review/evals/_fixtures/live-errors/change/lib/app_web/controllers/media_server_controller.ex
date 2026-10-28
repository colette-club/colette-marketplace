defmodule AppWeb.MediaServerController do
  @moduledoc """
  Receives the media server's webhooks. Every signed event is answered 200, so
  the media server does not send it again; a failure to record is logged.
  """
  use AppWeb, :controller

  alias App.Services.Live.RecordConnection

  require Logger

  def create(%Plug.Conn{assigns: %{connection: connection}} = conn, _params) do
    connection
    |> RecordConnection.run()
    |> log_failure()

    json(conn, %{status: "ok"})
  end

  def create(%Plug.Conn{} = conn, _params), do: json(conn, %{status: "ok"})

  defp log_failure({:ok, _participation}), do: :ok
  defp log_failure({:error, reason}), do: Logger.warning("Media server connection not recorded: #{inspect(reason)}")
end
