defmodule App.Repo.Migrations.CreateWishes do
  use Ecto.Migration

  def change do
    create table(:wishes) do
      add :title, :string, null: false
      add :member_id, references(:members), null: false
      timestamps()
    end
  end
end
