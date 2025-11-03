defmodule Interprocess.Server do
  use GenServer
  require Logger

  @def_port 2000

  # Client API

  @doc """
  Start the server GenServer.
  """
  def start_link(opts \\ []) do
    port = Keyword.get(opts, :port, @def_port)
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  @doc """
  Send tasks for clients by chunks
  and awaits results from them.
  """
  def start(port \\ @def_port) do
    start_link(port: port)
  end

  # Server Callbacks

  @impl true
  def init(port) do
    data = [2, 17, 3, 2, 5, 7, 15, 22, 1, 14, 15, 9, 0, 11]
    step = 4

    state = %{
      socket: nil,
      active_clients: MapSet.new(),
      results: %{},
      tasks: Enum.chunk_every(data, step),
      counter: 0,
      port: port
    }

    {:ok, state, {:continue, :start_listening}}
  end

  @impl true
  def handle_continue(:start_listening, state) do
    {:ok, socket} =
      :gen_tcp.listen(state.port, [
        :binary,
        packet: :raw,
        active: false,
        reuseaddr: true
      ])

    Logger.info("Server started on port #{state.port}")

    spawn_link(fn -> accept_loop(socket) end)

    {:noreply, %{state | socket: socket}}
  end

  @impl true
  def handle_cast({:client_connected, client}, state) do
    case state.tasks do
      [task | rest] ->
        counter = state.counter
        client_pid = spawn_link(fn -> handle_client(client, task, counter) end)

        {:noreply,
         %{
           state
           | tasks: rest,
             counter: counter + 1,
             active_clients: MapSet.put(state.active_clients, client_pid)
         }}

      [] ->
        Logger.warning("No tasks available, closing connection")
        :gen_tcp.close(client)
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:task_completed, pid, counter, solution}, state) do
    new_state =
      state
      |> Map.update!(:results, &Map.put(&1, counter, solution))
      |> Map.update!(:active_clients, &MapSet.delete(&1, pid))

    check_if_done(new_state)
  end

  @impl true
  def handle_cast({:task_failed, pid, reason}, state) do
    Logger.error("Task failed for #{inspect(pid)}: #{inspect(reason)}")

    new_state = Map.update!(state, :active_clients, &MapSet.delete(&1, pid))

    check_if_done(new_state)
  end

  defp check_if_done(state) do
    all_done = MapSet.size(state.active_clients) == 0 and length(state.tasks) == 0

    if all_done do
      Logger.info("All done!")
      Logger.info("Results: #{inspect(state.results)}")

      finish =
        state.results
        |> Enum.sort_by(fn {counter, _data} -> counter end)
        |> Enum.flat_map(fn {_counter, data} -> data end)

      Logger.info("Final results: #{inspect(finish)}")

      System.stop(0)
    end

    {:noreply, state}
  end

  defp accept_loop(socket) do
    case :gen_tcp.accept(socket) do
      {:ok, client} ->
        Logger.info("Accepted connection from #{inspect(client)}")
        GenServer.cast(__MODULE__, {:client_connected, client})
        accept_loop(socket)

      {:error, reason} ->
        Logger.error("Accept error: #{inspect(reason)}")
    end
  end

  defp handle_client(client, task, counter) do
    pid = self()

    case :gen_tcp.send(client, :erlang.term_to_binary(task)) do
      :ok ->
        case :gen_tcp.recv(client, 0) do
          {:ok, solution} ->
            Logger.info("Received solution for task #{counter}")
            data = :erlang.binary_to_term(solution)
            GenServer.cast(__MODULE__, {:task_completed, pid, counter, data})

          {:error, reason} ->
            GenServer.cast(__MODULE__, {:task_failed, pid, reason})
        end

      {:error, reason} ->
        GenServer.cast(__MODULE__, {:task_failed, pid, reason})
    end

    :gen_tcp.close(client)
  end
end
