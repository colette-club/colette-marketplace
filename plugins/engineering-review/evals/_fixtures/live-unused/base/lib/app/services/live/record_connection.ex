defmodule App.Services.Live.RecordConnection do
  @moduledoc """
  Records a viewer's connection to the current run of an activity's live, once
  per run; the first connection opens the run. The host's connections are not
  recorded.
  """

  alias App.Live
  alias App.Live.Connection

  @spec run(Connection.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def run(%Connection{activity_id: activity_id} = connection, opts \\ []) do
    activity_id
    |> Live.get_or_create_session(opts)
    |> record(connection, opts)
  end

  defp record({:ok, session}, %Connection{role: :viewer, user_id: user_id}, opts),
    do: Live.record_participation(session, user_id, opts)

  defp record({:ok, _session}, %Connection{role: :host}, _opts), do: {:ok, :ignored}
  defp record({:error, _changeset} = error, _connection, _opts), do: error
end
