defmodule SplitwiseWeb.ActivityLogJSON do
  alias Splitwise.ActivityLogs.ActivityLog

  def show(%{activity_logs: activity_logs}) do
    %{data: Enum.map(activity_logs, &data/1)}
  end

  defp data(%ActivityLog{} = activity_log) do
    %{
      id: activity_log.id,
      action: activity_log.action,
      details: activity_log.details,
      entity_type: activity_log.entity_type,
      entity_id: activity_log.entity_id,
      user_id: activity_log.user_id,
      group_id: activity_log.group_id,
      expense_id: activity_log.expense_id,
      payment_id: activity_log.payment_id,
      comment_id: activity_log.comment_id,
      inserted_at: activity_log.inserted_at,
      updated_at: activity_log.updated_at
    }
  end
end
