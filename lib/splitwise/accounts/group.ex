defmodule Splitwise.Accounts.Group do
  use Ecto.Schema
  import Ecto.Changeset

  schema "groups" do
    field :name, :string
    field :description, :string

    many_to_many :users, Splitwise.Accounts.User, join_through: "group_members"
    has_many :expenses, Splitwise.Expenses.Expense
    has_many :activity_logs, Splitwise.ActivityLogs.ActivityLog

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(group, attrs) do
    group
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
