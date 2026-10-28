defmodule App.Live.MediaServer do
  @moduledoc """
  The media server of the live rooms, through the adapter set under `:adapter`
  of `config :app, :live`. `App.Live.Adapter` is the contract.
  """

  alias App.Config
  alias App.Live.Adapter

  @spec get_server_url() :: String.t()
  def get_server_url, do: get_adapter().get_server_url()

  @spec mint_participant_token(Adapter.participant()) :: String.t()
  def mint_participant_token(participant), do: get_adapter().mint_participant_token(participant)

  defp get_adapter do
    :app
    |> Config.fetch_env!(:live)
    |> Keyword.fetch!(:adapter)
  end
end
