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
