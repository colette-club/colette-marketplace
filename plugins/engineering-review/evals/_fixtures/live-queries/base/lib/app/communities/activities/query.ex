defmodule App.Communities.Activities.Query do
  @moduledoc false
  use App.Query

  alias App.Communities.Registration

  def upcoming(queryable, now), do: where(queryable, [a], a.starts_at > ^now)

  def ordered_by_start(queryable), do: order_by(queryable, [a], asc: a.starts_at, asc: a.id)

  def without_registration_of(queryable, user_id) do
    queryable
    |> from(as: :activity)
    |> where([a], not exists(registration_of(user_id)))
  end

  defp registration_of(user_id) do
    from(r in Registration,
      where: r.activity_id == parent_as(:activity).id,
      where: r.user_id == ^user_id,
      select: 1
    )
  end
end
