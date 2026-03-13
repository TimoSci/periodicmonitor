defmodule Periodicmonitor.Notifications.Scheduler do
  use GenServer

  require Logger

  @daily_interval :timer.hours(24)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, @daily_interval)
    schedule_tick(interval)
    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_info(:tick, state) do
    check_and_notify()
    schedule_tick(state.interval)
    {:noreply, state}
  end

  def check_and_notify do
    alias Periodicmonitor.{Domains, Notifications}
    alias Periodicmonitor.Notifications.Transport

    transport = Transport.current()

    recipients =
      case Application.get_env(:periodicmonitor, :notification_transport, :session) do
        :session -> Application.get_env(:periodicmonitor, :session_recipients, [])
        :email -> Application.get_env(:periodicmonitor, :alert_recipients, [])
      end

    if recipients == [] do
      Logger.warning("[Notifications.Scheduler] No recipients configured, skipping.")
      :ok
    else
      Domains.list_domains()
      |> Enum.each(fn domain ->
        case Notifications.milestone_for_domain(domain) do
          nil ->
            :skip

          milestone ->
            unless Notifications.already_notified?(domain.name, milestone) do
              case transport.send_alert(domain, milestone, recipients) do
                :ok ->
                  Notifications.record_notification!(domain.name, milestone)

                  Logger.info(
                    "[Notifications.Scheduler] Sent #{milestone} alert for #{domain.name}"
                  )

                {:error, reason} ->
                  Logger.error(
                    "[Notifications.Scheduler] Failed to send alert for #{domain.name}: #{inspect(reason)}"
                  )
              end
            end
        end
      end)
    end
  end

  defp schedule_tick(interval) do
    Process.send_after(self(), :tick, interval)
  end
end
