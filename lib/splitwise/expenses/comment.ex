defmodule Splitwise.Expenses.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :content, :string

    belongs_to :user, Splitwise.Accounts.User
    belongs_to :expense, Splitwise.Expenses.Expense
    has_many :activity_logs, Splitwise.ActivityLogs.ActivityLog

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:content, :user_id, :expense_id])
    |> validate_required([:content, :user_id, :expense_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:expense_id)
  end
end
