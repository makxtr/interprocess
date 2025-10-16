defmodule Interprocess.Client do
  def start(port) do
    {:ok, socket} = :gen_tcp.connect(~c'localhost', port, [:binary, active: false])
    :gen_tcp.send(socket, "Hello from Client!")
    {:ok, response} = :gen_tcp.recv(socket, 0)
    # => "OK"
    IO.inspect(:erlang.binary_to_term(response))
  end
end
