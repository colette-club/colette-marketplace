defmodule AppWeb.Resolvers.Live do
  @moduledoc false

  alias App.{Communities, Live}
  alias App.Services.Live.Enter

  def open_live(%{activity_id: activity_id}, _resolution) do
    with {:ok, activity} <- Communities.get_activity(activity_id),
         {:ok, session} <- Live.open_session(activity) do
      {:ok, %{session: session}}
    end
  end

  def start_live(%{activity_id: activity_id}, _resolution) do
    with {:ok, session} <- Live.get_session(activity_id),
         {:ok, session} <- Live.start_live(session) do
      {:ok, %{session: session}}
    end
  end

  def end_live(%{activity_id: activity_id}, _resolution) do
    with {:ok, session} <- Live.get_session(activity_id),
         {:ok, session} <- Live.end_live(session) do
      {:ok, %{session: session}}
    end
  end

  def enter_activity_live(%{activity_id: activity_id}, %{context: %{current_user: user}}) do
    with {:ok, role} <- Enter.run(activity_id, user.id) do
      {:ok, %{role: role}}
    end
  end
end
