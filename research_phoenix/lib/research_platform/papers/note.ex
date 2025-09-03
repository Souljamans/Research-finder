defmodule ResearchPlatform.Papers.Note do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notes" do
    field :content, :string
    belongs_to :paper, ResearchPlatform.Papers.Paper
    belongs_to :user, ResearchPlatform.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(note, attrs, user_scope) do
    note
    |> cast(attrs, [:content])
    |> validate_required([:content])
    |> put_change(:user_id, user_scope.user.id)
  end
end
