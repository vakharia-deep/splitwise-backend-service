defmodule Splitwise.ActivityLogs.ActivityLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_logs" do
    field :action, :string
    field :details, :map
    field :entity_type, :string
    field :entity_id, :integer

    belongs_to :user, Splitwise.Accounts.User
    belongs_to :group, Splitwise.Accounts.Group
    belongs_to :expense, Splitwise.Expenses.Expense
    belongs_to :payment, Splitwise.Payments.Payment
    belongs_to :comment, Splitwise.Expenses.Comment

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(activity_log, attrs) do
    activity_log
    |> cast(attrs, [
      :action,
      :details,
      :entity_type,
      :entity_id,
      :user_id,
      :group_id,
      :expense_id,
      :payment_id,
      :comment_id
    ])
    |> validate_required([:action, :user_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:group_id)
    |> foreign_key_constraint(:expense_id)
    |> foreign_key_constraint(:payment_id)
    |> foreign_key_constraint(:comment_id)
  end
end
