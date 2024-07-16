defmodule Sup do
  use Supervisor
  require Logger

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    children = []

    Supervisor.init(children, strategy: :one_for_one)
  end

  def init_user({user}) do
    child_spec = %{
      # Using the name macro to generate gproc id
      id: {Global, {user}},
      start: {UserWorker, :start_link, [user]}
    }

    Supervisor.start_child(__MODULE__, child_spec)
  end
end
