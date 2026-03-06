defmodule Periodicmonitor.Repo.Migrations.CreateNotificationLogs do
  use Ecto.Migration

  def change do
    create table(:notification_logs) do
      add :domain_name, :string, null: false
      add :milestone, :string, null: false
      add :sent_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:notification_logs, [:domain_name, :milestone])
  end
end
