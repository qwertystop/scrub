defmodule APS.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false


    # Define workers and child supervisors to be supervised
    # First child is the neighbor registry
    n_reg = supervisor(Registry, [:multiple, :neighbor_registry])
    # Other workers are pulled from application configuration
    zones = for {module, args, opts} <- Application.get_env(:aps, :zones),
                  do: worker(module, args, opts)
    opts = [strategy: :one_for_one, name: APS.Supervisor]
    Supervisor.start_link([n_reg | zones], opts)
  end
end
