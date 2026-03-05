defmodule Periodicmonitor.Ethereum.ENS do
  @moduledoc """
  ENS (Ethereum Name Service) hashing utilities and contract interactions.
  """

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
end
