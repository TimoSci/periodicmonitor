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
end
