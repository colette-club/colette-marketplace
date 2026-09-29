defmodule App.Repo.Migrations.AddArchivedAtToWishes do
  use Ecto.Migration

  def change do
    alter table(:wishes) do
      add :archived_at, :utc_datetime
    end
  end
end
