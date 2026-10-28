defmodule App.Communities.Registration do
  @moduledoc "A member's registration to an activity."
  use App.Schema, :schema

  schema "registrations" do
    field :status, :string, default: "validated"
    belongs_to :activity, App.Communities.Activity
    belongs_to :user, App.Accounts.User
    timestamps(type: :utc_datetime_usec)
  end
end
