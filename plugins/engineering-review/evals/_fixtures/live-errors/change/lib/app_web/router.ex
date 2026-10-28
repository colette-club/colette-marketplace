defmodule AppWeb.Router do
  use AppWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :media_server_webhook do
    plug :accepts, ["json"]
    plug AppWeb.Plugs.MediaServerSignature
  end

  scope "/api", AppWeb do
    pipe_through :api
    forward "/graphql", Absinthe.Plug, schema: AppWeb.Schema
  end

  scope "/webhooks", AppWeb do
    pipe_through :media_server_webhook
    post "/media-server", MediaServerController, :create
  end
end
