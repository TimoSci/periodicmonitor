defmodule Periodicmonitor.Ethereum.RPC do
  @moduledoc """
  JSON-RPC client for Ethereum node communication via Req.
  """

  def eth_block_number do
    case json_rpc("eth_blockNumber", []) do
      {:ok, hex_string} ->
        {number, ""} = hex_string |> String.trim_leading("0x") |> Integer.parse(16)
        {:ok, number}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp json_rpc(method, params) do
    body = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => method,
      "params" => params
    }

    case Req.post(build_req(), json: body) do
      {:ok, %Req.Response{status: 200, body: %{"result" => result}}} ->
        {:ok, result}

      {:ok, %Req.Response{status: 200, body: %{"error" => %{"message" => message}}}} ->
        {:error, message}

      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  defp build_req do
    ethereum_config = Application.get_env(:periodicmonitor, :ethereum)
    endpoint = ethereum_config[:https_endpoint]
    req_options = ethereum_config[:req_options] || []

    Req.new([url: endpoint] ++ req_options)
  end
end
