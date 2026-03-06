defmodule Periodicmonitor.NotificationsTest do
  use Periodicmonitor.DataCase, async: true

  alias Periodicmonitor.Notifications
  alias Periodicmonitor.Notifications.NotificationLog

  describe "milestone_for_domain/1" do
    test "returns \"1d\" when domain expires in 1 day" do
      domain = %Periodicmonitor.Domains.EnsDomain{expires_at: DateTime.add(DateTime.utc_now(), 1, :day)}
      assert Notifications.milestone_for_domain(domain) == "1d"
    end

    test "returns \"7d\" when domain expires in 5 days" do
      domain = %Periodicmonitor.Domains.EnsDomain{expires_at: DateTime.add(DateTime.utc_now(), 5, :day)}
      assert Notifications.milestone_for_domain(domain) == "7d"
    end

    test "returns \"30d\" when domain expires in 20 days" do
      domain = %Periodicmonitor.Domains.EnsDomain{expires_at: DateTime.add(DateTime.utc_now(), 20, :day)}
      assert Notifications.milestone_for_domain(domain) == "30d"
    end

    test "returns nil when domain expires in more than 30 days" do
      domain = %Periodicmonitor.Domains.EnsDomain{expires_at: DateTime.add(DateTime.utc_now(), 60, :day)}
      assert Notifications.milestone_for_domain(domain) == nil
    end

    test "returns nil when domain has no expiry" do
      domain = %Periodicmonitor.Domains.EnsDomain{expires_at: nil}
      assert Notifications.milestone_for_domain(domain) == nil
    end

    test "returns nil when domain is already expired" do
      domain = %Periodicmonitor.Domains.EnsDomain{expires_at: DateTime.add(DateTime.utc_now(), -1, :day)}
      assert Notifications.milestone_for_domain(domain) == nil
    end
  end

  describe "already_notified?/2" do
    test "returns false when no log exists" do
      refute Notifications.already_notified?("test.eth", "30d")
    end

    test "returns true when log exists" do
      Repo.insert!(%NotificationLog{
        domain_name: "test.eth",
        milestone: "30d",
        sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      assert Notifications.already_notified?("test.eth", "30d")
    end
  end

  describe "record_notification!/2" do
    test "creates a notification log" do
      Notifications.record_notification!("test.eth", "7d")
      assert Repo.get_by(NotificationLog, domain_name: "test.eth", milestone: "7d")
    end
  end
end
