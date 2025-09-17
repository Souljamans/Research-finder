# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     ResearchPlatform.Repo.insert!(%ResearchPlatform.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias ResearchPlatform.Accounts
alias ResearchPlatform.Accounts.User
alias ResearchPlatform.Repo

# Create a test admin user
test_email = "admin@test.com"
test_username = "admin"
test_password = "adminpassword123"

# Check if user already exists
case Accounts.get_user_by_email(test_email) do
  nil ->
    # Create and hash the password
    hashed_password = Bcrypt.hash_pwd_salt(test_password)
    
    # Create user directly with all fields
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    user_changeset = %User{
      username: test_username,
      email: test_email,
      hashed_password: hashed_password,
      confirmed_at: now,
      inserted_at: now,
      updated_at: now
    }
    
    case Repo.insert(user_changeset) do
      {:ok, _user} ->
        IO.puts("✅ Created test admin user:")
        IO.puts("   Username: #{test_username}")
        IO.puts("   Email: #{test_email}")
        IO.puts("   Password: #{test_password}")
        IO.puts("   Status: Confirmed and ready to use")
        
      {:error, changeset} ->
        IO.puts("❌ Failed to create user: #{inspect(changeset.errors)}")
    end
    
  %User{} ->
    IO.puts("ℹ️  Test admin user already exists:")
    IO.puts("   Username: #{test_username}")
    IO.puts("   Email: #{test_email}")
    IO.puts("   Password: #{test_password}")
end
