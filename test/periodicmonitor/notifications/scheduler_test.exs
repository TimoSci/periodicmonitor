defmodule Periodicmonitor.Notifications.SchedulerTest do
  use Periodicmonitor.DataCase, async: false

  alias Periodicmonitor.Notifications.Scheduler
  alias Periodicmonitor.Notifications.NotificationLog
  alias Periodicmonitor.Domains

  setup do
    Application.put_env(:periodicmonitor, :session_recipients, ["05test_session_id"])
    on_exit(fn -> Application.put_env(:periodicmonitor, :session_recipients, []) end)

    Req.Test.stub(Periodicmonitor.Notifications.SessionTransport, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{status: "sent", message_hash: "abc", timestamp: 0})
      )
    end)

    :ok
  end

  describe "check_and_notify/0" do
    test "sends notification and records log for domain within milestone" do
      {:ok, _domain} =
        Domains.upsert_domain(%{
          name: "alert.eth",
          label_hash: "0xabc",
          owner: "0x1234",
          expires_at: DateTime.add(DateTime.utc_now(), 5, :day) |> DateTime.truncate(:second),
          status: "critical",
          last_checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      Scheduler.check_and_notify()

      assert Repo.get_by(NotificationLog, domain_name: "alert.eth", milestone: "7d")
    end

    test "does not send duplicate notifications" do
      {:ok, _domain} =
        Domains.upsert_domain(%{
          name: "alert.eth",
          label_hash: "0xabc",
          owner: "0x1234",
          expires_at: DateTime.add(DateTime.utc_now(), 5, :day) |> DateTime.truncate(:second),
          status: "critical",
          last_checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      Scheduler.check_and_notify()
      Scheduler.check_and_notify()

      logs = Repo.all(NotificationLog)
      assert length(logs) == 1
    end

    test "skips domains with no milestone" do
      {:ok, _domain} =
        Domains.upsert_domain(%{
          name: "safe.eth",
          label_hash: "0xdef",
          owner: "0x5678",
          expires_at: DateTime.add(DateTime.utc_now(), 60, :day) |> DateTime.truncate(:second),
          status: "active",
          last_checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      Scheduler.check_and_notify()

      assert Repo.all(NotificationLog) == []
    end
  end
end
