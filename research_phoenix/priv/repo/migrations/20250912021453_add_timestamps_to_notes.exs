defmodule ResearchPlatform.Repo.Migrations.AddTimestampsToNotes do
  use Ecto.Migration

  def change do
    alter table(:notes) do
      add_if_not_exists :inserted_at, :utc_datetime, default: fragment("NOW()")
      add_if_not_exists :updated_at, :utc_datetime, default: fragment("NOW()")
    end
  end
end
