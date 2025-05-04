defmodule SplitwiseWeb.PaymentController do
  use SplitwiseWeb, :controller

  alias Splitwise.Payments
  alias Splitwise.Expenses

  def show(conn, %{"id" => id}) do
    payment = Payments.get_payment!(id)
    render(conn, :show, payment: payment)
  end

  def update(conn, %{"id" => id, "payment" => payment_params}) do
    payment = Payments.get_payment!(id)

    case Payments.update_payment(payment, payment_params) do
      {:ok, payment} ->
        render(conn, :show, payment: payment)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    payment = Payments.get_payment!(id)
    {:ok, _payment} = Payments.delete_payment(payment)

    conn
    |> put_status(:no_content)
    |> text("")
  end

  @doc """
  Creates a payment for an expense share.
  """
  def create_for_share(conn, %{
        "expense_share_id" => expense_share_id,
        "payment" => payment_params
      }) do
    payment_params = Map.put(payment_params, "from_user_id", conn.assigns.current_user.id)
    current_user = conn.assigns[:current_user]

    case Expenses.create_payment_for_share(expense_share_id, payment_params, current_user) do
      {:ok, %{payment: payment, share: _share}} ->
        conn
        |> put_status(:created)
        |> render(:show, payment: payment)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: SplitwiseWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)

      {:error, reason} when is_binary(reason) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end
end
