defmodule App.Accounts.ReferralCodes do
  @moduledoc "Gives each member a code to share with friends they invite."

  alias App.Accounts.Member
  alias App.Repo

  @doc "Assigns a new eight-character referral code to a member."
  def assign_referral_code(%Member{} = member) do
    code = 5 |> :crypto.strong_rand_bytes() |> Base.encode32(padding: false)

    member
    |> Member.referral_code_changeset(code)
    |> Repo.update()
  end
end
