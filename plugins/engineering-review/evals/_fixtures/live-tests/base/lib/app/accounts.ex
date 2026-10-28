defmodule App.Accounts do
  @moduledoc "Member accounts."

  alias App.Accounts.Users

  defdelegate get_user(id), to: Users
end
