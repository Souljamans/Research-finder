defmodule ResearchPlatform.Services.PdfService do
  @moduledoc """
  Service for PDF processing including text extraction and metadata parsing.
  Uses external tools like pdftotext and pdfinfo for processing.
  """

  alias ResearchPlatform.Papers

  @upload_dir "priv/static/uploads/pdfs"
  
  def process_uploaded_pdf(file_path, _user_scope) do
    # Try to extract text and metadata using available tools
    text_result = extract_text(file_path)
    metadata_result = extract_metadata(file_path)
    
    case {text_result, metadata_result} do
      {{:ok, text}, {:ok, metadata}} ->
        # Both text and metadata extraction succeeded
        processed_metadata = %{
          extracted_text: text,
          word_count: estimate_word_count(text),
          extracted_title: metadata["title"] || extract_title_from_text(text),
          extracted_authors: extract_authors_from_text(text) || extract_authors_from_metadata(metadata),
          extracted_keywords: extract_keywords_from_text(text) || extract_keywords_from_metadata(metadata),
          pdf_metadata: metadata,
          processed_at: DateTime.utc_now()
        }
        {:ok, processed_metadata}
        
      {{:ok, text}, {:error, _metadata_error}} ->
        # Text extraction succeeded, metadata failed
        processed_metadata = %{
          extracted_text: text,
          word_count: estimate_word_count(text),
          extracted_title: extract_title_from_text(text),
          extracted_authors: extract_authors_from_text(text),
          extracted_keywords: extract_keywords_from_text(text),
          pdf_metadata: %{},
          processed_at: DateTime.utc_now()
        }
        {:ok, processed_metadata}
        
      {{:error, _text_error}, {:ok, metadata}} ->
        # Metadata extraction succeeded, text failed
        processed_metadata = %{
          extracted_text: "",
          word_count: 0,
          extracted_title: metadata["title"],
          extracted_authors: extract_authors_from_metadata(metadata),
          extracted_keywords: extract_keywords_from_metadata(metadata),
          pdf_metadata: metadata,
          processed_at: DateTime.utc_now()
        }
        {:ok, processed_metadata}
        
      {{:error, text_error}, {:error, metadata_error}} ->
        # Both failed, but we'll try to extract basic info from filename
        filename = Path.basename(file_path, ".pdf")
        processed_metadata = %{
          extracted_text: "",
          word_count: 0,
          extracted_title: extract_title_from_filename(filename),
          extracted_authors: extract_authors_from_filename(filename),
          extracted_keywords: [],
          pdf_metadata: %{},
          processed_at: DateTime.utc_now(),
          processing_errors: %{
            text_extraction: text_error,
            metadata_extraction: metadata_error
          }
        }
        {:ok, processed_metadata}
    end
  end

  def extract_text(file_path) do
    # Try Node.js pdf-parse first (more reliable in this environment)
    case extract_text_with_nodejs(file_path) do
      {:ok, text} -> {:ok, text}
      {:error, _} ->
        # Fallback to pdftotext if available
        case Rambo.run("pdftotext", ["-layout", file_path, "-"], log: false) do
          {:ok, %{out: text, status: 0}} ->
            {:ok, String.trim(text)}
          
          {:ok, %{status: status}} ->
            {:error, "pdftotext failed with status #{status}"}
            
          {:error, reason} ->
            # Try without -layout option
            case Rambo.run("pdftotext", [file_path, "-"], log: false) do
              {:ok, %{out: text, status: 0}} ->
                {:ok, String.trim(text)}
              _ ->
                {:error, "pdftotext not available: #{reason}"}
            end
        end
    end
  end

  defp extract_text_with_nodejs(file_path) do
    script_content = """
    const fs = require('fs');
    const pdfParse = require('pdf-parse');
    
    // When using node -e "script" filePath, the filePath becomes process.argv[1]  
    const filePath = process.argv[1];
    
    if (!filePath) {
      console.error('No file path provided');
      process.exit(1);
    }
    
    try {
      const dataBuffer = fs.readFileSync(filePath);
      pdfParse(dataBuffer).then(function(data) {
        console.log(data.text);
        process.exit(0);
      }).catch(err => {
        console.error('Error:', err.message);
        process.exit(1);
      });
    } catch(e) {
      console.error('Error:', e.message);
      process.exit(1);
    }
    """
    
    case System.cmd("node", ["-e", script_content, file_path], stderr_to_stdout: true) do
      {output, 0} when output != "" ->
        {:ok, String.trim(output)}
      {error_output, _} ->
        {:error, "nodejs pdf-parse failed: #{error_output}"}
    end
  rescue
    error -> {:error, "nodejs not available: #{inspect(error)}"}
  end

  def extract_metadata(file_path) do
    # Try Node.js pdf-parse for metadata first
    case extract_metadata_with_nodejs(file_path) do
      {:ok, metadata} -> {:ok, metadata}
      {:error, _} ->
        # Fallback to pdfinfo if available
        case Rambo.run("pdfinfo", [file_path], log: false) do
          {:ok, %{out: output, status: 0}} ->
            metadata = parse_pdfinfo_output(output)
            {:ok, metadata}
            
          {:ok, %{status: status}} ->
            {:error, "pdfinfo failed with status #{status}"}
            
          {:error, reason} ->
            {:error, "pdfinfo not available: #{reason}"}
        end
    end
  end

  defp extract_metadata_with_nodejs(file_path) do
    script_content = """
    const fs = require('fs');
    const pdfParse = require('pdf-parse');
    
    // When using node -e "script" filePath, the filePath becomes process.argv[1]  
    const filePath = process.argv[1];
    
    if (!filePath) {
      console.error('No file path provided');
      process.exit(1);
    }
    
    try {
      const dataBuffer = fs.readFileSync(filePath);
      pdfParse(dataBuffer).then(function(data) {
        const metadata = {
          title: data.info?.Title || '',
          author: data.info?.Author || '',
          subject: data.info?.Subject || '',
          keywords: data.info?.Keywords || '',
          creator: data.info?.Creator || '',
          producer: data.info?.Producer || '',
          creation_date: data.info?.CreationDate || '',
          modification_date: data.info?.ModDate || '',
          pages: data.numpages || 0
        };
        console.log(JSON.stringify(metadata));
        process.exit(0);
      }).catch(err => {
        console.error('Error:', err.message);
        process.exit(1);
      });
    } catch(e) {
      console.error('Error:', e.message);
      process.exit(1);
    }
    """
    
    case System.cmd("node", ["-e", script_content, file_path], stderr_to_stdout: true) do
      {output, 0} when output != "" ->
        try do
          case Jason.decode(output) do
            {:ok, metadata} -> {:ok, metadata}
            {:error, _} -> {:error, "failed to parse metadata JSON"}
          end
        rescue
          _ -> {:error, "failed to parse metadata"}
        end
      {error_output, _} ->
        {:error, "nodejs metadata extraction failed: #{error_output}"}
    end
  rescue
    error -> {:error, "nodejs not available: #{inspect(error)}"}
  end

  defp parse_pdfinfo_output(output) do
    output
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ":", parts: 2) do
        [key, value] ->
          clean_key = key |> String.trim() |> String.downcase() |> String.replace(" ", "_")
          clean_value = String.trim(value)
          Map.put(acc, clean_key, clean_value)
        _ ->
          acc
      end
    end)
  end

  def estimate_word_count(text) when is_binary(text) do
    text
    |> String.split(~r/\s+/)
    |> Enum.reject(&(&1 == ""))
    |> length()
  end
  
  def estimate_word_count(_), do: 0

  def extract_title_from_text(text) when is_binary(text) do
    lines = 
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.take(15)

    # Look for title pattern - often spans multiple lines after journal info
    # Find lines that contain "Predicting" or other title-like content
    title_lines = lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _index} ->
      # Look for lines that contain title keywords and are not journal names or authors
      Regex.match?(~r/(Predicting|Using|Assessment|Tool|Duration|Breastfeeding)/i, line) &&
      !Regex.match?(~r/(J\s+Hum\s+Lact|\d{4}|EdD|RN|IBCLC|Abstract|et\s+al)/i, line) &&
      !Regex.match?(~r/^[A-Z][a-z]+,\s*[A-Z]/i, line) && # Not author names starting with "Name,"
      String.length(line) > 5
    end)
    |> Enum.map(fn {line, _index} -> line end)

    case title_lines do
      [] -> nil
      [single_line] -> single_line
      multiple_lines ->
        # Combine consecutive title lines
        combined = multiple_lines
        |> Enum.join(" ")
        |> String.replace(~r/\s+/, " ")
        |> String.trim()
        
        # Clean up the combined title
        if String.length(combined) > 10 and String.length(combined) < 300 do
          combined
        else
          List.first(multiple_lines)
        end
    end
  end
  
  def extract_title_from_text(_), do: nil

  def extract_authors_from_text(text) when is_binary(text) do
    lines = 
      text
      |> String.split("\n")
      |> Enum.take(20)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    # Look for lines that contain academic credentials (indicating author lines)
    author_lines = lines
    |> Enum.filter(fn line ->
      # Look for lines with academic credentials that indicate authors
      Regex.match?(~r/[A-Z][a-z]+\s+[A-Z][a-z]+.*(?:EdD|RN|IBCLC|BSN|BA|MA|PhD|MD|Dr\.)/i, line) &&
      # Exclude lines that are clearly not authors (journal names, titles, etc.)
      !Regex.match?(~r/(J\s+Hum\s+Lact|Predicting|Breastfeeding|Duration|LATCH|Assessment|Tool|Abstract)/i, line)
    end)

    # Combine multi-line author sections (like "Name1, Name2," on one line and "and Name3" on next)
    combined_author_text = case author_lines do
      [] -> ""
      [single_line] -> single_line
      multiple_lines -> 
        # Join consecutive author lines, looking for continuation patterns
        multiple_lines
        |> Enum.join(" ")
    end

    # Extract all author names from the combined text
    if combined_author_text != "" do
      extract_individual_authors(combined_author_text)
    else
      []
    end
  end

  # Extract individual author names from a text containing multiple authors with credentials
  defp extract_individual_authors(author_text) do
    # More careful credential removal - only remove when preceded by comma or space
    cleaned_text = author_text
    |> String.replace(~r/,\s*(EdD|RN|IBCLC|BSN|BA|PhD|MD|Dr\.)\b/i, ",") # Remove credentials after comma
    |> String.replace(~r/\s+(EdD|RN|IBCLC|BSN|BA|PhD|MD|Dr\.)\b/i, " ") # Remove credentials after space
    |> String.replace(~r/,\s*,/, ",") # Clean up double commas
    |> String.replace(~r/\s+/, " ") # Normalize spaces
    |> String.trim()

    # Find all name patterns directly using regex
    # Look for "First Last" patterns throughout the text
    names = Regex.scan(~r/\b([A-Z][a-z]+)\s+([A-Z][a-z]+)\b/, cleaned_text)
    |> Enum.map(fn [_full, first, last] -> "#{first} #{last}" end)
    |> Enum.uniq()
    |> Enum.reject(fn name ->
      # Filter out non-author names (journal names, etc.)
      Regex.match?(~r/(Hum|Lact|Predicting|Breastfeeding|Duration|LATCH|Assessment|Tool)/i, name)
    end)
    |> Enum.take(10) # Reasonable limit

    names
  end
  
  def extract_authors_from_text(_), do: []

  def parse_author_string(author_string) when is_binary(author_string) do
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
    
    if length(names) > 0 do
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
  end

  def create_upload_dir do
    File.mkdir_p!(@upload_dir)
  end

  def get_upload_path(filename) do
    Path.join(@upload_dir, filename)
  end

  def generate_filename(original_filename, user_id) do
    timestamp = System.system_time(:millisecond)
    ext = Path.extname(original_filename)
    base = 
      original_filename
      |> Path.basename(ext)
      |> String.replace(~r/[^a-zA-Z0-9]/, "_")
      |> String.slice(0, 50)
    
    "#{user_id}_#{timestamp}_#{base}#{ext}"
  end

  def extract_authors_from_metadata(metadata) when is_map(metadata) do
    case metadata["author"] do
      nil -> []
      author_string when is_binary(author_string) ->
        author_string
        |> String.split([",", ";", " and ", " & "])
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.take(10)
      _ -> []
    end
  end
  def extract_authors_from_metadata(_), do: []

  def extract_keywords_from_text(text) when is_binary(text) do
    lines = 
      text
      |> String.split("\n")
      |> Enum.take(50)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    # Look for explicit keywords section
    keyword_line = 
      lines
      |> Enum.find(&Regex.match?(~r/(keywords?|key\s+words?):?\s*/i, &1))

    result = case keyword_line do
      nil ->
        # Try to extract from subject-like terms or common academic keywords
        lines
        |> Enum.take(20)
        |> Enum.filter(&Regex.match?(~r/(breastfeeding|LATCH|assessment|tool|duration|prediction|research|study|analysis)/i, &1))
        |> Enum.map(&String.downcase/1)
        |> Enum.flat_map(fn line ->
          Regex.scan(~r/(breastfeeding|LATCH|assessment|tool|duration|prediction|research|study|analysis)/i, line)
          |> Enum.map(&List.first/1)
          |> Enum.map(&String.downcase/1)
        end)
        |> Enum.uniq()
        |> Enum.take(5)
        
      line ->
        line
        |> String.replace(~r/^.*?(keywords?|key\s+words?):?\s*/i, "")
        |> String.split([",", ";", ".", "\n"])
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.take(10)
    end

    # Ensure we return a clean list
    case result do
      list when is_list(list) -> list
      _ -> []
    end
  end
  def extract_keywords_from_text(_), do: []

  def extract_keywords_from_metadata(metadata) when is_map(metadata) do
    result = case metadata["keywords"] || metadata["subject"] do
      nil -> []
      keyword_string when is_binary(keyword_string) ->
        keyword_string
        |> String.split([",", ";", " "])
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.take(10)
      _ -> []
    end

    # Ensure we return a clean list
    case result do
      list when is_list(list) -> list
      _ -> []
    end
  end
  def extract_keywords_from_metadata(_), do: []

  # Fallback functions for when PDF tools aren't available
  def extract_title_from_filename(filename) do
    filename
    |> String.replace(["-", "_"], " ")
    |> remove_user_id_and_timestamp()
    |> remove_author_patterns()
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
    |> String.trim()
    |> case do
      "" -> nil
      title -> title
    end
  end

  def extract_authors_from_filename(filename) do
    # Clean filename and extract potential author names
    cleaned = filename
    |> String.replace(~r/^\d+_\d+_/, "")  # Remove user_id_timestamp
    |> String.replace(~r/\.pdf$/i, "")     # Remove extension
    |> String.replace(~r/_?\d{4}_?/, " ")  # Remove years
    
    cond do
      # Handle "et al" patterns - try to extract more authors before "et al"
      String.contains?(filename, "et_al") || String.contains?(filename, "et-al") ->
        extract_authors_before_et_al(cleaned)
      
      # Look for multiple author pattern: "Author1_Author2_Author3_..."
      true ->
        extract_multiple_authors_from_underscores(cleaned)
    end
  end

  defp extract_authors_before_et_al(cleaned) do
    # Try to find authors before "et al" pattern
    case Regex.run(~r/^([^_]+?)[\s_-]+(et[\s_-]al)/i, cleaned) do
      [_, authors_part, _] ->
        # Split the authors part and extract names
        authors_part
        |> String.split(["_", "-", " "])
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.filter(&Regex.match?(~r/^[A-Z][a-z]+$/i, &1))
        |> Enum.map(&String.capitalize/1)
        |> Enum.reject(&(&1 in ["Et", "Al", "And", "The", "Of", "On", "In", "For"]))
        |> Enum.take(4)  # Take up to 4 authors
      _ -> 
        # Fallback to simple pattern
        case Regex.run(~r/([A-Z][a-z]+)[\s_-]+(et[\s_-]al)/i, cleaned) do
          [_, first_author, _] -> [String.capitalize(first_author)]
          _ -> []
        end
    end
  end

  defp extract_multiple_authors_from_underscores(cleaned) do
    # Extract all potential author names from underscore-separated parts
    potential_authors = cleaned
    |> String.split(["_", "-", " "])
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.filter(fn part ->
      # Must be a capitalized word, not common non-author words
      Regex.match?(~r/^[A-Z][a-z]+$/i, part) && 
      String.length(part) >= 3 &&
      !Regex.match?(~r/^\d+$/i, part) &&
      !(part in ["The", "Of", "On", "In", "For", "And", "Or", "Et", "Al", "Predicting", "Study", "Analysis", "Paper", "Research"])
    end)
    |> Enum.map(&String.capitalize/1)
    |> Enum.uniq()
    |> Enum.take(4)  # Limit to 4 authors to be reasonable

    # Only return if we found at least one reasonable author
    case potential_authors do
      [] -> []
      authors -> authors
    end
  end

  defp remove_user_id_and_timestamp(filename) do
    filename
    # Remove file extension
    |> String.replace(~r/\.pdf$/i, "")
    # Remove patterns like "3_1758067959396_" (user_id_timestamp_)
    |> String.replace(~r/^\d+_\d+_/, "")
    # Remove standalone years
    |> String.replace(~r/_?\d{4}_?/, " ")
    # Remove isolated single digits and numbers
    |> String.replace(~r/(^|\s)\d+(\s|$)/, " ")
    # Clean up
    |> String.replace(~r/_+/, " ")
    |> String.replace(~r/\s+/, " ")
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
end