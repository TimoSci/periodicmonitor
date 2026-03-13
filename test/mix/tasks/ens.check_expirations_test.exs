defmodule Mix.Tasks.Ens.CheckExpirationsTest do
  use Periodicmonitor.DataCase

  import ExUnit.CaptureIO

  @base_registrar "0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85"

  describe "run/1" do
    test "prints results for each configured ENS name" do
      Req.Test.stub(Periodicmonitor.Ethereum.RPC, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        params = decoded["params"]
        to = params |> List.first() |> Map.get("to")

        result =
          if to == @base_registrar do
            # nameExpires — return timestamp for 2027-06-01 00:00:00 UTC (1748736000 = 0x684c3800)
            "0x00000000000000000000000000000000000000000000000000000000684c3800"
          else
            # owner — return an address
            "0x000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045"
          end

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "jsonrpc" => "2.0",
            "id" => 1,
            "result" => result
          })
        )
      end)

      output =
        capture_io(fn ->
          Mix.Tasks.Ens.CheckExpirations.run([])
        end)

      assert output =~ "Checking ENS domain expirations"
      assert output =~ "test1.eth"
      assert output =~ "test2.eth"
      assert output =~ "Owner:"
      assert output =~ "Expires:"
      assert output =~ "Status:"
    end
  end
end
