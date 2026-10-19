defmodule App.Repo.Migrations.RenameWishesTitleToName do
  use Ecto.Migration

  def change do
    rename table(:wishes), :title, to: :name
  end
end
