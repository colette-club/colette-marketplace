defmodule App.Live.MediaServer do
  @moduledoc """
  The media server of the live rooms, through the adapter set under `:adapter`
  of `config :app, :live`. `App.Live.Adapter` is the contract.
  """

  alias App.Config

  @spec get_server_url() :: String.t()
  def get_server_url, do: get_adapter().get_server_url()

  defp get_adapter do
    :app
    |> Config.fetch_env!(:live)
    |> Keyword.fetch!(:adapter)
  end
end
