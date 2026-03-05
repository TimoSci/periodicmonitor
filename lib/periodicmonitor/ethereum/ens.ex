defmodule Periodicmonitor.Ethereum.ENS do
  @moduledoc """
  ENS (Ethereum Name Service) hashing utilities and contract interactions.
  """

  @base_registrar "0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85"
  @ens_registry "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e"
  @name_expires_selector ExKeccak.hash_256("nameExpires(uint256)")
                         |> binary_part(0, 4)
                         |> Base.encode16(case: :lower)
  @owner_selector ExKeccak.hash_256("owner(bytes32)")
                  |> binary_part(0, 4)
                  |> Base.encode16(case: :lower)

  alias Periodicmonitor.Ethereum.RPC

  @doc """
  Computes the keccak-256 hash of the label (name without `.eth` suffix).
  Returns a hex-encoded string prefixed with "0x".
  """
  def label_hash(name) do
    label = name |> String.replace_suffix(".eth", "")
    hash = ExKeccak.hash_256(label)
    "0x" <> Base.encode16(hash, case: :lower)
  end

  @doc """
  Computes the ENS namehash for a given domain name.
  Returns a hex-encoded string prefixed with "0x".

  See: https://docs.ens.domains/resolution/names#algorithm
  """
  def namehash("") do
    "0x" <> String.duplicate("00", 32)
  end

  def namehash(name) do
    labels = String.split(name, ".")

    node =
      labels
      |> Enum.reverse()
      |> Enum.reduce(<<0::256>>, fn label, node ->
        label_hash_raw = ExKeccak.hash_256(label)
        ExKeccak.hash_256(node <> label_hash_raw)
      end)

    "0x" <> Base.encode16(node, case: :lower)
  end

  @doc """
  Computes the ENS token ID for a given name.
  The token ID is the unsigned integer representation of the keccak-256 hash of the label.
  """
  def token_id(name) do
    label = name |> String.replace_suffix(".eth", "")
    hash = ExKeccak.hash_256(label)
    :binary.decode_unsigned(hash)
  end

  @doc """
  Queries the ENS BaseRegistrar for the expiration date of a given name.
  Returns `{:ok, %DateTime{}}` or `{:error, reason}`.
  """
  def name_expires(name) do
    tid = token_id(name)
    data = "0x" <> @name_expires_selector <> encode_uint256(tid)

    case RPC.eth_call(@base_registrar, data) do
      {:ok, hex_result} ->
        timestamp = decode_uint256(hex_result)
        {:ok, DateTime.from_unix!(timestamp)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Queries the ENS Registry for the owner of a given name.
  Returns `{:ok, address}` or `{:error, reason}`.
  """
  def get_owner(name) do
    node = namehash(name) |> String.trim_leading("0x")
    data = "0x" <> @owner_selector <> node

    case RPC.eth_call(@ens_registry, data) do
      {:ok, hex_result} ->
        address = decode_address(hex_result)
        {:ok, address}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp encode_uint256(integer) do
    integer
    |> :binary.encode_unsigned()
    |> Base.encode16(case: :lower)
    |> String.pad_leading(64, "0")
  end

  defp decode_uint256("0x" <> hex) do
    {value, ""} = Integer.parse(hex, 16)
    value
  end

  defp decode_address("0x" <> hex) do
    address_hex = String.slice(hex, 24, 40)
    "0x" <> address_hex
  end
end
