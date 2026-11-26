defmodule App.WishesTest do
  use App.DataCase, async: true

  alias App.Repo
  alias App.Wishes
  alias App.Wishes.Wish

  describe "list_wishes/1" do
    test "when the member has wishes" do
      member = insert(:member)
      wish = insert(:wish, member: member)

      assert [listed] = Wishes.list_wishes(member.id)
      assert listed.id == wish.id
    end
  end

  describe "archive_wish/2" do
    test "archives the member's wish" do
      wish = insert(:wish, archived_at: nil)

      assert {:ok, %Wish{archived_at: %DateTime{}}} = Wishes.archive_wish(wish.id, wish.member_id)
      assert %DateTime{} = Repo.get!(Wish, wish.id).archived_at
    end

    test "a wish of another member is not found" do
      wish = insert(:wish)
      other = insert(:member)

      assert {:error, :not_found} = Wishes.archive_wish(wish.id, other.id)
      assert Repo.get!(Wish, wish.id).archived_at == nil
    end

    test "an archived wish stays archived" do
      archived_at = ~U[2026-01-01 00:00:00Z]
      wish = insert(:wish, archived_at: archived_at)

      assert {:error, :already_archived} = Wishes.archive_wish(wish.id, wish.member_id)
      assert Repo.get!(Wish, wish.id).archived_at == archived_at
    end
  end
end
