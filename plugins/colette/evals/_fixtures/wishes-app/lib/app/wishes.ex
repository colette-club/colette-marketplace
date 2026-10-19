defmodule App.Wishes do
  @moduledoc "Wishes that members post for activities they would like to join."

  import Ecto.Query

  alias App.Repo
  alias App.Wishes.Wish

  @doc "Creates a wish for a member."
  def create_wish(attrs) do
    attrs
    |> Wish.create_changeset()
    |> Repo.insert()
  end

  @doc "Lists a member's wishes, sorted by title."
  def list_wishes(member_id) do
    Wish
    |> where(member_id: ^member_id)
    |> order_by(:title)
    |> Repo.all()
  end
end
