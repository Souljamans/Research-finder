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
    # Create the user with email and username first
    {:ok, user} = Accounts.register_user(%{email: test_email, username: test_username})
    
    # Add password to the user
    {:ok, {user_with_password, _tokens}} = 
      Accounts.update_user_password(user, %{password: test_password})
    
    # Confirm the user (skip email confirmation)
    confirmed_user = 
      user_with_password
      |> User.confirm_changeset()
      |> Repo.update!()
    
    IO.puts("✅ Created test admin user:")
    IO.puts("   Username: #{test_username}")
    IO.puts("   Email: #{test_email}")
    IO.puts("   Password: #{test_password}")
    IO.puts("   Status: Confirmed and ready to use")
    
  %User{} ->
    IO.puts("ℹ️  Test admin user already exists:")
    IO.puts("   Username: #{test_username}")
    IO.puts("   Email: #{test_email}")
    IO.puts("   Password: #{test_password}")
end
