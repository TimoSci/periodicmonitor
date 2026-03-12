defmodule Periodicmonitor.Notifications.Transport do
  @moduledoc "Behaviour for notification transports (Session, Email)."

  @callback send_alert(domain :: map(), milestone :: String.t(), recipients :: list(String.t())) ::
              :ok | {:error, term()}

  @callback send_test(recipients :: list(String.t())) ::
              :ok | {:error, term()}

  def current do
    case Application.get_env(:periodicmonitor, :notification_transport, :session) do
      :session -> Periodicmonitor.Notifications.SessionTransport
      :email -> Periodicmonitor.Notifications.EmailTransport
    end
  end
end
