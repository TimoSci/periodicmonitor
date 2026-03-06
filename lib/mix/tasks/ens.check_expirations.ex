defmodule Mix.Tasks.Ens.CheckExpirations do
  @moduledoc "Checks expiration dates for all configured ENS domains."
  @shortdoc "Checks ENS domain expiration dates"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    names = Application.get_env(:periodicmonitor, :ens_names, [])
    Mix.shell().info("Checking ENS domain expirations for #{length(names)} name(s)...\n")

    results = Periodicmonitor.Domains.check_all_domains()

    Enum.zip(names, results)
    |> Enum.each(fn {name, result} ->
      case result do
        {:ok, domain} ->
          Mix.shell().info("#{name}")
          Mix.shell().info("  Owner:   #{domain.owner}")
          Mix.shell().info("  Expires: #{domain.expires_at}")
          Mix.shell().info("  Status:  #{domain.status}\n")

        {:error, reason} ->
          Mix.shell().info("#{name}")
          Mix.shell().info("  Error: #{reason}\n")
      end
    end)
  end
end
