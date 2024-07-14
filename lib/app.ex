defmodule App do
  use Application

  def start(_type, _args) do
    children = [
      {Task.Supervisor, [name: ExBanking.TaskSupervisor]},
      {ExBanking, []},
      {Sup, []}
    ]

    opts = [strategy: :one_for_one, name: Supervisor]
    Supervisor.start_link(children, opts)
  end
end
