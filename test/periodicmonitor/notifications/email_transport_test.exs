defmodule Periodicmonitor.Notifications.EmailTransportTest do
  use Periodicmonitor.DataCase

  import Swoosh.TestAssertions

  alias Periodicmonitor.Notifications.EmailTransport

  describe "send_alert/3" do
    test "delivers an email alert for a domain" do
      domain = %Periodicmonitor.Domains.EnsDomain{
        name: "test.eth",
        expires_at: ~U[2026-04-06 00:00:00Z],
        status: "expiring",
        owner: "0x1234"
      }

      assert :ok = EmailTransport.send_alert(domain, "30d", ["user@test.com"])
      assert_email_sent(subject: "[ENS Alert] test.eth expires in 30 days")
    end
  end

  describe "send_test/1" do
    test "delivers a test email" do
      assert :ok = EmailTransport.send_test(["user@test.com"])
      assert_email_sent(subject: "[ENS Monitor] Test Email")
    end
  end
end
