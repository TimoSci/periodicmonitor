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
      assert output =~ "Current block number: 20244522"
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
