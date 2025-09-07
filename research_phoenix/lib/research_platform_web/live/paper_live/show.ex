defmodule ResearchPlatformWeb.PaperLive.Show do
  use ResearchPlatformWeb, :live_view

  alias ResearchPlatform.Papers

  on_mount {ResearchPlatformWeb.UserAuth, :default}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Paper {@paper.id}
        <:subtitle>This is a paper record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/papers"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <%= if @paper.file_path do %>
            <.button>
              <.link href={"/api/papers/#{@paper.id}/view"} target="_blank" class="flex items-center text-inherit no-underline">
                <.icon name="hero-document" class="mr-1" /> View PDF
              </.link>
            </.button>
          <% end %>
          <.button variant="primary" navigate={~p"/papers/#{@paper}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit paper
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Title">{@paper.title}</:item>
        <:item title="Authors">{@paper.authors}</:item>
        <:item title="Abstract">{@paper.abstract}</:item>
        <:item title="Keywords">{@paper.keywords}</:item>
        <:item title="File path">{@paper.file_path}</:item>
        <:item title="File size">{@paper.file_size}</:item>
        <:item title="Metadata">{inspect(@paper.metadata)}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Papers.subscribe_papers(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Paper")
     |> assign(:paper, Papers.get_paper!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_info(
        {:updated, %ResearchPlatform.Papers.Paper{id: id} = paper},
        %{assigns: %{paper: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :paper, paper)}
  end

  def handle_info(
        {:deleted, %ResearchPlatform.Papers.Paper{id: id}},
        %{assigns: %{paper: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current paper was deleted.")
     |> push_navigate(to: ~p"/papers")}
  end

  def handle_info({type, %ResearchPlatform.Papers.Paper{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
