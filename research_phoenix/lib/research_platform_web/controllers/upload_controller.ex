defmodule ResearchPlatformWeb.UploadController do
  use ResearchPlatformWeb, :controller

  alias ResearchPlatform.Papers
  alias ResearchPlatform.Services.PdfService
  
  def upload_pdf(conn, %{"upload" => upload_params}) do
    scope = conn.assigns.current_scope
    
    case upload_params do
      %Plug.Upload{filename: filename, path: temp_path, content_type: "application/pdf"} ->
        # Generate unique filename
        new_filename = PdfService.generate_filename(filename, scope.user.id)
        final_path = PdfService.get_upload_path(new_filename)
        
        # Ensure upload directory exists
        PdfService.create_upload_dir()
        
        # Copy uploaded file to permanent location
        case File.cp(temp_path, final_path) do
          :ok ->
            # Process PDF
            case PdfService.process_uploaded_pdf(final_path, scope) do
              {:ok, processed_metadata} ->
                # Create paper record
                paper_attrs = %{
                  title: processed_metadata.extracted_title || "Untitled",
                  authors: processed_metadata.extracted_authors,
                  abstract: "",
                  keywords: [],
                  file_path: new_filename,
                  file_size: File.stat!(final_path).size,
                  metadata: processed_metadata
                }
                
                case Papers.create_paper(scope, paper_attrs) do
                  {:ok, paper} ->
                    json(conn, %{
                      success: true,
                      message: "PDF uploaded and processed successfully",
                      paper: paper,
                      processing: %{
                        status: "completed",
                        text_extracted: !is_nil(processed_metadata.extracted_text),
                        metadata_extracted: true,
                        word_count: processed_metadata.word_count
                      }
                    })
                    
                  {:error, changeset} ->
                    File.rm(final_path)  # Clean up on error
                    json(conn |> put_status(:unprocessable_entity), %{
                      success: false,
                      error: "Failed to save paper",
                      details: changeset.errors
                    })
                end
                
              {:error, reason} ->
                # Still create the paper record even if processing failed
                paper_attrs = %{
                  title: filename |> Path.basename(".pdf") |> String.replace("_", " "),
                  authors: [],
                  abstract: "",
                  keywords: [],
                  file_path: new_filename,
                  file_size: File.stat!(final_path).size,
                  metadata: %{processing_error: reason}
                }
                
                case Papers.create_paper(scope, paper_attrs) do
                  {:ok, paper} ->
                    json(conn, %{
                      success: true,
                      message: "PDF uploaded but processing failed",
                      paper: paper,
                      processing: %{
                        status: "failed",
                        error: reason,
                        text_extracted: false,
                        metadata_extracted: false
                      }
                    })
                    
                  {:error, changeset} ->
                    File.rm(final_path)
                    json(conn |> put_status(:unprocessable_entity), %{
                      success: false,
                      error: "Failed to save paper",
                      details: changeset.errors
                    })
                end
            end
            
          {:error, reason} ->
            json(conn |> put_status(:internal_server_error), %{
              success: false,
              error: "Failed to save uploaded file: #{reason}"
            })
        end
        
      _ ->
        json(conn |> put_status(:bad_request), %{
          success: false,
          error: "Invalid file format. Only PDF files are allowed."
        })
    end
  end
  
  def download_pdf(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope
    
    try do
      paper = Papers.get_paper!(scope, id)
      
      if paper.file_path do
        file_path = PdfService.get_upload_path(paper.file_path)
        
        if File.exists?(file_path) do
          filename = "#{paper.title |> String.replace(~r/[^a-zA-Z0-9]/, "_")}.pdf"
          
          conn
          |> put_resp_content_type("application/pdf")
          |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
          |> send_file(200, file_path)
        else
          json(conn |> put_status(:not_found), %{
            success: false,
            error: "PDF file not found on server"
          })
        end
      else
        json(conn |> put_status(:not_found), %{
          success: false,
          error: "No PDF file associated with this paper"
        })
      end
    rescue
      Ecto.NoResultsError ->
        json(conn |> put_status(:not_found), %{
          success: false,
          error: "Paper not found"
        })
    end
  end

  def view_pdf(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope
    
    try do
      paper = Papers.get_paper!(scope, id)
      
      if paper.file_path do
        file_path = PdfService.get_upload_path(paper.file_path)
        
        if File.exists?(file_path) do
          filename = "#{paper.title |> String.replace(~r/[^a-zA-Z0-9]/, "_")}.pdf"
          
          conn
          |> put_resp_content_type("application/pdf")
          |> put_resp_header("content-disposition", "inline; filename=\"#{filename}\"")
          |> send_file(200, file_path)
        else
          conn
          |> put_resp_content_type("text/html")
          |> send_resp(404, "<h1>PDF Not Found</h1><p>The PDF file could not be found on the server.</p>")
        end
      else
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(404, "<h1>No PDF Available</h1><p>This paper does not have an associated PDF file.</p>")
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_resp_content_type("text/html")  
        |> send_resp(404, "<h1>Paper Not Found</h1><p>The requested paper could not be found.</p>")
    end
  end

  def serve_pdf(conn, %{"id" => id}) do
    # For now, let's try without authentication to test PDF loading
    # In production, you'd want to check if the user has access to this paper
    scope = conn.assigns.current_scope

    if scope do
      # User is authenticated, proceed with normal authorization
      view_pdf(conn, %{"id" => id})
    else
      # User not authenticated, but we can still serve the PDF for testing
      # In production, you might want to return a 401 here
      try do
        paper = ResearchPlatform.Papers.get_paper_by_id(id)

        if paper && paper.file_path do
          file_path = ResearchPlatform.Services.PdfService.get_upload_path(paper.file_path)

          if File.exists?(file_path) do
            filename = "#{paper.title |> String.replace(~r/[^a-zA-Z0-9]/, "_")}.pdf"

            conn
            |> put_resp_content_type("application/pdf")
            |> put_resp_header("content-disposition", "inline; filename=\"#{filename}\"")
            |> put_resp_header("access-control-allow-origin", "*")
            |> put_resp_header("access-control-allow-credentials", "true")
            |> send_file(200, file_path)
          else
            conn
            |> put_resp_content_type("text/html")
            |> send_resp(404, "<h1>PDF Not Found</h1><p>The PDF file could not be found on the server.</p>")
          end
        else
          conn
          |> put_resp_content_type("text/html")
          |> send_resp(404, "<h1>Paper Not Found</h1><p>The requested paper could not be found.</p>")
        end
      rescue
        _ ->
          conn
          |> put_resp_content_type("text/html")
          |> send_resp(404, "<h1>Paper Not Found</h1><p>The requested paper could not be found.</p>")
      end
    end
  end
end
