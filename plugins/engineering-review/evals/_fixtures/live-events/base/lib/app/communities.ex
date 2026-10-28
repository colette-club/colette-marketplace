defmodule App.Communities do
  @moduledoc "Communities: activities and who attends them."

  alias App.Communities.Activities
  alias App.Communities.Attendances

  defdelegate get_activity(id), to: Activities
  defdelegate update_activity(activity, attrs), to: Activities
  defdelegate confirm_attendance(activity_id, user_id), to: Attendances
end
