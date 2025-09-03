defmodule ResearchPlatform.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ResearchPlatformWeb.Telemetry,
      ResearchPlatform.Repo,
      {DNSCluster, query: Application.get_env(:research_platform, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ResearchPlatform.PubSub},
      # Start a worker by calling: ResearchPlatform.Worker.start_link(arg)
      # {ResearchPlatform.Worker, arg},
      # Start to serve requests, typically the last entry
      ResearchPlatformWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ResearchPlatform.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ResearchPlatformWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
