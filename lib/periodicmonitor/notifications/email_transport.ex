defmodule Periodicmonitor.Notifications.EmailTransport do
  @moduledoc "Email notification transport using Swoosh."

  @behaviour Periodicmonitor.Notifications.Transport

  alias Periodicmonitor.Notifications.Email
  alias Periodicmonitor.Mailer

  @impl true
  def send_alert(domain, milestone, recipients) do
    domain
    |> Email.expiration_alert(milestone, recipients)
    |> Mailer.deliver()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def send_test(recipients) do
    recipients
    |> Email.test_email()
    |> Mailer.deliver()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
