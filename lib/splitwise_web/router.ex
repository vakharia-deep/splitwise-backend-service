defmodule SplitwiseWeb.Router do
  use SplitwiseWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug SplitwiseWeb.API.AuthPlug
  end

  scope "/api", SplitwiseWeb do
    pipe_through [:api, :api_auth]

    post "/users", AccountController, :create
    get "/users", AccountController, :show
    patch "/users", AccountController, :update
    delete "/users", AccountController, :delete

    get "/activity-logs", ActivityLogController, :show

    get "/groups", AccountController, :user_groups
    post "/groups", AccountController, :create_group
    get "/groups/:id", AccountController, :show_group
    put "/groups/:id", AccountController, :update_group
    delete "/groups/:id", AccountController, :delete_group

    post "/groups/:group_id/add_users", AccountController, :add_users_to_group
    post "/groups/remove_user", AccountController, :remove_users_from_group

    get "/expense-shares/receivable", ExpenseController, :get_amount_receivable
    get "/expense-shares/payable", ExpenseController, :get_amount_payable

    post "/expenses", ExpenseController, :create
    patch "/expenses/:id", ExpenseController, :update
    delete "/expenses/:id", ExpenseController, :delete

    post "/expenses/:expense_id/comment", ExpenseController, :create_comment
    delete "/comments/:comment_id", ExpenseController, :delete_comment
    patch "/comments/:comment_id", ExpenseController, :update_comment
    # Payment routes
    resources "/payments", PaymentController, only: [:show, :update, :delete]

    # ActivityLog routes

    post "/expense_shares/:expense_share_id/payments", PaymentController, :create_for_share

    # Expense share routes
  end
end
