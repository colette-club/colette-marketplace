defmodule App.Live.Sessions.Query do
  @moduledoc false
  use App.Query

  def with_activity_id(queryable, activity_id), do: where(queryable, [s], s.activity_id == ^activity_id)
end
