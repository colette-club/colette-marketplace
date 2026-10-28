defmodule App.Live.Sessions.Query do
  @moduledoc false
  use App.Query

  alias App.Communities.Activity
  alias App.Live.Session

  def with_activity_id(queryable, activity_id), do: where(queryable, [s], s.activity_id == ^activity_id)

  @doc """
  The current run: the latest one, unless it ended and the activity has been
  moved since it opened — then the activity has no current run.
  """
  def current(queryable) do
    queryable
    |> from(as: :session)
    |> where([s], not exists(later_session()))
    |> where([s], s.status != "ended" or not exists(activity_moved_since()))
  end

  defp later_session do
    from(later in Session,
      where: later.activity_id == parent_as(:session).activity_id,
      where: later.inserted_at > parent_as(:session).inserted_at,
      select: 1
    )
  end

  # `activities.starts_at` is a timestamptz; `activity_starts_at` is a timestamp
  # holding UTC, so the activity's start is read in UTC before they are compared.
  defp activity_moved_since do
    from(a in Activity,
      where: a.id == parent_as(:session).activity_id,
      where: fragment("? AT TIME ZONE 'UTC'", a.starts_at) != parent_as(:session).activity_starts_at,
      select: 1
    )
  end
end
