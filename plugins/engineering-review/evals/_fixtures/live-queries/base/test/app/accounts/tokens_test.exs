defmodule App.Accounts.TokensTest do
  use App.DataCase, async: true

  alias App.Accounts.Tokens
  alias App.Accounts.UserToken
  alias App.Config

  describe "issue_session_token/1" do
    test "when sessions last 30 days" do
      Config.put_env(:app, :tokens, session_validity_in_days: 30, password_reset_validity_in_minutes: 15)
      user = insert(:user)

      assert {:ok, token} = Tokens.issue_session_token(user)

      user_token = Repo.get_by!(UserToken, token_hash: :crypto.hash(:sha256, token))
      assert user_token.context == "session"
      assert_in_delta DateTime.diff(user_token.expires_at, DateTime.utc_now(), :day), 30, 1
    end
  end

  describe "issue_password_reset_token/1" do
    test "when a reset lasts 5 minutes" do
      Config.put_env(:app, :tokens, session_validity_in_days: 30, password_reset_validity_in_minutes: 5)
      user = insert(:user)

      assert {:ok, token} = Tokens.issue_password_reset_token(user)

      user_token = Repo.get_by!(UserToken, token_hash: :crypto.hash(:sha256, token))
      assert user_token.context == "password_reset"
      assert_in_delta DateTime.diff(user_token.expires_at, DateTime.utc_now(), :minute), 5, 1
    end
  end
end
