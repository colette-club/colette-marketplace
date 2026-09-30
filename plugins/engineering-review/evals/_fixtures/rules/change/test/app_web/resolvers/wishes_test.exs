defmodule AppWeb.Resolvers.WishesTest do
  use App.DataCase, async: true

  alias AppWeb.Resolvers.Wishes

  test "create_wish records an audit entry" do
    user = insert(:user)
    assert {:ok, _wish} = Wishes.create_wish(nil, %{input: %{title: "Piano"}}, %{context: %{current_user: user}})
    assert [%{action: "wish.created"}] = Repo.all(App.Audit.Entry)
  end

  test "archive_wish archives the member's wish" do
    user = insert(:user)
    wish = insert(:wish, member: user)
    assert {:ok, %{archived_at: %DateTime{}}} = Wishes.archive_wish(nil, %{id: wish.id}, %{context: %{current_user: user}})
  end
end
