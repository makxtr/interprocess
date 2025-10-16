defmodule Interprocess.Server do
  require Logger

  @doc """
  Starts the server on the given port.
  """
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
    chunks = Enum.chunk_every(data, step)

    Logger.info("Server started on port #{port}")
    accept_loop(socket, chunks)
  end

  defp accept_loop(socket, [chunk | rest]) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info("Accepted connection from #{inspect(client)}")
    spawn_link(fn -> handle_client(client, chunk) end)
    accept_loop(socket, rest)
  end

  defp accept_loop(socket, []) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.warning("No more chunks available")
    :gen_tcp.send(client, "NO_DATA")
    :gen_tcp.close(client)
    accept_loop(socket, [])
  end

  defp handle_client(client, chunk) do
    case :gen_tcp.recv(client, 0) do
      {:ok, data} ->
        Logger.info("Received data: #{inspect(data)}")
        :gen_tcp.send(client, :erlang.term_to_binary(chunk))

      {:error, reason} ->
        Logger.error("Error receiving data: #{inspect(reason)}")
    end

    :gen_tcp.close(client)
  end
end
