defmodule PeriodicmonitorWeb.DomainsLiveTest do
  use PeriodicmonitorWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Periodicmonitor.Domains

  setup do
    {:ok, _} =
      Domains.upsert_domain(%{
        name: "active.eth",
        label_hash: "0xabc",
        owner: "0xd4416b13d2b3a9abae7acd5d6c2bbdbe25686401",
        expires_at: DateTime.add(DateTime.utc_now(), 60, :day) |> DateTime.truncate(:second),
        status: "active",
        last_checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    {:ok, _} =
      Domains.upsert_domain(%{
        name: "expired.eth",
        label_hash: "0xdef",
        owner: "0x0000000000000000000000000000000000000000",
        expires_at: ~U[2020-01-01 00:00:00Z],
        status: "expired",
        last_checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    :ok
  end

  test "renders domain list", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "ENS Domain Monitor"
    assert html =~ "active.eth"
    assert html =~ "expired.eth"
    assert has_element?(view, "span", "active")
    assert has_element?(view, "span", "expired")
  end

  test "shows empty state when no domains", %{conn: conn} do
    Periodicmonitor.Repo.delete_all(Periodicmonitor.Domains.EnsDomain)

    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "No domains found"
  end

  test "refresh button exists", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "button", "Refresh")
  end
end
