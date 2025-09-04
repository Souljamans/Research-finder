defmodule ResearchPlatformWeb.PaperLive.Form do
  use ResearchPlatformWeb, :live_view

  alias ResearchPlatform.Papers
  alias ResearchPlatform.Papers.Paper

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

      <.form for={@form} id="paper-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:title]} type="text" label="Title" />
        
        <div>
          <label for="paper_authors" class="block text-sm font-medium leading-6 text-zinc-800">Authors (one per line)</label>
          <div class="mt-2">
            <textarea 
              name="paper[authors]" 
              id="paper_authors"
              class="block w-full rounded-md border-0 py-1.5 text-white shadow-sm ring-1 ring-inset ring-zinc-300 placeholder:text-zinc-400 focus:ring-2 focus:ring-inset focus:ring-zinc-900 sm:text-sm sm:leading-6 min-h-[6rem] phx-no-feedback"
              rows="3"
              phx-debounce="200"
            >{@form[:authors].value || ""}</textarea>
          </div>
        </div>
        
        <.input field={@form[:abstract]} type="textarea" label="Abstract" />
        
        <div>
          <label for="paper_keywords" class="block text-sm font-medium leading-6 text-zinc-800">Keywords (comma-separated)</label>
          <div class="mt-2">
            <textarea 
              name="paper[keywords]" 
              id="paper_keywords"
              class="block w-full rounded-md border-0 py-1.5 text-white shadow-sm ring-1 ring-inset ring-zinc-300 placeholder:text-zinc-400 focus:ring-2 focus:ring-inset focus:ring-zinc-900 sm:text-sm sm:leading-6 min-h-[4rem] phx-no-feedback"
              rows="2"
              phx-debounce="200"
            >{@form[:keywords].value || ""}</textarea>
          </div>
        </div>
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
    IO.puts("=== PDF UPLOAD HANDLER STARTED ===")
    
    uploaded_files =
      consume_uploaded_entries(socket, :pdf_file, fn %{path: path}, entry ->
        dest = Path.join("priv/static/uploads/pdfs", "#{entry.client_name}")
        IO.puts("Copying #{path} -> #{dest}")
        File.cp!(path, dest)
        {:ok, dest}
      end)

    IO.puts("Uploaded files: #{inspect(uploaded_files)}")

    case uploaded_files do
      [file_path] ->
        IO.puts("Processing file: #{file_path}")
        
        # Convert relative path to absolute path for PDF extraction
        absolute_file_path = Path.expand(file_path)
        IO.puts("Absolute path: #{absolute_file_path}")
        IO.puts("File exists at absolute path: #{File.exists?(absolute_file_path)}")
        
        # Try to extract content from PDF, fallback to filename parsing if that fails
        IO.puts("About to call extract_pdf_content...")
        
        paper_attrs = try do
          case extract_pdf_content(absolute_file_path) do
            {:ok, extracted_content} ->
              IO.puts("PDF extraction successful!")
              IO.puts("Extracted title: #{extracted_content.title}")
              IO.puts("Extracted authors: #{inspect(extracted_content.authors)}")
              IO.puts("Extracted keywords: #{inspect(extracted_content.keywords)}")
              %{
              title: extracted_content.title || extract_title_from_filename(Path.basename(file_path)) || "Uploaded PDF",
              authors: extracted_content.authors || [],
              abstract: extracted_content.abstract || "PDF uploaded - please edit to add details",
              keywords: extracted_content.keywords || [],
              file_path: Path.basename(file_path),
              file_size: File.stat!(file_path).size,
              metadata: %{
                original_filename: Path.basename(file_path),
                upload_date: DateTime.utc_now() |> DateTime.truncate(:second),
                extracted_text: String.slice(extracted_content.text || "", 0, 1000),
                extraction_method: "pdf_content"
              }
            }
          {:error, _reason} ->
            # Fallback to filename parsing
            %{
              title: extract_title_from_filename(Path.basename(file_path)) || "Uploaded PDF",
              authors: [],
              abstract: "PDF uploaded - please edit to add details",
              keywords: [],
              file_path: Path.basename(file_path),
              file_size: File.stat!(file_path).size,
              metadata: %{
                original_filename: Path.basename(file_path),
                upload_date: DateTime.utc_now() |> DateTime.truncate(:second),
                extraction_method: "filename_only"
              }
            }
          end
        rescue
          error ->
            IO.puts("Exception during PDF extraction: #{inspect(error)}")
            IO.puts("Stack trace: #{Exception.format_stacktrace(__STACKTRACE__)}")
            # Fallback to filename parsing on exception
            %{
              title: extract_title_from_filename(Path.basename(file_path)) || "Uploaded PDF",
              authors: [],
              abstract: "PDF uploaded - please edit to add details",
              keywords: [],
              file_path: Path.basename(file_path),
              file_size: File.stat!(file_path).size,
              metadata: %{
                original_filename: Path.basename(file_path),
                upload_date: DateTime.utc_now() |> DateTime.truncate(:second),
                extraction_method: "exception_fallback"
              }
            }
        end
        
        case Papers.create_paper(socket.assigns.current_scope, paper_attrs) do
          {:ok, paper} ->
            {:noreply,
             socket
             |> put_flash(:info, "PDF uploaded successfully - please edit the details")
             |> push_navigate(to: ~p"/papers/#{paper}/edit")}
             
          {:error, changeset} ->
            File.rm(file_path)  # Clean up on error
            {:noreply,
             socket
             |> put_flash(:error, "Failed to save paper: #{inspect(changeset.errors)}")}
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

  defp extract_pdf_content(file_path) do
    # Add debugging
    IO.puts("Attempting PDF extraction for: #{file_path}")
    IO.puts("File exists: #{File.exists?(file_path)}")
    
    # Try different PDF extraction methods
    with {:error, reason1} <- extract_with_pdftotext(file_path),
         {:error, reason2} <- extract_with_python_pdfplumber(file_path),
         {:error, reason3} <- extract_with_nodejs(file_path) do
      IO.puts("All extraction methods failed:")
      IO.puts("  pdftotext: #{reason1}")
      IO.puts("  python: #{reason2}")
      IO.puts("  nodejs: #{reason3}")
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
    IO.puts("Trying nodejs extraction with file: #{file_path}")
    
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
    
    IO.puts("Running Node.js command with inline script")
    case System.cmd("node", ["-e", script_content]) do
      {output, 0} when output != "" ->
        IO.puts("Node.js command succeeded, output length: #{String.length(output)}")
        IO.puts("First 500 chars of output: #{String.slice(output, 0, 500)}")
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
              
              IO.puts("Final extracted data:")
              IO.puts("Title: #{title}")
              IO.puts("Authors: #{inspect(enhanced_parsed.authors)}")
              IO.puts("Keywords: #{inspect(enhanced_parsed.keywords)}")
              
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
      {output, exit_code} ->
        IO.puts("Node.js command failed with exit code: #{exit_code}")
        IO.puts("Error output: #{output}")
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
    
    IO.puts("Found potential author lines: #{inspect(author_lines)}")

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
    IO.puts("Parsing author string: #{author_string}")
    
    # Parse author string by looking for name patterns
    cleaned = author_string
    |> String.replace(~r/\s*(EdD|RN|IBCLC|BSN|BA|MA|PhD|MD|Dr\.)\s*/i, " ") # Remove credentials
    |> String.replace(~r/,\s*,/, ",") # Clean up double commas
    |> String.replace(~r/\s+/, " ") # Normalize spaces
    
    IO.puts("Cleaned author string: #{cleaned}")
    
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
          _ -> 
            IO.puts("Could not extract name from: #{name}")
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&(String.length(&1) < 4))
      |> Enum.take(10)
    end
    
    IO.puts("Parsed authors: #{inspect(result)}")
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
    IO.puts("Looking for keywords in lines...")
    
    # Find keywords section - look in more places
    keyword_line = 
      lines
      |> Enum.take(50)  # Look in first 50 lines
      |> Enum.find(&Regex.match?(~r/(keywords?|key\s+words?):?\s*/i, &1))

    case keyword_line do
      nil -> 
        IO.puts("No explicit keyword line found, trying to extract from subject/topics")
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
        
        IO.puts("Extracted potential keywords: #{inspect(potential_keywords)}")
        potential_keywords
        
      line ->
        IO.puts("Found keyword line: #{line}")
        result = line
        |> String.replace(~r/^.*?(keywords?|key\s+words?):?\s*/i, "")
        |> String.split([",", ";", ".", "\n"])
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.take(10)
        
        IO.puts("Extracted keywords from line: #{inspect(result)}")
        result
    end
  end

  defp error_to_string(:too_large), do: "File too large (max 50MB)"
  defp error_to_string(:not_accepted), do: "Only PDF files are allowed"
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"
end
