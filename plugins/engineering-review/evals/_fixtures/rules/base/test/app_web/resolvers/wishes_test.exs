defmodule AppWeb.Resolvers.WishesTest do
  use App.DataCase, async: true

  alias AppWeb.Resolvers.Wishes

  test "create_wish records an audit entry" do
    user = insert(:user)
    assert {:ok, _wish} = Wishes.create_wish(nil, %{input: %{title: "Piano"}}, %{context: %{current_user: user}})
    assert [%{action: "wish.created"}] = Repo.all(App.Audit.Entry)
  end
end
