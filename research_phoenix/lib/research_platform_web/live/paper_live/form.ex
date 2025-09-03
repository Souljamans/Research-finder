defmodule ResearchPlatformWeb.PaperLive.Form do
  use ResearchPlatformWeb, :live_view

  alias ResearchPlatform.Papers
  alias ResearchPlatform.Papers.Paper

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage paper records in your database.</:subtitle>
      </.header>

      <%= if @action == :new do %>
        <div class="mb-8 p-4 border-2 border-dashed border-gray-300 rounded-lg">
          <h3 class="text-lg font-medium mb-4">Upload PDF File</h3>
          <form 
            id="pdf-upload-form" 
            phx-change="validate_upload" 
            phx-submit="upload_pdf"
            enctype="multipart/form-data"
          >
            <div class="space-y-4">
              <.live_file_input upload={@uploads.pdf_file} class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100" />
              <%= for entry <- @uploads.pdf_file.entries do %>
                <div class="text-sm text-gray-600">
                  <%= entry.client_name %> - <%= div(entry.client_size, 1024) %>KB
                  <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} class="ml-2 text-red-600">✕</button>
                </div>
              <% end %>
              <.button type="submit" phx-disable-with="Uploading..." variant="primary">
                Upload & Process PDF
              </.button>
            </div>
          </form>
          
          <%= for error <- upload_errors(@uploads.pdf_file) do %>
            <div class="mt-2 text-red-600 text-sm"><%= error_to_string(error) %></div>
          <% end %>
        </div>

        <div class="text-center my-8">
          <span class="bg-gray-100 px-4 py-2 rounded">OR</span>
        </div>
      <% end %>

      <.form for={@form} id="paper-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:title]} type="text" label="Title" />
        <.input field={@form[:authors]} type="textarea" label="Authors (one per line)" />
        <.input field={@form[:abstract]} type="textarea" label="Abstract" />
        <.input field={@form[:keywords]} type="textarea" label="Keywords (comma-separated)" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Paper</.button>
          <.button navigate={return_path(@current_scope, @return_to, @paper)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> allow_upload(:pdf_file,
       accept: ~w(.pdf),
       max_entries: 1,
       max_file_size: 50_000_000  # 50MB
     )
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    paper = Papers.get_paper!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Paper")
    |> assign(:paper, paper)
    |> assign(:form, to_form(Papers.change_paper(socket.assigns.current_scope, paper)))
  end

  defp apply_action(socket, :new, _params) do
    paper = %Paper{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "New Paper")
    |> assign(:paper, paper)
    |> assign(:form, to_form(Papers.change_paper(socket.assigns.current_scope, paper)))
  end

  @impl true
  def handle_event("validate", %{"paper" => paper_params}, socket) do
    changeset = Papers.change_paper(socket.assigns.current_scope, socket.assigns.paper, paper_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"paper" => paper_params}, socket) do
    save_paper(socket, socket.assigns.live_action, paper_params)
  end

  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :pdf_file, ref)}
  end

  def handle_event("upload_pdf", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :pdf_file, fn %{path: path}, entry ->
        dest = Path.join("priv/static/uploads/pdfs", "#{entry.client_name}")
        File.cp!(path, dest)
        {:ok, dest}
      end)

    case uploaded_files do
      [file_path] ->
        # Process the PDF file
        alias ResearchPlatform.Services.PdfService
        
        case PdfService.process_uploaded_pdf(file_path, socket.assigns.current_scope) do
          {:ok, processed_metadata} ->
            # Create paper with extracted data
            paper_attrs = %{
              title: processed_metadata.extracted_title || "Untitled",
              authors: processed_metadata.extracted_authors || [],
              abstract: "",
              keywords: [],
              file_path: Path.basename(file_path),
              file_size: File.stat!(file_path).size,
              metadata: processed_metadata
            }
            
            case Papers.create_paper(socket.assigns.current_scope, paper_attrs) do
              {:ok, paper} ->
                {:noreply,
                 socket
                 |> put_flash(:info, "PDF uploaded and processed successfully")
                 |> push_navigate(to: ~p"/papers/#{paper}")}
                 
              {:error, changeset} ->
                File.rm(file_path)  # Clean up on error
                {:noreply,
                 socket
                 |> put_flash(:error, "Failed to save paper: #{inspect(changeset.errors)}")}
            end
            
          {:error, reason} ->
            File.rm(file_path)
            {:noreply,
             socket
             |> put_flash(:error, "Failed to process PDF: #{reason}")}
        end
        
      [] ->
        {:noreply, socket}
    end
  end

  defp save_paper(socket, :edit, paper_params) do
    case Papers.update_paper(socket.assigns.current_scope, socket.assigns.paper, paper_params) do
      {:ok, paper} ->
        {:noreply,
         socket
         |> put_flash(:info, "Paper updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, paper)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_paper(socket, :new, paper_params) do
    case Papers.create_paper(socket.assigns.current_scope, paper_params) do
      {:ok, paper} ->
        {:noreply,
         socket
         |> put_flash(:info, "Paper created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, paper)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _paper), do: ~p"/papers"
  defp return_path(_scope, "show", paper), do: ~p"/papers/#{paper}"

  defp error_to_string(:too_large), do: "File too large (max 50MB)"
  defp error_to_string(:not_accepted), do: "Only PDF files are allowed"
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"
end
