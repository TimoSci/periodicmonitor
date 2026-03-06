defmodule Periodicmonitor.Notifications.NotificationLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notification_logs" do
    field :domain_name, :string
    field :milestone, :string
    field :sent_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @valid_milestones ~w(30d 7d 1d)

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:domain_name, :milestone, :sent_at])
    |> validate_required([:domain_name, :milestone, :sent_at])
    |> validate_inclusion(:milestone, @valid_milestones)
    |> unique_constraint([:domain_name, :milestone])
  end
end
