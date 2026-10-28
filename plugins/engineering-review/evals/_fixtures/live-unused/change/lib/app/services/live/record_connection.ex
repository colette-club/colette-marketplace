defmodule App.Services.Live.RecordConnection do
  @moduledoc """
  Records a person's connection to the current run of an activity's live, once
  per run, with their role; the first connection opens the run. The host's
  connection also stamps the host as seen. A connection to a run the host has
  ended is ignored.
  """

  alias App.Live
  alias App.Live.{Connection, Session}

  @spec run(Connection.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def run(%Connection{activity_id: activity_id} = connection, opts \\ []) do
    activity_id
    |> Live.get_or_create_session(opts)
    |> record(connection, opts)
  end

  defp record({:ok, %Session{status: "ended"}}, _connection, _opts), do: {:ok, :ignored}

  defp record({:ok, session}, %Connection{role: :host, user_id: user_id}, opts) do
    with {:ok, seen} <- Live.mark_host_seen(session),
         do: Live.record_participation(seen, user_id, "host", opts)
  end

  defp record({:ok, session}, %Connection{role: :viewer, user_id: user_id}, opts),
    do: Live.record_participation(session, user_id, "viewer", opts)

  defp record({:error, _changeset} = error, _connection, _opts), do: error
end
