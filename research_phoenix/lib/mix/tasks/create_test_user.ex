defmodule Mix.Tasks.CreateTestUser do
  use Mix.Task

  @shortdoc "Creates a test user for development"
  
  def run(_args) do
    Mix.Task.run("app.start")
    
    # Create a test user directly in the database
    user_attrs = %{
      username: "testuser",
      email: "test@example.com", 
      password_hash: "$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/lewdBX7gowQN7S1jG", # "testpassword123"
      confirmed_at: DateTime.utc_now(:second)
    }
    
    case ResearchPlatform.Repo.insert(%ResearchPlatform.Accounts.User{} |> struct(user_attrs)) do
      {:ok, user} ->
        IO.puts("✅ Test user created successfully!")
        IO.puts("   Username: testuser")
        IO.puts("   Email: test@example.com") 
        IO.puts("   Password: testpassword123")
        IO.puts("   User ID: #{user.id}")
        
      {:error, changeset} ->
        IO.puts("❌ Failed to create test user:")
        IO.inspect(changeset.errors)
    end
  end
end