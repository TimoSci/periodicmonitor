defmodule Mix.Tasks.Notifications.TestEmailTest do
  use Periodicmonitor.DataCase

  import ExUnit.CaptureIO
  import Swoosh.TestAssertions

  describe "run/1" do
    test "sends a test email to configured recipients" do
      Application.put_env(:periodicmonitor, :alert_recipients, ["test@example.com"])

      output =
        capture_io(fn ->
          Mix.Tasks.Notifications.TestEmail.run([])
        end)

      assert output =~ "Test email sent"
      assert_email_sent(subject: "[ENS Monitor] Test Email")
    end

    test "prints error when no recipients configured" do
      Application.put_env(:periodicmonitor, :alert_recipients, [])

      output =
        capture_io(fn ->
          Mix.Tasks.Notifications.TestEmail.run([])
        end)

      assert output =~ "No recipients"
    end
  end
end
