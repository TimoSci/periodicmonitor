defmodule Periodicmonitor.Domains do
  @moduledoc """
  Context for managing monitored ENS domains.
  """

  alias Periodicmonitor.Repo
  alias Periodicmonitor.Domains.EnsDomain

  @expiring_threshold_days 30

  def list_domains do
    Repo.all(EnsDomain)
  end

  def upsert_domain(attrs) do
    case Repo.get_by(EnsDomain, name: attrs.name) do
      nil -> %EnsDomain{}
      existing -> existing
    end
    |> EnsDomain.changeset(attrs)
    |> Repo.insert_or_update()
  end

  def compute_status(nil), do: "unknown"

  def compute_status(%DateTime{} = expires_at) do
    now = DateTime.utc_now()

    cond do
      DateTime.compare(expires_at, now) == :lt ->
        "expired"

      DateTime.diff(expires_at, now, :day) <= @expiring_threshold_days ->
        "expiring"

      true ->
        "active"
    end
  end

  def check_domain(name) do
    alias Periodicmonitor.Ethereum.ENS

    with {:ok, expires_at} <- ENS.name_expires(name),
         {:ok, owner} <- ENS.get_owner(name) do
      upsert_domain(%{
        name: name,
        label_hash: ENS.label_hash(name),
        owner: owner,
        expires_at: DateTime.truncate(expires_at, :second),
        status: compute_status(expires_at),
        last_checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
    end
  end

  def check_all_domains do
    names = Application.get_env(:periodicmonitor, :ens_names, [])
    Enum.map(names, &check_domain/1)
  end
end
