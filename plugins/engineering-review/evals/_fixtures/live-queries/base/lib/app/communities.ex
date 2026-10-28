defmodule App.Communities do
  @moduledoc "Activities and the members registered to them."

  alias App.Communities.{Activities, Registrations}

  defdelegate get_activity(id), to: Activities
  defdelegate list_activities_to_join(user_id), to: Activities
  defdelegate registered?(activity_id, user_id), to: Registrations
end
