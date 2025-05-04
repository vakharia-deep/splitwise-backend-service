defmodule SplitwiseWeb.AccountJSON do
  alias Splitwise.Accounts.{User, Group}

  @doc """
  Renders a list of users.
  """
  def index(%{users: users}) do
    %{data: for(user <- users, do: data(user))}
  end

  @doc """
  Renders a single user.
  """
  def show(%{user: user}) do
    %{data: data(user)}
  end

  @doc """
  Renders a list of groups.
  """
  def group_index(%{groups: groups}) do
    %{data: for(group <- groups, do: group_data(group))}
  end

  @doc """
  Renders a single group.
  """
  def show_group(%{group: group}) do
    %{data: group_data(group)}
  end

  def update_group(%{group: group}) do
    %{success: true, data: %{id: group.id, name: group.name, description: group.description}}
  end

  def user_groups(%{groups: groups}) do
    %{groups: for(group <- groups, do: user_group_data(group))}
  end

  def add_users_to_group(%{users: users}) do
    %{data: %{users: Enum.map(users, &data/1)}}
  end

  def delete_user_from_group(%{group_member: _group_member}) do
    %{
      success: true
    }
  end

  defp data(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      name: user.name,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at,
      api_key: user.api_key,
      api_key_expires_at: user.api_key_expires_at
    }
  end

  defp group_data(%Group{} = group) do
    %{
      id: group.id,
      name: group.name,
      description: group.description,
      inserted_at: group.inserted_at,
      updated_at: group.updated_at,
      user_emails: Enum.map(group.users, & &1.email)
    }
  end

  defp user_group_data(%Group{} = group) do
    %{
      id: group.id,
      name: group.name,
      description: group.description,
      updated_at: group.updated_at,
      members: Enum.map(group.users, fn user -> user.email end)
    }
  end
end
