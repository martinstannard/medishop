defmodule Medishop.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MedishopWeb.Telemetry,
      Medishop.Repo,
      {DNSCluster, query: Application.get_env(:medishop, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Medishop.PubSub},
      # Start a worker by calling: Medishop.Worker.start_link(arg)
      # {Medishop.Worker, arg},
      # Start to serve requests, typically the last entry
      MedishopWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :medishop]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Medishop.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MedishopWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
