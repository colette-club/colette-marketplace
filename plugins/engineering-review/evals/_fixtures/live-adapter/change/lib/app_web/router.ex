defmodule AppWeb.Router do
  use AppWeb, :router

  pipeline :payment_webhook do
    plug AppWeb.Plugs.PaymentSignature
  end

  pipeline :livekit_webhook do
    plug AppWeb.Plugs.LiveKitSignature
  end

  scope "/webhooks", AppWeb.Webhooks do
    pipe_through :payment_webhook
    post "/payments", PaymentsController, :create
  end

  scope "/webhooks", AppWeb.Webhooks do
    pipe_through :livekit_webhook
    post "/livekit", LiveKitController, :create
  end
end
