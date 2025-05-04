defmodule Splitwise.Repo.Migrations.CreatePayments do
  use Ecto.Migration

  def change do
    create table(:payments) do
      add :amount, :float, null: false
      add :status, :string, default: "pending"
      add :transaction_id, :string
      add :from_user_id, references(:users, on_delete: :delete_all), null: false
      add :to_user_id, references(:users, on_delete: :delete_all), null: false
      add :expense_share_id, references(:expense_shares, on_delete: :delete_all)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:payments, [:transaction_id])
    create index(:payments, [:from_user_id])
    create index(:payments, [:to_user_id])
    create index(:payments, [:expense_share_id])
  end
end
