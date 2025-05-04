defmodule Splitwise.Release do
  @moduledoc """
  Release module for handling database migrations and other release tasks.
  """
  require Logger

  @start_apps [
    :postgrex,
    :ecto,
    :ecto_sql
  ]

  @repos Application.compile_env(:splitwise, :ecto_repos, [])

  @doc """
  Runs database migrations for the `Splitwise.Repo`.

  This function performs the following:
    1. Starts the necessary services for migration.
    2. Runs all pending migrations from the `priv/repo/migrations` directory.
    3. Logs the migration process.
    4. Stops the services once migration completes.

  Returns `:ok` if the migration runs successfully.
  """
  @spec migrate() :: :ok
  def migrate do
    start_services()

    path = Application.app_dir(:splitwise, "priv/repo/migrations")

    Logger.info("Starting migration")
    Ecto.Migrator.run(Splitwise.Repo, [path], :up, all: true)
    Logger.info("Migration ran successfully")

    stop_services()
  end

  defp start_services do
    IO.puts("Starting dependencies..")
    # Start apps necessary for executing migrations
    Enum.each(@start_apps, &Application.ensure_all_started/1)

    # Start the Repo(s) for app
    IO.puts("Starting repos..")

    # pool_size can be 1 for ecto < 3.0
    # required to be 2
    Enum.each(@repos, & &1.start_link(pool_size: 2))
  end

  defp stop_services do
    IO.puts("Success!")
    :init.stop()
  end
end
