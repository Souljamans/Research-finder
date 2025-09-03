defmodule ResearchPlatformWeb.UserSessionHTML do
  use ResearchPlatformWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:research_platform, ResearchPlatform.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
