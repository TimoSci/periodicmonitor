defmodule Periodicmonitor.Domains.EnsDomain do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ens_domains" do
    field :name, :string
    field :label_hash, :string
    field :owner, :string
    field :expires_at, :utc_datetime
    field :status, :string, default: "unknown"
    field :last_checked_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ens_domain, attrs) do
    ens_domain
    |> cast(attrs, [:name, :label_hash, :owner, :expires_at, :status, :last_checked_at])
    |> validate_required([:name, :label_hash, :status])
    |> unique_constraint(:name)
  end
end
