defmodule App.Listings do
  @moduledoc "Rooms offered by hosts."

  alias App.Listings.Listing
  alias App.Listings.Query
  alias App.Repo

  @doc "Gets a listing by id."
  def get_listing!(id), do: Repo.get!(Listing, id)

  @doc "Searches the active listings of a city, newest first, with their host."
  def search(city_id, _filters \\ %{}) do
    Query.base()
    |> Query.in_city(city_id)
    |> Query.not_archived()
    |> Query.newest_first()
    |> Repo.all()
    |> Enum.map(&Repo.preload(&1, :host))
  end
end
