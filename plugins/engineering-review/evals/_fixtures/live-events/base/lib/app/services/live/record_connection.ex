defmodule App.Services.Live.RecordConnection do
  @moduledoc """
  Records a connection to the current run of an activity's live, as the media
  server reports it: the host's first connection starts the run and every one
  stamps their presence; a viewer's first connection to the run is their
  participation. A connection to an activity with no run is ignored.
  """

  alias App.Errors
  alias App.Live
  alias App.Live.Connection
  alias App.Live.Session

  @spec run(Connection.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def run(%Connection{activity_id: activity_id} = connection, opts \\ []) do
    activity_id
    |> Live.get_session()
    |> record(connection, opts)
  end

  defp record({:ok, %Session{} = session}, %Connection{role: :host}, _opts) do
    with {:ok, started} <- Live.start_live(session), do: Live.mark_host_seen(started)
  end

  defp record({:ok, %Session{} = session}, %Connection{role: :viewer, user_id: user_id}, opts),
    do: Live.record_participation(session, user_id, opts)

  defp record({:error, %Errors.NotFoundError{}}, _connection, _opts), do: {:ok, :ignored}
end
