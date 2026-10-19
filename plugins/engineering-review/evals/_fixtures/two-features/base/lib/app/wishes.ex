defmodule App.Wishes do
  @moduledoc "Wishes that members post for activities they would like to join."

  alias App.Repo
  alias App.Wishes.Wish

  @doc "Creates a wish for a member."
  def create_wish(attrs) do
    attrs
    |> Wish.create_changeset()
    |> Repo.insert()
  end

  @doc "Lists a member's wishes, newest first."
  def list_wishes(member_id) do
    Wish
    |> Wish.Query.for_member(member_id)
    |> Wish.Query.newest_first()
    |> Repo.all()
  end
end
