defmodule ResearchPlatform.Repo.Migrations.AddMissingFieldsToPapers do
  use Ecto.Migration

  def change do
    alter table(:papers) do
      add_if_not_exists :upload_date, :utc_datetime
      add_if_not_exists :created_at, :utc_datetime
    end
  end
end
