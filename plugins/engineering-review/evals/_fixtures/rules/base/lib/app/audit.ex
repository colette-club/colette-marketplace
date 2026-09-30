defmodule App.Audit do
  @moduledoc "Records who did what, for the support team's audit trail."

  alias App.Audit.Entry
  alias App.Repo

  @doc "Records that `actor` performed `action`."
  def log(actor, action), do: Repo.insert(%Entry{actor_id: actor.id, action: action})
end
