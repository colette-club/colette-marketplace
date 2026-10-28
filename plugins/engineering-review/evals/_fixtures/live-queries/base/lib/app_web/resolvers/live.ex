defmodule AppWeb.Resolvers.Live do
  @moduledoc false

  alias App.{Communities, Live}

  def open_live(%{activity_id: activity_id}, _resolution) do
    with {:ok, activity} <- Communities.get_activity(activity_id),
         {:ok, session} <- Live.open_session(activity) do
      {:ok, %{session: session}}
    end
  end

  def start_live(%{session_id: session_id}, _resolution) do
    with {:ok, session} <- Live.fetch_session(session_id),
         {:ok, session} <- Live.start_live(session) do
      {:ok, %{session: session}}
    end
  end

  def end_live(%{session_id: session_id}, _resolution) do
    with {:ok, session} <- Live.fetch_session(session_id),
         {:ok, session} <- Live.end_live(session) do
      {:ok, %{session: session}}
    end
  end
end
