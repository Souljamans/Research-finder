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
    # Create user directly using proper changesets
    user_attrs = %{
      email: test_email,
      username: test_username
    }
    
    # First create user with email/username
    case Accounts.register_user(user_attrs) do
      {:ok, user} ->
        # Then set the password
        case Accounts.update_user_password(user, %{password: test_password}) do
          {:ok, {user_with_password, _tokens}} ->
            # Confirm the user (skip email confirmation)
            _confirmed_user = 
              user_with_password
              |> User.confirm_changeset()
              |> Repo.update!()
            
            IO.puts("✅ Created test admin user:")
            IO.puts("   Username: #{test_username}")
            IO.puts("   Email: #{test_email}")
            IO.puts("   Password: #{test_password}")
            IO.puts("   Status: Confirmed and ready to use")
            
          {:error, password_changeset} ->
            IO.puts("❌ Failed to set password: #{inspect(password_changeset.errors)}")
        end
        
      {:error, changeset} ->
        IO.puts("❌ Failed to create user: #{inspect(changeset.errors)}")
    end
    
  %User{} ->
    IO.puts("ℹ️  Test admin user already exists:")
    IO.puts("   Username: #{test_username}")
    IO.puts("   Email: #{test_email}")
    IO.puts("   Password: #{test_password}")
end
