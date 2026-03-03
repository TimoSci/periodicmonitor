defmodule Periodicmonitor.Repo do
  use Ecto.Repo,
    otp_app: :periodicmonitor,
    adapter: Ecto.Adapters.Postgres
end
