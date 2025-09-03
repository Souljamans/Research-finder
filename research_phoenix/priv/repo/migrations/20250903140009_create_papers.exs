defmodule ResearchPlatform.Repo.Migrations.CreatePapers do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:papers) do
      add :title, :string
      add :authors, {:array, :string}
      add :abstract, :text
      add :keywords, {:array, :string}
      add :file_path, :string
      add :file_size, :integer
      add :metadata, :map
      add :user_id, references(:users, type: :id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:papers, [:user_id])
  end
end
