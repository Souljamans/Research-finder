defmodule ResearchPlatformWeb.PageController do
  use ResearchPlatformWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
