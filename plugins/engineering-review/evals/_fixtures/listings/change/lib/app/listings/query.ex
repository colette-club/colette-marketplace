defmodule App.Listings.Query do
  @moduledoc "Composable queries on listings."
  import Ecto.Query

  alias App.Listings.Listing

  def base, do: from(l in Listing, as: :listings)

  def in_city(query, city_id), do: where(query, [listings: l], l.city_id == ^city_id)

  def not_archived(query), do: where(query, [listings: l], is_nil(l.archived_at))

  def newest_first(query), do: order_by(query, [listings: l], desc: l.inserted_at)
end
