defmodule App.Live.Adapter do
  @moduledoc """
  The media server that runs the live rooms. The module set under `:adapter` of
  `config :app, :live` implements it and reads its own settings.
  """

  @type participant :: %{room: String.t(), identity: String.t(), name: String.t(), role: :host | :viewer}

  @doc "The address clients connect to."
  @callback get_server_url() :: String.t()

  @doc "The token a person enters a room with; it carries their role."
  @callback issue_participant_token(participant()) :: String.t()
end
