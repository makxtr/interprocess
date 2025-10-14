defmodule Interprocess.Client do
  def start(port) do
    {:ok, socket} = :gen_tcp.connect(~c'localhost', port, [:binary, active: false])
    :gen_tcp.send(socket, "Hello from Elixir!")
    {:ok, response} = :gen_tcp.recv(socket, 0)
    # => "OK"
    IO.inspect(response)
  end
end
