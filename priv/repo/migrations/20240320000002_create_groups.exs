defmodule Splitwise.Repo.Migrations.CreateGroups do
  use Ecto.Migration

  def change do
    create table(:groups) do
      add :name, :string, null: false
      add :description, :string

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:groups, [:name])
  end
end
