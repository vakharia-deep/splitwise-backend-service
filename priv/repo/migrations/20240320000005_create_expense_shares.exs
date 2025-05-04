defmodule Splitwise.Repo.Migrations.CreateExpenseShares do
  use Ecto.Migration

  def change do
    create table(:expense_shares) do
      add :amount, :float, null: false
      add :remaining_amount, :float, null: false
      add :status, :string, default: "pending"
      add :expense_id, references(:expenses, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :share_percentage, :float, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:expense_shares, [:expense_id])
    create index(:expense_shares, [:user_id])
  end
end
