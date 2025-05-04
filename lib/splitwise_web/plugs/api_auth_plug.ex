defmodule SplitwiseWeb.API.AuthPlug do
  import Plug.Conn
  import Ecto.Query
  alias Splitwise.Repo
  alias Splitwise.Accounts.User

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "x-api-key") |> List.first() do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "API key is required"})
        |> halt()

      api_key ->
        case get_user_by_api_key(api_key) do
          nil ->
            conn
            |> put_status(:unauthorized)
            |> Phoenix.Controller.json(%{error: "Invalid API key"})
            |> halt()

          user ->
            case verify_api_key_expiration(user) do
              :ok ->
                assign(conn, :current_user, user)

              :error ->
                conn
                |> put_status(:unauthorized)
                |> Phoenix.Controller.json(%{error: "API key has expired"})
                |> halt()
            end
        end
    end
  end

  defp get_user_by_api_key(api_key) do
    User
    |> where([u], u.api_key == ^api_key)
    |> select([u], %{
      id: u.id,
      email: u.email,
      name: u.name,
      api_key: u.api_key,
      api_key_expires_at: u.api_key_expires_at
    })
    |> Repo.one()
  end

  defp verify_api_key_expiration(%{api_key_expires_at: nil}), do: :ok

  defp verify_api_key_expiration(%{api_key_expires_at: expires_at}) do
    if DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
      :ok
    else
      :error
    end
  end
end
