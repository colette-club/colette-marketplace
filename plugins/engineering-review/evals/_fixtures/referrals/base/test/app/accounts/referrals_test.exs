defmodule App.Accounts.ReferralsTest do
  use App.DataCase, async: true

  alias App.Accounts.Referrals

  describe "create_referral/2" do
    test "when the referrer invites a friend" do
      referrer = insert(:user, invites_remaining: 2)

      assert {:ok, referral} = Referrals.create_referral(%{referrer_id: referrer.id, email: "friend@example.com"})
      assert referral.email == "friend@example.com"
    end
  end
end
