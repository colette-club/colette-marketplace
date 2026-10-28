defmodule App.Repo.Migrations.CreateActivities do
  use Ecto.Migration

  def change do
    create table(:activities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :starts_at, :timestamptz, null: false
      add :ends_at, :timestamptz, null: false
      add :archived_at, :timestamptz
      add :organizer_id, references(:users, type: :binary_id)
      add :creator_id, references(:users, type: :binary_id), null: false
      timestamps(type: :utc_datetime_usec)
    end

    create index(:activities, [:organizer_id])
    create index(:activities, [:creator_id])
  end
end
