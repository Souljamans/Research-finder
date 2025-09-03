defmodule ResearchPlatform.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    # Users table already exists from Node.js version
    # Modify existing table to add Phoenix auth fields if needed
    alter table(:users) do
      add_if_not_exists :email, :citext
      add_if_not_exists :hashed_password, :string  
      add_if_not_exists :confirmed_at, :utc_datetime
      add_if_not_exists :inserted_at, :utc_datetime
      add_if_not_exists :updated_at, :utc_datetime
    end

    create_if_not_exists unique_index(:users, [:email])

    create_if_not_exists table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create_if_not_exists index(:users_tokens, [:user_id])
    create_if_not_exists unique_index(:users_tokens, [:context, :token])
  end
end
