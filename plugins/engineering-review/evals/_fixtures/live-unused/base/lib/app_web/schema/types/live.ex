defmodule AppWeb.Schema.Types.Live do
  @moduledoc false
  use Absinthe.Schema.Notation

  alias App.Live

  object :live_session do
    field :id, non_null(:id)
    field :status, non_null(:string)

    @desc "How many members took part in this run of the live."
    field :participant_count, non_null(:integer) do
      resolve(fn session, _args, _resolution -> {:ok, Live.count_participants(session.id)} end)
    end
  end
end
