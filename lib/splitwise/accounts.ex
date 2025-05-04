defmodule Splitwise.Accounts do
  import Ecto.Query, warn: false
  alias Splitwise.Repo
  alias Splitwise.Accounts.{User, Group, GroupMember}
  alias Ecto.Multi

  # User functions
  def list_users do
    Repo.all(User)
  end

  def get_user!(id), do: Repo.get!(User, id)

  def get_user(id) when is_integer(id) do
    case Repo.get(User, id) do
      nil -> {:error, "User not found"}
      user -> {:ok, user}
    end
  end

  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  def get_users_by_ids(user_ids) do
    users = Repo.all(from u in User, where: u.id in ^user_ids)

    if length(users) == length(user_ids) do
      {:ok, users}
    else
      found_ids = Enum.map(users, & &1.id)
      missing_ids = Enum.reject(user_ids, &(&1 in found_ids))
      {:error, missing_ids}
    end
  end

  def create_user(attrs \\ %{}, current_user) do
    Multi.new()
    |> Multi.insert(:user, User.changeset(%User{}, attrs))
    |> Multi.run(:activity_log, fn _repo, %{user: user} ->
      Splitwise.ActivityLogs.create_activity_log(%{
        action: "user_created",
        user_id: current_user.id,
        entity_type: "user",
        entity_id: user.id,
        details: %{email: user.email, name: user.name}
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
      {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
    end
  end

  def create_user_default(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs, current_user) do
    Multi.new()
    |> Multi.update(:user, User.changeset(user, attrs))
    |> Multi.run(:activity_log, fn _repo, %{user: updated_user} ->
      Splitwise.ActivityLogs.create_activity_log(%{
        action: "user_updated",
        user_id: current_user.id,
        entity_type: "user",
        entity_id: updated_user.id,
        details: %{email: updated_user.email, name: updated_user.name}
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: updated_user}} -> {:ok, updated_user}
      {:error, :user, changeset, _} -> {:error, changeset}
      {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
    end
  end

  def delete_user(%User{} = user, current_user) do
    Multi.new()
    |> Multi.delete(:user, user)
    |> Multi.run(:activity_log, fn _repo, %{user: _deleted_user} ->
      Splitwise.ActivityLogs.create_activity_log(%{
        action: "user_deleted",
        user_id: current_user.id,
        entity_type: "user",
        entity_id: user.id,
        details: %{email: user.email, name: user.name}
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} -> {:ok, :deleted}
      {:error, :user, changeset, _} -> {:error, changeset}
      {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
    end
  end

  def list_groups do
    Repo.all(
      from g in Group,
        preload: [users: ^from(u in User, select: %{id: u.id, email: u.email})]
    )
  end

  def get_group_by_name(name), do: Repo.get_by(Group, name: name)

  def get_group(id) when is_integer(id) do
    case Repo.get(Group, id) do
      nil -> {:error, "Group not found"}
      group -> {:ok, group}
    end
  end

  def get_group(_), do: {:error, "Invalid group ID"}

  def get_group_with_users(id) when is_integer(id) do
    case Repo.one(
           from g in Group,
             where: g.id == ^id,
             preload: [users: ^from(u in User, select: %{id: u.id, email: u.email})]
         ) do
      nil -> {:error, "Group not found"}
      group -> {:ok, group}
    end
  end

  def get_group_with_users(_), do: {:error, "Invalid group ID"}

  def get_group!(id), do: Repo.get!(Group, id)

  def get_user_groups(user_id) when is_integer(user_id) do
    Repo.all(
      from g in Group,
        join: gm in "group_members",
        on: gm.group_id == g.id,
        where: gm.user_id == ^user_id,
        preload: [users: ^from(u in User, select: %{id: u.id, email: u.email})]
    )
    |> case do
      [] -> {:error, "No groups found"}
      groups -> {:ok, groups}
    end
  end

  def get_user_groups(_), do: {:error, "Invalid user ID"}

  def create_group(attrs \\ %{}) do
    %Group{}
    |> Group.changeset(attrs)
    |> Repo.insert()
  end

  def build_group_creation_params(%{"group" => group_params, "user_emails" => user_emails}) do
    Multi.new()
    |> Multi.insert(:group, Group.changeset(%Group{}, group_params))
    |> Multi.run(:users, fn _repo, %{group: _group} ->
      users = Enum.map(user_emails, &get_user_by_email/1)

      if Enum.any?(users, &is_nil/1) do
        {:error, "One or more users not found"}
      else
        {:ok, users}
      end
    end)
    |> Multi.run(:group_members, fn _repo, %{group: group, users: users} ->
      group_members =
        Enum.map(users, fn user ->
          %{
            group_id: group.id,
            user_id: user.id,
            inserted_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
          }
        end)

      {count, _} = Repo.insert_all("group_members", group_members)
      {:ok, count}
    end)
  end

  def create_group_with_members(params, current_user) do
    build_group_creation_params(params)
    |> Multi.run(:activity_log, fn _repo, %{group: group} ->
      Splitwise.ActivityLogs.create_activity_log(%{
        action: "group_created",
        user_id: current_user.id,
        entity_type: "group",
        entity_id: group.id,
        group_id: group.id,
        details: %{name: group.name, user_emails: params["user_emails"]}
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{group: group}} ->
        group_with_users =
          Repo.preload(group, users: from(u in User, select: %{id: u.id, email: u.email}))

        {:ok, %{group: group_with_users}}

      error ->
        error
    end
  end

  def update_group(%Group{} = group, attrs, current_user) do
    Multi.new()
    |> Multi.update(:group, Group.changeset(group, attrs))
    |> Multi.run(:activity_log, fn _repo, %{group: updated_group} ->
      Splitwise.ActivityLogs.create_activity_log(%{
        action: "group_updated",
        user_id: current_user.id,
        entity_type: "group",
        entity_id: updated_group.id,
        group_id: updated_group.id,
        details: %{name: updated_group.name, description: updated_group.description}
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{group: updated_group}} -> {:ok, updated_group}
      {:error, :group, changeset, _} -> {:error, changeset}
      {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
    end
  end

  def delete_group(%Group{} = group, current_user) do
    Multi.new()
    |> Multi.delete(:group, group)
    |> Multi.run(:activity_log, fn _repo, %{group: _deleted_group} ->
      Splitwise.ActivityLogs.create_activity_log(%{
        action: "group_deleted",
        user_id: current_user.id,
        entity_type: "group",
        entity_id: group.id,
        group_id: group.id,
        details: %{name: group.name, description: group.description}
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} -> {:ok, :deleted}
      {:error, :group, changeset, _} -> {:error, changeset}
      {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
    end
  end

  # Group membership functions
  def add_user_to_group(%User{} = user, %Group{} = group) do
    user
    |> Repo.preload(:groups)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:groups, [group | user.groups])
    |> Repo.update()
  end

  def add_users_to_group(users, %Group{} = group, current_user) do
    Multi.new()
    |> Multi.run(:users, fn _repo, _changes ->
      users = Enum.map(users, &Repo.preload(&1, :groups))
      {:ok, users}
    end)
    |> Multi.run(:check_existing, fn _repo, %{users: users} ->
      existing_members =
        Repo.all(
          from gm in "group_members",
            where: gm.group_id == ^group.id and gm.user_id in ^Enum.map(users, & &1.id),
            select: gm.user_id
        )

      existing_user_ids = existing_members
      new_users = Enum.reject(users, &(&1.id in existing_user_ids))
      {:ok, %{new_users: new_users, existing_user_ids: existing_user_ids}}
    end)
    |> Multi.run(:update_users, fn _repo, %{check_existing: %{new_users: new_users}} ->
      if Enum.empty?(new_users) do
        {:ok, group}
      else
        group_members =
          Enum.map(new_users, fn user ->
            %{
              group_id: group.id,
              user_id: user.id,
              inserted_at: DateTime.utc_now(),
              updated_at: DateTime.utc_now()
            }
          end)

        {_count, _} = Repo.insert_all("group_members", group_members)
        {:ok, group}
      end
    end)
    |> Multi.run(:load_group, fn _repo, _changes ->
      group = Repo.preload(group, :users)
      {:ok, group}
    end)
    |> Multi.run(:activity_log, fn _repo, %{load_group: group} ->
      Splitwise.ActivityLogs.create_activity_log(%{
        action: "group_users_added",
        user_id: current_user.id,
        entity_type: "group",
        entity_id: group.id,
        group_id: group.id,
        details: %{added_user_ids: Enum.map(users, & &1.id)}
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{load_group: group}} -> {:ok, group}
      {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
    end
  end

  def get_group_member(user_id, group_id) do
    Repo.get_by(GroupMember, user_id: user_id, group_id: group_id)
  end

  def find_or_create_group_by_users(user_ids, current_user) when is_list(user_ids) do
    # First, find all groups that have exactly these users
    groups_with_users =
      from g in Group,
        join: gm in "group_members",
        on: gm.group_id == g.id,
        where: gm.user_id in ^user_ids,
        group_by: g.id,
        having: count(gm.user_id) == ^length(user_ids),
        select: g

    # Get all groups that match
    groups = Repo.all(groups_with_users)

    # For each group, check if it has exactly these users (no more, no less)
    matching_group =
      Enum.find(groups, fn group ->
        # Get all user IDs in this group
        group_users_query =
          from gm in "group_members",
            where: gm.group_id == ^group.id,
            select: gm.user_id

        group_users = Repo.all(group_users_query)

        # Check if the sets of user IDs are equal
        MapSet.new(group_users) == MapSet.new(user_ids)
      end)

    case matching_group do
      nil ->
        # No matching group found, create a new one
        group_name = "Group #{DateTime.utc_now() |> DateTime.to_unix()}"

        create_group_with_members(
          %{
            "group" => %{"name" => group_name, "description" => "Auto-created group"},
            "user_emails" => Enum.map(user_ids, &get_user!(&1).email)
          },
          current_user
        )

      group ->
        {:ok, %{group: group}}
    end
  end

  def remove_user_from_group(%GroupMember{} = group_member) do
    Repo.delete(group_member)
  end

  def remove_user_from_group(_group_member), do: {:error, "Invalid group member"}
end
