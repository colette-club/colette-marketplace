defmodule App.WishesTest do
  use App.DataCase, async: true

  alias App.Wishes

  describe "list_wishes/1" do
    test "when the member has wishes" do
      member = insert(:member)
      wish = insert(:wish, member: member)

      assert [listed] = Wishes.list_wishes(member.id)
      assert listed.id == wish.id
    end
  end

  describe "archive_wish/2" do
    test "archives the wish" do
      wish = insert(:wish)

      assert {:ok, _} = Wishes.archive_wish(wish.id, wish.member_id)
    end
  end
end
