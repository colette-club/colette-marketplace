defmodule App.Repo.Migrations.CreateCitiesAndListings do
  use Ecto.Migration

  def change do
    create table(:cities) do
      add :name, :string, null: false
      timestamps()
    end

    create table(:listings) do
      add :title, :string, null: false
      add :city_id, references(:cities), null: false
      add :host_id, references(:users), null: false
      add :archived_at, :utc_datetime
      timestamps()
    end
  end
end
