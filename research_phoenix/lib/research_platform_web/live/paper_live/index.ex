defmodule ResearchPlatformWeb.PaperLive.Index do
  use ResearchPlatformWeb, :live_view

  alias ResearchPlatform.Papers

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Papers
        <:actions>
          <.button variant="primary" navigate={~p"/papers/new"}>
            <.icon name="hero-plus" /> New Paper
          </.button>
        </:actions>
      </.header>

      <.table
        id="papers"
        rows={@streams.papers}
        row_click={fn {_id, paper} -> JS.navigate(~p"/papers/#{paper}") end}
      >
        <:col :let={{_id, paper}} label="Title">{paper.title}</:col>
        <:col :let={{_id, paper}} label="Authors">{paper.authors}</:col>
        <:col :let={{_id, paper}} label="Abstract">{paper.abstract}</:col>
        <:col :let={{_id, paper}} label="Keywords">{paper.keywords}</:col>
        <:col :let={{_id, paper}} label="File path">{paper.file_path}</:col>
        <:col :let={{_id, paper}} label="File size">{paper.file_size}</:col>
        <:col :let={{_id, paper}} label="Metadata">{paper.metadata}</:col>
        <:action :let={{_id, paper}}>
          <div class="sr-only">
            <.link navigate={~p"/papers/#{paper}"}>Show</.link>
          </div>
          <.link navigate={~p"/papers/#{paper}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, paper}}>
          <.link
            phx-click={JS.push("delete", value: %{id: paper.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Papers.subscribe_papers(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Papers")
     |> stream(:papers, list_papers(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    paper = Papers.get_paper!(socket.assigns.current_scope, id)
    {:ok, _} = Papers.delete_paper(socket.assigns.current_scope, paper)

    {:noreply, stream_delete(socket, :papers, paper)}
  end

  @impl true
  def handle_info({type, %ResearchPlatform.Papers.Paper{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, stream(socket, :papers, list_papers(socket.assigns.current_scope), reset: true)}
  end

  defp list_papers(current_scope) do
    Papers.list_papers(current_scope)
  end
end
