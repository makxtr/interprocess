defmodule Interprocess.Client do
  @def_timeout 5000
  @def_port 2000

  @doc """
    Get task from server,
    do job and send solution back to server
  """
  def start(port \\ @def_port)

  def start(port) do
    {:ok, socket} =
      :gen_tcp.connect(~c'localhost', port, [
        :binary,
        active: false
      ])

    case :gen_tcp.recv(socket, 0, @def_timeout) do
      {:ok, chunk} ->
        task = :erlang.binary_to_term(chunk)
        IO.puts("Received task: #{inspect(task)}")

        delay = :rand.uniform(10) * 1000
        IO.puts("Working for #{delay} ms...")
        :timer.sleep(delay)

        solution = Enum.map(task, fn x -> x * 2 end)
        IO.puts("Sending solution: #{inspect(solution)}")

        :gen_tcp.send(socket, :erlang.term_to_binary(solution))

      {:error, :timeout} ->
        IO.puts("Server didn't send task in time")

      {:error, :closed} ->
        IO.puts("Server closed connection")
    end

    :gen_tcp.close(socket)
  end
end
