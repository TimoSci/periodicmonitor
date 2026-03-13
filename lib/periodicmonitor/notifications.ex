defmodule Periodicmonitor.Notifications do
  alias Periodicmonitor.Repo
  alias Periodicmonitor.Notifications.NotificationLog

  def milestone_for_domain(%{expires_at: nil}), do: nil

  def milestone_for_domain(%{expires_at: expires_at}) do
    days = DateTime.diff(expires_at, DateTime.utc_now(), :day)

    cond do
      days < 0 -> nil
      days <= 1 -> "1d"
      days <= 7 -> "7d"
      days <= 30 -> "30d"
      true -> nil
    end
  end

  def already_notified?(domain_name, milestone) do
    Repo.get_by(NotificationLog, domain_name: domain_name, milestone: milestone) != nil
  end

  def record_notification!(domain_name, milestone) do
    %NotificationLog{}
    |> NotificationLog.changeset(%{
      domain_name: domain_name,
      milestone: milestone,
      sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()
  end
end
