defmodule AppWeb.Router do
  use AppWeb, :router

  pipeline :payment_webhook do
    plug AppWeb.Plugs.PaymentSignature
  end

  scope "/webhooks", AppWeb.Webhooks do
    pipe_through :payment_webhook
    post "/payments", PaymentsController, :create
  end
end
