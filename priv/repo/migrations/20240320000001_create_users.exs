defmodule Splitwise.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :name, :string, null: false
      add :password_hash, :string, null: false
      add :api_key, :uuid
      add :api_key_expires_at, :utc_datetime

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:api_key])
    create index(:users, [:api_key_expires_at])
  end
end
