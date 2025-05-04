defmodule SplitwiseWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use SplitwiseWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: SplitwiseWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, {:tarams_error, error}}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: error})
  end

  def call(conn, {:error, {cause, reason}})
      when (cause in [:bad_request, :internal_server_error, :unauthorized, :forbidden] and
              is_binary(reason)) or is_map(reason) do
    conn
    |> put_status(cause)
    |> json(%{error: reason})
  end

  def call(conn, {:error, {status, reason}})
      when is_integer(status) and (is_binary(reason) or is_map(reason)) do
    conn
    |> put_status(status)
    |> json(%{error: reason})
  end

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: SplitwiseWeb.ErrorHTML, json: SplitwiseWeb.ErrorJSON)
    |> render(:"404")
  end
end
