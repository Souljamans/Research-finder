defmodule ResearchPlatformWeb.PaperLive.Viewer do
  use ResearchPlatformWeb, :live_view

  alias ResearchPlatform.Papers
  alias ResearchPlatform.Papers.Note

  on_mount {ResearchPlatformWeb.UserAuth, :default}

  @impl true
  def render(assigns) do
    ~H"""
    <div phx-hook="DownloadHook" id="download-container" style="display: none;"></div>
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        <div class="flex items-center justify-between w-full">
          <div class="flex items-center space-x-4">
            <.button navigate={~p"/papers/#{@paper}"} class="btn btn-ghost btn-sm">
              <.icon name="hero-arrow-left" class="w-4 h-4" />
            </.button>
            <div>
              <h1 class="text-xl font-semibold">{@paper.title}</h1>
              <p class="text-sm text-gray-600">{@paper.authors}</p>
            </div>
          </div>
          <div class="flex items-center space-x-2">
            <.button 
              phx-click="toggle_notes_panel" 
              variant={if @show_notes_panel, do: "primary", else: "secondary"}
                          >
              <.icon name="hero-document-text" class="w-4 h-4 mr-1" />
              Notes ({length(@notes)})
            </.button>
            <.button phx-click="export_notes" class="btn btn-ghost btn-sm">
              <.icon name="hero-arrow-down-tray" class="w-4 h-4 mr-1" />
              Export
            </.button>
          </div>
        </div>
      </.header>

      <div class="flex h-screen">
        <div class={["flex-1", @show_notes_panel && "pr-4"]} id="pdf-container">
          <%= if @paper.file_path do %>
            <div
              id="pdf-viewer"
              phx-hook="PDFViewerHook"
              data-pdf-url={@pdf_url}
              data-paper-id={@paper.id}
              class="w-full h-full border rounded-lg shadow-lg bg-white"
            >
            </div>
          <% else %>
            <div class="flex items-center justify-center h-full border-2 border-dashed border-gray-300 rounded-lg">
              <div class="text-center">
                <.icon name="hero-document" class="w-16 h-16 text-gray-400 mx-auto mb-4" />
                <p class="text-gray-500">No PDF file available for this paper</p>
              </div>
            </div>
          <% end %>
        </div>

        <%= if @show_notes_panel do %>
          <div class="w-80 border-l border-gray-200 bg-gray-50 flex flex-col">
            <div class="p-4 border-b border-gray-200 bg-white">
              <div class="flex items-center justify-between mb-3">
                <h3 class="font-medium">Notes</h3>
                <.button phx-click="clear_selection" class="btn btn-ghost btn-xs text-gray-400">
                  Clear
                </.button>
              </div>
              
              <%= if @selected_position do %>
                <.form for={@note_form} phx-submit="create_note" class="space-y-3">
                  <.input field={@note_form[:content]} type="textarea" placeholder="Add your note..." rows="3" />
                  <.input field={@note_form[:note_type]} type="select" options={[{"Text Note", "text"}, {"Highlight", "highlight"}, {"Annotation", "annotation"}]} />
                  <div class="flex space-x-2">
                    <.button type="submit" class="btn btn-sm flex-1">Add Note</.button>
                    <.button type="button" phx-click="clear_selection" class="btn btn-ghost btn-sm">Cancel</.button>
                  </div>
                </.form>
              <% else %>
                <p class="text-sm text-gray-500">Click on the PDF to add a note at that position.</p>
              <% end %>
            </div>

            <div class="flex-1 overflow-y-auto p-4 space-y-3">
              <%= for note <- @notes do %>
                <div class="bg-white p-3 rounded-lg shadow-sm border border-gray-200 hover:shadow-md transition-shadow">
                  <div class="flex items-start justify-between mb-2">
                    <div class="flex-1">
                      <div class="flex items-center space-x-2 mb-1">
                        <span class={[
                          "px-2 py-1 text-xs rounded-full font-medium",
                          case note.note_type do
                            "highlight" -> "bg-yellow-100 text-yellow-800"
                            "annotation" -> "bg-blue-100 text-blue-800"
                            _ -> "bg-gray-100 text-gray-800"
                          end
                        ]}>
                          {String.capitalize(note.note_type || "text")}
                        </span>
                        <span class="text-xs text-gray-500">Page {note.page}</span>
                      </div>
                      <p class="text-sm text-gray-700">{note.content}</p>
                    </div>
                    <div class="flex items-center space-x-1 ml-2">
                      <.button 
                        phx-click="go_to_note" 
                        phx-value-note-id={note.id} 
                        class="btn btn-ghost" 
                                                title="Go to note"
                      >
                        <.icon name="hero-eye" class="w-3 h-3" />
                      </.button>
                      <.button 
                        phx-click="delete_note" 
                        phx-value-note-id={note.id} 
                        class="btn btn-ghost text-red-500 hover:text-red-700"
                        data-confirm="Are you sure you want to delete this note?"
                        title="Delete note"
                      >
                        <.icon name="hero-trash" class="w-3 h-3" />
                      </.button>
                    </div>
                  </div>
                  <div class="text-xs text-gray-400">
                    {Calendar.strftime(note.inserted_at, "%b %d, %Y at %I:%M %p")}
                  </div>
                </div>
              <% end %>
              
              <%= if Enum.empty?(@notes) do %>
                <div class="text-center py-8">
                  <.icon name="hero-document-text" class="w-12 h-12 text-gray-300 mx-auto mb-3" />
                  <p class="text-gray-500 text-sm">No notes yet</p>
                  <p class="text-gray-400 text-xs mt-1">Click on the PDF to add your first note</p>
                </div>
              <% end %>
            </div>

            <%= if length(@notes) > 0 do %>
              <div class="p-4 border-t border-gray-200 bg-white">
                <.form for={@search_form} phx-change="search_notes" class="mb-3">
                  <.input 
                    field={@search_form[:query]} 
                    type="text" 
                    placeholder="Search notes..." 
                    value={@search_query}
                  />
                </.form>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <%= if @selected_position do %>
        <div class="fixed inset-0 bg-black bg-opacity-25 z-40" phx-click="clear_selection"></div>
      <% end %>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    paper = Papers.get_paper!(socket.assigns.current_scope, id)
    notes = Papers.list_notes(socket.assigns.current_scope, paper.id)

    # Use public PDF route to avoid authentication issues with PDF.js
    pdf_url = "/public/pdf/#{paper.id}"

    socket =
      socket
      |> assign(:page_title, "Viewing #{paper.title}")
      |> assign(:paper, paper)
      |> assign(:notes, notes)
      |> assign(:pdf_url, pdf_url)
      |> assign(:show_notes_panel, true)
      |> assign(:selected_position, nil)
      |> assign(:search_query, "")
      |> assign(:note_form, to_form(Papers.change_note(%Note{}, %{})))
      |> assign(:search_form, to_form(%{"query" => ""}))

    if connected?(socket) do
      Papers.subscribe_papers(socket.assigns.current_scope)
      Papers.subscribe_notes(socket.assigns.current_scope, paper.id)

      # Send initial notes to JavaScript
      send(self(), :send_notes_to_js)
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("create_note", %{"content" => content, "note_type" => note_type, "page" => page, "x" => x, "y" => y}, socket) do
    note_params = %{
      "content" => content,
      "note_type" => note_type,
      "paper_id" => socket.assigns.paper.id,
      "page" => page,
      "x_position" => x,
      "y_position" => y
    }

    case Papers.create_note(note_params, socket.assigns.current_scope) do
      {:ok, note} ->
        updated_notes = [note | socket.assigns.notes]

        {:noreply,
         socket
         |> assign(:notes, updated_notes)
         |> push_event("add_note", %{
           id: note.id,
           page: note.page,
           x: note.x_position,
           y: note.y_position,
           content: note.content
         })
         |> put_flash(:info, "Note created successfully")}

      {:error, changeset} ->
        errors =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
          |> Enum.join(", ")

        {:noreply, put_flash(socket, :error, "Failed to create note: #{errors}")}
    end
  end

  # Keep the old handler for backward compatibility, but don't use it for the main flow
  def handle_event("page_clicked", %{"page" => page, "x" => x, "y" => y}, socket) do
    position = %{page: page, x: x, y: y}
    note_changeset = Papers.change_note(%Note{}, %{page: page, x_position: x, y_position: y})

    {:noreply,
     socket
     |> assign(:selected_position, position)
     |> assign(:note_form, to_form(note_changeset))}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_position, nil)
     |> assign(:note_form, to_form(Papers.change_note(%Note{}, %{})))}
  end

  def handle_event("create_note", %{"note" => note_params}, socket) do
    case socket.assigns.selected_position do
      %{page: page, x: x, y: y} ->
        note_params = 
          note_params
          |> Map.put("paper_id", socket.assigns.paper.id)
          |> Map.put("page", page)
          |> Map.put("x_position", x)
          |> Map.put("y_position", y)

        case Papers.create_note(note_params, socket.assigns.current_scope) do
          {:ok, note} ->
            {:noreply,
             socket
             |> push_event("add_note", %{
               id: note.id,
               page: note.page,
               x: note.x_position,
               y: note.y_position,
               content: note.content
             })
             |> put_flash(:info, "Note created successfully")
             |> assign(:selected_position, nil)
             |> assign(:note_form, to_form(Papers.change_note(%Note{}, %{})))}

          {:error, changeset} ->
            {:noreply, assign(socket, :note_form, to_form(changeset))}
        end

      nil ->
        {:noreply, put_flash(socket, :error, "Please select a position on the PDF first")}
    end
  end

  def handle_event("delete_note", %{"note-id" => note_id}, socket) do
    note = Papers.get_note!(socket.assigns.current_scope, note_id)

    case Papers.delete_note(note, socket.assigns.current_scope) do
      {:ok, _} ->
        {:noreply,
         socket
         |> push_event("remove_note", %{noteId: note_id})
         |> put_flash(:info, "Note deleted successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to delete note")}
    end
  end

  def handle_event("go_to_note", %{"note-id" => note_id}, socket) do
    note = Papers.get_note!(socket.assigns.current_scope, note_id)
    {:noreply, push_event(socket, "go_to_page", %{page: note.page})}
  end

  def handle_event("toggle_notes_panel", _params, socket) do
    {:noreply, assign(socket, :show_notes_panel, !socket.assigns.show_notes_panel)}
  end

  def handle_event("search_notes", %{"query" => query}, socket) do
    filtered_notes = 
      if String.trim(query) == "" do
        Papers.list_notes(socket.assigns.current_scope, socket.assigns.paper.id)
      else
        Papers.search_notes(socket.assigns.current_scope, socket.assigns.paper.id, query)
      end

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:notes, filtered_notes)}
  end

  def handle_event("export_notes", _params, socket) do
    notes_text = 
      socket.assigns.notes
      |> Enum.map(fn note ->
        "## Page #{note.page} - #{String.capitalize(note.note_type || "text")}\n\n#{note.content}\n\n---\n"
      end)
      |> Enum.join("\n")

    filename = "notes_#{socket.assigns.paper.title |> String.replace(~r/[^a-zA-Z0-9_-]/, "_")}.md"
    
    {:noreply,
     push_event(socket, "download_file", %{
       content: notes_text,
       filename: filename,
       content_type: "text/markdown"
     })}
  end

  def handle_event("note_clicked", %{"noteId" => note_id}, socket) do
    note = Papers.get_note!(socket.assigns.current_scope, note_id)
    {:noreply, put_flash(socket, :info, "Note: #{note.content}")}
  end

  def handle_info(:send_notes_to_js, socket) do
    notes_data =
      socket.assigns.notes
      |> Enum.map(fn note ->
        %{
          id: note.id,
          page: note.page || 1,
          x: note.x_position || 50,
          y: note.y_position || 50,
          content: note.content
        }
      end)

    {:noreply, push_event(socket, "load_notes", %{notes: notes_data})}
  end

  @impl true
  def handle_info({:created, %Note{} = note}, socket) do
    if note.paper_id == socket.assigns.paper.id do
      notes = [note | socket.assigns.notes]
      {:noreply, assign(socket, :notes, notes)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:updated, %Note{} = note}, socket) do
    if note.paper_id == socket.assigns.paper.id do
      notes = Enum.map(socket.assigns.notes, fn n -> if n.id == note.id, do: note, else: n end)
      {:noreply, assign(socket, :notes, notes)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:deleted, %Note{} = note}, socket) do
    if note.paper_id == socket.assigns.paper.id do
      notes = Enum.reject(socket.assigns.notes, &(&1.id == note.id))
      {:noreply, assign(socket, :notes, notes)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({type, %ResearchPlatform.Papers.Paper{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end

end