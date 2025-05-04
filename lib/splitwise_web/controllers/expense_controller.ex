defmodule SplitwiseWeb.ExpenseController do
  use SplitwiseWeb, :controller

  alias Splitwise.Expenses
  # alias Splitwise.Expenses.{Expense, ExpenseShare, Comment}

  def create(conn, %{"expense" => expense_params, "shares" => shares}) do
    current_user = conn.assigns[:current_user]
    merged_params = Map.put(expense_params, "added_by_id", current_user.id)

    # Validate that shares are valid float values
    case Expenses.create_expense_with_shares(merged_params, shares, current_user) do
      {:ok, expense} ->
        conn
        |> put_status(:created)
        |> render(:show, expense: expense)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)

      {:error, error} when is_binary(error) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: error})

      {:error, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})
    end
  end

  def update(conn, %{"id" => id, "expense" => expense_params, "shares" => shares}) do
    current_user = conn.assigns[:current_user]

    if is_nil(current_user) do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Authentication required."})
    else
      expense = Expenses.get_expense!(id)

      if expense.paid_by_id != current_user.id do
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Only the creator can update this expense."})
      else
        paid_by_id = Map.get(expense_params, "paid_by_id", current_user.id)

        if paid_by_id != current_user.id do
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "You cannot change the payer of the expense."})
        else
          if is_nil(shares) or not is_list(shares) do
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Missing or invalid 'shares' key. Must be a list."})
          else
            merged_params = Map.put(expense_params, "paid_by_id", current_user.id)

            case Expenses.update_expense_with_shares(expense, merged_params, shares, current_user) do
              {:ok, expense} ->
                render(conn, :show, expense: expense)

              {:error, %Ecto.Changeset{} = changeset} ->
                conn
                |> put_status(:unprocessable_entity)
                |> put_view(json: SplitwiseWeb.ChangesetJSON)
                |> render(:error, changeset: changeset)

              {:error, error} when is_binary(error) ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{error: error})
            end
          end
        end
      end
    end
  end

  def update(conn, %{"id" => id, "expense" => expense_params}) do
    current_user = conn.assigns[:current_user]

    with {parsed_id, _} <- Integer.parse(id),
         {:ok, expense} <- Expenses.get_expense(parsed_id),
         true <- expense.added_by_id == current_user.id do
      if expense.paid_by_id != current_user.id do
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Only the creator can update this expense."})
      else
        paid_by_id = Map.get(expense_params, "paid_by_id", current_user.id)

        if paid_by_id != current_user.id do
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "You cannot change the payer of the expense."})
        else
          merged_params = Map.put(expense_params, "paid_by_id", current_user.id)

          case Expenses.update_expense(expense, merged_params, current_user) do
            {:ok, expense} ->
              render(conn, :show, expense: expense)

            {:error, %Ecto.Changeset{} = changeset} ->
              conn
              |> put_status(:unprocessable_entity)
              |> put_view(json: SplitwiseWeb.ChangesetJSON)
              |> render(:error, changeset: changeset)

            {:error, error} when is_binary(error) ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{error: error})
          end
        end
      end
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with {parsed_id, _} <- Integer.parse(id),
         {:ok, expense} <- Expenses.get_expense(parsed_id),
         true <- expense.added_by_id == current_user.id,
         {:ok, _expense} <- Expenses.delete_expense(expense) do
      conn
      |> put_status(:ok)
      |> json(%{success: true})
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "You are not authorized to delete this expense"})

      {:error, message} when is_binary(message) ->
        conn
        |> put_status(:not_found)
        |> json(%{error: message})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)

      :error ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Expense not found"})
    end
  end

  def create_comment(conn, %{"expense_id" => expense_id, "comment" => comment_params}) do
    case Expenses.create_expense_comment(expense_id, comment_params, conn.assigns.current_user) do
      {:ok, comment} ->
        conn
        |> put_status(:created)
        |> render(:show_comment, comment: comment)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(error)})
    end
  end

  def update_comment(conn, %{"comment_id" => comment_id, "comment" => comment_params}) do
    case Expenses.update_comment(
           comment_id,
           %{"content" => comment_params},
           conn.assigns.current_user
         ) do
      {:ok, comment} ->
        render(conn, :show_comment, comment: comment)

      {:error, "Comment not found"} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Comment not found"})

      {:error, "You are not authorized to update this comment"} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "You are not authorized to update this comment"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  def delete_comment(conn, %{"comment_id" => comment_id}) do
    case Expenses.delete_comment(comment_id, conn.assigns.current_user) do
      {:ok, _comment} ->
        conn
        |> put_status(:ok)
        |> json(%{success: true})

      {:error, message} when is_binary(message) ->
        IO.inspect(message)

        conn
        |> put_status(:not_found)
        |> json(%{error: message})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  @doc """
  Fetches all expense shares where the current user owes money to others.
  """
  def get_amount_payable(conn, _params) do
    user_id = conn.assigns.current_user.id

    case Expenses.get_amount_payable(user_id) do
      {:ok, []} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "No payable expenses found"})

      {:ok, shares} ->
        render(conn, :owing_shares, shares: shares)
    end
  end

  def get_amount_receivable(conn, _params) do
    user_id = conn.assigns.current_user.id

    case Expenses.get_amount_receivable(user_id) do
      {:ok, []} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "No receivable expenses found"})

      {:ok, shares} ->
        render(conn, :receivable_shares, shares: shares)
    end
  end
end
