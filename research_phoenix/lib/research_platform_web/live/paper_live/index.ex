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
        <div class="flex-1 max-w-2xl">
          <form phx-change="search" phx-submit="search" class="space-y-3">
            <div class="relative">
              <.icon name="hero-magnifying-glass" class="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search papers... Try: 'machine learning', 'author:smith', 'keyword:AI'"
                class="w-full pl-10 pr-12 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm"
                phx-debounce="300"
                phx-focus="show_suggestions"
                phx-blur="hide_suggestions"
                autocomplete="off"
              />
              <button
                type="button"
                phx-click="toggle_filters"
                class="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
              >
                <.icon name="hero-adjustments-horizontal" class="w-4 h-4" />
              </button>
              
              <%= if @show_suggestions and length(@search_suggestions) > 0 do %>
                <div class="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded-lg shadow-lg z-50 max-h-60 overflow-y-auto">
                  <%= for suggestion <- @search_suggestions do %>
                    <button
                      type="button"
                      phx-click="select_suggestion"
                      phx-value-suggestion={suggestion}
                      class="w-full text-left px-4 py-2 hover:bg-gray-100 text-sm border-b border-gray-100 last:border-b-0 text-black"
                    >
                      <%= suggestion %>
                    </button>
                  <% end %>
                </div>
              <% end %>
            </div>
            
            <%= if @show_filters do %>
              <div class="bg-gray-50 p-4 rounded-lg border space-y-3">
                <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Author</label>
                    <input
                      type="text"
                      name="author_filter"
                      value={@filters.author}
                      placeholder="Author name..."
                      class="w-full px-3 py-1.5 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
                      phx-debounce="300"
                    />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Keyword</label>
                    <input
                      type="text"
                      name="keyword_filter"
                      value={@filters.keyword}
                      placeholder="Keyword..."
                      class="w-full px-3 py-1.5 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
                      phx-debounce="300"
                    />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Date Range</label>
                    <select
                      name="date_range"
                      value={@filters.date_range}
                      class="w-full px-3 py-1.5 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
                    >
                      <option value="">All time</option>
                      <option value="week">Last week</option>
                      <option value="month">Last month</option>
                      <option value="year">Last year</option>
                    </select>
                  </div>
                </div>
                <div class="flex justify-end space-x-2">
                  <button
                    type="button"
                    phx-click="clear_filters"
                    class="px-3 py-1.5 text-xs text-gray-600 hover:text-gray-800"
                  >
                    Clear filters
                  </button>
                </div>
              </div>
            <% end %>
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
                    <div class="flex items-center space-x-3">
                      <%= if paper.file_path do %>
                        <.link href={"/api/papers/#{paper.id}/view"} target="_blank" class="text-blue-600 hover:text-blue-800 text-sm font-medium" onclick="event.stopPropagation();">
                          View
                        </.link>
                      <% end %>
                      <.link navigate={~p"/papers/#{paper}/edit"} class="text-indigo-600 hover:text-indigo-800 text-sm font-medium" onclick="event.stopPropagation();">
                        Edit
                      </.link>
                      <button
                        phx-click="delete"
                        phx-value-id={paper.id}
                        data-confirm="Are you sure?"
                        class="text-red-600 hover:text-red-800 text-sm font-medium bg-transparent border-none cursor-pointer"
                      >
                        Delete
                      </button>
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
     |> assign(:show_filters, false)
     |> assign(:show_suggestions, false)
     |> assign(:search_suggestions, [])
     |> assign(:filters, %{author: "", keyword: "", date_range: ""})
     |> stream(:papers, list_papers(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("search", params, socket) do
    query = Map.get(params, "query", socket.assigns.search_query)
    
    filters = %{
      author: Map.get(params, "author_filter", socket.assigns.filters.author),
      keyword: Map.get(params, "keyword_filter", socket.assigns.filters.keyword),
      date_range: Map.get(params, "date_range", socket.assigns.filters.date_range)
    }
    
    # Build combined query with filters
    combined_query = build_combined_query(query, filters)
    
    # Get suggestions if query is not empty
    suggestions = if String.trim(query) != "" and String.length(String.trim(query)) >= 2 do
      Papers.get_search_suggestions(socket.assigns.current_scope, query)
    else
      []
    end
    
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:filters, filters)
     |> assign(:search_suggestions, suggestions)
     |> stream(:papers, search_papers(socket.assigns.current_scope, combined_query), reset: true)}
  end

  @impl true
  def handle_event("toggle_filters", _params, socket) do
    {:noreply, assign(socket, :show_filters, !socket.assigns.show_filters)}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:filters, %{author: "", keyword: "", date_range: ""})
     |> assign(:search_query, "")
     |> assign(:search_suggestions, [])
     |> assign(:show_suggestions, false)
     |> stream(:papers, list_papers(socket.assigns.current_scope), reset: true)}
  end

  @impl true
  def handle_event("show_suggestions", _params, socket) do
    {:noreply, assign(socket, :show_suggestions, true)}
  end

  @impl true
  def handle_event("hide_suggestions", _params, socket) do
    # Add a small delay before hiding to allow clicking on suggestions
    Process.send_after(self(), :hide_suggestions_delayed, 100)
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_suggestion", %{"suggestion" => suggestion}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, suggestion)
     |> assign(:show_suggestions, false)
     |> stream(:papers, search_papers(socket.assigns.current_scope, suggestion), reset: true)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    # Convert string ID to integer if needed
    id = if is_binary(id), do: String.to_integer(id), else: id
    paper = Papers.get_paper!(socket.assigns.current_scope, id)
    {:ok, _} = Papers.delete_paper(socket.assigns.current_scope, paper)

    {:noreply, stream_delete(socket, :papers, paper)}
  end

  @impl true
  def handle_info({type, %ResearchPlatform.Papers.Paper{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, stream(socket, :papers, list_papers(socket.assigns.current_scope), reset: true)}
  end

  @impl true
  def handle_info(:hide_suggestions_delayed, socket) do
    {:noreply, assign(socket, :show_suggestions, false)}
  end

  defp list_papers(current_scope) do
    Papers.list_papers(current_scope)
  end

  defp search_papers(current_scope, query) when query == "" or is_nil(query) do
    Papers.list_papers(current_scope)
  end

  defp search_papers(current_scope, query) do
    Papers.search_papers(current_scope, query)
  end

  defp build_combined_query(base_query, filters) do
    query_parts = [base_query]
    
    query_parts =
      if filters.author != "" do
        ["author:#{filters.author}" | query_parts]
      else
        query_parts
      end
    
    query_parts =
      if filters.keyword != "" do
        ["keyword:#{filters.keyword}" | query_parts]
      else
        query_parts
      end
    
    query_parts =
      if filters.date_range != "" do
        ["date:#{filters.date_range}" | query_parts]
      else
        query_parts
      end
    
    Enum.join(query_parts, " ")
    |> String.trim()
  end

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
