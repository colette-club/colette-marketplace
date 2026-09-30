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

  @doc "Lists every wish of a member, including archived ones, newest first."
  def list_wishes(member_id) do
    Wish
    |> Wish.Query.for_member(member_id)
    |> Wish.Query.not_archived()
    |> Wish.Query.newest_first()
    |> Repo.all()
  end

  @doc "Archives one of the member's wishes."
  def archive_wish(wish_id, member_id) do
    case Repo.get_by(Wish, id: wish_id, member_id: member_id) do
      nil -> {:error, :not_found}
      %Wish{archived_at: %DateTime{}} -> {:error, :already_archived}
      %Wish{} = wish -> wish |> Wish.archive_changeset() |> Repo.update()
    end
  end
end
