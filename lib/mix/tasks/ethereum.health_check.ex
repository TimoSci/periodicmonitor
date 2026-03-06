defmodule Mix.Tasks.Ethereum.HealthCheck do
  @moduledoc "Checks connectivity to the configured Ethereum HTTPS endpoint."
  @shortdoc "Tests Ethereum HTTPS endpoint connectivity"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    endpoint = Application.get_env(:periodicmonitor, :ethereum)[:https_endpoint]
    masked = mask_endpoint(endpoint)

    Mix.shell().info("Checking Ethereum HTTPS endpoint: #{masked}")

    case Periodicmonitor.Ethereum.RPC.eth_block_number() do
      {:ok, block_number} ->
        Mix.shell().info("Ethereum HTTPS connection: OK")
        Mix.shell().info("Current block number: #{block_number}")

      {:error, reason} ->
        Mix.shell().info("Ethereum HTTPS connection: FAILED")
        Mix.shell().info("Error: #{reason}")
    end
  end

  defp mask_endpoint(url) when is_binary(url) do
    uri = URI.parse(url)
    "#{uri.scheme}://#{uri.host}/***"
  end

  defp mask_endpoint(_), do: "(not configured)"
end
