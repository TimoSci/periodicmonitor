# Email Notifications Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Send email alerts when ENS domains are 30 days, 7 days, and 1 day from expiration, with a test email task to verify setup.

**Architecture:** A `notification_logs` table tracks which alerts have been sent (domain + milestone). A `Notifications.Email` module builds and sends emails via Swoosh. A `Notifications.Scheduler` GenServer ticks daily to check domains and fire emails. A mix task sends a test email.

**Tech Stack:** Swoosh (already in project) with SendGrid adapter, Ecto for notification_logs, GenServer for scheduling.

---

### Task 1: Create notification_logs migration

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_notification_logs.exs`

**Step 1: Generate the migration**

Run: `cd /Users/alexandre/documents_copy/code/periodicmonitor && mix ecto.gen.migration create_notification_logs`

**Step 2: Write the migration**

```elixir
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
```

**Step 3: Run the migration**

Run: `mix ecto.migrate`
Expected: migration runs successfully

**Step 4: Commit**

```bash
git add priv/repo/migrations/*_create_notification_logs.exs
git commit -m "feat: add notification_logs migration"
```

---

### Task 2: Create NotificationLog schema

**Files:**
- Create: `lib/periodicmonitor/notifications/notification_log.ex`
- Test: `test/periodicmonitor/notifications/notification_log_test.exs`

**Step 1: Write the failing test**

```elixir
defmodule Periodicmonitor.Notifications.NotificationLogTest do
  use Periodicmonitor.DataCase, async: true

  alias Periodicmonitor.Notifications.NotificationLog

  describe "changeset/2" do
    test "valid changeset" do
      attrs = %{domain_name: "test.eth", milestone: "30d", sent_at: DateTime.utc_now()}
      changeset = NotificationLog.changeset(%NotificationLog{}, attrs)
      assert changeset.valid?
    end

    test "requires domain_name, milestone, and sent_at" do
      changeset = NotificationLog.changeset(%NotificationLog{}, %{})
      refute changeset.valid?
      assert %{domain_name: ["can't be blank"], milestone: ["can't be blank"], sent_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates milestone is one of 30d, 7d, 1d" do
      attrs = %{domain_name: "test.eth", milestone: "99d", sent_at: DateTime.utc_now()}
      changeset = NotificationLog.changeset(%NotificationLog{}, attrs)
      refute changeset.valid?
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/periodicmonitor/notifications/notification_log_test.exs`
Expected: FAIL — module not found

**Step 3: Write the schema**

```elixir
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
```

**Step 4: Run test to verify it passes**

Run: `mix test test/periodicmonitor/notifications/notification_log_test.exs`
Expected: 3 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/periodicmonitor/notifications/notification_log.ex test/periodicmonitor/notifications/notification_log_test.exs
git commit -m "feat: add NotificationLog schema"
```

---

### Task 3: Create Notifications.Email module

**Files:**
- Create: `lib/periodicmonitor/notifications/email.ex`
- Test: `test/periodicmonitor/notifications/email_test.exs`

**Step 1: Write the failing test**

```elixir
defmodule Periodicmonitor.Notifications.EmailTest do
  use Periodicmonitor.DataCase, async: true

  alias Periodicmonitor.Notifications.Email

  describe "expiration_alert/3" do
    test "builds email with correct subject and body for a domain" do
      domain = %Periodicmonitor.Domains.EnsDomain{
        name: "test.eth",
        expires_at: ~U[2026-04-06 00:00:00Z],
        status: "expiring",
        owner: "0x1234"
      }

      email = Email.expiration_alert(domain, "30d", ["user@test.com"])

      assert email.subject =~ "test.eth"
      assert email.subject =~ "30 days"
      assert email.to == [{"", "user@test.com"}]
      assert email.text_body =~ "test.eth"
      assert email.text_body =~ "2026-04-06"
    end

    test "builds email for 7d milestone" do
      domain = %Periodicmonitor.Domains.EnsDomain{
        name: "urs.eth",
        expires_at: ~U[2026-03-13 00:00:00Z],
        status: "critical",
        owner: "0x1234"
      }

      email = Email.expiration_alert(domain, "7d", ["a@b.com", "c@d.com"])

      assert email.subject =~ "7 days"
      assert length(email.to) == 2
    end

    test "builds email for 1d milestone" do
      domain = %Periodicmonitor.Domains.EnsDomain{
        name: "urs.eth",
        expires_at: ~U[2026-03-07 00:00:00Z],
        status: "critical",
        owner: "0x1234"
      }

      email = Email.expiration_alert(domain, "1d", ["a@b.com"])
      assert email.subject =~ "1 day"
    end
  end

  describe "test_email/1" do
    test "builds a test email" do
      email = Email.test_email(["user@test.com"])

      assert email.subject =~ "Test"
      assert email.to == [{"", "user@test.com"}]
      assert email.text_body =~ "working correctly"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/periodicmonitor/notifications/email_test.exs`
Expected: FAIL — module not found

**Step 3: Write the implementation**

```elixir
defmodule Periodicmonitor.Notifications.Email do
  import Swoosh.Email

  @milestone_labels %{"30d" => "30 days", "7d" => "7 days", "1d" => "1 day"}

  def expiration_alert(domain, milestone, recipients) do
    label = Map.fetch!(@milestone_labels, milestone)
    from_address = Application.get_env(:periodicmonitor, :alert_from_email, "alerts@periodicmonitor.local")

    new()
    |> to(Enum.map(recipients, &{"", &1}))
    |> from({"ENS Monitor", from_address})
    |> subject("[ENS Alert] #{domain.name} expires in #{label}")
    |> text_body("""
    ENS Domain Expiration Alert

    Domain: #{domain.name}
    Expires: #{Calendar.strftime(domain.expires_at, "%Y-%m-%d %H:%M UTC")}
    Status: #{domain.status}
    Owner: #{domain.owner}

    This domain will expire in #{label}. Please renew it to avoid losing ownership.

    --
    ENS Domain Monitor
    """)
  end

  def test_email(recipients) do
    from_address = Application.get_env(:periodicmonitor, :alert_from_email, "alerts@periodicmonitor.local")

    new()
    |> to(Enum.map(recipients, &{"", &1}))
    |> from({"ENS Monitor", from_address})
    |> subject("[ENS Monitor] Test Email")
    |> text_body("""
    ENS Domain Monitor — Test Email

    This email confirms that your notification system is working correctly.

    You will receive alerts when your ENS domains are 30 days, 7 days, and 1 day from expiration.

    --
    ENS Domain Monitor
    """)
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/periodicmonitor/notifications/email_test.exs`
Expected: 4 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/periodicmonitor/notifications/email.ex test/periodicmonitor/notifications/email_test.exs
git commit -m "feat: add Notifications.Email module for expiration alerts"
```

---

### Task 4: Create Notifications context module

**Files:**
- Create: `lib/periodicmonitor/notifications.ex`
- Test: `test/periodicmonitor/notifications_test.exs`

**Step 1: Write the failing test**

```elixir
defmodule Periodicmonitor.NotificationsTest do
  use Periodicmonitor.DataCase, async: true

  alias Periodicmonitor.Notifications
  alias Periodicmonitor.Notifications.NotificationLog
  alias Periodicmonitor.Domains

  describe "milestone_for_domain/1" do
    test "returns \"1d\" when domain expires in 1 day" do
      domain = %Periodicmonitor.Domains.EnsDomain{expires_at: DateTime.add(DateTime.utc_now(), 1, :day)}
      assert Notifications.milestone_for_domain(domain) == "1d"
    end

    test "returns \"7d\" when domain expires in 5 days" do
      domain = %Periodicmonitor.Domains.EnsDomain{expires_at: DateTime.add(DateTime.utc_now(), 5, :day)}
      assert Notifications.milestone_for_domain(domain) == "7d"
    end

    test "returns \"30d\" when domain expires in 20 days" do
      domain = %Periodicmonitor.Domains.EnsDomain{expires_at: DateTime.add(DateTime.utc_now(), 20, :day)}
      assert Notifications.milestone_for_domain(domain) == "30d"
    end

    test "returns nil when domain expires in more than 30 days" do
      domain = %Periodicmonitor.Domains.EnsDomain{expires_at: DateTime.add(DateTime.utc_now(), 60, :day)}
      assert Notifications.milestone_for_domain(domain) == nil
    end

    test "returns nil when domain has no expiry" do
      domain = %Periodicmonitor.Domains.EnsDomain{expires_at: nil}
      assert Notifications.milestone_for_domain(domain) == nil
    end

    test "returns nil when domain is already expired" do
      domain = %Periodicmonitor.Domains.EnsDomain{expires_at: DateTime.add(DateTime.utc_now(), -1, :day)}
      assert Notifications.milestone_for_domain(domain) == nil
    end
  end

  describe "already_notified?/2" do
    test "returns false when no log exists" do
      refute Notifications.already_notified?("test.eth", "30d")
    end

    test "returns true when log exists" do
      Repo.insert!(%NotificationLog{
        domain_name: "test.eth",
        milestone: "30d",
        sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      assert Notifications.already_notified?("test.eth", "30d")
    end
  end

  describe "record_notification!/2" do
    test "creates a notification log" do
      Notifications.record_notification!("test.eth", "7d")
      assert Repo.get_by(NotificationLog, domain_name: "test.eth", milestone: "7d")
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/periodicmonitor/notifications_test.exs`
Expected: FAIL — module not found

**Step 3: Write the implementation**

```elixir
defmodule Periodicmonitor.Notifications do
  alias Periodicmonitor.Repo
  alias Periodicmonitor.Notifications.NotificationLog

  def milestone_for_domain(%{expires_at: nil}), do: nil

  def milestone_for_domain(%{expires_at: expires_at}) do
    days = DateTime.diff(expires_at, DateTime.utc_now(), :day)

    cond do
      days < 0 -> nil
      days <= 1 -> "1d"
      days <= 7 -> "7d"
      days <= 30 -> "30d"
      true -> nil
    end
  end

  def already_notified?(domain_name, milestone) do
    Repo.get_by(NotificationLog, domain_name: domain_name, milestone: milestone) != nil
  end

  def record_notification!(domain_name, milestone) do
    %NotificationLog{}
    |> NotificationLog.changeset(%{
      domain_name: domain_name,
      milestone: milestone,
      sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/periodicmonitor/notifications_test.exs`
Expected: 8 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/periodicmonitor/notifications.ex test/periodicmonitor/notifications_test.exs
git commit -m "feat: add Notifications context with milestone detection and logging"
```

---

### Task 5: Create Notifications.Scheduler GenServer

**Files:**
- Create: `lib/periodicmonitor/notifications/scheduler.ex`
- Test: `test/periodicmonitor/notifications/scheduler_test.exs`
- Modify: `lib/periodicmonitor/application.ex`

**Step 1: Write the failing test**

```elixir
defmodule Periodicmonitor.Notifications.SchedulerTest do
  use Periodicmonitor.DataCase, async: false

  alias Periodicmonitor.Notifications.Scheduler
  alias Periodicmonitor.Notifications.NotificationLog
  alias Periodicmonitor.Domains

  describe "check_and_notify/0" do
    test "sends notification and records log for domain within milestone" do
      # Insert a domain expiring in 5 days (7d milestone)
      {:ok, _domain} =
        Domains.upsert_domain(%{
          name: "alert.eth",
          label_hash: "0xabc",
          owner: "0x1234",
          expires_at: DateTime.add(DateTime.utc_now(), 5, :day) |> DateTime.truncate(:second),
          status: "critical",
          last_checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      Scheduler.check_and_notify()

      # Should have recorded a notification log
      assert Repo.get_by(NotificationLog, domain_name: "alert.eth", milestone: "7d")
    end

    test "does not send duplicate notifications" do
      {:ok, _domain} =
        Domains.upsert_domain(%{
          name: "alert.eth",
          label_hash: "0xabc",
          owner: "0x1234",
          expires_at: DateTime.add(DateTime.utc_now(), 5, :day) |> DateTime.truncate(:second),
          status: "critical",
          last_checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      Scheduler.check_and_notify()
      Scheduler.check_and_notify()

      logs = Repo.all(NotificationLog)
      assert length(logs) == 1
    end

    test "skips domains with no milestone" do
      {:ok, _domain} =
        Domains.upsert_domain(%{
          name: "safe.eth",
          label_hash: "0xdef",
          owner: "0x5678",
          expires_at: DateTime.add(DateTime.utc_now(), 60, :day) |> DateTime.truncate(:second),
          status: "active",
          last_checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      Scheduler.check_and_notify()

      assert Repo.all(NotificationLog) == []
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/periodicmonitor/notifications/scheduler_test.exs`
Expected: FAIL — module not found

**Step 3: Write the implementation**

```elixir
defmodule Periodicmonitor.Notifications.Scheduler do
  use GenServer

  require Logger

  @daily_interval :timer.hours(24)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, @daily_interval)
    schedule_tick(interval)
    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_info(:tick, state) do
    check_and_notify()
    schedule_tick(state.interval)
    {:noreply, state}
  end

  def check_and_notify do
    alias Periodicmonitor.{Domains, Notifications}
    alias Periodicmonitor.Notifications.Email
    alias Periodicmonitor.Mailer

    recipients = Application.get_env(:periodicmonitor, :alert_recipients, [])

    if recipients == [] do
      Logger.warning("[Notifications.Scheduler] No alert recipients configured, skipping.")
      :ok
    else
      Domains.list_domains()
      |> Enum.each(fn domain ->
        case Notifications.milestone_for_domain(domain) do
          nil ->
            :skip

          milestone ->
            unless Notifications.already_notified?(domain.name, milestone) do
              email = Email.expiration_alert(domain, milestone, recipients)

              case Mailer.deliver(email) do
                {:ok, _} ->
                  Notifications.record_notification!(domain.name, milestone)
                  Logger.info("[Notifications.Scheduler] Sent #{milestone} alert for #{domain.name}")

                {:error, reason} ->
                  Logger.error("[Notifications.Scheduler] Failed to send alert for #{domain.name}: #{inspect(reason)}")
              end
            end
        end
      end)
    end
  end

  defp schedule_tick(interval) do
    Process.send_after(self(), :tick, interval)
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/periodicmonitor/notifications/scheduler_test.exs`
Expected: 3 tests, 0 failures

**Step 5: Add Scheduler to application supervision tree**

Modify `lib/periodicmonitor/application.ex` — add to children list, before the Endpoint:

```elixir
Periodicmonitor.Notifications.Scheduler,
```

**Step 6: Run full test suite**

Run: `mix test`
Expected: All tests pass

**Step 7: Commit**

```bash
git add lib/periodicmonitor/notifications/scheduler.ex test/periodicmonitor/notifications/scheduler_test.exs lib/periodicmonitor/application.ex
git commit -m "feat: add Notifications.Scheduler GenServer for daily email alerts"
```

---

### Task 6: Configuration for SendGrid and recipients

**Files:**
- Modify: `config/config.exs`
- Modify: `config/dev.exs`
- Modify: `config/test.exs`
- Modify: `config/runtime.exs`

**Step 1: Add notification config defaults to config/config.exs**

Add before the `import_config` line:

```elixir
# Notification settings
config :periodicmonitor, :alert_recipients, []
config :periodicmonitor, :alert_from_email, "alerts@periodicmonitor.local"
```

**Step 2: Configure test.exs — disable scheduler and use test mailer**

Add to `config/test.exs`:

```elixir
# Disable notification scheduler in tests
config :periodicmonitor, :start_notification_scheduler, false
```

**Step 3: Configure dev.exs — disable scheduler by default (use mix task to test)**

Add to `config/dev.exs`:

```elixir
# Disable notification scheduler in dev (use mix task to test manually)
config :periodicmonitor, :start_notification_scheduler, false
```

**Step 4: Update application.ex to conditionally start scheduler**

The scheduler child entry should be conditional:

```elixir
# In children list, replace the plain module with:
if Application.get_env(:periodicmonitor, :start_notification_scheduler, true) do
  [Periodicmonitor.Notifications.Scheduler]
else
  []
end
```

Flatten into children list with `++`.

**Step 5: Add runtime.exs config for prod (SendGrid + recipients)**

Add to the `if config_env() == :prod do` block in `config/runtime.exs`:

```elixir
# SendGrid email delivery
config :periodicmonitor, Periodicmonitor.Mailer,
  adapter: Swoosh.Adapters.Sendgrid,
  api_key: System.get_env("SENDGRID_API_KEY") ||
    raise("environment variable SENDGRID_API_KEY is missing.")

config :swoosh, :api_client, Swoosh.ApiClient.Req

config :periodicmonitor,
  :alert_recipients,
  System.get_env("ALERT_RECIPIENTS", "")
  |> String.split(",", trim: true)
  |> Enum.map(&String.trim/1)

config :periodicmonitor,
  :alert_from_email,
  System.get_env("ALERT_FROM_EMAIL", "alerts@periodicmonitor.local")
```

**Step 6: Run full test suite**

Run: `mix test`
Expected: All tests pass

**Step 7: Commit**

```bash
git add config/config.exs config/dev.exs config/test.exs config/runtime.exs lib/periodicmonitor/application.ex
git commit -m "feat: add SendGrid and notification configuration"
```

---

### Task 7: Create mix task for test email

**Files:**
- Create: `lib/mix/tasks/notifications.test_email.ex`
- Test: `test/mix/tasks/notifications.test_email_test.exs`

**Step 1: Write the failing test**

```elixir
defmodule Mix.Tasks.Notifications.TestEmailTest do
  use Periodicmonitor.DataCase

  import ExUnit.CaptureIO
  import Swoosh.TestAssertions

  describe "run/1" do
    test "sends a test email to configured recipients" do
      Application.put_env(:periodicmonitor, :alert_recipients, ["test@example.com"])

      output =
        capture_io(fn ->
          Mix.Tasks.Notifications.TestEmail.run([])
        end)

      assert output =~ "Test email sent"
      assert_email_sent(subject: "[ENS Monitor] Test Email")
    end

    test "prints error when no recipients configured" do
      Application.put_env(:periodicmonitor, :alert_recipients, [])

      output =
        capture_io(fn ->
          Mix.Tasks.Notifications.TestEmail.run([])
        end)

      assert output =~ "No recipients"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mix/tasks/notifications.test_email_test.exs`
Expected: FAIL — module not found

**Step 3: Write the implementation**

```elixir
defmodule Mix.Tasks.Notifications.TestEmail do
  @moduledoc "Sends a test email to verify notification setup."
  @shortdoc "Send a test notification email"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    recipients = Application.get_env(:periodicmonitor, :alert_recipients, [])

    if recipients == [] do
      Mix.shell().info("No recipients configured. Set ALERT_RECIPIENTS env var.")
    else
      email = Periodicmonitor.Notifications.Email.test_email(recipients)

      case Periodicmonitor.Mailer.deliver(email) do
        {:ok, _} ->
          Mix.shell().info("Test email sent to: #{Enum.join(recipients, ", ")}")

        {:error, reason} ->
          Mix.shell().info("Failed to send test email: #{inspect(reason)}")
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mix/tasks/notifications.test_email_test.exs`
Expected: 2 tests, 0 failures

**Step 5: Run precommit**

Run: `mix precommit`
Expected: All checks pass

**Step 6: Commit**

```bash
git add lib/mix/tasks/notifications.test_email.ex test/mix/tasks/notifications.test_email_test.exs
git commit -m "feat: add mix notifications.test_email task"
```

---

### Task 8: Update README and CLAUDE.md

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`

**Step 1: Add notification docs to README**

Add a section covering:
- Environment variables needed: `SENDGRID_API_KEY`, `ALERT_RECIPIENTS`, `ALERT_FROM_EMAIL`
- How to test: `mix notifications.test_email`
- How the scheduler works (daily check, milestones 30d/7d/1d)

**Step 2: Update CLAUDE.md status**

Mark the notification feature as completed in the TODO list.

**Step 3: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: add email notification setup instructions"
```
