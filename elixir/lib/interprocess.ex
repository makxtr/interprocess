defmodule Interprocess do
  use Application

  @moduledoc """
  TCP-based distributed computing.

  See `Interprocess.Server` and `Interprocess.Client`.
  """

  def start(_type, _args) do
    children = [
      Supervisor.child_spec(
        {Interprocess.Server, port: 2000},
        restart: :transient
      )
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
