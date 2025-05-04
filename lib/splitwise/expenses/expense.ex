defmodule Splitwise.Expenses.Expense do
  use Ecto.Schema
  import Ecto.Changeset

  @status ["pending", "settled"]

  schema "expenses" do
    field :description, :string
    field :amount, :float
    field :date, :date
    field :status, :string, default: "pending"

    belongs_to :paid_by, Splitwise.Accounts.User
    belongs_to :added_by, Splitwise.Accounts.User
    belongs_to :group, Splitwise.Accounts.Group, on_replace: :nilify
    has_many :expense_shares, Splitwise.Expenses.ExpenseShare
    has_many :comments, Splitwise.Expenses.Comment
    has_many :activity_logs, Splitwise.ActivityLogs.ActivityLog

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(
          {map(),
           %{
             optional(atom()) =>
               atom()
               | {:array | :assoc | :embed | :in | :map | :parameterized | :supertype | :try,
                  any()}
           }}
          | %{
              :__struct__ => atom() | %{:__changeset__ => map(), optional(any()) => any()},
              optional(atom()) => any()
            },
          :invalid | %{optional(:__struct__) => none(), optional(atom() | binary()) => any()}
        ) :: Ecto.Changeset.t()
  def changeset(expense, attrs) do
    expense
    |> cast(attrs, [:description, :amount, :date, :status, :paid_by_id, :added_by_id, :group_id])
    |> validate_required([:description, :amount, :date, :paid_by_id, :added_by_id, :group_id])
    |> validate_inclusion(:status, @status)
    |> foreign_key_constraint(:paid_by_id)
    |> foreign_key_constraint(:added_by_id)
    |> foreign_key_constraint(:group_id)
  end
end
