defmodule App.Listings do
  @moduledoc "Rooms offered by hosts."

  alias App.Listings.Listing
  alias App.Repo

  @doc "Gets a listing by id."
  def get_listing!(id), do: Repo.get!(Listing, id)
end
