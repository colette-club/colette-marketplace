defmodule App.Listings.Listing do
  @moduledoc "A room offered by a host."
  use App.Schema, :schema

  schema "listings" do
    field :title, :string
    field :archived_at, :utc_datetime
    belongs_to :city, App.Places.City
    belongs_to :host, App.Accounts.User
    timestamps()
  end
end
