defmodule App.Communities.Registrations.Query do
  @moduledoc false
  use App.Query

  def with_activity_id(queryable, activity_id), do: where(queryable, [r], r.activity_id == ^activity_id)
  def with_user_id(queryable, user_id), do: where(queryable, [r], r.user_id == ^user_id)
end
