# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Splitwise.Repo.insert!(%Splitwise.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Splitwise.Accounts

# Create sample users with all required fields
users = [
  %{
    email: "john@example.com",
    name: "John Doe",
    password_hash: "password123",
    api_key: "c94e9832-6422-4131-b73c-4955ae40eeb6",
    api_key_expires_at: DateTime.add(DateTime.utc_now(), 30, :day),
    inserted_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now()
  },
  %{
    email: "jane@example.com",
    name: "Jane Smith",
    password_hash: "password123",
    api_key: "2e4e9ee9-b3e4-4878-bfbb-b6d3c4e13802",
    api_key_expires_at: DateTime.add(DateTime.utc_now(), 30, :day),
    inserted_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now()
  },
  %{
    email: "bob@example.com",
    name: "Bob Johnson",
    password_hash: "password123",
    api_key: "b909a804-9602-49d2-825e-69950b4475ba",
    api_key_expires_at: DateTime.add(DateTime.utc_now(), 30, :day),
    inserted_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now()
  },
  %{
    email: "alice@example.com",
    name: "Alice Brown",
    password_hash: "password123",
    api_key: "d92706b7-fd4b-4055-a665-20a893dcdf22",
    api_key_expires_at: DateTime.add(DateTime.utc_now(), 30, :day),
    inserted_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now()
  },
  %{
    email: "charlie@example.com",
    name: "Charlie Wilson",
    password_hash: "password123",
    api_key: "bb2ce2ed-5bd1-49ba-8304-c5756d38f132",
    api_key_expires_at: DateTime.add(DateTime.utc_now(), 30, :day),
    inserted_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now()
  }
]

# Insert users and handle any errors
Enum.each(users, fn user_attrs ->
  case Accounts.create_user_default(user_attrs) do
    {:ok, user} ->
      IO.puts("Created user: #{user.email}")

    {:error, changeset} ->
      IO.puts("Error creating user #{user_attrs.email}: #{inspect(changeset.errors)}")
  end
end)

IO.puts("User seed data creation completed!")
