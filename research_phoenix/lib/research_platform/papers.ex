defmodule ResearchPlatform.Papers do
  @moduledoc """
  The Papers context.
  """

  import Ecto.Query, warn: false
  alias ResearchPlatform.Repo

  alias ResearchPlatform.Papers.Paper
  alias ResearchPlatform.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any paper changes.

  The broadcasted messages match the pattern:

    * {:created, %Paper{}}
    * {:updated, %Paper{}}
    * {:deleted, %Paper{}}

  """
  def subscribe_papers(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(ResearchPlatform.PubSub, "user:#{key}:papers")
  end

  defp broadcast_paper(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(ResearchPlatform.PubSub, "user:#{key}:papers", message)
  end

  @doc """
  Returns the list of papers.

  ## Examples

      iex> list_papers(scope)
      [%Paper{}, ...]

  """
  def list_papers(%Scope{} = scope) do
    Repo.all_by(Paper, user_id: scope.user.id)
  end

  @doc """
  Searches papers using full-text search.
  
  ## Examples
  
      iex> search_papers(scope, "machine learning")
      [%Paper{}, ...]
      
      iex> search_papers(scope, "author:smith")
      [%Paper{}, ...]
  """
  def search_papers(%Scope{} = scope, query) when is_binary(query) and query != "" do
    # Parse search query to extract filters
    {search_term, filters} = parse_search_query(query)
    
    base_query = from(p in Paper, where: p.user_id == ^scope.user.id)
    
    query_with_search = 
      if search_term != "" do
        from p in base_query,
          where: fragment("? @@ plainto_tsquery('english', ?)", p.search_vector, ^search_term),
          order_by: [desc: fragment("ts_rank(?, plainto_tsquery('english', ?))", p.search_vector, ^search_term)]
      else
        base_query
      end
    
    final_query = apply_search_filters(query_with_search, filters)
    
    Repo.all(final_query)
  end

  def search_papers(%Scope{} = scope, _query) do
    list_papers(scope)
  end

  @doc """
  Gets search suggestions based on partial input.
  """
  def get_search_suggestions(%Scope{} = scope, query) when is_binary(query) and query != "" do
    # Get all papers for this user and extract suggestions in Elixir
    papers = from(p in Paper,
      where: p.user_id == ^scope.user.id,
      select: %{title: p.title, authors: p.authors, keywords: p.keywords}
    ) |> Repo.all()
    
    query_lower = String.downcase(query)
    
    # Extract all unique titles, authors, and keywords
    titles = papers |> Enum.map(& &1.title) |> Enum.filter(& &1) |> Enum.uniq()
    authors = papers |> Enum.flat_map(& &1.authors || []) |> Enum.uniq()
    keywords = papers |> Enum.flat_map(& &1.keywords || []) |> Enum.uniq()
    
    title_matches = filter_suggestions(titles, query_lower)
    author_matches = filter_suggestions(authors, query_lower)
    keyword_matches = filter_suggestions(keywords, query_lower)
    
    (title_matches ++ author_matches ++ keyword_matches)
    |> Enum.uniq()
    |> Enum.take(10)
  end

  def get_search_suggestions(_scope, _query), do: []

  defp parse_search_query(query) do
    # Simple parser for filters like "author:smith" or "keyword:machine"
    filters = Regex.scan(~r/(\w+):(\w+)/, query)
    |> Enum.map(fn [_full, field, value] -> {field, value} end)
    
    search_term = Regex.replace(~r/\w+:\w+/, query, "")
    |> String.trim()
    
    {search_term, filters}
  end

  defp apply_search_filters(query, []), do: query
  defp apply_search_filters(query, [{field, value} | rest]) do
    filtered_query = case field do
      "author" ->
        from p in query,
          where: fragment("EXISTS (SELECT 1 FROM unnest(?) AS author WHERE LOWER(author) LIKE ?)", 
                         p.authors, ^"%#{String.downcase(value)}%")
      "keyword" ->
        from p in query,
          where: fragment("EXISTS (SELECT 1 FROM unnest(?) AS keyword WHERE LOWER(keyword) LIKE ?)", 
                         p.keywords, ^"%#{String.downcase(value)}%")
      "title" ->
        from p in query, where: ilike(p.title, ^"%#{value}%")
      "date" ->
        cutoff_date = get_date_cutoff(value)
        if cutoff_date do
          from p in query, where: p.created_at >= ^cutoff_date
        else
          query
        end
      _ -> query
    end
    
    apply_search_filters(filtered_query, rest)
  end

  defp get_date_cutoff("week") do
    DateTime.utc_now() |> DateTime.add(-7, :day)
  end
  defp get_date_cutoff("month") do
    DateTime.utc_now() |> DateTime.add(-30, :day) 
  end
  defp get_date_cutoff("year") do
    DateTime.utc_now() |> DateTime.add(-365, :day)
  end
  defp get_date_cutoff(_), do: nil

  defp filter_suggestions(items, query) do
    items
    |> Enum.filter(fn item -> 
      item && String.contains?(String.downcase(item), query)
    end)
    |> Enum.take(3)
  end

  @doc """
  Gets a single paper.

  Raises `Ecto.NoResultsError` if the Paper does not exist.

  ## Examples

      iex> get_paper!(scope, 123)
      %Paper{}

      iex> get_paper!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_paper!(%Scope{} = scope, id) do
    Repo.get_by!(Paper, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a paper.

  ## Examples

      iex> create_paper(scope, %{field: value})
      {:ok, %Paper{}}

      iex> create_paper(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_paper(%Scope{} = scope, attrs) do
    with {:ok, paper = %Paper{}} <-
           %Paper{}
           |> Paper.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_paper(scope, {:created, paper})
      {:ok, paper}
    end
  end

  @doc """
  Updates a paper.

  ## Examples

      iex> update_paper(scope, paper, %{field: new_value})
      {:ok, %Paper{}}

      iex> update_paper(scope, paper, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_paper(%Scope{} = scope, %Paper{} = paper, attrs) do
    true = paper.user_id == scope.user.id

    with {:ok, paper = %Paper{}} <-
           paper
           |> Paper.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_paper(scope, {:updated, paper})
      {:ok, paper}
    end
  end

  @doc """
  Deletes a paper.

  ## Examples

      iex> delete_paper(scope, paper)
      {:ok, %Paper{}}

      iex> delete_paper(scope, paper)
      {:error, %Ecto.Changeset{}}

  """
  def delete_paper(%Scope{} = scope, %Paper{} = paper) do
    true = paper.user_id == scope.user.id

    with {:ok, paper = %Paper{}} <-
           Repo.delete(paper) do
      broadcast_paper(scope, {:deleted, paper})
      {:ok, paper}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking paper changes.

  ## Examples

      iex> change_paper(scope, paper)
      %Ecto.Changeset{data: %Paper{}}

  """
  def change_paper(%Scope{} = scope, %Paper{} = paper, attrs \\ %{}) do
    true = paper.user_id == scope.user.id

    # Convert paper to form representation
    form_paper = paper_to_form(paper)
    
    Paper.Form.changeset(form_paper, attrs, scope)
  end

  defp convert_arrays_to_strings_for_form(attrs) do
    attrs
    |> convert_array_field_to_string(:authors, "\n")
    |> convert_array_field_to_string(:keywords, ", ")
  end

  defp convert_array_field_to_string(attrs, field, separator) do
    case Map.get(attrs, field) do
      list when is_list(list) -> Map.put(attrs, field, Enum.join(list, separator))
      _ -> attrs
    end
  end

  defp prepare_paper_for_form(paper) do
    %{paper |
      authors: convert_list_to_string(paper.authors, "\n"),
      keywords: convert_list_to_string(paper.keywords, ", ")
    }
  end

  defp convert_list_to_string(nil, _separator), do: ""
  defp convert_list_to_string([], _separator), do: ""
  defp convert_list_to_string(list, separator) when is_list(list) do
    Enum.join(list, separator)
  end
  defp convert_list_to_string(value, _separator) when is_binary(value), do: value
  defp convert_list_to_string(_value, _separator), do: ""

  defp paper_to_form(%Paper{} = paper) do
    %Paper.Form{
      id: paper.id,
      title: paper.title || "",
      authors: convert_list_to_string(paper.authors, "\n"),
      abstract: paper.abstract || "",
      keywords: convert_list_to_string(paper.keywords, ", "),
      file_path: paper.file_path,
      file_size: paper.file_size,
      metadata: paper.metadata,
      upload_date: paper.upload_date,
      created_at: paper.created_at,
      updated_at: paper.updated_at,
      inserted_at: paper.inserted_at,
      user_id: paper.user_id
    }
  end

  alias ResearchPlatform.Papers.Note
  alias ResearchPlatform.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any note changes.

  The broadcasted messages match the pattern:

    * {:created, %Note{}}
    * {:updated, %Note{}}
    * {:deleted, %Note{}}

  """
  def subscribe_notes(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(ResearchPlatform.PubSub, "user:#{key}:notes")
  end

  defp broadcast_note(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(ResearchPlatform.PubSub, "user:#{key}:notes", message)
  end

  @doc """
  Returns the list of notes.

  ## Examples

      iex> list_notes(scope)
      [%Note{}, ...]

  """
  def list_notes(%Scope{} = scope) do
    Repo.all_by(Note, user_id: scope.user.id)
  end

  @doc """
  Gets a single note.

  Raises `Ecto.NoResultsError` if the Note does not exist.

  ## Examples

      iex> get_note!(scope, 123)
      %Note{}

      iex> get_note!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_note!(%Scope{} = scope, id) do
    Repo.get_by!(Note, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a note.

  ## Examples

      iex> create_note(scope, %{field: value})
      {:ok, %Note{}}

      iex> create_note(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_note(%Scope{} = scope, attrs) do
    with {:ok, note = %Note{}} <-
           %Note{}
           |> Note.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_note(scope, {:created, note})
      {:ok, note}
    end
  end

  @doc """
  Updates a note.

  ## Examples

      iex> update_note(scope, note, %{field: new_value})
      {:ok, %Note{}}

      iex> update_note(scope, note, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_note(%Scope{} = scope, %Note{} = note, attrs) do
    true = note.user_id == scope.user.id

    with {:ok, note = %Note{}} <-
           note
           |> Note.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_note(scope, {:updated, note})
      {:ok, note}
    end
  end

  @doc """
  Deletes a note.

  ## Examples

      iex> delete_note(scope, note)
      {:ok, %Note{}}

      iex> delete_note(scope, note)
      {:error, %Ecto.Changeset{}}

  """
  def delete_note(%Scope{} = scope, %Note{} = note) do
    true = note.user_id == scope.user.id

    with {:ok, note = %Note{}} <-
           Repo.delete(note) do
      broadcast_note(scope, {:deleted, note})
      {:ok, note}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking note changes.

  ## Examples

      iex> change_note(scope, note)
      %Ecto.Changeset{data: %Note{}}

  """
  def change_note(%Scope{} = scope, %Note{} = note, attrs \\ %{}) do
    true = note.user_id == scope.user.id

    Note.changeset(note, attrs, scope)
  end
end
