defmodule Splitwise.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :name, :string
    field :password_hash, :string
    field :api_key, Ecto.UUID
    field :api_key_expires_at, :utc_datetime

    many_to_many :groups, Splitwise.Accounts.Group, join_through: "group_members"
    has_many :expenses_paid, Splitwise.Expenses.Expense, foreign_key: :paid_by_id
    has_many :expenses_added, Splitwise.Expenses.Expense, foreign_key: :added_by_id
    has_many :expense_shares, Splitwise.Expenses.ExpenseShare
    has_many :payments_sent, Splitwise.Payments.Payment, foreign_key: :from_user_id
    has_many :payments_received, Splitwise.Payments.Payment, foreign_key: :to_user_id
    has_many :comments, Splitwise.Expenses.Comment
    has_many :activity_logs, Splitwise.ActivityLogs.ActivityLog

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :password_hash, :api_key, :api_key_expires_at])
    |> validate_required([:email, :name, :password_hash, :api_key, :api_key_expires_at])
    |> unique_constraint(:email)
  end
end
