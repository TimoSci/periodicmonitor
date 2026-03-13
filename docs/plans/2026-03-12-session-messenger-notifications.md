# Session Messenger Notifications — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace email as the default notification transport with Session Messenger, while keeping email as an inactive fallback configurable via a single config flag.

**Architecture:** A Bun microservice (`session_service/`) exposes HTTP endpoints for sending Session messages. Elixir calls it via `Req`. A transport behaviour abstracts Session vs Email, selected by `:notification_transport` config. The Scheduler dispatches through the active transport.

**Tech Stack:** Bun + @session.js/client (microservice), Elixir/Phoenix + Req (client), existing Swoosh/Mailgun (dormant fallback)

---

## File Structure

### New Files
- `session_service/index.ts` — Bun HTTP server (~60 lines)
- `session_service/package.json` — Bun dependencies
- `session_service/.env.example` — Example env vars for the microservice
- `lib/periodicmonitor/notifications/transport.ex` — Transport behaviour
- `lib/periodicmonitor/notifications/session_transport.ex` — Session implementation (calls microservice via Req)
- `lib/periodicmonitor/notifications/email_transport.ex` — Email implementation (wraps existing Email + Mailer)
- `lib/mix/tasks/notifications.test_session.ex` — Mix task to test Session delivery
- `test/periodicmonitor/notifications/session_transport_test.exs` — SessionTransport tests
- `test/periodicmonitor/notifications/email_transport_test.exs` — EmailTransport tests
- `test/mix/tasks/notifications.test_session_test.exs` — Test Session mix task tests

### Modified Files
- `lib/periodicmonitor/notifications/scheduler.ex` — Use transport dispatcher instead of direct Email+Mailer
- `config/config.exs` — Add `:notification_transport`, `:session_recipients`, `:session_service_url`
- `config/runtime.exs` — Add Session env vars, keep Mailgun config
- `config/test.exs` — Add session test config
- `config/dev.exs` — (no change, private.exs handles secrets)
- `.gitignore` — Add `session_service/node_modules/`, `session_service/.env`

### Unchanged Files
- `lib/periodicmonitor/notifications.ex` — Milestone logic stays as-is
- `lib/periodicmonitor/notifications/notification_log.ex` — Logging stays as-is
- `lib/periodicmonitor/notifications/email.ex` — Kept for fallback
- `lib/periodicmonitor/mailer.ex` — Kept for fallback
- `test/periodicmonitor/notifications_test.exs` — Milestone tests stay as-is
- `test/periodicmonitor/notifications/email_test.exs` — Email tests stay as-is

---

## Chunk 1: Bun Microservice

### Task 1: Scaffold the Bun microservice

**Files:**
- Create: `session_service/package.json`
- Create: `session_service/.env.example`
- Create: `session_service/index.ts`

- [ ] **Step 1: Create package.json**

```json
{
  "name": "session-service",
  "version": "1.0.0",
  "dependencies": {
    "@session.js/client": "latest"
  }
}
```

- [ ] **Step 2: Create .env.example**

```env
SESSION_BOT_MNEMONIC=your thirteen word mnemonic phrase goes here replace this
SESSION_DISPLAY_NAME=ENS Monitor Bot
PORT=3100
```

- [ ] **Step 3: Create index.ts with all endpoints**

```typescript
import { Session, ready } from "@session.js/client";

await ready;

const mnemonic = process.env.SESSION_BOT_MNEMONIC;
if (!mnemonic) {
  console.error("SESSION_BOT_MNEMONIC is required");
  process.exit(1);
}

const displayName = process.env.SESSION_DISPLAY_NAME || "ENS Monitor Bot";
const port = parseInt(process.env.PORT || "3100", 10);

const session = new Session();
session.setMnemonic(mnemonic, displayName);

const sessionId = session.getSessionID();
console.log(`Bot Session ID: ${sessionId}`);
console.log(`Listening on port ${port}`);

Bun.serve({
  port,
  async fetch(req) {
    const url = new URL(req.url);

    if (req.method === "GET" && url.pathname === "/health") {
      return Response.json({ status: "ok", session_id: sessionId });
    }

    if (req.method === "GET" && url.pathname === "/generate-mnemonic") {
      const { Mnemonic } = await import("@session.js/mnemonic");
      const newMnemonic = Mnemonic.generate();
      return Response.json({ mnemonic: newMnemonic });
    }

    if (req.method === "POST" && url.pathname === "/send") {
      try {
        const body = await req.json();
        const { to, text } = body;

        if (!to || !text) {
          return Response.json(
            { error: "Missing 'to' or 'text' field" },
            { status: 400 }
          );
        }

        const result = await session.sendMessage({ to, text });
        return Response.json({
          status: "sent",
          message_hash: result.messageHash,
          timestamp: result.timestamp,
        });
      } catch (error) {
        return Response.json(
          { error: String(error) },
          { status: 500 }
        );
      }
    }

    return Response.json({ error: "Not found" }, { status: 404 });
  },
});
```

- [ ] **Step 4: Install dependencies**

Run: `cd session_service && bun install`
Expected: `node_modules/` created, `@session.js/client` installed

- [ ] **Step 5: Add to .gitignore**

Append to project root `.gitignore`:
```
# Session microservice
session_service/node_modules/
session_service/.env
session_service/bun.lockb
```

- [ ] **Step 6: Commit**

```bash
git add session_service/package.json session_service/.env.example session_service/index.ts .gitignore
git commit -m "feat: add Session Messenger Bun microservice"
```

---

## Chunk 2: Transport Behaviour & Implementations

### Task 2: Create the Transport behaviour

**Files:**
- Create: `lib/periodicmonitor/notifications/transport.ex`

- [ ] **Step 1: Write the Transport behaviour**

```elixir
defmodule Periodicmonitor.Notifications.Transport do
  @moduledoc "Behaviour for notification transports (Session, Email)."

  @callback send_alert(domain :: map(), milestone :: String.t(), recipients :: list(String.t())) ::
              :ok | {:error, term()}

  @callback send_test(recipients :: list(String.t())) ::
              :ok | {:error, term()}

  def current do
    case Application.get_env(:periodicmonitor, :notification_transport, :session) do
      :session -> Periodicmonitor.Notifications.SessionTransport
      :email -> Periodicmonitor.Notifications.EmailTransport
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add lib/periodicmonitor/notifications/transport.ex
git commit -m "feat: add Transport behaviour for notification dispatching"
```

### Task 3: Create EmailTransport (wraps existing code)

**Files:**
- Create: `test/periodicmonitor/notifications/email_transport_test.exs`
- Create: `lib/periodicmonitor/notifications/email_transport.ex`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule Periodicmonitor.Notifications.EmailTransportTest do
  use Periodicmonitor.DataCase

  import Swoosh.TestAssertions

  alias Periodicmonitor.Notifications.EmailTransport

  describe "send_alert/3" do
    test "delivers an email alert for a domain" do
      domain = %Periodicmonitor.Domains.EnsDomain{
        name: "test.eth",
        expires_at: ~U[2026-04-06 00:00:00Z],
        status: "expiring",
        owner: "0x1234"
      }

      assert :ok = EmailTransport.send_alert(domain, "30d", ["user@test.com"])
      assert_email_sent(subject: "[ENS Alert] test.eth expires in 30 days")
    end
  end

  describe "send_test/1" do
    test "delivers a test email" do
      assert :ok = EmailTransport.send_test(["user@test.com"])
      assert_email_sent(subject: "[ENS Monitor] Test Email")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/periodicmonitor/notifications/email_transport_test.exs`
Expected: FAIL — `EmailTransport` module not found

- [ ] **Step 3: Write the implementation**

```elixir
defmodule Periodicmonitor.Notifications.EmailTransport do
  @moduledoc "Email notification transport using Swoosh."

  @behaviour Periodicmonitor.Notifications.Transport

  alias Periodicmonitor.Notifications.Email
  alias Periodicmonitor.Mailer

  @impl true
  def send_alert(domain, milestone, recipients) do
    domain
    |> Email.expiration_alert(milestone, recipients)
    |> Mailer.deliver()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def send_test(recipients) do
    recipients
    |> Email.test_email()
    |> Mailer.deliver()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/periodicmonitor/notifications/email_transport_test.exs`
Expected: 2 tests, 0 failures

- [ ] **Step 5: Commit**

```bash
git add lib/periodicmonitor/notifications/email_transport.ex test/periodicmonitor/notifications/email_transport_test.exs
git commit -m "feat: add EmailTransport wrapping existing Swoosh delivery"
```

### Task 4: Create SessionTransport

**Files:**
- Create: `test/periodicmonitor/notifications/session_transport_test.exs`
- Create: `lib/periodicmonitor/notifications/session_transport.ex`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule Periodicmonitor.Notifications.SessionTransportTest do
  use Periodicmonitor.DataCase, async: true

  alias Periodicmonitor.Notifications.SessionTransport

  @milestone_labels %{"30d" => "30 days", "7d" => "7 days", "1d" => "1 day"}

  setup do
    # Use Req.Test to stub the session service
    Req.Test.stub(Periodicmonitor.Notifications.SessionTransport, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        status: "sent",
        message_hash: "abc123",
        timestamp: System.system_time(:millisecond)
      }))
    end)

    :ok
  end

  describe "send_alert/3" do
    test "sends a Session message for each recipient" do
      domain = %Periodicmonitor.Domains.EnsDomain{
        name: "test.eth",
        expires_at: ~U[2026-04-06 00:00:00Z],
        status: "expiring",
        owner: "0x1234"
      }

      recipients = ["05abc123def456", "05def789abc012"]
      assert :ok = SessionTransport.send_alert(domain, "30d", recipients)
    end
  end

  describe "send_test/1" do
    test "sends a test message to recipients" do
      recipients = ["05abc123def456"]
      assert :ok = SessionTransport.send_test(recipients)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/periodicmonitor/notifications/session_transport_test.exs`
Expected: FAIL — `SessionTransport` module not found

- [ ] **Step 3: Write the implementation**

```elixir
defmodule Periodicmonitor.Notifications.SessionTransport do
  @moduledoc "Session Messenger notification transport via Bun microservice."

  @behaviour Periodicmonitor.Notifications.Transport

  @milestone_labels %{"30d" => "30 days", "7d" => "7 days", "1d" => "1 day"}

  @impl true
  def send_alert(domain, milestone, recipients) do
    label = Map.fetch!(@milestone_labels, milestone)

    text =
      String.trim("""
      ENS Domain Monitor Alert

      The domain #{domain.name} expires in #{label}.

      Details:
        Expiration date: #{Calendar.strftime(domain.expires_at, "%Y-%m-%d %H:%M UTC")}
        Status: #{domain.status}
        Owner: #{domain.owner}

      Please renew it to avoid losing ownership.
      """)

    send_to_all(recipients, text)
  end

  @impl true
  def send_test(recipients) do
    text =
      String.trim("""
      ENS Domain Monitor — Test Message

      This message confirms that your Session notification system is working correctly.

      You will receive alerts when your ENS domains are 30 days, 7 days, and 1 day from expiration.
      """)

    send_to_all(recipients, text)
  end

  defp send_to_all(recipients, text) do
    results =
      Enum.map(recipients, fn recipient ->
        base_url = Application.get_env(:periodicmonitor, :session_service_url, "http://localhost:3100")

        req =
          Req.new(url: "#{base_url}/send", receive_timeout: 10_000)
          |> attach_test_plug()

        case Req.post(req, json: %{to: recipient, text: text}) do
          {:ok, %{status: 200}} -> :ok
          {:ok, resp} -> {:error, {:unexpected_status, resp.status, resp.body}}
          {:error, reason} -> {:error, reason}
        end
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  defp attach_test_plug(req) do
    case Application.get_env(:periodicmonitor, :session_transport_req_options) do
      nil -> req
      opts -> Req.merge(req, opts)
    end
  end
end
```

- [ ] **Step 4: Add test config for SessionTransport**

In `config/test.exs`, add:
```elixir
# Session transport test config — uses Req.Test plug, no real HTTP calls
config :periodicmonitor, :session_transport_req_options,
  plug: {Req.Test, Periodicmonitor.Notifications.SessionTransport}

config :periodicmonitor, :notification_transport, :session
config :periodicmonitor, :session_recipients, ["05test_session_id_1", "05test_session_id_2"]
config :periodicmonitor, :session_service_url, "http://localhost:3100"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/periodicmonitor/notifications/session_transport_test.exs`
Expected: 2 tests, 0 failures

- [ ] **Step 6: Commit**

```bash
git add lib/periodicmonitor/notifications/session_transport.ex test/periodicmonitor/notifications/session_transport_test.exs config/test.exs
git commit -m "feat: add SessionTransport calling Bun microservice via Req"
```

---

## Chunk 3: Scheduler Refactor & Config

### Task 5: Refactor Scheduler to use Transport

**Files:**
- Modify: `lib/periodicmonitor/notifications/scheduler.ex`
- Modify: `test/periodicmonitor/notifications/scheduler_test.exs`

- [ ] **Step 1: Update Scheduler to use Transport dispatcher**

Replace the body of `check_and_notify/0`:

```elixir
def check_and_notify do
  alias Periodicmonitor.{Domains, Notifications}
  alias Periodicmonitor.Notifications.Transport

  transport = Transport.current()

  recipients =
    case Application.get_env(:periodicmonitor, :notification_transport, :session) do
      :session -> Application.get_env(:periodicmonitor, :session_recipients, [])
      :email -> Application.get_env(:periodicmonitor, :alert_recipients, [])
    end

  if recipients == [] do
    Logger.warning("[Notifications.Scheduler] No recipients configured, skipping.")
    :ok
  else
    Domains.list_domains()
    |> Enum.each(fn domain ->
      case Notifications.milestone_for_domain(domain) do
        nil ->
          :skip

        milestone ->
          unless Notifications.already_notified?(domain.name, milestone) do
            case transport.send_alert(domain, milestone, recipients) do
              :ok ->
                Notifications.record_notification!(domain.name, milestone)

                Logger.info(
                  "[Notifications.Scheduler] Sent #{milestone} alert for #{domain.name}"
                )

              {:error, reason} ->
                Logger.error(
                  "[Notifications.Scheduler] Failed to send alert for #{domain.name}: #{inspect(reason)}"
                )
            end
          end
      end
    end)
  end
end
```

- [ ] **Step 2: Update scheduler tests to use Session transport**

The scheduler now uses the transport config. Update `test/periodicmonitor/notifications/scheduler_test.exs` to configure Session recipients and stub the microservice:

```elixir
defmodule Periodicmonitor.Notifications.SchedulerTest do
  use Periodicmonitor.DataCase, async: false

  alias Periodicmonitor.Notifications.Scheduler
  alias Periodicmonitor.Notifications.NotificationLog
  alias Periodicmonitor.Domains

  setup do
    Application.put_env(:periodicmonitor, :session_recipients, ["05test_session_id"])
    on_exit(fn -> Application.put_env(:periodicmonitor, :session_recipients, []) end)

    Req.Test.stub(Periodicmonitor.Notifications.SessionTransport, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{status: "sent", message_hash: "abc", timestamp: 0}))
    end)

    :ok
  end

  describe "check_and_notify/0" do
    test "sends notification and records log for domain within milestone" do
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

- [ ] **Step 3: Run all notification tests**

Run: `mix test test/periodicmonitor/notifications/`
Expected: All pass

- [ ] **Step 4: Commit**

```bash
git add lib/periodicmonitor/notifications/scheduler.ex test/periodicmonitor/notifications/scheduler_test.exs
git commit -m "refactor: scheduler uses Transport behaviour for dispatching"
```

### Task 6: Update configuration files

**Files:**
- Modify: `config/config.exs`
- Modify: `config/runtime.exs`

- [ ] **Step 1: Update config.exs — add Session defaults**

After the existing `alert_from_email` line, add:

```elixir
# Notification transport: :session (default) or :email (fallback)
config :periodicmonitor, :notification_transport, :session

# Session Messenger settings
config :periodicmonitor, :session_recipients, []
config :periodicmonitor, :session_service_url, "http://localhost:3100"
```

- [ ] **Step 2: Update runtime.exs — add Session env vars for dev and prod**

In the dev block (after the existing Mailgun block, around line 45), add:

```elixir
# Session Messenger config in dev when env vars are set
if config_env() == :dev and System.get_env("SESSION_RECIPIENTS") do
  config :periodicmonitor,
         :session_recipients,
         System.get_env("SESSION_RECIPIENTS", "")
         |> String.split(",", trim: true)
         |> Enum.map(&String.trim/1)

  if url = System.get_env("SESSION_SERVICE_URL") do
    config :periodicmonitor, :session_service_url, url
  end

  if transport = System.get_env("NOTIFICATION_TRANSPORT") do
    config :periodicmonitor, :notification_transport, String.to_existing_atom(transport)
  end
end
```

In the prod block, add (after the Mailgun config):

```elixir
# Session Messenger
config :periodicmonitor,
       :session_recipients,
       System.get_env("SESSION_RECIPIENTS", "")
       |> String.split(",", trim: true)
       |> Enum.map(&String.trim/1)

if url = System.get_env("SESSION_SERVICE_URL") do
  config :periodicmonitor, :session_service_url, url
end

config :periodicmonitor,
       :notification_transport,
       System.get_env("NOTIFICATION_TRANSPORT", "session") |> String.to_existing_atom()
```

- [ ] **Step 3: Run full test suite**

Run: `mix test`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add config/config.exs config/runtime.exs
git commit -m "feat: add Session Messenger configuration with transport switch"
```

---

## Chunk 4: Mix Task & Documentation

### Task 7: Create mix notifications.test_session task

**Files:**
- Create: `test/mix/tasks/notifications.test_session_test.exs`
- Create: `lib/mix/tasks/notifications.test_session.ex`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule Mix.Tasks.Notifications.TestSessionTest do
  use Periodicmonitor.DataCase

  import ExUnit.CaptureIO

  describe "run/1" do
    setup do
      Req.Test.stub(Periodicmonitor.Notifications.SessionTransport, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{status: "sent", message_hash: "abc", timestamp: 0}))
      end)

      :ok
    end

    test "sends a test Session message to configured recipients" do
      Application.put_env(:periodicmonitor, :session_recipients, ["05abc123"])
      on_exit(fn -> Application.put_env(:periodicmonitor, :session_recipients, []) end)

      output =
        capture_io(fn ->
          Mix.Tasks.Notifications.TestSession.run([])
        end)

      assert output =~ "Test Session message sent"
    end

    test "prints error when no recipients configured" do
      Application.put_env(:periodicmonitor, :session_recipients, [])

      output =
        capture_io(fn ->
          Mix.Tasks.Notifications.TestSession.run([])
        end)

      assert output =~ "No Session recipients"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/mix/tasks/notifications.test_session_test.exs`
Expected: FAIL — module not found

- [ ] **Step 3: Write the implementation**

```elixir
defmodule Mix.Tasks.Notifications.TestSession do
  @moduledoc "Sends a test message via Session Messenger to verify setup."
  @shortdoc "Send a test Session notification"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    recipients = Application.get_env(:periodicmonitor, :session_recipients, [])

    if recipients == [] do
      Mix.shell().info("No Session recipients configured. Set SESSION_RECIPIENTS env var.")
    else
      case Periodicmonitor.Notifications.SessionTransport.send_test(recipients) do
        :ok ->
          Mix.shell().info("Test Session message sent to: #{Enum.join(recipients, ", ")}")

        {:error, reason} ->
          Mix.shell().info("Failed to send test Session message: #{inspect(reason)}")
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/mix/tasks/notifications.test_session_test.exs`
Expected: 2 tests, 0 failures

- [ ] **Step 5: Commit**

```bash
git add lib/mix/tasks/notifications.test_session.ex test/mix/tasks/notifications.test_session_test.exs
git commit -m "feat: add mix notifications.test_session task"
```

### Task 8: Update README and run precommit

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add Session Messenger section to README**

Add a section documenting:
- Session service setup: `cd session_service && bun install`
- Generating a mnemonic: `curl http://localhost:3100/generate-mnemonic`
- Environment variables: `SESSION_BOT_MNEMONIC`, `SESSION_RECIPIENTS`, `SESSION_SERVICE_URL`, `NOTIFICATION_TRANSPORT`
- Running the service: `cd session_service && bun run index.ts`
- Testing: `mix notifications.test_session`
- Switching back to email: set `NOTIFICATION_TRANSPORT=email`
- Bun installation requirement: https://bun.sh

- [ ] **Step 2: Run precommit**

Run: `mix precommit`
Expected: Compiles (0 warnings), formatted, all tests pass

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add Session Messenger setup and usage instructions"
```

---

## Summary of Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SESSION_BOT_MNEMONIC` | Yes (microservice) | — | 13-word Session seed phrase |
| `SESSION_DISPLAY_NAME` | No | `ENS Monitor Bot` | Bot display name |
| `SESSION_RECIPIENTS` | Yes (if transport=session) | `[]` | Comma-separated Session IDs |
| `SESSION_SERVICE_URL` | No | `http://localhost:3100` | Microservice URL |
| `NOTIFICATION_TRANSPORT` | No | `session` | `session` or `email` |
| `MAILGUN_API_KEY` | Yes (if transport=email) | — | Mailgun API key (existing) |
| `MAILGUN_DOMAIN` | Yes (if transport=email) | — | Mailgun domain (existing) |
| `ALERT_RECIPIENTS` | Yes (if transport=email) | `[]` | Email addresses (existing) |
