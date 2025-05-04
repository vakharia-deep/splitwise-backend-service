defmodule Splitwise.Repo.Migrations.CreateActivityLogs do
  use Ecto.Migration

  def change do
    create table(:activity_logs) do
      add :action, :string, null: false
      add :details, :map
      add :entity_type, :string
      add :entity_id, :integer
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :group_id, references(:groups, on_delete: :delete_all)
      add :expense_id, references(:expenses, on_delete: :delete_all)
      add :payment_id, references(:payments, on_delete: :delete_all)
      add :comment_id, references(:comments, on_delete: :delete_all)
      timestamps(type: :utc_datetime_usec)
    end

    create index(:activity_logs, [:user_id])
    create index(:activity_logs, [:group_id])
    create index(:activity_logs, [:expense_id])
    create index(:activity_logs, [:payment_id])
    create index(:activity_logs, [:comment_id])
    create index(:activity_logs, [:entity_type, :entity_id])
  end
end
