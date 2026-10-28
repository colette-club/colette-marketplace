defmodule App.Live.Adapter do
  @moduledoc """
  The media server that runs the live rooms. The module set under `:adapter`
  of `config :app, :live` implements it and reads its own settings.
  """

  @doc "Whether the person is connected to the activity's room right now."
  @callback participant_in_room?(activity_id :: binary(), user_id :: binary()) :: boolean()

  @doc "The connection a signed webhook body reports, or why it was not accepted."
  @callback verify_webhook(token :: String.t() | nil, body :: binary()) ::
              {:ok, App.Live.Connection.t()} | {:ok, :ignored} | {:error, :invalid_signature}
end
