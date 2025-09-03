defmodule ResearchPlatform.Repo do
  use Ecto.Repo,
    otp_app: :research_platform,
    adapter: Ecto.Adapters.Postgres
end
