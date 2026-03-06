defmodule Mix.Tasks.Notifications.TestEmail do
  @moduledoc "Sends a test email to verify notification setup."
  @shortdoc "Send a test notification email"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    recipients = Application.get_env(:periodicmonitor, :alert_recipients, [])

    if recipients == [] do
      Mix.shell().info("No recipients configured. Set ALERT_RECIPIENTS env var.")
    else
      email = Periodicmonitor.Notifications.Email.test_email(recipients)

      case Periodicmonitor.Mailer.deliver(email) do
        {:ok, _} ->
          Mix.shell().info("Test email sent to: #{Enum.join(recipients, ", ")}")

        {:error, reason} ->
          Mix.shell().info("Failed to send test email: #{inspect(reason)}")
      end
    end
  end
end
