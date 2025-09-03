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

    Paper.changeset(paper, attrs, scope)
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
