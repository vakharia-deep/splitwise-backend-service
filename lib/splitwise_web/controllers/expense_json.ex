defmodule SplitwiseWeb.ExpenseJSON do
  alias Splitwise.Expenses.{Expense, ExpenseShare, Comment}

  @doc """
  Renders a list of expenses.
  """
  def index(%{expenses: expenses}) do
    %{data: for(expense <- expenses, do: data(expense))}
  end

  @doc """
  Renders a single expense.
  """
  def show(%{expenses: expenses}) do
    %{data: for(expense <- expenses, do: data(expense))}
  end

  def show(%{expense: expense}) do
    %{data: data(expense)}
  end

  @doc """
  Renders a list of expense shares.
  """
  def share_index(%{shares: shares}) do
    %{data: for(share <- shares, do: share_data(share))}
  end

  @doc """
  Renders a single expense share.
  """
  def show_share(%{share: share}) do
    %{data: share_data(share)}
  end

  @doc """
  Renders a list of comments.
  """
  def comment_index(%{comments: comments}) do
    %{data: for(comment <- comments, do: comment_data(comment))}
  end

  @doc """
  Renders a single comment.
  """
  def show_comment(%{comment: comment}) do
    %{data: comment_data(comment)}
  end

  defp data(%Expense{} = expense) do
    %{
      id: expense.id,
      description: expense.description,
      amount: expense.amount,
      date: expense.date,
      status: expense.status,
      paid_by_id: expense.paid_by_id,
      added_by_id: expense.added_by_id,
      group_id: expense.group_id,
      inserted_at: expense.inserted_at,
      updated_at: expense.updated_at
    }
  end

  defp share_data(%ExpenseShare{} = share) do
    %{
      id: share.id,
      amount: share.amount,
      remaining_amount: share.remaining_amount,
      status: share.status,
      expense_id: share.expense_id,
      user_id: share.user_id,
      inserted_at: share.inserted_at,
      updated_at: share.updated_at
    }
  end

  defp comment_data(%Comment{} = comment) do
    %{
      id: comment.id,
      content: comment.content,
      user_id: comment.user_id,
      expense_id: comment.expense_id,
      inserted_at: comment.inserted_at,
      updated_at: comment.updated_at
    }
  end

  def owing_shares(%{shares: shares}) do
    %{data: Enum.map(shares, &owing_share/1)}
  end

  defp owing_share(share) do
    %{
      expense_id: share.expense_id,
      expense_description: share.expense_description,
      expense_amount: share.expense_amount,
      amount_owed: share.amount_owed,
      owed_to: %{
        user_id: share.owed_to.user_id,
        email: share.owed_to.email,
        name: share.owed_to.name,
        remaining_amount: share.owed_to.remaining_amount
      },
      created_at: share.created_at
    }
  end

  def receivable_shares(%{shares: shares}) do
    %{data: Enum.map(shares, &receivable_share/1)}
  end

  defp receivable_share(share) do
    %{
      expense_id: share.expense_id,
      expense_description: share.expense_description,
      expense_amount: share.expense_amount,
      amount_receivable: share.amount_receivable,
      group_name: share.group_name,
      owed_by: %{
        user_id: share.owed_by.user_id,
        email: share.owed_by.email,
        name: share.owed_by.name,
        remaining_amount: share.owed_by.remaining_amount
      },
      created_at: share.created_at
    }
  end
end
