defmodule App.Accounts.Referrals do
  @moduledoc "Referrals: a member invites a friend by email."

  alias App.Accounts.Events
  alias App.Accounts.Referral
  alias App.Repo

  @doc "Creates a referral from a referrer to an email address."
  def create_referral(attrs, opts \\ []) do
    attrs
    |> Referral.create_changeset()
    |> Repo.insert(success_event: Events.ReferralCreated, event_opts: opts)
  end
end
