defmodule App.Ledger do
  @moduledoc "Moves cents between members' accounts and records ledger entries on statements."

  import Ecto.Query

  alias App.Ledger.Account
  alias App.Ledger.Entry
  alias App.Ledger.Statement
  alias App.Repo

  @doc """
  Moves `cents` from one account to another. Both accounts are locked in id order before either balance changes.
  """
  def transfer(from_id, to_id, cents) when is_integer(cents) and cents > 0 do
    if from_id == to_id do
      {:error, :same_account}
    else
      Repo.transact(fn -> lock_and_move(from_id, to_id, cents) end)
    end
  end

  defp lock_and_move(from_id, to_id, cents) do
    locked = Repo.all(from(a in Account, where: a.id in ^[from_id, to_id], order_by: a.id, lock: "FOR UPDATE"))

    with 2 <- length(locked),
         {1, _} <- Repo.update_all(debitable(from_id, cents), inc: [balance_cents: -cents]) do
      {1, _} = Repo.update_all(from(a in Account, where: a.id == ^to_id), inc: [balance_cents: cents])
      {:ok, :transferred}
    else
      {0, _} -> {:error, :insufficient_funds}
      _count -> {:error, :not_found}
    end
  end

  defp debitable(account_id, cents),
    do: from(a in Account, where: a.id == ^account_id and a.balance_cents >= ^cents)

  @doc "Records an entry of `amount_cents` on a statement and adds one to the statement's `entry_count`."
  def record_entry(statement_id, amount_cents) do
    Repo.transact(fn ->
      with {:ok, entry} <- insert_entry(statement_id, amount_cents) do
        Repo.update_all(from(s in Statement, where: s.id == ^statement_id), inc: [entry_count: 1])
        {:ok, entry}
      end
    end)
  end

  defp insert_entry(statement_id, amount_cents) do
    %Entry{}
    |> Entry.changeset(%{statement_id: statement_id, amount_cents: amount_cents})
    |> Repo.insert()
  end
end
