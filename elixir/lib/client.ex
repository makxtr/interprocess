defmodule Interprocess.Client do
  def start(port) do
    {:ok, socket} =
      :gen_tcp.connect(~c'localhost', port, [
        :binary,
        active: false
      ])

    case :gen_tcp.recv(socket, 0, 5000) do
      {:ok, chunk} ->
        # 1. Get task
        task = :erlang.binary_to_term(chunk)
        IO.puts("Received task: #{inspect(task)}")

        # 2. Do job
        solution = Enum.map(task, fn x -> x * 2 end)
        IO.puts("Sending solution: #{inspect(solution)}")

        # 3. Send solution back to server
        :gen_tcp.send(socket, :erlang.term_to_binary(solution))

      {:error, :timeout} ->
        IO.puts("Server didn't send task in time")
    end

    :gen_tcp.close(socket)
  end
end
