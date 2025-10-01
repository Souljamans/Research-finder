defmodule ResearchPlatform.Services.PdfService do
  @moduledoc """
  Service for PDF processing including text extraction and metadata parsing.
  Uses external tools like pdftotext and pdfinfo for processing.
  """


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
          extracted_title: get_best_title(metadata["title"], text),
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
          extracted_title: get_best_title(metadata["title"], ""),
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
      |> Enum.take(25)

    # Skip common header lines that aren't titles
    filtered_lines = lines
    |> Enum.reject(fn line ->
      # Skip journal names, EBSCO headers, page numbers, etc.
      Regex.match?(~r/^(J\s+Hum\s+Lact|Journal|EBSCO|Full\s*text|EBSCOhost|\d+$|page\s+\d+|vol\.|volume)/i, line) ||
      # Skip university/institutional headers
      Regex.match?(~r/(university|college|school|library|database|accessed|downloaded)/i, line) ||
      # Skip very short lines (likely not titles)
      String.length(line) < 4 ||
      # Skip lines that are purely numbers or dates
      Regex.match?(~r/^\d+[\d\s\-\/]*$/, line) ||
      # Skip lines with just initials or short codes
      Regex.match?(~r/^[A-Z]{2,4}[\d\s]*$/, line)
    end)

    # Look for title candidates - lines that could be titles
    title_candidates = filtered_lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, index} ->
      # Good title indicators:
      # - Not author names (which typically have credentials or comma patterns)
      !Regex.match?(~r/^[A-Z][a-z]+,\s*[A-Z]/i, line) && # Not "Name, First"
      !Regex.match?(~r/(EdD|RN|IBCLC|BSN|BA|MA|PhD|MD|Dr\.)/i, line) && # No credentials
      !Regex.match?(~r/\bet\s+al\b/i, line) && # Not "et al"
      !Regex.match?(~r/^Abstract\b/i, line) && # Not "Abstract"
      # Should be substantial text
      String.length(line) >= 8 &&
      String.length(line) <= 200 &&
      # Should contain some lowercase (mixed case suggests title)
      Regex.match?(~r/[a-z]/, line) &&
      # Prefer lines in first 20 positions (expanded from 15)
      index < 20 &&
      # Should look like title content (contains meaningful words)
      title_like_content?(line) &&
      # Allow "artificial intelligence" etc. when they appear in title context
      # (but still filter out pure author name patterns)
      !appears_to_be_pure_author_line?(line)
    end)
    |> Enum.map(fn {line, index} -> {line, index} end)

    # Find the best title candidate
    case title_candidates do
      [] ->
        # Fallback - take the first substantial line that's not obviously metadata
        filtered_lines
        |> Enum.find(fn line ->
          String.length(line) >= 10 && String.length(line) <= 200 &&
          Regex.match?(~r/[a-z]/, line) &&
          !Regex.match?(~r/^\d+$/, line)
        end)

      [{single_line, _index}] ->
        clean_title(single_line)

      multiple_candidates ->
        # Take the first substantial candidate, or combine if they seem related
        [{first_line, first_index} | rest] = multiple_candidates

        # Look for continuation lines that could be part of a multi-line title
        potential_continuations = rest
        |> Enum.take_while(fn {_line, index} ->
          # Allow for slightly non-consecutive lines (gaps for formatting)
          index <= first_index + 3
        end)
        |> Enum.filter(fn {line, _index} ->
          # Continuation lines should also look like title content
          title_like_content?(line) &&
          !Regex.match?(~r/(EdD|RN|IBCLC|BSN|BA|MA|PhD|MD|Dr\.)/i, line) &&
          !Regex.match?(~r/^[A-Z][a-z]+,\s*[A-Z]/i, line)
        end)
        |> Enum.map(fn {line, _index} -> line end)

        # Combine lines that seem to be part of the same title
        all_title_parts = [first_line | potential_continuations]
        combined_title = Enum.join(all_title_parts, " ")

        if String.length(combined_title) <= 300 && String.length(combined_title) >= String.length(first_line) do
          clean_title(combined_title)
        else
          clean_title(first_line)
        end
    end
  end

  defp title_like_content?(line) do
    # Check if line contains words that typically appear in titles
    word_count = String.split(line, ~r/\s+/) |> length()

    # Should have multiple words (2 or more)
    word_count >= 2 &&
    # Contains common title words or patterns
    (Regex.match?(~r/(the|impact|of|on|for|in|and|or|with|from|to|a|an|analysis|study|research|effect|effects|influence|role|using|toward|towards|approach|method|case|review|survey|investigation|examination|assessment|evaluation|comparison|development|implementation|application|framework|model|system|strategy|policy|management|design|optimization|enhancement|improvement|innovation|technology|artificial|intelligence|machine|learning|data|digital|smart|automation|future|trends|challenges|opportunities|risks|benefits|solutions|issues|problems|factors|considerations|implications|consequences|outcomes|results|findings|insights|perspectives|aspects|dimensions|elements|components|features|characteristics|properties|attributes|qualities|principles|concepts|theories|approaches|methods|techniques|strategies|practices|tools|instruments|measures|metrics|indicators|criteria|standards|guidelines|recommendations|best|practices|lessons|learned|job|loss|labor|market|government|governments|economic|economy|social|society|human|work|employment|unemployment|skills|training|education|technological|transformation|disruption|evolution|change|predicting|breastfeeding|duration|latch|assessment|tool|maternal|infant|newborn|feeding|lactation|birth|pregnancy|postpartum|clinical|hospital|healthcare|health|care|medical|nursing|patient|women|mother|baby|child|pediatric|obstetric|intervention|outcome|score|scale|validity|reliability|predictive|predictors|factors|associated|correlation|relationship)/i, line) ||
    # Or contains technical/academic terms
    Regex.match?(~r/(algorithm|analysis|application|approach|assessment|challenges|comparison|component|concept|conclusion|consideration|contribution|decision|development|discussion|effect|evaluation|examination|finding|framework|implication|implementation|improvement|investigation|limitation|management|method|model|optimization|outcome|perspective|policy|potential|problem|process|proposal|recommendation|research|result|review|solution|strategy|study|survey|system|technology|theory|tool)/i, line))
  end

  defp appears_to_be_pure_author_line?(line) do
    # Check if this looks like a pure author line (names with credentials)
    Regex.match?(~r/^[A-Z][a-z]+\s+[A-Z][a-z]+(\s+[A-Z][a-z]+)*,?\s*(EdD|RN|IBCLC|BSN|BA|MA|PhD|MD|Dr\.)/i, line) ||
    # Or starts with author name pattern followed by comma
    Regex.match?(~r/^[A-Z][a-z]+,\s*[A-Z]/i, line)
  end

  defp get_best_title(metadata_title, text) do
    case metadata_title do
      title when is_binary(title) and title != "" ->
        # Use metadata title if it's a non-empty string
        title
      _ ->
        # Fall back to text extraction
        extract_title_from_text(text) || "Untitled"
    end
  end

  defp clean_title(title) when is_binary(title) do
    title
    |> String.replace(~r/\s+/, " ")  # Normalize whitespace
    |> String.replace(~r/^\W+|\W+$/, "")  # Remove leading/trailing non-word chars
    |> String.trim()
    |> case do
      "" -> nil
      cleaned -> cleaned
    end
  end

  def extract_title_from_text(_), do: nil

  def extract_authors_from_text(text) when is_binary(text) do
    lines =
      text
      |> String.split("\n")
      |> Enum.take(30)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    # Filter out lines that are clearly not authors
    filtered_lines = lines
    |> Enum.reject(fn line ->
      # Skip journal names, EBSCO headers, institutions, etc.
      Regex.match?(~r/^(J\s+Hum\s+Lact|Journal|EBSCO|Full\s*text|EBSCOhost|University|College|School|Library|Database|Abstract)/i, line) ||
      # Skip very short or very long lines
      String.length(line) < 4 || String.length(line) > 150 ||
      # Skip lines that are purely numbers, dates, or codes
      Regex.match?(~r/^\d+[\d\s\-\/]*$/, line) ||
      # Skip common non-author patterns
      Regex.match?(~r/^(page|vol\.|volume|issue|doi:|accessed|downloaded|available|from:)/i, line)
    end)

    # Strategy 1: Lines with academic credentials
    credential_lines = filtered_lines
    |> Enum.filter(fn line ->
      # Contains names with credentials but not title/journal words
      Regex.match?(~r/[A-Z][a-z]+\s+[A-Z][a-z]+.*(?:EdD|RN|IBCLC|BSN|BA|MA|PhD|MD|Dr\.)/i, line) &&
      !contains_non_author_keywords?(line)
    end)

    # Strategy 2: Lines that look like author name lists (comma-separated names)
    name_list_lines = filtered_lines
    |> Enum.filter(fn line ->
      # Contains comma-separated patterns that look like names
      name_count = Regex.scan(~r/[A-Z][a-z]+\s+[A-Z][a-z]+/, line) |> length()
      comma_count = String.graphemes(line) |> Enum.count(&(&1 == ","))

      name_count >= 1 && comma_count >= 1 && name_count >= comma_count &&
      !contains_non_author_keywords?(line) &&
      # Not purely institutional (like "University of Michigan, Department of...")
      !Regex.match?(~r/(university|college|school|department|center|institute)/i, line)
    end)

    # Strategy 3: Lines after title that contain proper names
    title_found_index = filtered_lines
    |> Enum.find_index(fn line ->
      # A substantial line that could be a title
      String.length(line) >= 15 && String.length(line) <= 200 &&
      Regex.match?(~r/[a-z]/, line) &&
      !Regex.match?(~r/(EdD|RN|IBCLC|BSN|BA|MA|PhD|MD|Dr\.)/i, line)
    end)

    post_title_authors = case title_found_index do
      nil -> []
      index when index < length(filtered_lines) - 1 ->
        filtered_lines
        |> Enum.drop(index + 1)
        |> Enum.take(5)  # Check next 5 lines after title
        |> Enum.filter(fn line ->
          # Look for lines with proper names that could be authors
          name_count = Regex.scan(~r/[A-Z][a-z]+\s+[A-Z][a-z]+/, line) |> length()
          name_count >= 1 && name_count <= 6 &&  # Reasonable author count
          !contains_non_author_keywords?(line) &&
          String.length(line) >= 8 && String.length(line) <= 120
        end)
      _ -> []
    end

    # Combine all potential author lines
    all_author_candidates = (credential_lines ++ name_list_lines ++ post_title_authors) |> Enum.uniq()

    # Extract authors from the best candidates
    case all_author_candidates do
      [] ->
        # Fallback: look for any decent name patterns in the first 20 lines
        extract_fallback_authors(filtered_lines |> Enum.take(20))

      candidates ->
        candidates
        |> Enum.flat_map(&extract_individual_authors/1)
        |> Enum.uniq()
        |> Enum.take(8)  # Reasonable limit
    end
  end

  def extract_authors_from_text(_), do: []

  defp contains_non_author_keywords?(line) do
    Regex.match?(~r/(predicting|breastfeeding|duration|latch|assessment|tool|abstract|study|research|analysis|conclusion|introduction|method|result|discussion|journal|volume|issue|page|artificial|intelligence|machine|learning|impact|government|job|loss|risk)/i, line)
  end

  defp extract_fallback_authors(lines) do
    lines
    |> Enum.flat_map(fn line ->
      # Extract any reasonable name patterns
      Regex.scan(~r/\b([A-Z][a-z]+)\s+([A-Z][a-z]+)\b/, line)
      |> Enum.map(fn [_full, first, last] -> "#{first} #{last}" end)
    end)
    |> Enum.reject(fn name ->
      # Filter out obvious non-names
      contains_non_author_keywords?(name) ||
      Regex.match?(~r/(Full|Text|Human|Lactation|Journal|Page|Vol|Issue|Artificial|Intelligence|Machine|Learning|Data|Science|Computer|Technology|Digital|System|Model|Algorithm|Information|Knowledge)/i, name) ||
      is_common_non_name_combination?(name)
    end)
    |> Enum.uniq()
    |> Enum.take(4)
  end

  # Extract individual author names from a text containing multiple authors with credentials
  defp extract_individual_authors(author_text) do
    # More careful credential removal - only remove when preceded by comma or space
    cleaned_text = author_text
    |> String.replace(~r/,\s*(EdD|RN|IBCLC|BSN|BA|MA|PhD|MD|Dr\.)\b/i, ",") # Remove credentials after comma
    |> String.replace(~r/\s+(EdD|RN|IBCLC|BSN|BA|MA|PhD|MD|Dr\.)\b/i, " ") # Remove credentials after space
    |> String.replace(~r/,\s*,/, ",") # Clean up double commas
    |> String.replace(~r/\s+/, " ") # Normalize spaces
    |> String.trim()

    # Find all name patterns directly using regex
    # Look for "First Last" patterns throughout the text
    names = Regex.scan(~r/\b([A-Z][a-z]+)\s+([A-Z][a-z]+)\b/, cleaned_text)
    |> Enum.map(fn [_full, first, last] -> "#{first} #{last}" end)
    |> Enum.uniq()
    |> Enum.reject(fn name ->
      # Filter out non-author names (journal names, institutional names, common terms, etc.)
      contains_non_author_keywords?(name) ||
      Regex.match?(~r/(Full|Text|Human|Lactation|Journal|Page|Vol|Issue|EBSCO|University|College|School|Library|Database|Artificial|Intelligence|Machine|Learning|Neural|Network|Data|Science|Computer|Technology|Digital|System|Model|Algorithm|Information|Knowledge)/i, name) ||
      # Filter out common non-name combinations
      is_common_non_name_combination?(name)
    end)
    |> Enum.take(8) # Reasonable limit

    names
  end

  defp is_common_non_name_combination?(name) do
    # Common patterns that aren't names
    common_terms = [
      "Artificial Intelligence", "Machine Learning", "Deep Learning", "Neural Network",
      "Data Science", "Computer Science", "Information Technology", "Digital Transformation",
      "Business Intelligence", "Social Media", "Public Policy", "Human Resources",
      "Quality Control", "Risk Management", "Project Management", "Change Management",
      "United States", "New York", "San Francisco", "Los Angeles", "United Kingdom",
      "North America", "South America", "Middle East", "Southeast Asia",
      "Research Paper", "Case Study", "White Paper", "Technical Report",
      "Executive Summary", "Literature Review", "Systematic Review", "Meta Analysis"
    ]

    Enum.any?(common_terms, fn term -> String.downcase(name) == String.downcase(term) end)
  end

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