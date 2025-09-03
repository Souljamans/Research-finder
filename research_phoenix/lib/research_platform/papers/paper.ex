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
    belongs_to :user, ResearchPlatform.Accounts.User
    has_many :notes, ResearchPlatform.Papers.Note

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(paper, attrs, user_scope) do
    paper
    |> cast(attrs, [:title, :authors, :abstract, :keywords, :file_path, :file_size, :metadata])
    |> validate_required([:title, :authors, :abstract, :keywords, :file_path, :file_size])
    |> put_change(:user_id, user_scope.user.id)
  end
end
