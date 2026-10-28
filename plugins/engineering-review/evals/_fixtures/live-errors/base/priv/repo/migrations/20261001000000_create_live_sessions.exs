defmodule App.Repo.Migrations.CreateLiveSessions do
  use Ecto.Migration

  def change do
    create table(:live_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :activity_id, references(:activities, type: :binary_id), null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:live_sessions, [:activity_id])
  end
end
