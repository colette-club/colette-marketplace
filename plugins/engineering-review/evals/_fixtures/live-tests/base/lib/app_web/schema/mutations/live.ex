defmodule AppWeb.Schema.Mutations.Live do
  @moduledoc false
  use Absinthe.Schema.Notation

  alias AppWeb.Resolvers
  alias AppWeb.Schema.Middlewares

  object :live_mutations do
    @desc "The host opens a new run of the activity's live."
    field :open_live, non_null(:live_session_payload) do
      arg :activity_id, non_null(:id)
      middleware Middlewares.ActivityHost
      resolve &Resolvers.Live.open_live/2
    end

    @desc "The host starts the waiting run."
    field :start_live, non_null(:live_session_payload) do
      arg :activity_id, non_null(:id)
      middleware Middlewares.ActivityHost
      resolve &Resolvers.Live.start_live/2
    end

    @desc "The host ends the run."
    field :end_live, non_null(:live_session_payload) do
      arg :activity_id, non_null(:id)
      middleware Middlewares.ActivityHost
      resolve &Resolvers.Live.end_live/2
    end
  end

  object :live_session_payload do
    field :session, non_null(:live_session)
  end

  object :live_session do
    field :id, non_null(:id)
    field :status, non_null(:string)
  end
end
