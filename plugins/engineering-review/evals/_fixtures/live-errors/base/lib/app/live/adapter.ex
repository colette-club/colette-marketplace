defmodule App.Live.Adapter do
  @moduledoc """
  The media server that runs the live rooms. The module set under `:adapter`
  of `config :app, :live` implements it and reads its own settings.
  """

  @doc """
  The connection a signed webhook body reports; `{:ok, :ignored}` for an event
  that is not a connection; `{:error, :invalid_signature}` when the body is not
  signed by the media server.
  """
  @callback verify_webhook(token :: String.t() | nil, body :: binary()) ::
              {:ok, App.Live.Connection.t()} | {:ok, :ignored} | {:error, :invalid_signature}
end
