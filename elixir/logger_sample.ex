# An example of Logger run as a supervisor
#  * Log handler: filter or send log to another server
#  * Using deps like `socket`,`msgpax` deps and middleware like `fluent_logger`

defmodule SampleProject.Logger do
  use Supervisor
  alias SampleProject.Logger.Client

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Supervisor.init(
      [
        {Client, []}
      ],
      strategy: :one_for_one
    )
  end

  @spec send_log(tag :: binary, level :: Atom.t(), data :: Map.t()) :: {:ok, pid} | nil
  def send_log(tag, level, data) when level in [:info, :error] and is_map(data) do
    Task.start(fn ->
      tag_with_level = "#{tag}.#{level}"

      data =
        data
        |> Map.take(log_attrs())
        |> Map.put("level", "#{level}")

      GenServer.cast(Client, {:send, tag_with_level, data})
    end)
  end

  def send_log(_, _, _), do: nil

  defp log_attrs do
    ~w(
      level
      id
      attr_sample1
      attr_sample2
      attr_sample3
      error
    )
  end
end

defmodule SampleProject.Logger.Client do
  use GenServer

  require Logger

  defmodule State do
    defstruct socket: nil, config: []
  end

  def default_config do
    [
      host: "localhost",
      port: 24224,
      prefix: "Samplelog",
      retry_times: 10
    ]
  end

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  def init(_options) do
    config = compile_config() || default_config()
    {:ok, %State{config: config}}
  end

  def handle_cast(msg, %State{socket: nil, config: config} = state) do
    if socket = connect(config, config[:retry_times]) do
      handle_cast(msg, %State{state | socket: socket})
    else
      Logger.error("Cannot connect to #{config[:host]}:#{config[:port]}")
      {:noreply, state}
    end
  end

  def handle_cast({:send, tag, data}, state) do
    state = send(tag, data, state)
    {:noreply, state}
  end

  def handle_cast(_, state), do: {:noreply, state}

  defp connect(config, retry_times) do
    case Socket.TCP.connect(config[:host], config[:port], packet: 0) do
      {:ok, socket} ->
        socket

      {:error, _error} ->
        Logger.info("Try connecting to: #{config[:host]}:#{config[:port]}", type: :common)

        if retry_times > 0 do
          :timer.sleep(10)
          connect(config, retry_times - 1)
        end
    end
  end

  defp send(tag, data, %State{socket: socket, config: config} = state) do
    try do
      cur_time = System.system_time(:second)
      packet = Msgpax.pack!([tag, cur_time, data])
      Socket.Stream.send!(socket, packet)
    rescue
      reason in _ ->
        Logger.error("#{inspect(reason)}")
    end

    state
  end

  defp compile_config, do: Application.get_env(:sample_project, :fluent_logger)
end
