defmodule App.DataCase do
  @moduledoc "Runs each test inside a sandboxed database transaction."
  use ExUnit.CaseTemplate

  using do
    quote do
      alias App.Repo
      import Ecto.Query
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(App.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
