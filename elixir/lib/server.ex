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

    Logger.info("Server started on port #{port}")
    accept_loop(socket)
  end

  defp accept_loop(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info("Accepted connection from #{inspect(client)}")
    spawn_link(fn -> handle_client(client) end)
    accept_loop(socket)
  end

  defp handle_client(client) do
    case :gen_tcp.recv(client, 0) do
      {:ok, data} ->
        Logger.info("Received data: #{inspect(data)}")
        :gen_tcp.send(client, "OK")

      {:error, reason} ->
        Logger.error("Error receiving data: #{inspect(reason)}")
    end

    :gen_tcp.close(client)
  end
end
