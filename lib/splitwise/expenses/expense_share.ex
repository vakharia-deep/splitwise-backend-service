defmodule Splitwise.Expenses.ExpenseShare do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ["pending", "settled"]

  schema "expense_shares" do
    field :amount, :float
    field :remaining_amount, :float
    field :status, :string, default: "pending"
    field :share_percentage, :float

    belongs_to :expense, Splitwise.Expenses.Expense
    belongs_to :user, Splitwise.Accounts.User
    has_many :payments, Splitwise.Payments.Payment

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(expense_share, attrs) do
    expense_share
    |> cast(attrs, [:amount, :remaining_amount, :status, :expense_id, :user_id, :share_percentage])
    |> validate_required([:amount, :remaining_amount, :expense_id, :user_id, :share_percentage])
    |> validate_inclusion(:status, @statuses)
    |> validate_share_percentage()
    |> foreign_key_constraint(:expense_id)
    |> foreign_key_constraint(:user_id)
  end

  defp validate_share_percentage(changeset) do
    case get_change(changeset, :share_percentage) do
      nil ->
        changeset

      percentage when is_float(percentage) or is_integer(percentage) ->
        cond do
          percentage < 0 ->
            add_error(changeset, :share_percentage, "must be between 0 and 1")

          percentage > 1 ->
            add_error(changeset, :share_percentage, "must be between 0 and 1")

          true ->
            changeset
        end

      _ ->
        add_error(changeset, :share_percentage, "must be a number")
    end
  end
end
