defmodule Splitwise.Repo do
  use Ecto.Repo,
    otp_app: :splitwise,
    adapter: Ecto.Adapters.Postgres
end
