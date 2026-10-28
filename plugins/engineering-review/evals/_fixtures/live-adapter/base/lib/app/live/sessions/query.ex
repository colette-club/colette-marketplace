defmodule App.Live.Sessions.Query do
  @moduledoc false
  use App.Query

  def current_of_activity(queryable, activity_id) when is_binary(activity_id) do
    queryable
    |> where([s], s.activity_id == ^activity_id)
    |> order_by([s], desc: s.inserted_at, desc: s.id)
    |> limit(1)
  end
end
