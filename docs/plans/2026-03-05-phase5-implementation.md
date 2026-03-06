# Phase 5: Alerts & Web Interface — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the default home page with a LiveView dashboard showing ENS domains with color-coded statuses and a refresh button.

**Architecture:** A single LiveView module (`DomainsLive`) replaces the PageController at `/`. It loads domains from the DB on mount, provides an async refresh button that queries Ethereum, and uses Tailwind/daisyUI classes for color-coded status badges with a CSS pulse animation for expired domains.

**Tech Stack:** Phoenix LiveView, Tailwind CSS v4, daisyUI, Ecto.

---

### Task 1: Update compute_status to support "critical" level

**Files:**
- Modify: `lib/periodicmonitor/domains.ex`
- Modify: `test/periodicmonitor/domains_test.exs`

**Step 1: Write the failing test**

Add to `test/periodicmonitor/domains_test.exs`, inside the `describe "compute_status/1"` block, after the existing tests:

```elixir
test "returns \"critical\" when expires_at is less than 7 days away" do
  soon = DateTime.add(DateTime.utc_now(), 3, :day)
  assert Domains.compute_status(soon) == "critical"
end
```

Also update the existing "expiring" test to use a value between 7 and 30 days (it already uses 15 so it's fine).

**Step 2: Run test to verify it fails**

Run: `mix test test/periodicmonitor/domains_test.exs --trace`
Expected: FAIL — "critical" expected but got "expiring".

**Step 3: Update implementation**

In `lib/periodicmonitor/domains.ex`, change `compute_status/1` to:

```elixir
@critical_threshold_days 7
@expiring_threshold_days 30

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
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/periodicmonitor/domains_test.exs --trace`
Expected: 8 tests, 0 failures.

**Step 5: Commit**

```bash
git add lib/periodicmonitor/domains.ex test/periodicmonitor/domains_test.exs
git commit -m "feat: add critical status level (<7 days to expiration)"
```

---

### Task 2: Create DomainsLive LiveView

**Files:**
- Create: `lib/periodicmonitor_web/live/domains_live.ex`
- Modify: `lib/periodicmonitor_web/router.ex`

**Step 1: Create the LiveView module**

Create `lib/periodicmonitor_web/live/domains_live.ex`:

```elixir
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
    {:noreply, assign(socket, :loading, true) |> start_async(:refresh, fn -> Domains.check_all_domains() end)}
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
      "critical" -> "badge badge-error"
      "expired" -> "badge badge-error animate-pulse"
      _ -> "badge badge-ghost"
    end
  end

  defp format_expires_at(nil), do: "—"

  defp format_expires_at(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d")
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
                <td>{format_expires_at(domain.expires_at)}</td>
                <td>{days_until(domain.expires_at)}</td>
                <td>
                  <span class={status_badge_class(domain.status)}>
                    {domain.status}
                  </span>
                </td>
                <td class="text-sm text-base-content/60">{format_expires_at(domain.last_checked_at)}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
```

**Step 2: Update router**

In `lib/periodicmonitor_web/router.ex`, replace:

```elixir
get "/", PageController, :home
```

with:

```elixir
live "/", DomainsLive
```

**Step 3: Verify it compiles**

Run: `mix compile`
Expected: No errors.

**Step 4: Commit**

```bash
git add lib/periodicmonitor_web/live/domains_live.ex lib/periodicmonitor_web/router.ex
git commit -m "feat: add DomainsLive LiveView as home page"
```

---

### Task 3: Write LiveView tests

**Files:**
- Create: `test/periodicmonitor_web/live/domains_live_test.exs`
- Delete: `test/periodicmonitor_web/controllers/page_controller_test.exs`

**Step 1: Create the test file**

Create `test/periodicmonitor_web/live/domains_live_test.exs`:

```elixir
defmodule PeriodicmonitorWeb.DomainsLiveTest do
  use PeriodicmonitorWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Periodicmonitor.Domains

  setup do
    # Insert test domains directly
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
    # Clean up domains inserted in setup
    Periodicmonitor.Repo.delete_all(Periodicmonitor.Domains.EnsDomain)

    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "No domains found"
  end

  test "refresh button exists", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "button", "Refresh")
  end
end
```

**Step 2: Delete old page controller test**

Delete: `test/periodicmonitor_web/controllers/page_controller_test.exs`

**Step 3: Run tests**

Run: `mix test test/periodicmonitor_web/live/domains_live_test.exs --trace`
Expected: 3 tests, 0 failures.

**Step 4: Commit**

```bash
git add test/periodicmonitor_web/live/domains_live_test.exs
git rm test/periodicmonitor_web/controllers/page_controller_test.exs
git commit -m "feat: add DomainsLive tests, remove PageController test"
```

---

### Task 4: Clean up unused PageController

**Files:**
- Delete: `lib/periodicmonitor_web/controllers/page_controller.ex`
- Delete: `lib/periodicmonitor_web/controllers/page_html.ex`
- Delete: `lib/periodicmonitor_web/controllers/page_html/home.html.heex`

**Step 1: Remove files**

```bash
rm lib/periodicmonitor_web/controllers/page_controller.ex
rm lib/periodicmonitor_web/controllers/page_html.ex
rm -r lib/periodicmonitor_web/controllers/page_html/
```

**Step 2: Run full test suite**

Run: `mix test --trace`
Expected: All tests pass (no references to PageController remain).

**Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove unused PageController and templates"
```

---

### Task 5: Update app layout for ENS Monitor

**Files:**
- Modify: `lib/periodicmonitor_web/components/layouts.ex`

**Step 1: Update the app layout header**

Replace the current navbar content in the `app/1` function with a simpler header for the ENS monitor app. Keep the theme toggle.

In `lib/periodicmonitor_web/components/layouts.ex`, replace the `app` function's `~H` template:

```elixir
def app(assigns) do
  ~H"""
  <header class="navbar px-4 sm:px-6 lg:px-8">
    <div class="flex-1">
      <a href="/" class="flex-1 flex w-fit items-center gap-2">
        <.icon name="hero-shield-check" class="size-7 text-primary" />
        <span class="text-lg font-bold">Periodic Monitor</span>
      </a>
    </div>
    <div class="flex-none">
      <.theme_toggle />
    </div>
  </header>

  <main class="px-4 py-10 sm:px-6 lg:px-8">
    <div class="mx-auto max-w-4xl space-y-4">
      {render_slot(@inner_block)}
    </div>
  </main>

  <.flash_group flash={@flash} />
  """
end
```

Note: Changed `max-w-2xl` to `max-w-4xl` for the wider table.

**Step 2: Verify visually**

Run: `mix phx.server` and check localhost:4000.

**Step 3: Commit**

```bash
git add lib/periodicmonitor_web/components/layouts.ex
git commit -m "feat: update app layout with ENS Monitor branding"
```

---

### Task 6: Run precommit, update README and CLAUDE.md

**Step 1: Run precommit**

Run: `mix precommit`
Expected: All tests pass.

**Step 2: Update README.md**

Add to README after the ENS Domain Monitoring section:

```markdown
## Web Interface

Start the server and visit [localhost:4000](http://localhost:4000):

\```bash
mix phx.server
\```

The dashboard displays all monitored ENS domains with color-coded status:
- **Green** — Active (>30 days to expiration)
- **Yellow** — Expiring (7-30 days)
- **Red** — Critical (<7 days)
- **Red pulsing** — Expired

Use the **Refresh** button to query Ethereum and update domain data.
```

**Step 3: Update CLAUDE.md**

Mark Phase 5 items as completed.

**Step 4: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: update README and CLAUDE.md for Phase 5 completion"
```
