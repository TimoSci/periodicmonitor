defmodule Periodicmonitor.Domains do
  @moduledoc """
  Context for managing monitored ENS domains.
  """

  alias Periodicmonitor.Repo
  alias Periodicmonitor.Domains.EnsDomain

  @expiring_threshold_days 30
  @critical_threshold_days 7

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

      DateTime.diff(expires_at, now, :day) <= @critical_threshold_days ->
        "critical"

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
      {final_expires, status} = classify_domain(expires_at, owner)

      upsert_domain(%{
        name: name,
        label_hash: ENS.label_hash(name),
        owner: owner,
        expires_at: final_expires,
        status: status,
        last_checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
    end
  end

  defp classify_domain(expires_at, owner) do
    zero_address = "0x0000000000000000000000000000000000000000"

    if DateTime.compare(expires_at, ~U[1970-01-02 00:00:00Z]) == :lt and owner == zero_address do
      {nil, "expired"}
    else
      {DateTime.truncate(expires_at, :second), compute_status(expires_at)}
    end
  end

  def check_all_domains do
    names = Application.get_env(:periodicmonitor, :ens_names, [])
    Enum.map(names, &check_domain/1)
  end
end
