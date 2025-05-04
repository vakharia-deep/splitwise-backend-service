defmodule Splitwise.Payments do
  import Ecto.Query, warn: false
  alias Splitwise.Repo
  alias Splitwise.Payments.Payment

  def list_payments do
    Repo.all(Payment)
  end

  def get_payment!(id), do: Repo.get!(Payment, id)

  def get_payment_by_transaction_id(transaction_id),
    do: Repo.get_by(Payment, transaction_id: transaction_id)

  def create_payment(attrs \\ %{}) do
    %Payment{}
    |> Payment.changeset(attrs)
    |> Repo.insert()
  end

  def update_payment(%Payment{} = payment, attrs) do
    payment
    |> Payment.changeset(attrs)
    |> Repo.update()
  end

  def delete_payment(%Payment{} = payment) do
    Repo.delete(payment)
  end

  # Query functions
  def get_payments_by_user(user_id) do
    Payment
    |> where([p], p.from_user_id == ^user_id or p.to_user_id == ^user_id)
    |> Repo.all()
  end

  def get_payments_by_expense_share(expense_share_id) do
    Payment
    |> where([p], p.expense_share_id == ^expense_share_id)
    |> Repo.all()
  end
end
