defmodule SplitwiseWeb.ActivityLogController do
  use SplitwiseWeb, :controller

  alias Splitwise.ActivityLogs

  def show(conn, _params) do
    current_user = conn.assigns[:current_user]

    case ActivityLogs.get_activity_logs_by_user(current_user.id) do
      {:ok, activity_logs} ->
        render(conn, :show, activity_logs: activity_logs)

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: error})
    end
  end
end
