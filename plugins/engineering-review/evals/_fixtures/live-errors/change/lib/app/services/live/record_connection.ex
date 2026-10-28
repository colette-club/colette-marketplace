defmodule App.Services.Live.RecordConnection do
  @moduledoc """
  Records a person's connection to an activity's live room, as the media
  server reports it: the room opens on its first connection, and each person's
  first connection is their participation.
  """

  alias App.Live
  alias App.Live.Connection
  alias App.Live.Participation

  @spec run(Connection.t()) :: {:ok, Participation.t()} | {:error, term()}
  def run(%Connection{activity_id: activity_id, user_id: user_id}) do
    with {:ok, session} <- Live.get_or_create_session(activity_id) do
      Live.record_participation(session, user_id)
    end
  end
end
