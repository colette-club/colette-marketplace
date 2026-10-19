defmodule App.Accounts.Member do
  @moduledoc "A club member."
  use App.Schema, :schema

  schema "members" do
    field :email, :string
    field :referral_code, :string
    timestamps()
  end

  def referral_code_changeset(%__MODULE__{} = member, code) do
    member
    |> change(referral_code: code)
    |> unique_constraint(:referral_code)
  end
end
