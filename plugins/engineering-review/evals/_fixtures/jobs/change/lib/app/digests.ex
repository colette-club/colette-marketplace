defmodule App.Digests do
  @moduledoc "Weekly digest emails for members."

  alias App.Digests.Builder
  alias App.Workers.SendDigest

  @doc "Builds the digest for a member."
  def build(member), do: Builder.build(member)

  @doc "Schedules the weekly digest email for a member."
  def schedule(member), do: %{"member_id" => member.id} |> SendDigest.new() |> Oban.insert()
end
