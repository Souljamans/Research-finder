defmodule ResearchPlatform.Papers.Note do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notes" do
    field :content, :string
    field :page, :integer, default: 1
    field :x_position, :float
    field :y_position, :float
    field :note_type, :string, default: "text"
    belongs_to :paper, ResearchPlatform.Papers.Paper
    belongs_to :user, ResearchPlatform.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(note, attrs, user_scope) do
    note
    |> cast(attrs, [:content, :page, :x_position, :y_position, :note_type, :paper_id])
    |> validate_required([:content, :paper_id])
    |> validate_number(:page, greater_than: 0)
    |> validate_number(:x_position, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:y_position, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_inclusion(:note_type, ["text", "highlight", "annotation"])
    |> put_change(:user_id, user_scope.user.id)
  end
end
