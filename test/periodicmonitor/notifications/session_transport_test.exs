defmodule Periodicmonitor.Notifications.SessionTransportTest do
  use Periodicmonitor.DataCase, async: true

  alias Periodicmonitor.Notifications.SessionTransport

  setup do
    # Use Req.Test to stub the session service
    Req.Test.stub(Periodicmonitor.Notifications.SessionTransport, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      _decoded = Jason.decode!(body)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          status: "sent",
          message_hash: "abc123",
          timestamp: System.system_time(:millisecond)
        })
      )
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
