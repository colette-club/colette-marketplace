defmodule App.Live.Host do
  @moduledoc "Who hosts an activity's live: its organizer, or its creator when it has none."

  alias App.Communities.Activity

  @spec id(Activity.t()) :: binary()
  def id(%Activity{organizer_id: nil, creator_id: creator_id}), do: creator_id
  def id(%Activity{organizer_id: organizer_id}), do: organizer_id
end
