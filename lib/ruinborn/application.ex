defmodule Ruinborn.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RuinbornWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:ruinborn, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Ruinborn.PubSub},
      {Registry, keys: :unique, name: Ruinborn.MatchRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Ruinborn.MatchSupervisor},
      # Start a worker by calling: Ruinborn.Worker.start_link(arg)
      # {Ruinborn.Worker, arg},
      # Start to serve requests, typically the last entry
      RuinbornWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Ruinborn.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RuinbornWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
