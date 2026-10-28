defmodule App.Repo.Migrations.CreateLiveSessions do
  use Ecto.Migration

  def change do
    create table(:live_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :activity_id, references(:activities, type: :binary_id), null: false
      add :status, :string, null: false, default: "waiting"
      add :host_last_seen_at, :utc_datetime_usec
      add :host_absent_since, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create index(:live_sessions, [:activity_id, :inserted_at])
    create index(:live_sessions, [:status, :host_absent_since])

    create table(:live_participations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :activity_id, references(:activities, type: :binary_id), null: false
      add :session_id, references(:live_sessions, type: :binary_id), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :first_joined_at, :utc_datetime_usec, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:live_participations, [:session_id, :user_id])
    create index(:live_participations, [:user_id])
    create index(:live_participations, [:activity_id])
  end
end
