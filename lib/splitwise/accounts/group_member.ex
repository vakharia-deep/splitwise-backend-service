defmodule Splitwise.Accounts.GroupMember do
  use Ecto.Schema
  import Ecto.Changeset

  schema "group_members" do
    belongs_to :group, Splitwise.Accounts.Group
    belongs_to :user, Splitwise.Accounts.User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(group_member, attrs) do
    group_member
    |> cast(attrs, [:group_id, :user_id])
    |> validate_required([:group_id, :user_id])
    |> foreign_key_constraint(:group_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:group_id, :user_id], name: :group_members_group_id_user_id_index)
  end
end
