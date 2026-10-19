defmodule App.Repo.Migrations.AddReferralCodeToMembers do
  use Ecto.Migration

  def change do
    alter table(:members) do
      add :referral_code, :string
    end

    create unique_index(:members, [:referral_code])
  end
end
