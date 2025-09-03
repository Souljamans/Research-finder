defmodule ResearchPlatform.Repo.Migrations.CreateNotes do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:notes) do
      add :content, :text
      add :paper_id, references(:papers, type: :id, on_delete: :delete_all)
      add :user_id, references(:users, type: :id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:notes, [:paper_id])
    create_if_not_exists index(:notes, [:user_id])
  end
end
