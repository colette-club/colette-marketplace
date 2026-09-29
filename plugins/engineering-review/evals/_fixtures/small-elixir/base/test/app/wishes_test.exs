defmodule App.WishesTest do
  use App.DataCase, async: true

  alias App.Wishes

  describe "create_wish/1" do
    test "when the attributes are valid" do
      member = insert(:member)

      assert {:ok, wish} = Wishes.create_wish(%{title: "Pottery class", member_id: member.id})
      assert wish.title == "Pottery class"
    end
  end
end
