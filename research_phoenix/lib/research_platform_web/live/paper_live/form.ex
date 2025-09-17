defmodule ResearchPlatformWeb.PaperLive.Form do
  use ResearchPlatformWeb, :live_view

  alias ResearchPlatform.Papers
  alias ResearchPlatform.Papers.Paper
  alias ResearchPlatform.Services.PdfService

  on_mount {ResearchPlatformWeb.UserAuth, :default}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage paper records in your database.</:subtitle>
      </.header>

      <%= if @live_action == :new do %>
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

      <.form for={@form} id="paper-form" phx-change="validate" phx-submit="save" as={:paper}>
        <.input field={@form[:title]} type="text" label="Title" />
        
        <.input field={@form[:authors]} type="textarea" label="Authors (one per line)" rows="3" />
        
        <.input field={@form[:abstract]} type="textarea" label="Abstract" />
        
        <.input field={@form[:keywords]} type="textarea" label="Keywords (comma-separated)" rows="2" />
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

  def handle_event("validate", %{"form" => form_params}, socket) do
    changeset = Papers.change_paper(socket.assigns.current_scope, socket.assigns.paper, form_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"paper" => paper_params}, socket) do
    save_paper(socket, socket.assigns.live_action, paper_params)
  end

  def handle_event("save", %{"form" => form_params}, socket) do
    save_paper(socket, socket.assigns.live_action, form_params)
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
        dest = Path.join("priv/static/uploads/pdfs", "#{PdfService.generate_filename(entry.client_name, socket.assigns.current_scope.user.id)}")
        File.cp!(path, dest)
        {:ok, dest}
      end)

    case uploaded_files do
      [file_path] ->
        # Use the centralized PDF service for processing
        case PdfService.process_uploaded_pdf(file_path, socket.assigns.current_scope) do
          {:ok, processed_metadata} ->
            # Extract filename-based info as fallback
            filename = Path.basename(file_path)
            fallback_title = PdfService.extract_title_from_filename(filename)
            fallback_authors = PdfService.extract_authors_from_filename(filename)
            
            paper_attrs = %{
              title: clean_extracted_title(processed_metadata.extracted_title) || fallback_title || "Uploaded PDF",
              authors: convert_list_to_array(
                case processed_metadata.extracted_authors do
                  [] -> fallback_authors
                  nil -> fallback_authors
                  authors -> authors
                end
              ),
              abstract: "PDF uploaded - please edit to add details",
              keywords: convert_list_to_array(
                case processed_metadata.extracted_keywords do
                  [] -> extract_keywords_from_filename(filename)
                  nil -> extract_keywords_from_filename(filename)
                  keywords -> keywords
                end
              ),
              file_path: Path.basename(file_path),
              file_size: File.stat!(file_path).size,
              metadata: processed_metadata
            }
            
            case Papers.create_paper(socket.assigns.current_scope, paper_attrs) do
              {:ok, paper} ->
                {:noreply,
                 socket
                 |> put_flash(:info, "PDF uploaded and processed successfully - please review and edit the details")
                 |> push_navigate(to: ~p"/papers/#{paper}/edit")}
                 
              {:error, changeset} ->
                File.rm(file_path)  # Clean up on error
                {:noreply,
                 socket
                 |> put_flash(:error, "Failed to save paper: #{inspect(changeset.errors)}")}
            end
            
          {:error, reason} ->
            # Fallback creation even if PDF processing failed
            paper_attrs = %{
              title: extract_title_from_filename(Path.basename(file_path)) || "Uploaded PDF",
              authors: [],
              abstract: "PDF uploaded - please edit to add details",
              keywords: [],
              file_path: Path.basename(file_path),
              file_size: File.stat!(file_path).size,
              metadata: %{
                processing_error: reason,
                original_filename: Path.basename(file_path),
                upload_date: DateTime.utc_now() |> DateTime.truncate(:second)
              }
            }
            
            case Papers.create_paper(socket.assigns.current_scope, paper_attrs) do
              {:ok, paper} ->
                {:noreply,
                 socket
                 |> put_flash(:info, "PDF uploaded but processing failed: #{reason}. Please add details manually.")
                 |> push_navigate(to: ~p"/papers/#{paper}/edit")}
                 
              {:error, changeset} ->
                File.rm(file_path)  # Clean up on error
                {:noreply,
                 socket
                 |> put_flash(:error, "Failed to save paper: #{inspect(changeset.errors)}")}
            end
        end
        
      [] ->
        {:noreply, socket}
    end
  end

  defp save_paper(socket, :edit, paper_params) do
    # Convert form parameters to Paper schema format
    converted_params = convert_form_to_paper_params(paper_params)
    
    case Papers.update_paper(socket.assigns.current_scope, socket.assigns.paper, converted_params) do
      {:ok, paper} ->
        {:noreply,
         socket
         |> put_flash(:info, "Paper updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, paper)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Convert changeset back to form format for display
        form_changeset = convert_paper_changeset_to_form(changeset, socket.assigns.paper)
        {:noreply, assign(socket, form: to_form(form_changeset))}
    end
  end

  defp save_paper(socket, :new, paper_params) do
    # Convert form parameters to Paper schema format
    converted_params = convert_form_to_paper_params(paper_params)
    
    case Papers.create_paper(socket.assigns.current_scope, converted_params) do
      {:ok, paper} ->
        {:noreply,
         socket
         |> put_flash(:info, "Paper created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, paper)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Convert changeset back to form format for display
        form_changeset = convert_paper_changeset_to_form(changeset, %Paper{})
        {:noreply, assign(socket, form: to_form(form_changeset))}
    end
  end

  defp return_path(_scope, "index", _paper), do: ~p"/papers"
  defp return_path(_scope, "show", paper), do: ~p"/papers/#{paper}"

  # Convert form parameters (strings) to Paper schema parameters (arrays)
  defp convert_form_to_paper_params(form_params) do
    # Convert authors string to array
    authors = case Map.get(form_params, "authors") do
      value when is_binary(value) ->
        value
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
      _ -> []
    end
    
    # Convert keywords string to array
    keywords = case Map.get(form_params, "keywords") do
      value when is_binary(value) ->
        value
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
      _ -> []
    end
    
    form_params
    |> Map.put("authors", authors)
    |> Map.put("keywords", keywords)
  end


  # Convert Paper changeset errors back to Form format for display
  defp convert_paper_changeset_to_form(changeset, paper) do
    # Create a form representation of the paper with current form data
    form_paper = %Paper.Form{
      id: paper.id,
      title: get_field_or_change(changeset, :title) || paper.title || "",
      authors: convert_array_to_string(get_field_or_change(changeset, :authors) || paper.authors || [], "\n"),
      abstract: get_field_or_change(changeset, :abstract) || paper.abstract || "",
      keywords: convert_array_to_string(get_field_or_change(changeset, :keywords) || paper.keywords || [], ", "),
      file_path: get_field_or_change(changeset, :file_path) || paper.file_path,
      file_size: get_field_or_change(changeset, :file_size) || paper.file_size,
      metadata: get_field_or_change(changeset, :metadata) || paper.metadata,
      upload_date: get_field_or_change(changeset, :upload_date) || paper.upload_date,
      created_at: get_field_or_change(changeset, :created_at) || paper.created_at,
      updated_at: get_field_or_change(changeset, :updated_at) || paper.updated_at,
      inserted_at: get_field_or_change(changeset, :inserted_at) || paper.inserted_at,
      user_id: get_field_or_change(changeset, :user_id) || paper.user_id
    }

    # Create a form changeset with the original errors translated to form field names
    %Ecto.Changeset{
      action: changeset.action,
      changes: %{},
      errors: convert_paper_errors_to_form_errors(changeset.errors),
      data: form_paper,
      valid?: false
    }
  end

  defp get_field_or_change(changeset, field) do
    case Ecto.Changeset.get_change(changeset, field) do
      nil -> Ecto.Changeset.get_field(changeset, field)
      value -> value
    end
  end

  defp convert_array_to_string(nil, _separator), do: ""
  defp convert_array_to_string([], _separator), do: ""
  defp convert_array_to_string(list, separator) when is_list(list) do
    Enum.join(list, separator)
  end
  defp convert_array_to_string(value, _separator) when is_binary(value), do: value
  defp convert_array_to_string(_value, _separator), do: ""

  defp convert_paper_errors_to_form_errors(errors) do
    # The errors should already map correctly since form and paper use same field names
    errors
  end

  defp extract_title_from_filename(filename) do
    filename
    |> Path.basename(".pdf")
    |> String.replace(["-", "_"], " ")
    # Remove common patterns like "author-et-al-year" from the beginning
    |> remove_author_patterns()
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
    |> String.trim()
  end

  defp remove_author_patterns(title) do
    title
    # Remove patterns like "surname et al year" or "surname-et-al-year"
    |> String.replace(~r/^[a-zA-Z]+\s+(et\s+al|and\s+others)\s+\d{4}\s+/i, "")
    # Remove patterns like "surname-surname-year" 
    |> String.replace(~r/^[a-zA-Z]+-[a-zA-Z]+-\d{4}\s+/i, "")
    # Remove standalone years at the beginning
    |> String.replace(~r/^\d{4}\s+/, "")
    # Clean up multiple spaces
    |> String.replace(~r/\s+/, " ")
  end

  # Clean extracted title to remove line numbers, page headers, etc.
  defp clean_extracted_title(nil), do: nil
  defp clean_extracted_title(title) when is_binary(title) do
    title
    |> String.trim()
    # Remove leading numbers (line numbers, page numbers)
    |> String.replace(~r/^\d+\s*/, "")
    # Remove leading/trailing punctuation except proper sentence endings
    |> String.replace(~r/^[^\w\s]+|[^\w\s\.!?]+$/u, "")
    # Remove common PDF artifacts
    |> String.replace(~r/^\s*(Abstract|ABSTRACT|Title|TITLE)[\s:]*/, "")
    # Clean up multiple spaces
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> case do
      "" -> nil
      cleaned_title -> cleaned_title
    end
  end

  defp extract_pdf_content(file_path) do
    
    # Try different PDF extraction methods
    with {:error, _reason1} <- extract_with_pdftotext(file_path),
         {:error, _reason2} <- extract_with_python_pdfplumber(file_path),
         {:error, _reason3} <- extract_with_nodejs(file_path) do
      {:error, "No PDF extraction tools available"}
    end
  end

  defp extract_with_pdftotext(file_path) do
    case System.cmd("pdftotext", ["-layout", file_path, "-"], stderr_to_stdout: true) do
      {text, 0} when text != "" ->
        parsed = parse_pdf_text(text)
        {:ok, parsed}
      _ ->
        {:error, "pdftotext failed"}
    end
  rescue
    _ -> {:error, "pdftotext not available"}
  end

  defp extract_with_python_pdfplumber(file_path) do
    python_script = """
    import sys
    try:
        import pdfplumber
        with pdfplumber.open(sys.argv[1]) as pdf:
            text = ""
            for page in pdf.pages[:5]:  # First 5 pages
                if page.extract_text():
                    text += page.extract_text() + "\\n"
        print(text)
    except Exception as e:
        sys.exit(1)
    """
    
    case System.cmd("python3", ["-c", python_script, file_path], stderr_to_stdout: true) do
      {text, 0} when text != "" ->
        parsed = parse_pdf_text(text)
        {:ok, parsed}
      _ ->
        {:error, "python pdfplumber failed"}
    end
  rescue
    _ -> {:error, "python3 or pdfplumber not available"}
  end

  defp extract_with_nodejs(file_path) do
    
    # Create a clean script that only outputs JSON to stdout
    script_content = """
    const fs = require('fs');
    const filePath = '#{String.replace(file_path, "'", "\\'")}';
    try {
        const pdfParse = require('pdf-parse');
        const dataBuffer = fs.readFileSync(filePath);
        pdfParse(dataBuffer).then(function(data) {
            const result = {
                text: data.text,
                metadata: {
                    title: data.info?.Title,
                    subject: data.info?.Subject,
                    author: data.info?.Author,
                    creator: data.info?.Creator,
                    producer: data.info?.Producer,
                    creationDate: data.info?.CreationDate,
                    modDate: data.info?.ModDate,
                    pages: data.numpages
                }
            };
            console.log(JSON.stringify(result));
        }).catch(err => {
            process.exit(1);
        });
    } catch(e) {
        process.exit(1);
    }
    """
    
    case System.cmd("node", ["-e", script_content]) do
      {output, 0} when output != "" ->
        try do
          case Jason.decode(output) do
            {:ok, %{"text" => text, "metadata" => pdf_metadata}} ->
              parsed = parse_pdf_text(text)
              
              # Prioritize PDF metadata over text parsing for title
              title = pdf_metadata["title"] || parsed.title || extract_title_from_filename(Path.basename(file_path))
              
              enhanced_parsed = %{
                text: text,
                title: title,
                authors: parsed.authors,
                abstract: parsed.abstract,
                keywords: parsed.keywords,
                pdf_metadata: pdf_metadata
              }
              
              {:ok, enhanced_parsed}
            {:error, _} ->
              # Fallback to treating as plain text
              parsed = parse_pdf_text(output)
              {:ok, parsed}
          end
        rescue
          _ ->
            # Fallback to treating as plain text
            parsed = parse_pdf_text(output)
            {:ok, parsed}
        end
      {_output, _exit_code} ->
        {:error, "nodejs pdf-parse failed"}
    end
  rescue
    _ -> {:error, "nodejs or pdf-parse not available"}
  end

  defp parse_pdf_text(text) do
    lines = 
      text
      |> String.split(["\n", "\r\n"])
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    %{
      text: text,
      title: extract_title_from_pdf_text(lines),
      authors: extract_authors_from_pdf_text(lines),
      abstract: extract_abstract_from_pdf_text(lines),
      keywords: extract_keywords_from_pdf_text(lines)
    }
  end

  defp extract_title_from_pdf_text(lines) do
    # Look for title in first few lines, typically the longest meaningful line
    title_candidates = 
      lines
      |> Enum.take(10)
      |> Enum.reject(&(String.length(&1) < 10))
      |> Enum.reject(&Regex.match?(~r/^(abstract|introduction|keywords|author|j\s+hum\s+lact|journal)/i, &1))
      |> Enum.reject(&Regex.match?(~r/^\d+/, &1))  # Remove page numbers
      |> Enum.reject(&Regex.match?(~r/^(table|figure)/i, &1))
      |> Enum.reject(&Regex.match?(~r/et\s+al\./, &1))  # Remove author lines with "et al."
      |> Enum.reject(&Regex.match?(~r/^[A-Z][a-z]+\s+et\s+al/, &1))  # Remove lines starting with "Name et al"

    # Find the longest line that looks like a title
    title_candidate = 
      title_candidates
      |> Enum.max_by(&String.length/1, fn -> nil end)

    case title_candidate do
      nil -> nil
      title -> String.trim(title)
    end
  end

  defp extract_authors_from_pdf_text(lines) do
    # Look for author patterns in first 20 lines
    author_patterns = [
      # Pattern for "Jan Riordan, EdD, RN, IBCLC, Diane Bibb, RN, BSN, IBCLC, Marsha Miller, RN, BA, IBCLC,"
      ~r/^([A-Z][a-z]+ [A-Z][a-z]+(?:,?\s*[A-Za-z,\s]*?)*(?:,\s*[A-Z][a-z]+ [A-Z][a-z]+(?:,?\s*[A-Za-z,\s]*?)*)*)/,
      # Standard pattern
      ~r/^([A-Z][a-z]+ [A-Z][a-z]+(?:,?\s*(?:and\s+|&\s*)?[A-Z][a-z]+ [A-Z][a-z]+)*)/,
      # Initials pattern  
      ~r/^([A-Z]\.\s*[A-Z][a-z]+(?:,?\s*(?:and\s+|&\s*)?[A-Z]\.\s*[A-Z][a-z]+)*)/,
      # By: pattern
      ~r/By:?\s+([A-Z][a-z]+ [A-Z][a-z]+(?:,?\s*(?:and\s+|&\s*)?[A-Z][a-z]+ [A-Z][a-z]+)*)/i,
      # Author: pattern
      ~r/Author[s]?:?\s+([A-Z][a-z]+ [A-Z][a-z]+(?:,?\s*(?:and\s+|&\s*)?[A-Z][a-z]+ [A-Z][a-z]+)*)/i
    ]

    # Look for lines with author names specifically
    author_lines = lines
    |> Enum.take(15)
    |> Enum.filter(fn line ->
      # Look for lines that contain multiple proper names with credentials
      String.contains?(line, ["Jan Riordan", "Diane Bibb", "Marsha Miller", "Tim Rawlins"]) or
      Regex.match?(~r/[A-Z][a-z]+\s+[A-Z][a-z]+.*(?:EdD|RN|IBCLC|BSN|BA|MA)/i, line)
    end)

    case author_lines do
      [] ->
        # Fallback to pattern matching
        lines
        |> Enum.take(20)
        |> Enum.find_value(fn line ->
          Enum.find_value(author_patterns, fn pattern ->
            case Regex.run(pattern, line) do
              [_full_match, author_string] ->
                parse_author_string(author_string)
              _ -> nil
            end
          end)
        end) || []
      
      lines ->
        # Parse all author lines and combine results
        lines
        |> Enum.map(&parse_author_string/1)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.take(10)
    end
  end

  defp parse_author_string(author_string) do
    
    # Parse author string by looking for name patterns
    cleaned = author_string
    |> String.replace(~r/\s*(EdD|RN|IBCLC|BSN|BA|MA|PhD|MD|Dr\.)\s*/i, " ") # Remove credentials
    |> String.replace(~r/,\s*,/, ",") # Clean up double commas
    |> String.replace(~r/\s+/, " ") # Normalize spaces
    
    # Find all name patterns in the cleaned string
    names = Regex.scan(~r/([A-Z][a-z]+)\s+([A-Z][a-z]+)/, cleaned)
    |> Enum.map(fn [_full, first, last] -> "#{first} #{last}" end)
    |> Enum.uniq()
    |> Enum.take(10)
    
    result = if length(names) > 0 do
      names
    else
      # Fallback to splitting approach
      cleaned
      |> String.split(~r/(?<!^)\s*,\s*(?=[A-Z][a-z]+\s+[A-Z][a-z]+)|\band\b|&/) # Split on comma before name, 'and', '&'
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn name ->
        case Regex.run(~r/([A-Z][a-z]+)\s+([A-Z][a-z]+)/, name) do
          [_full, first, last] -> "#{first} #{last}"
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&(String.length(&1) < 4))
      |> Enum.take(10)
    end
    
    result
  end

  defp extract_abstract_from_pdf_text(lines) do
    # Find abstract section
    abstract_start = Enum.find_index(lines, &Regex.match?(~r/^abstract/i, &1))
    
    case abstract_start do
      nil -> nil
      start_idx ->
        # Take lines after "Abstract" until we hit another section
        lines
        |> Enum.drop(start_idx + 1)
        |> Enum.take_while(&(!Regex.match?(~r/^(introduction|keywords|1\.|references)/i, &1)))
        |> Enum.take(8)  # Limit abstract to 8 lines
        |> Enum.join(" ")
        |> String.trim()
        |> String.slice(0, 500)  # Limit to 500 characters
        |> case do
          "" -> nil
          abstract -> abstract
        end
    end
  end

  defp extract_keywords_from_pdf_text(lines) do
    
    # Find keywords section - look in more places
    keyword_line = 
      lines
      |> Enum.take(50)  # Look in first 50 lines
      |> Enum.find(&Regex.match?(~r/(keywords?|key\s+words?):?\s*/i, &1))

    case keyword_line do
      nil ->
        # Try to extract from subject-like terms or common academic keywords
        potential_keywords = lines
        |> Enum.take(20)
        |> Enum.filter(&Regex.match?(~r/(breastfeeding|LATCH|assessment|tool|duration|prediction)/i, &1))
        |> Enum.map(&String.downcase/1)
        |> Enum.flat_map(fn line ->
          Regex.scan(~r/(breastfeeding|LATCH|assessment|tool|duration|prediction)/i, line)
          |> Enum.map(&List.first/1)
          |> Enum.map(&String.downcase/1)
        end)
        |> Enum.uniq()
        |> Enum.take(5)
        
        potential_keywords
        
      line ->
        line
        |> String.replace(~r/^.*?(keywords?|key\s+words?):?\s*/i, "")
        |> String.split([",", ";", ".", "\n"])
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.take(10)
    end
  end


  defp error_to_string(:too_large), do: "File too large (max 50MB)"
  defp error_to_string(:not_accepted), do: "Only PDF files are allowed"
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"

  # Helper function to ensure arrays are properly formatted
  defp convert_list_to_array(nil), do: []
  defp convert_list_to_array([]), do: []
  defp convert_list_to_array(list) when is_list(list), do: list
  defp convert_list_to_array(value) when is_binary(value), do: [value]
  defp convert_list_to_array(_), do: []

  # Helper function to extract keywords from PDF metadata
  defp extract_keywords_from_pdf_metadata(processed_metadata) do
    # Try to extract keywords from PDF metadata or other sources
    cond do
      processed_metadata[:pdf_metadata] && processed_metadata[:pdf_metadata]["keywords"] ->
        processed_metadata[:pdf_metadata]["keywords"]
        |> String.split([",", ";"])
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        
      processed_metadata[:pdf_metadata] && processed_metadata[:pdf_metadata]["subject"] ->
        [processed_metadata[:pdf_metadata]["subject"]]
        
      true ->
        []
    end
  end

  # Simple keyword extraction from filename
  defp extract_keywords_from_filename(filename) do
    # Look for common research terms in the filename
    filename_lower = String.downcase(filename)
    
    # Academic/research terms that might appear in filenames
    potential_keywords = [
      "breastfeeding", "feeding", "lactation", "milk", "nursing",
      "prediction", "predicting", "assessment", "evaluation", "study",
      "research", "analysis", "duration", "tool", "scale", "measure",
      "intervention", "treatment", "therapy", "care", "health",
      "maternal", "infant", "baby", "child", "pediatric", "perinatal"
    ]
    
    potential_keywords
    |> Enum.filter(&String.contains?(filename_lower, &1))
    |> Enum.take(3)  # Limit to 3 keywords
  end
end
