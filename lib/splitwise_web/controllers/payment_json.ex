defmodule SplitwiseWeb.PaymentJSON do
  alias Splitwise.Payments.Payment

  @doc """
  Renders a list of payments.
  """
  def index(%{payments: payments}) do
    %{data: for(payment <- payments, do: data(payment))}
  end

  @doc """
  Renders a single payment.
  """
  def show(%{payment: payment}) do
    %{data: data(payment)}
  end

  defp data(%Payment{} = payment) do
    %{
      id: payment.id,
      amount: payment.amount,
      status: payment.status,
      transaction_id: payment.transaction_id,
      from_user_id: payment.from_user_id,
      to_user_id: payment.to_user_id,
      expense_share_id: payment.expense_share_id,
      inserted_at: payment.inserted_at,
      updated_at: payment.updated_at
    }
  end
end
