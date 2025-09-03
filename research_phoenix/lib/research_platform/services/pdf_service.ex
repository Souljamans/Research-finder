defmodule ResearchPlatform.Services.PdfService do
  @moduledoc """
  Service for PDF processing including text extraction and metadata parsing.
  Uses external tools like pdftotext and pdfinfo for processing.
  """

  alias ResearchPlatform.Papers

  @upload_dir "priv/static/uploads/pdfs"
  
  def process_uploaded_pdf(file_path, user_scope) do
    with {:ok, text} <- extract_text(file_path),
         {:ok, metadata} <- extract_metadata(file_path) do
      
      processed_metadata = %{
        extracted_text: text,
        word_count: estimate_word_count(text),
        extracted_title: extract_title_from_text(text),
        extracted_authors: extract_authors_from_text(text),
        pdf_metadata: metadata,
        processed_at: DateTime.utc_now()
      }
      
      {:ok, processed_metadata}
    else
      {:error, reason} -> {:error, "Failed to process PDF: #{reason}"}
    end
  end

  def extract_text(file_path) do
    case Rambo.run("pdftotext", ["-layout", file_path, "-"], log: false) do
      {:ok, %{out: text, status: 0}} ->
        {:ok, String.trim(text)}
      
      {:ok, %{status: status}} ->
        {:error, "pdftotext failed with status #{status}"}
        
      {:error, reason} ->
        # Fallback: try without -layout option
        case Rambo.run("pdftotext", [file_path, "-"], log: false) do
          {:ok, %{out: text, status: 0}} ->
            {:ok, String.trim(text)}
          _ ->
            {:error, "pdftotext not available: #{reason}"}
        end
    end
  end

  def extract_metadata(file_path) do
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
      |> Enum.take(10)

    Enum.find_value(lines, fn line ->
      cond do
        String.length(line) > 10 and String.length(line) < 200 ->
          # Skip lines that look like headers or page numbers
          unless Regex.match?(~r/^(abstract|introduction|\d+\.?\s|[A-Z\s]{10,}$)/i, line) do
            line
          end
        true ->
          nil
      end
    end)
  end
  
  def extract_title_from_text(_), do: nil

  def extract_authors_from_text(text) when is_binary(text) do
    lines = 
      text
      |> String.split("\n")
      |> Enum.take(20)
      |> Enum.map(&String.trim/1)

    author_patterns = [
      ~r/^([A-Z][a-z]+ [A-Z][a-z]+(?:,?\s*(?:and\s+|&\s*)?[A-Z][a-z]+ [A-Z][a-z]+)*)/,
      ~r/^([A-Z]\.\s*[A-Z][a-z]+(?:,?\s*(?:and\s+|&\s*)?[A-Z]\.\s*[A-Z][a-z]+)*)/,
      ~r/By:?\s+([A-Z][a-z]+ [A-Z][a-z]+(?:,?\s*(?:and\s+|&\s*)?[A-Z][a-z]+ [A-Z][a-z]+)*)/i
    ]

    Enum.find_value(lines, fn line ->
      Enum.find_value(author_patterns, fn pattern ->
        case Regex.run(pattern, line) do
          [_full_match, author_string] ->
            author_string
            |> String.split(~r/,|\band\b|&/)
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(String.length(&1) < 4))
            |> Enum.filter(&Regex.match?(~r/^[A-Z]/, &1))
            |> Enum.take(10)
            |> case do
              [] -> nil
              authors -> authors
            end
          _ -> nil
        end
      end)
    end) || []
  end
  
  def extract_authors_from_text(_), do: []

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
end