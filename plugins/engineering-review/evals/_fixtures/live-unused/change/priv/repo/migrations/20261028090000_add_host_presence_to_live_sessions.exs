defmodule App.Repo.Migrations.AddHostPresenceToLiveSessions do
  use Ecto.Migration

  def change do
    alter table(:live_sessions) do
      add :host_last_seen_at, :utc_datetime_usec
      add :host_absent_since, :utc_datetime_usec
    end
  end
end
