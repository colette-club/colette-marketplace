defmodule App.Live.MediaServer do
  @moduledoc "The media server, through the adapter set under `:adapter` of `config :app, :live`."

  alias App.Config

  def verify_webhook(token, body), do: get_adapter().verify_webhook(token, body)

  defp get_adapter do
    :app
    |> Config.fetch_env!(:live)
    |> Keyword.fetch!(:adapter)
  end
end
