defmodule AppWeb.Resolvers.Wishes do
  @moduledoc "GraphQL resolvers for wishes."

  alias App.Audit
  alias App.Wishes

  def create_wish(_parent, %{input: input}, %{context: %{current_user: user}}) do
    with {:ok, wish} <- Wishes.create_wish(user, input) do
      Audit.log(user, "wish.created")
      {:ok, wish}
    end
  end

  def archive_wish(_parent, %{id: id}, %{context: %{current_user: user}}) do
    Wishes.archive_wish(user, id)
  end
end
