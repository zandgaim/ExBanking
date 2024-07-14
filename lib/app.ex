defmodule App do
  use Application

  def start(_type, _args) do
    children = [
      {Sup, []}
    ]

    opts = [strategy: :one_for_one, name: Supervisor]
    Supervisor.start_link(children, opts)
  end
end
