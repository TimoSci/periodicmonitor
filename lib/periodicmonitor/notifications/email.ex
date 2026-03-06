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
    ENS Domain Expiration Alert

    Domain: #{domain.name}
    Expires: #{Calendar.strftime(domain.expires_at, "%Y-%m-%d %H:%M UTC")}
    Status: #{domain.status}
    Owner: #{domain.owner}

    This domain will expire in #{label}. Please renew it to avoid losing ownership.

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

    --
    ENS Domain Monitor
    """)
  end
end
