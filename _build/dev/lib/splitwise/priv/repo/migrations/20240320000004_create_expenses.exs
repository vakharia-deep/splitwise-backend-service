defmodule Splitwise.Repo.Migrations.CreateExpenses do
  use Ecto.Migration

  def change do
    create table(:expenses) do
      add :description, :string, null: false
      add :amount, :float, null: false
      add :date, :date, null: false
      add :status, :string, default: "pending"
      add :paid_by_id, references(:users, on_delete: :nothing), null: false
      add :added_by_id, references(:users, on_delete: :nothing), null: false
      add :group_id, references(:groups, on_delete: :nothing)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:expenses, [:paid_by_id])
    create index(:expenses, [:added_by_id])
    create index(:expenses, [:group_id])
  end
end
