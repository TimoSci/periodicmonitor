defmodule Periodicmonitor.Notifications.NotificationLogTest do
  use Periodicmonitor.DataCase, async: true

  alias Periodicmonitor.Notifications.NotificationLog

  describe "changeset/2" do
    test "valid changeset" do
      attrs = %{domain_name: "test.eth", milestone: "30d", sent_at: DateTime.utc_now()}
      changeset = NotificationLog.changeset(%NotificationLog{}, attrs)
      assert changeset.valid?
    end

    test "requires domain_name, milestone, and sent_at" do
      changeset = NotificationLog.changeset(%NotificationLog{}, %{})
      refute changeset.valid?
      assert %{domain_name: ["can't be blank"], milestone: ["can't be blank"], sent_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates milestone is one of 30d, 7d, 1d" do
      attrs = %{domain_name: "test.eth", milestone: "99d", sent_at: DateTime.utc_now()}
      changeset = NotificationLog.changeset(%NotificationLog{}, attrs)
      refute changeset.valid?
    end
  end
end
