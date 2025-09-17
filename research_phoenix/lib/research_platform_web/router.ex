defmodule ResearchPlatformWeb.Router do
  use ResearchPlatformWeb, :router

  import ResearchPlatformWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ResearchPlatformWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ResearchPlatformWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # API routes for file uploads
  scope "/api", ResearchPlatformWeb do
    pipe_through [:browser, :require_authenticated_user]
    
    post "/papers/upload", UploadController, :upload_pdf
    get "/papers/:id/download", UploadController, :download_pdf
    get "/papers/:id/view", UploadController, :view_pdf
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:research_platform, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ResearchPlatformWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", ResearchPlatformWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", ResearchPlatformWeb do
    pipe_through [:browser, :require_authenticated_user]

    live "/papers", PaperLive.Index, :index
    live "/papers/new", PaperLive.Form, :new
    live "/papers/:id", PaperLive.Show, :show
    live "/papers/:id/viewer", PaperLive.Viewer, :viewer
    live "/papers/:id/edit", PaperLive.Form, :edit

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", ResearchPlatformWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
