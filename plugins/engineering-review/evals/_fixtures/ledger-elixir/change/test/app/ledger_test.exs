defmodule App.LedgerTest do
  use App.DataCase, async: true

  alias App.Ledger
  alias App.Ledger.Account
  alias App.Ledger.Statement

  defp account(cents), do: Repo.insert!(%Account{balance_cents: cents})
  defp balance(account), do: Repo.get!(Account, account.id).balance_cents

  describe "transfer/3" do
    test "moves the cents from one account to the other" do
      [from, to] = [account(500), account(100)]

      assert {:ok, :transferred} = Ledger.transfer(from.id, to.id, 200)
      assert {balance(from), balance(to)} == {300, 300}
    end

    test "changes nothing when the source holds too little" do
      [from, to] = [account(100), account(0)]

      assert {:error, :insufficient_funds} = Ledger.transfer(from.id, to.id, 200)
      assert {balance(from), balance(to)} == {100, 0}
    end

    test "refuses a transfer to the same account" do
      from = account(100)

      assert {:error, :same_account} = Ledger.transfer(from.id, from.id, 50)
      assert balance(from) == 100
    end

    test "changes nothing when an account does not exist" do
      from = account(100)

      assert {:error, :not_found} = Ledger.transfer(from.id, -1, 50)
      assert balance(from) == 100
    end
  end

  describe "record_entry/2" do
    test "records the entry and counts it on its statement" do
      statement = Repo.insert!(%Statement{account_id: account(0).id, month: ~D[2026-10-01]})

      assert {:ok, entry} = Ledger.record_entry(statement.id, 250)
      assert entry.amount_cents == 250
      assert Repo.get!(Statement, statement.id).entry_count == 1
    end

    test "returns the changeset error for an unknown statement" do
      assert {:error, changeset} = Ledger.record_entry(-1, 250)
      assert %{statement_id: ["does not exist"]} = errors_on(changeset)
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
  end
end
