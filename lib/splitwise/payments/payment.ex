defmodule Splitwise.Payments.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ["pending", "completed"]

  schema "payments" do
    field :amount, :float
    field :status, :string, default: "pending"
    field :transaction_id, :string

    belongs_to :from_user, Splitwise.Accounts.User
    belongs_to :to_user, Splitwise.Accounts.User
    belongs_to :expense_share, Splitwise.Expenses.ExpenseShare
    has_many :activity_logs, Splitwise.ActivityLogs.ActivityLog

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [
      :amount,
      :status,
      :transaction_id,
      :from_user_id,
      :to_user_id,
      :expense_share_id
    ])
    |> validate_required([:amount, :from_user_id, :to_user_id])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:transaction_id)
    |> foreign_key_constraint(:from_user_id)
    |> foreign_key_constraint(:to_user_id)
    |> foreign_key_constraint(:expense_share_id)
  end
end
