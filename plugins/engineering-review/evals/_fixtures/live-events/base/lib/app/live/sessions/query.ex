defmodule App.Live.Sessions.Query do
  @moduledoc false
  use App.Query

  def with_activity_id(queryable, activity_id), do: where(queryable, [s], s.activity_id == ^activity_id)
  def with_status(queryable, status), do: where(queryable, [s], s.status == ^status)
  def latest(queryable), do: queryable |> order_by([s], desc: s.inserted_at) |> limit(1)

  def activity_over(queryable, %DateTime{} = now) do
    queryable
    |> join(:inner, [s], a in assoc(s, :activity), as: :activity)
    |> where([activity: a], a.ends_at < ^now)
  end

  def host_absent_for(queryable, %DateTime{} = now, minutes) do
    since = DateTime.add(now, -minutes, :minute)
    where(queryable, [s], s.host_absent_since <= ^since)
  end
end
