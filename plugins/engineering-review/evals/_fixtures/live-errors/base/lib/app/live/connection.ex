defmodule App.Live.Connection do
  @moduledoc "A person's connection to an activity's live room, as the media server adapter reports it."

  @enforce_keys [:activity_id, :user_id, :role]
  defstruct [:activity_id, :user_id, :role]

  @type t :: %__MODULE__{activity_id: binary(), user_id: binary(), role: :host | :viewer}
end
