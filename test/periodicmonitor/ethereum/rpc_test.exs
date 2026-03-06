defmodule Periodicmonitor.Ethereum.RPCTest do
  use ExUnit.Case, async: true

  alias Periodicmonitor.Ethereum.RPC

  describe "eth_block_number/0" do
    test "returns block number on successful response" do
      Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "jsonrpc" => "2.0",
            "id" => 1,
            "result" => "0x134e82a"
          })
        )
      end)

      assert {:ok, block_number} = RPC.eth_block_number()
      assert block_number == 20_244_522
    end

    test "returns error on JSON-RPC error response" do
      Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "jsonrpc" => "2.0",
            "id" => 1,
            "error" => %{"code" => -32600, "message" => "Invalid request"}
          })
        )
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

  describe "eth_call/2" do
    test "returns hex result on success" do
      Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "jsonrpc" => "2.0",
            "id" => 1,
            "result" => "0x000000000000000000000000000000000000000000000000000000006789abcd"
          })
        )
      end)

      assert {:ok, "0x000000000000000000000000000000000000000000000000000000006789abcd"} =
               Periodicmonitor.Ethereum.RPC.eth_call("0xcontract", "0xdata")
    end

    test "returns error on JSON-RPC error" do
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

      assert {:error, "execution reverted"} =
               Periodicmonitor.Ethereum.RPC.eth_call("0xcontract", "0xdata")
    end
  end
end
