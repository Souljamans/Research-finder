defmodule ResearchPlatform.Papers.Paper do
  use Ecto.Schema
  import Ecto.Changeset

  schema "papers" do
    field :title, :string
    field :authors, {:array, :string}
    field :abstract, :string
    field :keywords, {:array, :string}
    field :file_path, :string
    field :file_size, :integer
    field :metadata, :map
    field :upload_date, :utc_datetime
    field :created_at, :utc_datetime
    field :updated_at, :utc_datetime
    field :inserted_at, :utc_datetime
    belongs_to :user, ResearchPlatform.Accounts.User
    has_many :notes, ResearchPlatform.Papers.Note
  end

  @doc false
  def changeset(paper, attrs, user_scope) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    
    changeset = paper
    |> cast(attrs, [:title, :authors, :abstract, :keywords, :file_path, :file_size, :metadata])
    |> normalize_authors()
    |> normalize_keywords()
    |> put_change(:user_id, user_scope.user.id)
    |> put_change(:updated_at, now)
    |> maybe_put_timestamps(paper.id)

    # Only apply strict validation on submit, not during live validation
    case changeset.action do
      action when action in [:insert, :update] ->
        changeset
        |> validate_required([:title])
        |> validate_length(:title, min: 1)
      _ ->
        changeset
    end
  end

  @doc false
  def form_changeset(paper, attrs, user_scope) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    
    changeset = paper
    |> cast(attrs, [:title, :authors, :abstract, :keywords, :file_path, :file_size, :metadata])
    # Don't normalize for form display - keep strings as strings
    |> put_change(:user_id, user_scope.user.id)
    |> put_change(:updated_at, now)
    |> maybe_put_timestamps(paper.id)

    # Only apply strict validation on submit, not during live validation
    case changeset.action do
      action when action in [:insert, :update] ->
        changeset
        |> validate_required([:title])
        |> validate_length(:title, min: 1)
      _ ->
        changeset
    end
  end

  defp normalize_authors(changeset) do
    case get_change(changeset, :authors) do
      nil -> 
        put_change(changeset, :authors, [])
      authors when is_binary(authors) ->
        # Convert string to array, splitting by newlines and filtering empty lines
        author_list = 
          authors
          |> String.split(["\n", "\r\n"], trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
        
        put_change(changeset, :authors, author_list)
      authors when is_list(authors) -> 
        changeset
    end
  end

  defp normalize_keywords(changeset) do
    case get_change(changeset, :keywords) do
      nil -> 
        put_change(changeset, :keywords, [])
      keywords when is_binary(keywords) ->
        # Convert string to array, splitting by commas and filtering empty entries
        keyword_list = 
          keywords
          |> String.split(",", trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
        
        put_change(changeset, :keywords, keyword_list)
      keywords when is_list(keywords) -> 
        changeset
    end
  end

  defp maybe_put_timestamps(changeset, nil) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    changeset
    |> put_change(:created_at, now)
    |> put_change(:inserted_at, now)
    |> put_change(:upload_date, now)
  end

  defp maybe_put_timestamps(changeset, _existing_id), do: changeset
end
