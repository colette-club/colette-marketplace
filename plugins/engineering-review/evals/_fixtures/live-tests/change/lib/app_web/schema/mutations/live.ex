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

    @desc "Enter the activity's live room, as its host or as a registered member."
    field :enter_activity_live, non_null(:live_entry) do
      arg :activity_id, non_null(:id)
      middleware Middlewares.Authenticated
      resolve &Resolvers.Live.enter_activity_live/2
    end
  end

  object :live_session_payload do
    field :session, non_null(:live_session)
  end

  object :live_session do
    field :id, non_null(:id)
    field :status, non_null(:string)
  end

  @desc "What the person entering the room is: its host, or a viewer."
  object :live_entry do
    field :role, non_null(:live_role)
  end

  enum :live_role do
    value :host
    value :viewer
  end
end
