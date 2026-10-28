defmodule App.Accounts.Tokens do
  @moduledoc "Issues the tokens members sign in and reset their password with."

  alias App.Accounts.{User, UserToken}
  alias App.Config
  alias App.Repo

  @doc "Issues a session token, valid `session_validity_in_days` of `config :app, :tokens`."
  @spec issue_session_token(User.t()) :: {:ok, String.t()} | {:error, Ecto.Changeset.t()}
  def issue_session_token(%User{} = user) do
    validity_in_days = :app |> Config.fetch_env!(:tokens) |> Keyword.fetch!(:session_validity_in_days)
    issue(user, "session", validity_in_days * 24 * 60)
  end

  @doc "Issues a password reset token, valid `password_reset_validity_in_minutes`."
  @spec issue_password_reset_token(User.t()) :: {:ok, String.t()} | {:error, Ecto.Changeset.t()}
  def issue_password_reset_token(%User{} = user) do
    validity_in_minutes = :app |> Config.fetch_env!(:tokens) |> Keyword.fetch!(:password_reset_validity_in_minutes)
    issue(user, "password_reset", validity_in_minutes)
  end

  defp issue(%User{id: user_id}, context, validity_in_minutes) do
    token = 32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    token_hash = :crypto.hash(:sha256, token)
    expires_at = DateTime.add(DateTime.utc_now(), validity_in_minutes * 60, :second)

    %{user_id: user_id, context: context, token_hash: token_hash, expires_at: expires_at}
    |> UserToken.create_changeset()
    |> Repo.insert()
    |> case do
      {:ok, %UserToken{}} -> {:ok, token}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
    end
  end
end
