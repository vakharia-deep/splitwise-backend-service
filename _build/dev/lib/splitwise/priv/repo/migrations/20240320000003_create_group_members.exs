defmodule Splitwise.Repo.Migrations.CreateGroupMembers do
  use Ecto.Migration

  def change do
    create table(:group_members) do
      add :group_id, references(:groups, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:group_members, [:group_id, :user_id],
             name: :group_members_group_id_user_id_index
           )

    create index(:group_members, [:user_id])
    create index(:group_members, [:group_id])
  end
end
