defmodule Splitwise.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments) do
      add :content, :string, null: false
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :expense_id, references(:expenses, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:comments, [:user_id])
    create index(:comments, [:expense_id])
  end
end
