defmodule Periodicmonitor.DomainsTest do
  use Periodicmonitor.DataCase, async: true

  alias Periodicmonitor.Domains
  alias Periodicmonitor.Domains.EnsDomain

  describe "compute_status/1" do
    test "returns \"expired\" when expires_at is in the past" do
      past = DateTime.add(DateTime.utc_now(), -1, :day)
      assert Domains.compute_status(past) == "expired"
    end

    test "returns \"expiring\" when expires_at is within 30 days" do
      soon = DateTime.add(DateTime.utc_now(), 15, :day)
      assert Domains.compute_status(soon) == "expiring"
    end

    test "returns \"active\" when expires_at is more than 30 days away" do
      far = DateTime.add(DateTime.utc_now(), 60, :day)
      assert Domains.compute_status(far) == "active"
    end

    test "returns \"unknown\" when expires_at is nil" do
      assert Domains.compute_status(nil) == "unknown"
    end

    test "returns \"critical\" when expires_at is less than 7 days away" do
      soon = DateTime.add(DateTime.utc_now(), 3, :day)
      assert Domains.compute_status(soon) == "critical"
    end
  end

  describe "upsert_domain/1" do
    test "inserts a new domain" do
      attrs = %{
        name: "test.eth",
        label_hash: "0xabc123",
        owner: "0x1234",
        expires_at: ~U[2027-01-01 00:00:00Z],
        status: "active",
        last_checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      assert {:ok, %EnsDomain{} = domain} = Domains.upsert_domain(attrs)
      assert domain.name == "test.eth"
      assert domain.status == "active"
    end

    test "updates an existing domain" do
      attrs = %{
        name: "test.eth",
        label_hash: "0xabc123",
        owner: "0x1234",
        expires_at: ~U[2027-01-01 00:00:00Z],
        status: "active",
        last_checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      {:ok, _} = Domains.upsert_domain(attrs)

      updated_attrs = Map.merge(attrs, %{status: "expiring", owner: "0x5678"})
      assert {:ok, %EnsDomain{} = domain} = Domains.upsert_domain(updated_attrs)
      assert domain.owner == "0x5678"
      assert domain.status == "expiring"

      assert Repo.aggregate(EnsDomain, :count) == 1
    end
  end

  describe "list_domains/0" do
    test "returns all domains" do
      attrs = %{
        name: "test.eth",
        label_hash: "0xabc123",
        owner: "0x1234",
        expires_at: ~U[2027-01-01 00:00:00Z],
        status: "active",
        last_checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      {:ok, _} = Domains.upsert_domain(attrs)
      assert [%EnsDomain{name: "test.eth"}] = Domains.list_domains()
    end
  end
end
