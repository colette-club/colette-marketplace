defmodule App.Accounts.Users do
  @moduledoc "Reads member accounts."

  alias App.Accounts.User
  alias App.Errors
  alias App.Repo

  @doc "The user with this id, or `NotFoundError`."
  @spec get_user(binary()) :: {:ok, User.t()} | {:error, Errors.NotFoundError.t()}
  def get_user(id) when is_binary(id) do
    User
    |> Repo.get(id)
    |> found()
  end

  defp found(%User{} = user), do: {:ok, user}
  defp found(nil), do: {:error, Errors.NotFoundError.new(resource_type: "User")}
end
