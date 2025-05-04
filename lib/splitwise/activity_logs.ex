defmodule Splitwise.ActivityLogs do
  import Ecto.Query, warn: false
  alias Splitwise.Repo
  alias Splitwise.ActivityLogs.ActivityLog

  def list_activity_logs do
    Repo.all(ActivityLog)
  end

  def get_activity_log!(id), do: Repo.get!(ActivityLog, id)

  def create_activity_log(attrs \\ %{}) do
    %ActivityLog{}
    |> ActivityLog.changeset(attrs)
    |> Repo.insert()
  end

  def update_activity_log(%ActivityLog{} = activity_log, attrs) do
    activity_log
    |> ActivityLog.changeset(attrs)
    |> Repo.update()
  end

  def delete_activity_log(%ActivityLog{} = activity_log) do
    Repo.delete(activity_log)
  end

  # Query functions
  def get_activity_logs_by_user(user_id) do
    ActivityLog
    |> where([al], al.user_id == ^user_id)
    |> Repo.all()
    |> case do
      [] -> {:error, "No activity logs found"}
      activity_logs -> {:ok, activity_logs}
    end
  end

  def get_activity_logs_by_entity(entity_type, entity_id) do
    ActivityLog
    |> where([al], al.entity_type == ^entity_type and al.entity_id == ^entity_id)
    |> Repo.all()
  end

  def get_activity_logs_by_group(group_id) do
    ActivityLog
    |> where([al], al.group_id == ^group_id)
    |> Repo.all()
  end
end
