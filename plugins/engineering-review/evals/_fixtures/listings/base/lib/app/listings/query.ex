defmodule App.Listings.Query do
  @moduledoc "Composable queries on listings."
  import Ecto.Query

  alias App.Listings.Listing

  def base, do: from(l in Listing, as: :listings)
end
