defmodule Interprocess.Server do
  require Logger

  @def_port 2000

  @doc """
  Send tasks for clients by chunks
  and awaits results from them.
  """
  def start(port \\ @def_port)

  def start(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [
        :binary,
        packet: :raw,
        active: false,
        reuseaddr: true
      ])

    data = [2, 17, 3, 2, 5, 7, 15, 22, 1, 14, 15, 9, 0, 11]
    step = 4

    {:ok, agent_pid} =
      Agent.start_link(fn ->
        %{
          connections: [],
          results: [],
          tasks: Enum.chunk_every(data, step),
          counter: 0
        }
      end)

    Logger.info("Server started on port #{port}")
    accept_loop(socket, agent_pid)
  end

  defp accept_loop(socket, agent_pid) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info("Accepted connection from #{inspect(client)}")

    case Agent.get_and_update(agent_pid, fn state ->
           case state.tasks do
             [task | rest] -> {{:task, task}, %{state | tasks: rest}}
             [] -> {:no_tasks, state}
           end
         end) do
      {:task, task} ->
        counter =
          Agent.get_and_update(agent_pid, fn state ->
            {state.counter, %{state | counter: state.counter + 1}}
          end)

        Agent.update(agent_pid, fn state ->
          client_info = %{socket: client, done: false, get: counter}
          %{state | connections: [client_info | state.connections]}
        end)

        spawn_link(fn -> handle_client(client, task, counter, agent_pid) end)

      {:no_tasks} ->
        Logger.warning("No tasks available, closing connection")
        :gen_tcp.close(client)
    end

    accept_loop(socket, agent_pid)
  end

  defp handle_client(client, task, counter, agent_pid) do
    :gen_tcp.send(client, :erlang.term_to_binary(task))

    case :gen_tcp.recv(client, 0) do
      {:ok, solution} ->
        Logger.info("Received solution: #{inspect(client)}")

        result = %{get: counter, data: :erlang.binary_to_term(solution)}

        Agent.update(agent_pid, fn state ->
          %{state | results: [result | state.results]}
        end)

      {:error, reason} ->
        Logger.error("Error receiving solution: #{inspect(reason)}")
    end

    :gen_tcp.close(client)

    state =
      Agent.get_and_update(agent_pid, fn state ->
        new_connections = Enum.reject(state.connections, fn c -> c.socket == client end)
        new_state = %{state | connections: new_connections}

        {new_state, new_state}
      end)

    tasks_length = length(state.tasks)
    conn_length = length(state.connections)

    all_done = conn_length == 0 and tasks_length == 0

    if all_done do
      Logger.info("All done!")

      Logger.info("#{inspect(state.results)}")

      finish =
        state.results
        |> Enum.sort_by(fn r -> r.get end)
        |> Enum.flat_map(fn r -> r.data end)

      Logger.info("Final results: #{inspect(finish)}")

      System.stop(0)
    end
  end
end
