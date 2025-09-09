defmodule ResearchPlatformWeb.PaperLive.Index do
  use ResearchPlatformWeb, :live_view

  alias ResearchPlatform.Papers

  on_mount {ResearchPlatformWeb.UserAuth, :default}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.minimal flash={@flash} current_scope={@current_scope}>
      <!-- Navigation Row -->
      <div class="mb-6 flex justify-between items-center gap-4">
        <.link navigate={~p"/"} class="inline-flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 flex-shrink-0">
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Dashboard
        </.link>
        
        <!-- Search Bar -->
        <div class="flex-1 max-w-md">
          <form phx-change="search" phx-submit="search" class="relative">
            <.icon name="hero-magnifying-glass" class="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              type="text"
              name="query"
              value={@search_query}
              placeholder="Search papers by title, authors, or keywords..."
              class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm"
              phx-debounce="300"
            />
          </form>
        </div>
        
        <.button variant="primary" navigate={~p"/papers/new"} class="flex items-center gap-2 flex-shrink-0">
          <.icon name="hero-plus" class="w-4 h-4" /> New Paper
        </.button>
      </div>

      <div class="bg-white rounded-lg shadow-sm">
        <div class="px-6 py-4 border-b border-gray-200">
          <h1 class="text-2xl font-bold text-gray-900">Research Papers</h1>
        </div>

        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="bg-gray-50 border-b border-gray-200">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Title</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Authors</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Abstract</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Keywords</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for {id, paper} <- @streams.papers do %>
                <tr 
                  id={id} 
                  class="hover:bg-gray-50 cursor-pointer transition-colors duration-150"
                  phx-click={JS.navigate(~p"/papers/#{paper}")}
                >
                  <td class="px-6 py-4">
                    <div class="text-sm font-medium text-gray-900 truncate max-w-xs" title={paper.title}>
                      {String.slice(paper.title || "", 0, 60)}{if String.length(paper.title || "") > 60, do: "...", else: ""}
                    </div>
                  </td>
                  <td class="px-6 py-4">
                    <div class="text-sm text-gray-600 truncate max-w-xs" title={format_authors(paper.authors)}>
                      {truncate_text(format_authors(paper.authors), 40)}
                    </div>
                  </td>
                  <td class="px-6 py-4">
                    <div class="text-sm text-gray-600 max-w-md" title={paper.abstract}>
                      {truncate_text(paper.abstract || "", 120)}
                    </div>
                  </td>
                  <td class="px-6 py-4">
                    <div class="text-sm text-gray-600 truncate max-w-xs" title={format_keywords(paper.keywords)}>
                      {truncate_text(format_keywords(paper.keywords), 30)}
                    </div>
                  </td>
                  <td class="px-6 py-4">
                    <div class="flex items-center space-x-3" onclick="event.stopPropagation();">
                      <%= if paper.file_path do %>
                        <.link href={"/api/papers/#{paper.id}/view"} target="_blank" class="text-blue-600 hover:text-blue-800 text-sm font-medium">
                          View
                        </.link>
                      <% end %>
                      <.link navigate={~p"/papers/#{paper}/edit"} class="text-indigo-600 hover:text-indigo-800 text-sm font-medium">
                        Edit
                      </.link>
                      <.link
                        phx-click={JS.push("delete", value: %{id: paper.id}) |> hide("##{id}")}
                        data-confirm="Are you sure?"
                        class="text-red-600 hover:text-red-800 text-sm font-medium"
                      >
                        Delete
                      </.link>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.minimal>
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
     |> assign(:search_query, "")
     |> stream(:papers, list_papers(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> stream(:papers, search_papers(socket.assigns.current_scope, query), reset: true)}
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

  defp search_papers(current_scope, query) when query == "" or is_nil(query) do
    Papers.list_papers(current_scope)
  end

  defp search_papers(current_scope, query) do
    Papers.list_papers(current_scope)
    |> Enum.filter(fn paper ->
      query_lower = String.downcase(query)
      
      title_match = paper.title && String.contains?(String.downcase(paper.title), query_lower)
      authors_match = search_in_field(paper.authors, query_lower)
      abstract_match = paper.abstract && String.contains?(String.downcase(paper.abstract), query_lower)
      keywords_match = search_in_field(paper.keywords, query_lower)
      
      title_match || authors_match || abstract_match || keywords_match
    end)
  end

  defp search_in_field(field, query) when is_list(field) do
    field
    |> Enum.any?(fn item -> 
      item && String.contains?(String.downcase(to_string(item)), query)
    end)
  end

  defp search_in_field(field, query) when is_binary(field) do
    String.contains?(String.downcase(field), query)
  end

  defp search_in_field(_, _), do: false

  defp format_authors(authors) when is_list(authors), do: Enum.join(authors, ", ")
  defp format_authors(authors) when is_binary(authors), do: authors
  defp format_authors(_), do: ""

  defp format_keywords(keywords) when is_list(keywords), do: Enum.join(keywords, ", ")
  defp format_keywords(keywords) when is_binary(keywords), do: keywords  
  defp format_keywords(_), do: ""

  defp truncate_text(text, max_length) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "..."
    else
      text
    end
  end
end
