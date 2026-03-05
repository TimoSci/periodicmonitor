defmodule PeriodicmonitorWeb.DomainsLive do
  use PeriodicmonitorWeb, :live_view

  alias Periodicmonitor.Domains

  @impl true
  def mount(_params, _session, socket) do
    domains = Domains.list_domains()

    {:ok,
     socket
     |> assign(:domains, domains)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply,
     socket
     |> assign(:loading, true)
     |> start_async(:refresh, fn -> Domains.check_all_domains() end)}
  end

  @impl true
  def handle_async(:refresh, {:ok, _results}, socket) do
    domains = Domains.list_domains()

    {:noreply,
     socket
     |> assign(:domains, domains)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_async(:refresh, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Failed to refresh domains")
     |> assign(:loading, false)}
  end

  defp status_badge_class(status) do
    case status do
      "active" -> "badge badge-success"
      "expiring" -> "badge badge-warning"
      "critical" -> "badge badge-error animate-pulse"
      "expired" -> "badge badge-error animate-pulse"
      _ -> "badge badge-ghost"
    end
  end

  defp format_date(nil), do: "—"

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d")
  end

  defp format_datetime(nil), do: "—"

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
  end

  defp days_until(nil), do: "—"

  defp days_until(%DateTime{} = dt) do
    days = DateTime.diff(dt, DateTime.utc_now(), :day)

    cond do
      days < 0 -> "#{abs(days)} days ago"
      days == 0 -> "today"
      true -> "#{days} days"
    end
  end

  defp truncate_address(nil), do: "—"

  defp truncate_address(addr) when byte_size(addr) > 10 do
    String.slice(addr, 0, 6) <> "..." <> String.slice(addr, -4, 4)
  end

  defp truncate_address(addr), do: addr

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">ENS Domain Monitor</h1>
          <button
            phx-click="refresh"
            disabled={@loading}
            class={["btn btn-primary", @loading && "btn-disabled"]}
          >
            <.icon :if={@loading} name="hero-arrow-path" class="size-4 animate-spin" />
            <.icon :if={!@loading} name="hero-arrow-path" class="size-4" />
            {if @loading, do: "Refreshing...", else: "Refresh"}
          </button>
        </div>

        <div :if={@domains == []} class="alert alert-info">
          <.icon name="hero-information-circle" class="size-5" />
          <span>No domains found. Click Refresh to check your configured ENS names.</span>
        </div>

        <div :if={@domains != []} class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Owner</th>
                <th>Expires</th>
                <th>Time Left</th>
                <th>Status</th>
                <th>Last Checked</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={domain <- @domains} id={"domain-#{domain.id}"}>
                <td class="font-mono font-semibold">{domain.name}</td>
                <td class="font-mono text-sm">{truncate_address(domain.owner)}</td>
                <td>{format_date(domain.expires_at)}</td>
                <td>{days_until(domain.expires_at)}</td>
                <td>
                  <span class={status_badge_class(domain.status)}>
                    {domain.status}
                  </span>
                </td>
                <td class="text-sm text-base-content/60">{format_datetime(domain.last_checked_at)}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
