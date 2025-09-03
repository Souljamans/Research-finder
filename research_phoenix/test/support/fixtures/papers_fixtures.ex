defmodule ResearchPlatform.PapersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ResearchPlatform.Papers` context.
  """

  @doc """
  Generate a paper.
  """
  def paper_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        abstract: "some abstract",
        authors: ["option1", "option2"],
        file_path: "some file_path",
        file_size: 42,
        keywords: ["option1", "option2"],
        metadata: %{},
        title: "some title"
      })

    {:ok, paper} = ResearchPlatform.Papers.create_paper(scope, attrs)
    paper
  end

  @doc """
  Generate a note.
  """
  def note_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        content: "some content"
      })

    {:ok, note} = ResearchPlatform.Papers.create_note(scope, attrs)
    note
  end
end
