defmodule App.Communities.Registration do
  @moduledoc "A member's registration to an activity; `attended_at` is set once they attended."
  use App.Schema, :schema

  schema "registrations" do
    field :attended_at, :utc_datetime_usec
    belongs_to :activity, App.Communities.Activity
    belongs_to :user, App.Accounts.User
    timestamps()
  end

  def attend_changeset(%__MODULE__{} = registration) do
    change(registration, attended_at: DateTime.utc_now())
  end
end
