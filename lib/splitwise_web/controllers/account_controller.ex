defmodule SplitwiseWeb.AccountController do
  use SplitwiseWeb, :controller

  alias Splitwise.Accounts
  alias Splitwise.Accounts.GroupMember
  alias Splitwise.Accounts.User
  alias Splitwise.Accounts.GroupMember
  action_fallback SplitwiseWeb.FallbackController

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

  def update(conn, %{"user" => user_params}) do
    current_user = conn.assigns[:current_user]

    with {:ok, user = %User{}} <- Accounts.get_user(current_user.id),
         {:ok, user} <- Accounts.update_user(user, user_params, current_user) do
      render(conn, :show, user: user)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)

      {:error, message} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: message})
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with {parsed_id, _} <- Integer.parse(id),
         {:ok, user} <- Accounts.get_user(parsed_id),
         {:ok, _user} <- Accounts.delete_user(user, current_user) do
      conn
      |> put_status(:ok)
      |> json(%{message: "User deleted successfully"})
    else
      :error ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Invalid user ID"})

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: reason})

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

      {:error, message} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: message})
    end
  end

  def create_group(conn, %{"group" => group_params, "user_emails" => user_emails})
      when is_list(user_emails) do
    current_user = conn.assigns[:current_user]

    user_emails =
      if current_user.email in user_emails do
        user_emails
      else
        [current_user.email | user_emails]
      end

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

      {:error, :users, message, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: message})

      {:error, :group_members, _error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to add users to group"})
    end
  end

  def show_group(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with {parsed_id, _} <- Integer.parse(id),
         {:ok, group} <- Accounts.get_group_with_users(parsed_id),
         {:ok, %GroupMember{} = _group_member} <-
           Accounts.get_group_member(current_user.id, parsed_id) do
      render(conn, :show_group, group: group)
    else
      {:error, "Group not found"} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Group not found"})

      {:error, "Group member not found"} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "You are not a member of this group"})
    end
  end

  def update_group(conn, %{"id" => id, "group" => group_params}) do
    current_user = conn.assigns[:current_user]

    # Filter out any fields that are not allowed to be updated
    allowed_fields = ["name", "description"]
    filtered_params = Map.take(group_params, allowed_fields)

    # Check if there are any fields that are not allowed
    disallowed_fields = Map.keys(group_params) -- allowed_fields

    if disallowed_fields != [] do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{
        error:
          "Only name and description can be updated. Disallowed fields: #{Enum.join(disallowed_fields, ", ")}"
      })
    else
      with {parsed_id, _} <- Integer.parse(id),
           {:ok, group} <- Accounts.get_group(parsed_id),
           {:ok, %GroupMember{}} <- Accounts.get_group_member(current_user.id, parsed_id),
           {:ok, updated_group} <- Accounts.update_group(group, filtered_params, current_user) do
        render(conn, :update_group, group: updated_group)
      else
        :error ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Invalid group ID"})

        {:error, "Group not found"} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Group not found"})

        {:error, "Group member not found"} ->
          conn
          |> put_status(:forbidden)
          |> json(%{error: "You are not a member of this group"})

        {:error, %Ecto.Changeset{} = changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(json: SplitwiseWeb.ChangesetJSON)
          |> render(:error, changeset: changeset)
      end
    end
  end

  def delete_group(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with {parsed_id, _} <- Integer.parse(id),
         {:ok, group} <- Accounts.get_group(parsed_id),
         {:ok, %GroupMember{}} <- Accounts.get_group_member(current_user.id, parsed_id),
         {:ok, _group} <- Accounts.delete_group(group) do
      conn
      |> put_status(:ok)
      |> json(%{success: true})
    else
      :error ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Invalid group ID"})

      {:error, "Group not found"} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Group not found"})

      {:error, "Group member not found"} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "You are not a member of this group"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  def add_users_to_group(conn, %{"group_id" => group_id, "user_emails" => user_emails}) do
    current_user = conn.assigns[:current_user]

    with {parsed_id, _} <- Integer.parse(group_id),
         {:ok, group} <- Accounts.get_group(parsed_id),
         {:ok, %GroupMember{}} <- Accounts.get_group_member(current_user.id, parsed_id),
         {:ok, users} <- Accounts.get_users_by_emails(user_emails),
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

      {:error, "Group member not found"} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "You are not a member of this group"})

      {:error, missing_emails} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Users not found", missing_emails: missing_emails})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  def remove_users_from_group(conn, %{"group_id" => group_id, "user_id" => user_id})
      when is_integer(group_id) and is_integer(user_id) do
    current_user = conn.assigns[:current_user]

    with {:ok, %GroupMember{}} <- Accounts.get_group_member(current_user.id, group_id),
         {:ok, group_member} <- Accounts.get_group_member(user_id, group_id),
         {:ok, _} <- Accounts.remove_user_from_group(group_member) do
      render(conn, :delete_user_from_group, group_member: group_member)
    else
      {:error, "Invalid group member"} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to remove user from group"})

      {:error, "Group member not found"} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "You are not a member of this group"})

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
