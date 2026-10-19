defmodule AppWeb.Resolvers.Wishes do
  @moduledoc "GraphQL resolvers for a member's wishes."

  alias App.Wishes

  def archive_wish(_parent, %{id: id}, %{context: %{current_member: member}}) do
    with {:ok, wish} <- Wishes.fetch_member_wish(member, id) do
      Wishes.archive_wish(wish)
    end
  end
end
