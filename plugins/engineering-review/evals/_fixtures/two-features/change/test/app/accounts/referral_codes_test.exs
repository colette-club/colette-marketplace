defmodule App.Accounts.ReferralCodesTest do
  use App.DataCase, async: true

  alias App.Accounts.ReferralCodes

  describe "assign_referral_code/1" do
    test "when the member has no code" do
      member = insert(:member, referral_code: nil)

      assert {:ok, updated} = ReferralCodes.assign_referral_code(member)
      assert String.length(updated.referral_code) == 8
    end
  end
end
