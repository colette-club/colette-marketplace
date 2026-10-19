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

  @doc "Fetches one of a member's wishes."
  def fetch_member_wish(member, id) do
    case Repo.get_by(Wish, id: id, member_id: member.id) do
      nil -> {:error, :not_found}
      wish -> {:ok, wish}
    end
  end

  @doc "Archives a wish so it leaves the member's list."
  def archive_wish(%Wish{} = wish) do
    wish
    |> Wish.archive_changeset()
    |> Repo.update()
  end

  @doc "Lists a member's active wishes, sorted by title."
  def list_wishes(member_id) do
    Wish
    |> where(member_id: ^member_id)
    |> where([wish], is_nil(wish.archived_at))
    |> order_by(:title)
    |> Repo.all()
  end
end
