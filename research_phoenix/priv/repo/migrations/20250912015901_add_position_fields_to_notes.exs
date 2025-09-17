defmodule ResearchPlatform.Repo.Migrations.AddPositionFieldsToNotes do
  use Ecto.Migration

  def change do
    alter table(:notes) do
      add :page, :integer, default: 1
      add :x_position, :float
      add :y_position, :float
      add :note_type, :string, default: "text"
    end
  end
end
