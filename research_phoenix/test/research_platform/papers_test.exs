defmodule ResearchPlatform.PapersTest do
  use ResearchPlatform.DataCase

  alias ResearchPlatform.Papers

  describe "papers" do
    alias ResearchPlatform.Papers.Paper

    import ResearchPlatform.AccountsFixtures, only: [user_scope_fixture: 0]
    import ResearchPlatform.PapersFixtures

    @invalid_attrs %{title: nil, keywords: nil, metadata: nil, abstract: nil, authors: nil, file_path: nil, file_size: nil}

    test "list_papers/1 returns all scoped papers" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      paper = paper_fixture(scope)
      other_paper = paper_fixture(other_scope)
      assert Papers.list_papers(scope) == [paper]
      assert Papers.list_papers(other_scope) == [other_paper]
    end

    test "get_paper!/2 returns the paper with given id" do
      scope = user_scope_fixture()
      paper = paper_fixture(scope)
      other_scope = user_scope_fixture()
      assert Papers.get_paper!(scope, paper.id) == paper
      assert_raise Ecto.NoResultsError, fn -> Papers.get_paper!(other_scope, paper.id) end
    end

    test "create_paper/2 with valid data creates a paper" do
      valid_attrs = %{title: "some title", keywords: ["option1", "option2"], metadata: %{}, abstract: "some abstract", authors: ["option1", "option2"], file_path: "some file_path", file_size: 42}
      scope = user_scope_fixture()

      assert {:ok, %Paper{} = paper} = Papers.create_paper(scope, valid_attrs)
      assert paper.title == "some title"
      assert paper.keywords == ["option1", "option2"]
      assert paper.metadata == %{}
      assert paper.abstract == "some abstract"
      assert paper.authors == ["option1", "option2"]
      assert paper.file_path == "some file_path"
      assert paper.file_size == 42
      assert paper.user_id == scope.user.id
    end

    test "create_paper/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Papers.create_paper(scope, @invalid_attrs)
    end

    test "update_paper/3 with valid data updates the paper" do
      scope = user_scope_fixture()
      paper = paper_fixture(scope)
      update_attrs = %{title: "some updated title", keywords: ["option1"], metadata: %{}, abstract: "some updated abstract", authors: ["option1"], file_path: "some updated file_path", file_size: 43}

      assert {:ok, %Paper{} = paper} = Papers.update_paper(scope, paper, update_attrs)
      assert paper.title == "some updated title"
      assert paper.keywords == ["option1"]
      assert paper.metadata == %{}
      assert paper.abstract == "some updated abstract"
      assert paper.authors == ["option1"]
      assert paper.file_path == "some updated file_path"
      assert paper.file_size == 43
    end

    test "update_paper/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      paper = paper_fixture(scope)

      assert_raise MatchError, fn ->
        Papers.update_paper(other_scope, paper, %{})
      end
    end

    test "update_paper/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      paper = paper_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Papers.update_paper(scope, paper, @invalid_attrs)
      assert paper == Papers.get_paper!(scope, paper.id)
    end

    test "delete_paper/2 deletes the paper" do
      scope = user_scope_fixture()
      paper = paper_fixture(scope)
      assert {:ok, %Paper{}} = Papers.delete_paper(scope, paper)
      assert_raise Ecto.NoResultsError, fn -> Papers.get_paper!(scope, paper.id) end
    end

    test "delete_paper/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      paper = paper_fixture(scope)
      assert_raise MatchError, fn -> Papers.delete_paper(other_scope, paper) end
    end

    test "change_paper/2 returns a paper changeset" do
      scope = user_scope_fixture()
      paper = paper_fixture(scope)
      assert %Ecto.Changeset{} = Papers.change_paper(scope, paper)
    end
  end

  describe "notes" do
    alias ResearchPlatform.Papers.Note

    import ResearchPlatform.AccountsFixtures, only: [user_scope_fixture: 0]
    import ResearchPlatform.PapersFixtures

    @invalid_attrs %{content: nil}

    test "list_notes/1 returns all scoped notes" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      note = note_fixture(scope)
      other_note = note_fixture(other_scope)
      assert Papers.list_notes(scope) == [note]
      assert Papers.list_notes(other_scope) == [other_note]
    end

    test "get_note!/2 returns the note with given id" do
      scope = user_scope_fixture()
      note = note_fixture(scope)
      other_scope = user_scope_fixture()
      assert Papers.get_note!(scope, note.id) == note
      assert_raise Ecto.NoResultsError, fn -> Papers.get_note!(other_scope, note.id) end
    end

    test "create_note/2 with valid data creates a note" do
      valid_attrs = %{content: "some content"}
      scope = user_scope_fixture()

      assert {:ok, %Note{} = note} = Papers.create_note(scope, valid_attrs)
      assert note.content == "some content"
      assert note.user_id == scope.user.id
    end

    test "create_note/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Papers.create_note(scope, @invalid_attrs)
    end

    test "update_note/3 with valid data updates the note" do
      scope = user_scope_fixture()
      note = note_fixture(scope)
      update_attrs = %{content: "some updated content"}

      assert {:ok, %Note{} = note} = Papers.update_note(scope, note, update_attrs)
      assert note.content == "some updated content"
    end

    test "update_note/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      note = note_fixture(scope)

      assert_raise MatchError, fn ->
        Papers.update_note(other_scope, note, %{})
      end
    end

    test "update_note/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      note = note_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Papers.update_note(scope, note, @invalid_attrs)
      assert note == Papers.get_note!(scope, note.id)
    end

    test "delete_note/2 deletes the note" do
      scope = user_scope_fixture()
      note = note_fixture(scope)
      assert {:ok, %Note{}} = Papers.delete_note(scope, note)
      assert_raise Ecto.NoResultsError, fn -> Papers.get_note!(scope, note.id) end
    end

    test "delete_note/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      note = note_fixture(scope)
      assert_raise MatchError, fn -> Papers.delete_note(other_scope, note) end
    end

    test "change_note/2 returns a note changeset" do
      scope = user_scope_fixture()
      note = note_fixture(scope)
      assert %Ecto.Changeset{} = Papers.change_note(scope, note)
    end
  end
end
