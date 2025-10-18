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

    state_pid =
      spawn(fn ->
        state_loop(%{
          connections: [],
          results: [],
          tasks: Enum.chunk_every(data, step),
          counter: 0
        })
      end)

    Logger.info("Server started on port #{port}")
    accept_loop(socket, state_pid)
  end

  defp state_loop(state) do
    receive do
      {:add_connection, client_socket, counter, from} ->
        client = %{socket: client_socket, done: false, get: counter}
        new_state = %{state | connections: [client | state.connections]}
        send(from, :ok)
        state_loop(new_state)

      {:remove_connection, client_socket, from} ->
        new_connections = Enum.reject(state.connections, fn c -> c.socket == client_socket end)
        new_state = %{state | connections: new_connections}
        send(from, {:ok, new_state})
        state_loop(new_state)

      {:add_result, result, from} ->
        new_state = %{state | results: [result | state.results]}
        send(from, :ok)
        state_loop(new_state)

      {:get_counter, from} ->
        send(from, {:counter, state.counter})
        state_loop(%{state | counter: state.counter + 1})

      {:next_task, from} ->
        case state.tasks do
          [task | rest_tasks] ->
            send(from, {:task, task})
            state_loop(%{state | tasks: rest_tasks})

          [] ->
            send(from, {:no_tasks})
            state_loop(state)
        end
    end
  end

  defp accept_loop(socket, state_pid) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info("Accepted connection from #{inspect(client)}")

    send(state_pid, {:next_task, self()})

    receive do
      {:task, task} ->
        send(state_pid, {:get_counter, self()})

        counter =
          receive do
            {:counter, c} -> c
          end

        send(state_pid, {:add_connection, client, counter, self()})

        receive do
          :ok -> :ok
        end

        spawn_link(fn -> handle_client(client, task, counter, state_pid) end)

      {:no_tasks} ->
        Logger.warning("No tasks available, closing connection")
        :gen_tcp.close(client)
    end

    accept_loop(socket, state_pid)
  end

  defp handle_client(client, task, counter, state_pid) do
    :gen_tcp.send(client, :erlang.term_to_binary(task))

    case :gen_tcp.recv(client, 0) do
      {:ok, solution} ->
        Logger.info("Received solution: #{inspect(solution)}")

        result = %{get: counter, data: :erlang.binary_to_term(solution)}
        send(state_pid, {:add_result, result, self()})

        receive do
          :ok -> :ok
        end

      {:error, reason} ->
        Logger.error("Error receiving solution: #{inspect(reason)}")
    end

    :gen_tcp.close(client)

    send(state_pid, {:remove_connection, client, self()})

    receive do
      {:ok, state} ->
        tasks_length = length(state.tasks)
        conn_length = length(state.connections)

        Logger.info("Closed connection. Remaining tasks: #{tasks_length}")

        all_done = conn_length == 0 and tasks_length == 0

        if all_done do
          Logger.info("All done!")

          finish =
            state.results
            |> Enum.sort_by(fn r -> r.get end)
            |> Enum.flat_map(fn r -> r.data end)

          Logger.info("Final results: #{inspect(finish)}")

          System.stop(0)
        end
    end
  end
end
