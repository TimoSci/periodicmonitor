defmodule Periodicmonitor.Ethereum.ENSTest do
  use ExUnit.Case, async: true

  alias Periodicmonitor.Ethereum.ENS

  describe "label_hash/1" do
    test "computes keccak256 of label" do
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
      assert ENS.namehash("") == "0x" <> String.duplicate("00", 32)
    end

    test "computes namehash for eth" do
      # Known constant: namehash("eth")
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

  describe "name_expires/1" do
    test "returns expiration datetime for a name" do
      # Timestamp 1735689600 = 2025-01-01 00:00:00 UTC = 0x67748580
      Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "jsonrpc" => "2.0",
            "id" => 1,
            "result" => "0x0000000000000000000000000000000000000000000000000000000067748580"
          })
        )
      end)

      assert {:ok, %DateTime{} = dt} = ENS.name_expires("urs")
      assert dt == ~U[2025-01-01 00:00:00Z]
    end

    test "returns error when RPC fails" do
      Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "jsonrpc" => "2.0",
            "id" => 1,
            "error" => %{"code" => -32000, "message" => "execution reverted"}
          })
        )
      end)

      assert {:error, "execution reverted"} = ENS.name_expires("urs")
    end
  end

  describe "get_owner/1" do
    test "returns owner address for a name" do
      Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "jsonrpc" => "2.0",
            "id" => 1,
            "result" => "0x000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045"
          })
        )
      end)

      assert {:ok, "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"} = ENS.get_owner("urs.eth")
    end

    test "returns error when RPC fails" do
      Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "jsonrpc" => "2.0",
            "id" => 1,
            "error" => %{"code" => -32000, "message" => "execution reverted"}
          })
        )
      end)

      assert {:error, "execution reverted"} = ENS.get_owner("urs.eth")
    end
  end
end
