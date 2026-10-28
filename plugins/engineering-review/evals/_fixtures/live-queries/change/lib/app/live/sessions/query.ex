defmodule App.Live.Sessions.Query do
  @moduledoc false
  use App.Query

  def with_activity_id(queryable, activity_id), do: where(queryable, [s], s.activity_id == ^activity_id)

  @doc "The latest run: no run of the same activity opened after it."
  def current(queryable) do
    where(
      queryable,
      [s],
      fragment(
        """
        NOT EXISTS (
          SELECT 1 FROM live_sessions AS later
          WHERE later.activity_id = ? AND (later.inserted_at, later.id) > (?, ?)
        )
        """,
        s.activity_id,
        s.inserted_at,
        s.id
      )
    )
  end
end
