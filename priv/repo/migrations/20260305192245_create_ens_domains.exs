defmodule Periodicmonitor.Repo.Migrations.CreateEnsDomains do
  use Ecto.Migration

  def change do
    create table(:ens_domains) do
      add :name, :string, null: false
      add :label_hash, :string, null: false
      add :owner, :string
      add :expires_at, :utc_datetime
      add :status, :string, null: false, default: "unknown"
      add :last_checked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:ens_domains, [:name])
  end
end
