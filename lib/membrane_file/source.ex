defmodule Membrane.File.Source do
  @moduledoc """
  Element that reads chunks of data from given file and sends them as buffers
  through the output pad.
  """

  use Membrane.Source
  alias Membrane.Buffer
  alias Membrane.File.CommonFile

  import Mockery.Macro

  def_options location: [type: :string, description: "Path to the file"],
              chunk_size: [
                type: :integer,
                spec: pos_integer,
                default: 2048,
                description: "Size of chunks being read"
              ]

  def_output_pad :output, caps: :any

  # Private API

  @impl true
  def handle_init(%__MODULE__{location: location, chunk_size: size}) do
    {:ok,
     %{
       location: location,
       chunk_size: size,
       fd: nil
     }}
  end

  @impl true
  def handle_stopped_to_prepared(_ctx, state), do: mockable(CommonFile).open(:read, state)

  @impl true
  def handle_demand(:output, _size, :buffers, _ctx, %{chunk_size: chunk_size} = state),
    do: supply_demand(chunk_size, [redemand: :output], state)

  def handle_demand(:output, size, :bytes, _ctx, state),
    do: supply_demand(size, [], state)

  def supply_demand(size, redemand, %{fd: fd} = state) do
    with <<payload::binary>> <- fd |> mockable(CommonFile).binread(size) do
      {{:ok, [buffer: {:output, %Buffer{payload: payload}}] ++ redemand}, state}
    else
      _ -> {{:ok, end_of_stream: :output}, state}
    end
  end

  @impl true
  def handle_prepared_to_stopped(_ctx, state), do: mockable(CommonFile).close(state)
end
