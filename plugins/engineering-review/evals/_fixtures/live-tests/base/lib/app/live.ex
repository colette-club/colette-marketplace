defmodule App.Live do
  @moduledoc """
  The live of an online activity: its runs, one session each, and their state.
  """

  alias App.Live.Sessions

  defdelegate get_session(activity_id), to: Sessions
  defdelegate open_session(activity), to: Sessions
  defdelegate start_live(session), to: Sessions
  defdelegate end_live(session), to: Sessions
end
