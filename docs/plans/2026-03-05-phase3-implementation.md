# Phase 3: Configuration & Diagnostics — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Ethereum endpoint config, ENS name list config, and an HTTPS health check mix task.

**Architecture:** Configuration via standard Phoenix config files (config.exs, dev.exs, test.exs, runtime.exs). A thin `Periodicmonitor.Ethereum.RPC` module wraps JSON-RPC calls using `Req`. A mix task exposes the health check CLI.

**Tech Stack:** Elixir, Phoenix config, Req HTTP client, Req.Test for testing.

---

### Task 1: Add Ethereum and ENS configuration

**Files:**
- Modify: `config/config.exs` (add after line 12, before endpoint config)
- Modify: `config/dev.exs` (add at end of file)
- Modify: `config/test.exs` (add at end of file)
- Modify: `config/runtime.exs` (add inside the `if config_env() == :prod do` block)

**Step 1: Add default config to config/config.exs**

Add after line 12 (after `generators: [timestamp_type: :utc_datetime]`), before the endpoint config block:

```elixir
# Ethereum endpoint configuration
config :periodicmonitor, :ethereum,
  https_endpoint: "https://placeholder.example.com",
  wss_endpoint: "wss://placeholder.example.com"

# ENS names to monitor
config :periodicmonitor, :ens_names, []
```

**Step 2: Add dev config to config/dev.exs**

Add at end of file:

```elixir
# Ethereum endpoints (Chainstack) — replace with your real URLs
config :periodicmonitor, :ethereum,
  https_endpoint: "https://your-chainstack-https-endpoint",
  wss_endpoint: "wss://your-chainstack-wss-endpoint"

# ENS names to monitor
config :periodicmonitor, :ens_names, [
  "example1.eth",
  "example2.eth",
  "example3.eth"
]
```

**Step 3: Add test config to config/test.exs**

Add at end of file:

```elixir
# Ethereum test config — uses Req.Test plug, no real HTTP calls
config :periodicmonitor, :ethereum,
  https_endpoint: "https://test.example.com",
  wss_endpoint: "wss://test.example.com"

config :periodicmonitor, :ens_names, ["test1.eth", "test2.eth"]
```

**Step 4: Add prod runtime config to config/runtime.exs**

Add inside the `if config_env() == :prod do` block (before the closing `end` on line 120):

```elixir
  config :periodicmonitor, :ethereum,
    https_endpoint:
      System.get_env("ETHEREUM_HTTPS_ENDPOINT") ||
        raise("environment variable ETHEREUM_HTTPS_ENDPOINT is missing."),
    wss_endpoint:
      System.get_env("ETHEREUM_WSS_ENDPOINT") ||
        raise("environment variable ETHEREUM_WSS_ENDPOINT is missing.")

  config :periodicmonitor, :ens_names,
    System.get_env("ENS_NAMES", "")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
```

**Step 5: Verify compilation**

Run: `mix compile`
Expected: Compiles with no errors or warnings.

**Step 6: Commit**

```bash
git add config/config.exs config/dev.exs config/test.exs config/runtime.exs
git commit -m "feat: add Ethereum endpoint and ENS name configuration"
```

---

### Task 2: Create Periodicmonitor.Ethereum.RPC module (TDD)

**Files:**
- Create: `test/periodicmonitor/ethereum/rpc_test.exs`
- Create: `lib/periodicmonitor/ethereum/rpc.ex`

**Step 1: Write the failing test**

Create `test/periodicmonitor/ethereum/rpc_test.exs`:

```elixir
defmodule Periodicmonitor.Ethereum.RPCTest do
  use ExUnit.Case, async: true

  alias Periodicmonitor.Ethereum.RPC

  describe "eth_block_number/0" do
    test "returns block number on successful response" do
      Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "jsonrpc" => "2.0",
          "id" => 1,
          "result" => "0x134e82a"
        }))
      end)

      assert {:ok, block_number} = RPC.eth_block_number()
      assert block_number == 20_307_498
    end

    test "returns error on JSON-RPC error response" do
      Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "jsonrpc" => "2.0",
          "id" => 1,
          "error" => %{"code" => -32600, "message" => "Invalid request"}
        }))
      end)

      assert {:error, "Invalid request"} = RPC.eth_block_number()
    end

    test "returns error on HTTP failure" do
      Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
        conn
        |> Plug.Conn.send_resp(500, "Internal Server Error")
      end)

      assert {:error, _reason} = RPC.eth_block_number()
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/periodicmonitor/ethereum/rpc_test.exs`
Expected: Compilation error — module `Periodicmonitor.Ethereum.RPC` not found.

**Step 3: Write minimal implementation**

Create `lib/periodicmonitor/ethereum/rpc.ex`:

```elixir
defmodule Periodicmonitor.Ethereum.RPC do
  @moduledoc """
  JSON-RPC client for Ethereum node communication via Req.
  """

  def eth_block_number do
    case json_rpc("eth_blockNumber", []) do
      {:ok, hex_string} ->
        {number, ""} = hex_string |> String.trim_leading("0x") |> Integer.parse(16)
        {:ok, number}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp json_rpc(method, params) do
    body = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => method,
      "params" => params
    }

    case Req.post(build_req(), json: body) do
      {:ok, %Req.Response{status: 200, body: %{"result" => result}}} ->
        {:ok, result}

      {:ok, %Req.Response{status: 200, body: %{"error" => %{"message" => message}}}} ->
        {:error, message}

      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  defp build_req do
    endpoint = Application.get_env(:periodicmonitor, :ethereum)[:https_endpoint]

    Req.new(url: endpoint)
    |> Req.Request.register_options([:plug])
    |> Req.Test.plug(Periodicmonitor.Ethereum.RPC)
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/periodicmonitor/ethereum/rpc_test.exs`
Expected: 3 tests, 0 failures.

**Step 5: Commit**

```bash
git add lib/periodicmonitor/ethereum/rpc.ex test/periodicmonitor/ethereum/rpc_test.exs
git commit -m "feat: add Ethereum JSON-RPC client module with tests"
```

---

### Task 3: Create mix ethereum.health_check task (TDD)

**Files:**
- Create: `test/mix/tasks/ethereum.health_check_test.exs`
- Create: `lib/mix/tasks/ethereum.health_check.ex`

**Step 1: Write the failing test**

Create `test/mix/tasks/ethereum.health_check_test.exs`:

```elixir
defmodule Mix.Tasks.Ethereum.HealthCheckTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  describe "run/1" do
    test "prints block number on success" do
      Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "jsonrpc" => "2.0",
          "id" => 1,
          "result" => "0x134e82a"
        }))
      end)

      output = capture_io(fn ->
        Mix.Tasks.Ethereum.HealthCheck.run([])
      end)

      assert output =~ "Ethereum HTTPS connection: OK"
      assert output =~ "Current block number: 20307498"
    end

    test "prints error on failure" do
      Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
        conn
        |> Plug.Conn.send_resp(500, "Internal Server Error")
      end)

      output = capture_io(fn ->
        Mix.Tasks.Ethereum.HealthCheck.run([])
      end)

      assert output =~ "Ethereum HTTPS connection: FAILED"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mix/tasks/ethereum.health_check_test.exs`
Expected: Compilation error — module `Mix.Tasks.Ethereum.HealthCheck` not found.

**Step 3: Write minimal implementation**

Create `lib/mix/tasks/ethereum.health_check.ex`:

```elixir
defmodule Mix.Tasks.Ethereum.HealthCheck do
  @moduledoc "Checks connectivity to the configured Ethereum HTTPS endpoint."
  @shortdoc "Tests Ethereum HTTPS endpoint connectivity"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    endpoint = Application.get_env(:periodicmonitor, :ethereum)[:https_endpoint]
    masked = mask_endpoint(endpoint)

    Mix.shell().info("Checking Ethereum HTTPS endpoint: #{masked}")

    case Periodicmonitor.Ethereum.RPC.eth_block_number() do
      {:ok, block_number} ->
        Mix.shell().info("Ethereum HTTPS connection: OK")
        Mix.shell().info("Current block number: #{block_number}")

      {:error, reason} ->
        Mix.shell().info("Ethereum HTTPS connection: FAILED")
        Mix.shell().info("Error: #{reason}")
    end
  end

  defp mask_endpoint(url) when is_binary(url) do
    uri = URI.parse(url)
    "#{uri.scheme}://#{uri.host}/***"
  end

  defp mask_endpoint(_), do: "(not configured)"
end
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/mix/tasks/ethereum.health_check_test.exs`
Expected: 2 tests, 0 failures.

**Step 5: Commit**

```bash
git add lib/mix/tasks/ethereum.health_check.ex test/mix/tasks/ethereum.health_check_test.exs
git commit -m "feat: add mix ethereum.health_check task with tests"
```

---

### Task 4: Run full precommit and finalize

**Step 1: Run full test suite**

Run: `mix precommit`
Expected: Compilation clean, formatting OK, all tests pass.

**Step 2: Ask user for real Chainstack endpoints and ENS names**

Prompt user to provide:
- Chainstack HTTPS endpoint URL
- Chainstack WSS endpoint URL
- 3 ENS names to monitor

**Step 3: Update config/dev.exs with real values**

Replace placeholder URLs and ENS names.

**Step 4: Run real health check**

Run: `mix ethereum.health_check`
Expected: Shows real block number from Ethereum mainnet.

**Step 5: Final commit**

```bash
git add config/dev.exs
git commit -m "feat: configure real Chainstack endpoints and ENS names"
```

---

### Task 5: Update README.md

**Files:**
- Modify: `README.md`

**Step 1: Add Phase 3 documentation**

Add section covering:
- How to configure Ethereum endpoints (dev vs prod)
- How to set ENS names list
- How to run `mix ethereum.health_check`
- Environment variables needed for production

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add Phase 3 configuration and health check instructions"
```
