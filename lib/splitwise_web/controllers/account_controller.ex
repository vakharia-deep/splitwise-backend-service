defmodule SplitwiseWeb.AccountController do
  use SplitwiseWeb, :controller

  alias Splitwise.Accounts
  alias Splitwise.Accounts.User
  alias Splitwise.Accounts.GroupMember

  def create(conn, %{"user" => user_params}) do
    current_user = conn.assigns[:current_user]

    case Accounts.create_user(user_params, current_user) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> render(:show, user: user)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  def show(conn, _params) do
    user = conn.assigns[:current_user]

    case Accounts.get_user(user.id) do
      {:ok, user} ->
        render(conn, :show, user: user)

      {:error, "User not found"} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})
    end
  end

  def user_groups(conn, _params) do
    case Accounts.get_user_groups(conn.assigns.current_user.id) do
      {:ok, groups} ->
        render(conn, :user_groups, groups: groups)

      {:error, "User not found"} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})
    end
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    current_user = conn.assigns[:current_user]

    with {:ok, user = %User{}} <- Accounts.get_user(id),
         {:ok, user} <- Accounts.update_user(user, user_params, current_user) do
      render(conn, :show, user: user)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)

      {:error, "User not found"} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with {parsed_id, _} <- Integer.parse(id),
         {:ok, user} <- Accounts.get_user(parsed_id),
         {:ok, _user} <- Accounts.delete_user(user, current_user) do
      conn
      |> put_status(:no_content)
      |> text("User deleted successfully")
    else
      :error ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Invalid user ID"})

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  def create_group(conn, %{"group" => group_params, "user_emails" => user_emails})
      when is_list(user_emails) do
    current_user = conn.assigns[:current_user]

    case Accounts.create_group_with_members(
           %{"group" => group_params, "user_emails" => user_emails},
           current_user
         ) do
      {:ok, %{group: group}} ->
        conn
        |> put_status(:created)
        |> render(:show_group, group: group)

      {:error, :group, %Ecto.Changeset{} = changeset, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)

      {:error, :users, "One or more users not found", _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "One or more users not found"})

      {:error, :group_members, _error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to add users to group"})
    end
  end

  def show_group(conn, %{"id" => id}) do
    with {parsed_id, _} <- Integer.parse(id),
         {:ok, group} <- Accounts.get_group_with_users(parsed_id) do
      render(conn, :show_group, group: group)
    else
      {:error, "Invalid group ID"} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Invalid group ID"})

      {:error, "Group not found"} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Group not found"})
    end
  end

  def update_group(conn, %{"id" => id, "group" => group_params}) do
    current_user = conn.assigns[:current_user]

    with {parsed_id, _} <- Integer.parse(id),
         {:ok, group} <- Accounts.get_group(parsed_id),
         {:ok, updated_group} <- Accounts.update_group(group, group_params, current_user) do
      render(conn, :update_group, group: updated_group)
    else
      {:error, "Invalid group ID"} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Invalid group ID"})

      {:error, "Group not found"} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Group not found"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  def delete_group(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with {parsed_id, _} <- Integer.parse(id),
         {:ok, group} <- Accounts.get_group(parsed_id),
         {:ok, _group} <- Accounts.delete_group(group, current_user) do
      conn
      |> put_status(:no_content)
      |> text("")
    else
      :error ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Invalid group ID"})

      {:error, "Group not found"} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Group not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  def add_users_to_group(conn, %{"group_id" => group_id, "user_ids" => user_ids}) do
    current_user = conn.assigns[:current_user]

    with {parsed_id, _} <- Integer.parse(group_id),
         {:ok, group} <- Accounts.get_group(parsed_id),
         {:ok, users} <- Accounts.get_users_by_ids(user_ids),
         {:ok, group} <- Accounts.add_users_to_group(users, group, current_user) do
      render(conn, :show_group, group: group)
    else
      :error ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Invalid group ID"})

      {:error, "Group not found"} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Group not found"})

      {:error, missing_ids} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Users not found", missing_user_ids: missing_ids})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  def remove_user_from_group(conn, %{"group_id" => group_id, "user_id" => user_id}) do
    with {parsed_user_id, _} <- Integer.parse(user_id),
         {parsed_group_id, _} <- Integer.parse(group_id),
         %GroupMember{} = group_member <-
           Accounts.get_group_member(parsed_user_id, parsed_group_id),
         {:ok, _} <- Accounts.remove_user_from_group(group_member) do
      render(conn, :delete_user_from_group, group_member: group_member)
    else
      {:error, "Invalid group member"} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to remove user from group"})

      :error ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Invalid user ID or Group ID"})

      {:error, "User not found"} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      {:error, "Group not found"} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Group not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)

      _res ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to remove user from group"})
    end
  end
end
