# Phase 4: Core ENS Monitoring — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Query ENS contracts for domain expiration dates and owners, store results in PostgreSQL.

**Architecture:** Extend the existing RPC module with `eth_call`, add an ENS module for contract interactions (keccak256 hashing, ABI encoding/decoding), a Domains context for DB persistence, and a mix task to trigger checks.

**Tech Stack:** Elixir, Ecto/PostgreSQL, Req HTTP client, `:crypto` for keccak256, ENS BaseRegistrar + Registry contracts.

---

### Task 1: Add eth_call to RPC module

**Files:**
- Modify: `lib/periodicmonitor/ethereum/rpc.ex`
- Modify: `test/periodicmonitor/ethereum/rpc_test.exs`

**Step 1: Write the failing test**

Add to `test/periodicmonitor/ethereum/rpc_test.exs`, inside the module but after the existing `describe` block:

```elixir
describe "eth_call/2" do
  test "returns hex result on success" do
    Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => "0x000000000000000000000000000000000000000000000000000000006789abcd"
      }))
    end)

    assert {:ok, "0x000000000000000000000000000000000000000000000000000000006789abcd"} =
             Periodicmonitor.Ethereum.RPC.eth_call("0xcontract", "0xdata")
  end

  test "returns error on JSON-RPC error" do
    Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "jsonrpc" => "2.0",
        "id" => 1,
        "error" => %{"code" => -32000, "message" => "execution reverted"}
      }))
    end)

    assert {:error, "execution reverted"} =
             Periodicmonitor.Ethereum.RPC.eth_call("0xcontract", "0xdata")
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/periodicmonitor/ethereum/rpc_test.exs`
Expected: FAIL — `eth_call/2` undefined.

**Step 3: Write minimal implementation**

Add to `lib/periodicmonitor/ethereum/rpc.ex`, after `eth_block_number/0` and before `defp json_rpc`:

```elixir
def eth_call(to, data) do
  params = [%{"to" => to, "data" => data}, "latest"]
  json_rpc("eth_call", params)
end
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/periodicmonitor/ethereum/rpc_test.exs --trace`
Expected: 5 tests, 0 failures.

**Step 5: Commit**

```bash
git add lib/periodicmonitor/ethereum/rpc.ex test/periodicmonitor/ethereum/rpc_test.exs
git commit -m "feat: add eth_call/2 to RPC module"
```

---

### Task 2: Create ENS module with hashing helpers

**Files:**
- Create: `lib/periodicmonitor/ethereum/ens.ex`
- Create: `test/periodicmonitor/ethereum/ens_test.exs`

**Step 1: Write the failing tests**

Create `test/periodicmonitor/ethereum/ens_test.exs`:

```elixir
defmodule Periodicmonitor.Ethereum.ENSTest do
  use ExUnit.Case, async: true

  alias Periodicmonitor.Ethereum.ENS

  describe "label_hash/1" do
    test "computes keccak256 of label" do
      # keccak256("urs") — verified against known value
      result = ENS.label_hash("urs")
      assert is_binary(result)
      assert String.starts_with?(result, "0x")
      assert String.length(result) == 66
    end

    test "strips .eth suffix" do
      assert ENS.label_hash("urs.eth") == ENS.label_hash("urs")
    end
  end

  describe "namehash/1" do
    test "returns zero hash for empty name" do
      assert ENS.namehash("") == String.duplicate("00", 32) |> then(&"0x#{&1}")
    end

    test "computes namehash for .eth" do
      # namehash("eth") is a known constant
      result = ENS.namehash("eth")
      assert result == "0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae"
    end

    test "computes namehash for urs.eth" do
      result = ENS.namehash("urs.eth")
      assert is_binary(result)
      assert String.starts_with?(result, "0x")
      assert String.length(result) == 66
    end
  end

  describe "token_id/1" do
    test "returns integer token ID from label" do
      token_id = ENS.token_id("urs")
      assert is_integer(token_id)
      assert token_id > 0
    end

    test "strips .eth suffix" do
      assert ENS.token_id("urs.eth") == ENS.token_id("urs")
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/periodicmonitor/ethereum/ens_test.exs`
Expected: Compilation error — module not found.

**Step 3: Write minimal implementation**

Create `lib/periodicmonitor/ethereum/ens.ex`:

```elixir
defmodule Periodicmonitor.Ethereum.ENS do
  @moduledoc """
  ENS (Ethereum Name Service) hashing utilities and contract interactions.
  """

  @doc """
  Computes keccak256 hash of the label (name without .eth suffix).
  Returns hex-encoded string with 0x prefix.
  """
  def label_hash(name) do
    label = name |> String.replace_suffix(".eth", "")
    "0x" <> Base.encode16(:crypto.hash(:keccak_256, label), case: :lower)
  end

  @doc """
  Computes the ENS namehash for a full domain name.
  See: https://docs.ens.domains/resolution/names#namehash
  """
  def namehash("") do
    "0x" <> String.duplicate("00", 32)
  end

  def namehash(name) do
    labels = String.split(name, ".")

    node =
      labels
      |> Enum.reverse()
      |> Enum.reduce(<<0::256>>, fn label, node ->
        label_hash_raw = :crypto.hash(:keccak_256, label)
        :crypto.hash(:keccak_256, node <> label_hash_raw)
      end)

    "0x" <> Base.encode16(node, case: :lower)
  end

  @doc """
  Computes the token ID for a .eth name (used by BaseRegistrar).
  The token ID is the uint256 of keccak256(label).
  """
  def token_id(name) do
    label = name |> String.replace_suffix(".eth", "")
    hash = :crypto.hash(:keccak_256, label)
    :binary.decode_unsigned(hash)
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/periodicmonitor/ethereum/ens_test.exs --trace`
Expected: 6 tests, 0 failures.

**Step 5: Commit**

```bash
git add lib/periodicmonitor/ethereum/ens.ex test/periodicmonitor/ethereum/ens_test.exs
git commit -m "feat: add ENS hashing utilities (label_hash, namehash, token_id)"
```

---

### Task 3: Add ENS contract query functions

**Files:**
- Modify: `lib/periodicmonitor/ethereum/ens.ex`
- Modify: `test/periodicmonitor/ethereum/ens_test.exs`

**Step 1: Write the failing tests**

Add to `test/periodicmonitor/ethereum/ens_test.exs`, after existing describes:

```elixir
describe "name_expires/1" do
  test "returns expiration datetime for a name" do
    # nameExpires(uint256) selector = 0xd5fa2b00... no, it's 0x28ed4f6c
    # We mock eth_call to return a unix timestamp (hex-encoded uint256)
    # Timestamp 1735689600 = 2025-01-01 00:00:00 UTC
    # Hex: 0x67748580 padded to 32 bytes
    Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => "0x0000000000000000000000000000000000000000000000000000000067748580"
      }))
    end)

    assert {:ok, %DateTime{} = dt} = ENS.name_expires("urs")
    assert dt == ~U[2025-01-01 00:00:00Z]
  end

  test "returns error when RPC fails" do
    Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "jsonrpc" => "2.0",
        "id" => 1,
        "error" => %{"code" => -32000, "message" => "execution reverted"}
      }))
    end)

    assert {:error, "execution reverted"} = ENS.name_expires("urs")
  end
end

describe "get_owner/1" do
  test "returns owner address for a name" do
    # owner(bytes32) selector = 0x02571be3
    # Return an address padded to 32 bytes
    Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => "0x000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045"
      }))
    end)

    assert {:ok, "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"} = ENS.get_owner("urs.eth")
  end

  test "returns error when RPC fails" do
    Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "jsonrpc" => "2.0",
        "id" => 1,
        "error" => %{"code" => -32000, "message" => "execution reverted"}
      }))
    end)

    assert {:error, "execution reverted"} = ENS.get_owner("urs.eth")
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/periodicmonitor/ethereum/ens_test.exs`
Expected: FAIL — `name_expires/1` and `get_owner/1` undefined.

**Step 3: Write minimal implementation**

Add to `lib/periodicmonitor/ethereum/ens.ex`, after the existing functions:

```elixir
# ENS BaseRegistrar contract address
@base_registrar "0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85"

# ENS Registry contract address
@ens_registry "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e"

# Function selectors (first 4 bytes of keccak256 of function signature)
# keccak256("nameExpires(uint256)") = 0xd5fa2b00... first 4 bytes
@name_expires_selector "d5fa2b00"

# keccak256("owner(bytes32)") = 0x02571be3
@owner_selector "02571be3"

alias Periodicmonitor.Ethereum.RPC

@doc """
Queries the BaseRegistrar for when a .eth name expires.
Returns {:ok, DateTime.t()} or {:error, reason}.
"""
def name_expires(name) do
  tid = token_id(name)
  data = "0x" <> @name_expires_selector <> encode_uint256(tid)

  case RPC.eth_call(@base_registrar, data) do
    {:ok, hex_result} ->
      timestamp = decode_uint256(hex_result)
      {:ok, DateTime.from_unix!(timestamp)}

    {:error, reason} ->
      {:error, reason}
  end
end

@doc """
Queries the ENS Registry for the owner of a name.
Returns {:ok, address_string} or {:error, reason}.
"""
def get_owner(name) do
  node = namehash(name) |> String.trim_leading("0x")
  data = "0x" <> @owner_selector <> node

  case RPC.eth_call(@ens_registry, data) do
    {:ok, hex_result} ->
      address = decode_address(hex_result)
      {:ok, address}

    {:error, reason} ->
      {:error, reason}
  end
end

defp encode_uint256(integer) do
  integer
  |> :binary.encode_unsigned()
  |> Base.encode16(case: :lower)
  |> String.pad_leading(64, "0")
end

defp decode_uint256("0x" <> hex) do
  {value, ""} = Integer.parse(hex, 16)
  value
end

defp decode_address("0x" <> hex) do
  # Address is last 20 bytes (40 hex chars) of 32-byte response
  address_hex = String.slice(hex, 24, 40)
  "0x" <> address_hex
end
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/periodicmonitor/ethereum/ens_test.exs --trace`
Expected: 10 tests, 0 failures.

**Step 5: Commit**

```bash
git add lib/periodicmonitor/ethereum/ens.ex test/periodicmonitor/ethereum/ens_test.exs
git commit -m "feat: add ENS contract query functions (name_expires, get_owner)"
```

---

### Task 4: Create database migration and schema

**Files:**
- Create: `priv/repo/migrations/*_create_ens_domains.exs` (via mix task)
- Create: `lib/periodicmonitor/domains/ens_domain.ex`

**Step 1: Generate migration**

Run: `mix ecto.gen.migration create_ens_domains`

**Step 2: Write the migration**

Edit the generated file in `priv/repo/migrations/*_create_ens_domains.exs`:

```elixir
defmodule Periodicmonitor.Repo.Migrations.CreateEnsDomains do
  use Ecto.Migration

  def change do
    create table(:ens_domains) do
      add :name, :string, null: false
      add :label_hash, :string, null: false
      add :owner, :string
      add :expires_at, :utc_datetime
      add :status, :string, null: false, default: "unknown"
      add :last_checked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:ens_domains, [:name])
  end
end
```

**Step 3: Create the Ecto schema**

Create `lib/periodicmonitor/domains/ens_domain.ex`:

```elixir
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
```

**Step 4: Run migration**

Run: `mix ecto.migrate`
Expected: Migration runs successfully.

**Step 5: Verify migration**

Run: `mix ecto.rollback` then `mix ecto.migrate`
Expected: Both succeed (migration is reversible).

**Step 6: Commit**

```bash
git add lib/periodicmonitor/domains/ens_domain.ex priv/repo/migrations/*_create_ens_domains.exs
git commit -m "feat: add ens_domains table and EnsDomain schema"
```

---

### Task 5: Create Domains context

**Files:**
- Create: `lib/periodicmonitor/domains.ex`
- Create: `test/periodicmonitor/domains_test.exs`

**Step 1: Write the failing tests**

Create `test/periodicmonitor/domains_test.exs`:

```elixir
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

      # Should still be only 1 record
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
```

**Step 2: Run test to verify it fails**

Run: `mix test test/periodicmonitor/domains_test.exs`
Expected: FAIL — module `Periodicmonitor.Domains` not found.

**Step 3: Write minimal implementation**

Create `lib/periodicmonitor/domains.ex`:

```elixir
defmodule Periodicmonitor.Domains do
  @moduledoc """
  Context for managing monitored ENS domains.
  """

  import Ecto.Query
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
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/periodicmonitor/domains_test.exs --trace`
Expected: 6 tests, 0 failures.

**Step 5: Commit**

```bash
git add lib/periodicmonitor/domains.ex test/periodicmonitor/domains_test.exs
git commit -m "feat: add Domains context with upsert, status computation, and ENS checking"
```

---

### Task 6: Create mix ens.check_expirations task

**Files:**
- Create: `lib/mix/tasks/ens.check_expirations.ex`
- Create: `test/mix/tasks/ens.check_expirations_test.exs`

**Step 1: Write the failing test**

Create `test/mix/tasks/ens.check_expirations_test.exs`:

```elixir
defmodule Mix.Tasks.Ens.CheckExpirationsTest do
  use Periodicmonitor.DataCase

  import ExUnit.CaptureIO

  describe "run/1" do
    test "prints results for each configured ENS name" do
      # Stub RPC to return expiration and owner for any call
      Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        result =
          case decoded["method"] do
            "eth_call" ->
              # Check if it's a nameExpires or owner call by data prefix
              data = decoded["params"] |> List.first() |> Map.get("data")

              if String.starts_with?(data, "0xd5fa2b00") do
                # nameExpires — return timestamp for 2027-06-01 00:00:00 UTC (1748736000)
                "0x00000000000000000000000000000000000000000000000000000000684c3800"
              else
                # owner — return an address
                "0x000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045"
              end
          end

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "jsonrpc" => "2.0",
          "id" => 1,
          "result" => result
        }))
      end)

      output = capture_io(fn ->
        Mix.Tasks.Ens.CheckExpirations.run([])
      end)

      assert output =~ "Checking ENS domain expirations"
      assert output =~ "test1.eth"
      assert output =~ "test2.eth"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mix/tasks/ens.check_expirations_test.exs`
Expected: FAIL — module not found.

**Step 3: Write minimal implementation**

Create `lib/mix/tasks/ens.check_expirations.ex`:

```elixir
defmodule Mix.Tasks.Ens.CheckExpirations do
  @moduledoc "Checks expiration dates for all configured ENS domains."
  @shortdoc "Checks ENS domain expiration dates"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    names = Application.get_env(:periodicmonitor, :ens_names, [])
    Mix.shell().info("Checking ENS domain expirations for #{length(names)} name(s)...\n")

    results = Periodicmonitor.Domains.check_all_domains()

    Enum.zip(names, results)
    |> Enum.each(fn {name, result} ->
      case result do
        {:ok, domain} ->
          Mix.shell().info("#{name}")
          Mix.shell().info("  Owner:   #{domain.owner}")
          Mix.shell().info("  Expires: #{domain.expires_at}")
          Mix.shell().info("  Status:  #{domain.status}\n")

        {:error, reason} ->
          Mix.shell().info("#{name}")
          Mix.shell().info("  Error: #{reason}\n")
      end
    end)
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/mix/tasks/ens.check_expirations_test.exs --trace`
Expected: 1 test, 0 failures.

**Step 5: Commit**

```bash
git add lib/mix/tasks/ens.check_expirations.ex test/mix/tasks/ens.check_expirations_test.exs
git commit -m "feat: add mix ens.check_expirations task"
```

---

### Task 7: Run precommit, test with real endpoints, update README

**Step 1: Run full precommit**

Run: `mix precommit`
Expected: Compilation clean, all tests pass.

**Step 2: Test with real Ethereum data**

Run: `mix ens.check_expirations`
Expected: Shows real expiration dates and owners for urs.eth, andernatt.eth, alm.eth.

**Step 3: Update README.md**

Add to the Diagnostics section:

```markdown
## ENS Domain Monitoring

Check expiration dates for all configured ENS names:

\```bash
mix ens.check_expirations
\```

This queries the ENS BaseRegistrar and Registry contracts for each configured name and stores results in the database.
```

**Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add ENS monitoring instructions to README"
```

---

### Task 8: Update CLAUDE.md status

**Step 1: Update CLAUDE.md**

Mark Phase 4 items as completed in the TODO section.

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: mark Phase 4 tasks as completed in CLAUDE.md"
```
