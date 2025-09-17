defmodule ResearchPlatform.Repo.Migrations.AddFulltextSearchToPapers do
  use Ecto.Migration

  def up do
    # Add a tsvector column for full-text search
    alter table(:papers) do
      add :search_vector, :tsvector
    end

    # Create a GIN index on the tsvector column for fast full-text search
    create index(:papers, [:search_vector], using: :gin)

    # Create a function to update the search vector
    execute """
    CREATE OR REPLACE FUNCTION papers_search_vector_update() RETURNS trigger AS $$
    BEGIN
      NEW.search_vector :=
        COALESCE(to_tsvector('english', NEW.title), '') ||
        COALESCE(to_tsvector('english', array_to_string(NEW.authors, ' ')), '') ||
        COALESCE(to_tsvector('english', NEW.abstract), '') ||
        COALESCE(to_tsvector('english', array_to_string(NEW.keywords, ' ')), '');
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Create a trigger to automatically update search_vector on insert/update
    execute """
    CREATE TRIGGER papers_search_vector_trigger
    BEFORE INSERT OR UPDATE
    ON papers
    FOR EACH ROW
    EXECUTE FUNCTION papers_search_vector_update();
    """

    # Update existing records to populate search_vector
    execute """
    UPDATE papers SET search_vector = 
      COALESCE(to_tsvector('english', title), '') ||
      COALESCE(to_tsvector('english', array_to_string(authors, ' ')), '') ||
      COALESCE(to_tsvector('english', abstract), '') ||
      COALESCE(to_tsvector('english', array_to_string(keywords, ' ')), '');
    """
  end

  def down do
    # Drop the trigger and function
    execute "DROP TRIGGER IF EXISTS papers_search_vector_trigger ON papers;"
    execute "DROP FUNCTION IF EXISTS papers_search_vector_update();"
    
    # Remove the search_vector column
    alter table(:papers) do
      remove :search_vector
    end
  end
end