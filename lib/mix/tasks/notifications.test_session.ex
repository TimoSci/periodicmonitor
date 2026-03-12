defmodule Mix.Tasks.Notifications.TestSession do
  @moduledoc "Sends a test message via Session Messenger to verify setup."
  @shortdoc "Send a test Session notification"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    recipients = Application.get_env(:periodicmonitor, :session_recipients, [])

    if recipients == [] do
      Mix.shell().info("No Session recipients configured. Set SESSION_RECIPIENTS env var.")
    else
      case Periodicmonitor.Notifications.SessionTransport.send_test(recipients) do
        :ok ->
          Mix.shell().info("Test Session message sent to: #{Enum.join(recipients, ", ")}")

        {:error, reason} ->
          Mix.shell().info("Failed to send test Session message: #{inspect(reason)}")
      end
    end
  end
end
