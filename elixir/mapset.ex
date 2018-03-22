# MapSet type for Ecto.schema
# Usage:
#
# schema "rooms" do
#   field(:id, :integer)
#   field(:members, Sample.Ecto.MapSet)
# end

defmodule Sample.Ecto.MapSet do
  @behaviour Ecto.Type
  def type, do: {:mapset, :integer}

  def cast(mapset) when is_map(mapset) do
    if mapset |> MapSet.to_list() |> Enum.all?(&is_number/1) do
      {:ok, mapset}
    else
      :error
    end
  end

  def cast(_), do: :error
  defdelegate dump(x), to: {:mapset, :integer}
  defdelegate load(x), to: {:mapset, :integer}
end
