defmodule App.Repo.Migrations.AddListingsHostIdIndex do
  use Ecto.Migration

  def change do
    create index(:listings, [:host_id])
  end
end
