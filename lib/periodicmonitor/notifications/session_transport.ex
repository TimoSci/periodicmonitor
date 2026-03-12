defmodule Periodicmonitor.Notifications.SessionTransport do
  @moduledoc "Session Messenger notification transport via Bun microservice."

  @behaviour Periodicmonitor.Notifications.Transport

  @milestone_labels %{"30d" => "30 days", "7d" => "7 days", "1d" => "1 day"}

  @impl true
  def send_alert(domain, milestone, recipients) do
    label = Map.fetch!(@milestone_labels, milestone)

    text =
      String.trim("""
      ENS Domain Monitor Alert

      The domain #{domain.name} expires in #{label}.

      Details:
        Expiration date: #{Calendar.strftime(domain.expires_at, "%Y-%m-%d %H:%M UTC")}
        Status: #{domain.status}
        Owner: #{domain.owner}

      Please renew it to avoid losing ownership.
      """)

    send_to_all(recipients, text)
  end

  @impl true
  def send_test(recipients) do
    text =
      String.trim("""
      ENS Domain Monitor — Test Message

      This message confirms that your Session notification system is working correctly.

      You will receive alerts when your ENS domains are 30 days, 7 days, and 1 day from expiration.
      """)

    send_to_all(recipients, text)
  end

  defp send_to_all(recipients, text) do
    results =
      Enum.map(recipients, fn recipient ->
        base_url = Application.get_env(:periodicmonitor, :session_service_url, "http://localhost:3100")

        req =
          Req.new(url: "#{base_url}/send", receive_timeout: 10_000)
          |> attach_test_plug()

        case Req.post(req, json: %{to: recipient, text: text}) do
          {:ok, %{status: 200}} -> :ok
          {:ok, resp} -> {:error, {:unexpected_status, resp.status, resp.body}}
          {:error, reason} -> {:error, reason}
        end
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  defp attach_test_plug(req) do
    case Application.get_env(:periodicmonitor, :session_transport_req_options) do
      nil -> req
      opts -> Req.merge(req, opts)
    end
  end
end
