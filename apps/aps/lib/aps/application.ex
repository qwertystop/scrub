defmodule APS.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    # Workers are pulled from application configuration
    children = for {module, args, opts} <- Application.get_env(:aps, :zones),
                  do: worker(module, args, opts)
    opts = [strategy: :one_for_one, name: APS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
