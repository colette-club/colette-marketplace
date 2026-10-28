defmodule App.Payments.Adapters.Stripe do
  @moduledoc """
  Stripe as the payment provider. Reads `api_key` and `webhook_secret` from
  `config :app, App.Payments.Adapters.Stripe`.
  """

  @behaviour App.Payments.Adapter

  alias App.Payments.Adapters.Stripe.{Client, Signature}
  alias App.Payments.PaymentEvent

  @impl true
  def create_payment_intent(amount_cents, currency),
    do: Client.create_payment_intent(amount_cents, currency, fetch_setting!(:api_key))

  @impl true
  def verify_webhook(signature, body) do
    with :ok <- Signature.verify(signature, body, fetch_setting!(:webhook_secret)) do
      body |> JSON.decode!() |> to_payment_event()
    end
  end

  defp to_payment_event(%{"type" => "payment_intent.succeeded", "data" => %{"object" => %{"id" => id}}}),
    do: {:ok, %PaymentEvent{payment_intent_id: id, outcome: :succeeded}}

  defp to_payment_event(%{"type" => "payment_intent.payment_failed", "data" => %{"object" => %{"id" => id}}}),
    do: {:ok, %PaymentEvent{payment_intent_id: id, outcome: :failed}}

  defp to_payment_event(%{}), do: {:ok, :ignored}

  defp fetch_setting!(key), do: :app |> Application.fetch_env!(__MODULE__) |> Keyword.fetch!(key)
end
