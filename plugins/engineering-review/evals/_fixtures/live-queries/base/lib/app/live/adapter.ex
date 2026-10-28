defmodule App.Live.Adapter do
  @moduledoc """
  The media server that hosts the live rooms. The module set under `:adapter`
  of `config :app, :live` implements it and reads its own settings.
  """

  @doc "The address clients connect to."
  @callback get_server_url() :: String.t()
end
