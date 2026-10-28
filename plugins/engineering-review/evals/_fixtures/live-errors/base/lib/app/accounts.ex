defmodule App.Accounts do
  @moduledoc """
  Member accounts. An account is deleted on the member's request: the row is
  removed at once, with everything that cascades from it.
  """

  alias App.Accounts.User
  alias App.Errors
  alias App.Repo

  @doc "The member, or `NotFoundError`."
  def get_user(id) when is_binary(id) do
    case Repo.get(User, id) do
      %User{} = user -> {:ok, user}
      nil -> {:error, Errors.NotFoundError.new(resource_type: "User", resource_id: id)}
    end
  end

  @doc "Deletes the member's account for good."
  def delete_user(%User{} = user), do: Repo.delete(user)
end
