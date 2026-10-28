defmodule App.Live.Sessions.Query do
  @moduledoc false
  use App.Query

  alias App.Live.Session

  def with_activity_id(queryable, activity_id), do: where(queryable, [s], s.activity_id == ^activity_id)

  @doc "The latest run: no run of the same activity opened after it."
  def current(queryable) do
    queryable
    |> from(as: :session)
    |> where([s], not exists(later_session()))
  end

  defp later_session do
    from(later in Session,
      where: later.activity_id == parent_as(:session).activity_id,
      where: later.inserted_at > parent_as(:session).inserted_at,
      select: 1
    )
  end
end
