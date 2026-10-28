defmodule App.Live.MediaServer do
  @moduledoc "The media server of the live rooms, through the adapter set under `:adapter` of `config :app, :live`."

  alias App.Live.Adapter

  @spec get_server_url() :: String.t()
  def get_server_url, do: get_adapter().get_server_url()

  @spec issue_participant_token(Adapter.participant()) :: String.t()
  def issue_participant_token(participant), do: get_adapter().issue_participant_token(participant)

  defp get_adapter, do: :app |> Application.fetch_env!(:live) |> Keyword.fetch!(:adapter)
end
