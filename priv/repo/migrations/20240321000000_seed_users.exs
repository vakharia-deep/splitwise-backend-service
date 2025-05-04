defmodule Splitwise.Repo.Migrations.SeedUsers do
  use Ecto.Migration

  def up do
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

    # Insert users directly into the database
    Enum.each(users, fn user ->
      execute """
      INSERT INTO users (email, name, password_hash, api_key, api_key_expires_at, inserted_at, updated_at)
      VALUES (
        '#{user.email}',
        '#{user.name}',
        '#{user.password_hash}',
        '#{user.api_key}',
        '#{user.api_key_expires_at}',
        '#{user.inserted_at}',
        '#{user.updated_at}'
      )
      ON CONFLICT (email) DO NOTHING;
      """
    end)
  end

  def down do
    # Remove the seeded users
    execute """
    DELETE FROM users
    WHERE email IN (
      'john@example.com',
      'jane@example.com',
      'bob@example.com',
      'alice@example.com',
      'charlie@example.com'
    );
    """
  end
end
