defmodule Periodicmonitor.Notifications.Email do
  import Swoosh.Email

  @milestone_labels %{"30d" => "30 days", "7d" => "7 days", "1d" => "1 day"}

  def expiration_alert(domain, milestone, recipients) do
    label = Map.fetch!(@milestone_labels, milestone)

    from_address =
      Application.get_env(:periodicmonitor, :alert_from_email, "alerts@periodicmonitor.local")

    new()
    |> to(Enum.map(recipients, &{"", &1}))
    |> from({"ENS Monitor", from_address})
    |> subject("[ENS Alert] #{domain.name} expires in #{label}")
    |> text_body("""
    This is a notification from the ENS Domain Monitor.

    The domain #{domain.name} expires in #{label}.

    Details:
      Expiration date: #{Calendar.strftime(domain.expires_at, "%Y-%m-%d %H:%M UTC")}
      Status: #{domain.status}
      Owner: #{domain.owner}

    Please renew it to avoid losing ownership.

    --
    ENS Domain Monitor
    """)
  end

  def test_email(recipients) do
    from_address =
      Application.get_env(:periodicmonitor, :alert_from_email, "alerts@periodicmonitor.local")

    new()
    |> to(Enum.map(recipients, &{"", &1}))
    |> from({"ENS Monitor", from_address})
    |> subject("[ENS Monitor] Test Email")
    |> text_body("""
    ENS Domain Monitor — Test Email

    This email confirms that your notification system is working correctly.

    You will receive alerts when your ENS domains are 30 days, 7 days, and 1 day from expiration.

    Here is an example of what an alert will look like:

    -------------------------------------------------------
    This is a notification from the ENS Domain Monitor.

    The domain example.eth expires in 30 days.

    Details:
      Expiration date: 2026-04-06 00:00 UTC
      Status: expiring
      Owner: 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045

    Please renew it to avoid losing ownership.
    -------------------------------------------------------

    --
    ENS Domain Monitor
    """)
  end
end
