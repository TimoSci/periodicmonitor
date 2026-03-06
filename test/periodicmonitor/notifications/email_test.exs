defmodule Periodicmonitor.Notifications.EmailTest do
  use Periodicmonitor.DataCase, async: true

  alias Periodicmonitor.Notifications.Email

  describe "expiration_alert/3" do
    test "builds email with correct subject and body for a domain" do
      domain = %Periodicmonitor.Domains.EnsDomain{
        name: "test.eth",
        expires_at: ~U[2026-04-06 00:00:00Z],
        status: "expiring",
        owner: "0x1234"
      }

      email = Email.expiration_alert(domain, "30d", ["user@test.com"])

      assert email.subject =~ "test.eth"
      assert email.subject =~ "30 days"
      assert email.to == [{"", "user@test.com"}]
      assert email.text_body =~ "test.eth"
      assert email.text_body =~ "2026-04-06"
    end

    test "builds email for 7d milestone" do
      domain = %Periodicmonitor.Domains.EnsDomain{
        name: "urs.eth",
        expires_at: ~U[2026-03-13 00:00:00Z],
        status: "critical",
        owner: "0x1234"
      }

      email = Email.expiration_alert(domain, "7d", ["a@b.com", "c@d.com"])

      assert email.subject =~ "7 days"
      assert length(email.to) == 2
    end

    test "builds email for 1d milestone" do
      domain = %Periodicmonitor.Domains.EnsDomain{
        name: "urs.eth",
        expires_at: ~U[2026-03-07 00:00:00Z],
        status: "critical",
        owner: "0x1234"
      }

      email = Email.expiration_alert(domain, "1d", ["a@b.com"])
      assert email.subject =~ "1 day"
    end
  end

  describe "test_email/1" do
    test "builds a test email" do
      email = Email.test_email(["user@test.com"])

      assert email.subject =~ "Test"
      assert email.to == [{"", "user@test.com"}]
      assert email.text_body =~ "working correctly"
    end
  end
end
