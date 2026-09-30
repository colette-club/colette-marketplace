defmodule App.Digests do
  @moduledoc "Weekly digest emails for members."

  alias App.Digests.Builder

  @doc "Builds the digest for a member."
  def build(member), do: Builder.build(member)
end
