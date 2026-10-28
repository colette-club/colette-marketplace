defmodule App.Repo.Migrations.CreateLiveSessions do
  use Ecto.Migration

  def change do
    create table(:live_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :activity_id, references(:activities, type: :binary_id), null: false
      add :status, :string, null: false, default: "waiting"
      timestamps(type: :utc_datetime_usec)
    end

    create index(:live_sessions, [:activity_id, :inserted_at, :id])
    create constraint(:live_sessions, :live_sessions_status_check, check: "status IN ('waiting', 'live', 'ended')")
  end
end
