defmodule App.Repo.Migrations.CreateWishes do
  use Ecto.Migration

  def change do
    create table(:wishes) do
      add :title, :string, null: false
      add :member_id, references(:members, on_delete: :delete_all), null: false
      timestamps()
    end

    create index(:wishes, [:member_id])
  end
end
