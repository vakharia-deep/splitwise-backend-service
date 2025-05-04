defmodule Splitwise.Expenses do
  import Ecto.Query, warn: false
  alias Splitwise.Repo
  alias Splitwise.Expenses.{Expense, ExpenseShare, Comment}
  alias Splitwise.Payments
  alias Ecto.Multi
  alias Splitwise.Accounts.User
  alias Splitwise.Accounts.Group

  require Decimal

  # Expense functions
  def list_expenses do
    Repo.all(Expense)
  end

  def get_expense!(id), do: Repo.get!(Expense, id)

  def get_expense(id) when is_integer(id) do
    case Repo.get(Expense, id) do
      nil -> {:error, "Expense not found"}
      expense -> {:ok, expense}
    end
  end

  def get_expense(_), do: {:error, "Invalid expense ID"}

  def get_expenses_by_user_id(user_id) do
    Expense
    |> where([e], e.paid_by_id == ^user_id)
    |> Repo.all()
    |> case do
      [] -> {:error, "No expenses found"}
      expenses -> {:ok, expenses}
    end
  end

  def create_expense(attrs \\ %{}) do
    %Expense{}
    |> Expense.changeset(attrs)
    |> Repo.insert()
  end

  def update_expense(%Expense{} = expense, attrs) do
    expense
    |> Expense.changeset(attrs)
    |> Repo.update()
  end

  def delete_expense(%Expense{} = expense) do
    Repo.delete(expense)
  end

  # ExpenseShare functions
  def list_expense_shares do
    Repo.all(ExpenseShare)
  end

  def get_expense_share!(id), do: Repo.get!(ExpenseShare, id)

  def create_expense_share(attrs \\ %{}) do
    %ExpenseShare{}
    |> ExpenseShare.changeset(attrs)
    |> Repo.insert()
  end

  def update_expense_share(%ExpenseShare{} = expense_share, attrs) do
    expense_share
    |> ExpenseShare.changeset(attrs)
    |> Repo.update()
  end

  def delete_expense_share(%ExpenseShare{} = expense_share) do
    Repo.delete(expense_share)
  end

  # Comment functions
  def list_comments do
    Repo.all(Comment)
  end

  def get_comment!(id), do: Repo.get!(Comment, id)

  def create_comment(attrs \\ %{}) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> Repo.insert()
  end

  def update_comment(comment_id, comment_params, current_user) do
    Multi.new()
    |> Multi.run(:get_comment, fn repo, _changes ->
      comment =
        from(c in Comment,
          join: e in Expense,
          on: c.expense_id == e.id,
          where: c.id == ^comment_id and c.user_id == ^current_user.id,
          select: %{comment: c, expense: e},
          lock: "FOR UPDATE"
        )
        |> repo.one()

      if is_nil(comment) do
        {:error, "Comment not found"}
      else
        {:ok, comment}
      end
    end)
    |> Multi.run(:authorize, fn _repo, %{get_comment: %{comment: comment}} ->
      if comment.user_id == current_user.id do
        {:ok, comment}
      else
        {:error, "You are not authorized to update this comment"}
      end
    end)
    |> Multi.update(:update_comment, fn %{get_comment: %{comment: comment}} ->
      Comment.changeset(comment, comment_params)
    end)
    |> Multi.run(:activity_log, fn _repo,
                                   %{
                                     get_comment: %{comment: comment, expense: expense},
                                     update_comment: updated_comment
                                   } ->
      Splitwise.ActivityLogs.create_activity_log(%{
        action: "comment_updated",
        user_id: current_user.id,
        entity_type: "comment",
        entity_id: comment.id,
        expense_id: expense.id,
        group_id: expense.group_id,
        comment_id: comment.id,
        details: %{
          old_content: comment.content,
          new_content: updated_comment.content,
          expense_id: expense.id,
          group_id: expense.group_id
        }
      })
    end)
    |> Multi.run(:load_comment, fn repo, %{update_comment: comment} ->
      comment = repo.preload(comment, :user)
      {:ok, comment}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{load_comment: comment}} -> {:ok, comment}
      {:error, :get_comment, error, _} -> {:error, error}
      {:error, :authorize, error, _} -> {:error, error}
      {:error, :update_comment, changeset, _} -> {:error, changeset}
      {:error, :activity_log, error, _} -> {:error, error}
      {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
    end
  end

  def delete_comment(comment_id, current_user) do
    comment =
      from(c in Comment,
        where: c.id == ^comment_id and c.user_id == ^current_user.id,
        lock: "FOR UPDATE"
      )
      |> Repo.one()

    cond do
      is_nil(comment) ->
        {:error, "Comment not found"}

      comment.user_id != current_user.id ->
        {:error, "You are not authorized to delete this comment"}

      true ->
        case Repo.delete(comment) do
          {:ok, comment} -> {:ok, comment}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  def get_expenses_by_user(user_id) do
    Expense
    |> where([e], e.paid_by_id == ^user_id or e.added_by_id == ^user_id)
    |> Repo.all()
  end

  def get_expense_shares_by_user(user_id) do
    ExpenseShare
    |> where([es], es.user_id == ^user_id)
    |> Repo.all()
  end

  def get_comments_by_expense(expense_id) do
    Comment
    |> where([c], c.expense_id == ^expense_id)
    |> Repo.all()
  end

  def create_expense_with_shares(expense_params, shares, current_user) when is_list(shares) do
    if shares == [] or Enum.any?(shares, fn s -> !is_map(s) or is_nil(s["user_id"]) end) do
      {:error, "Shares list must be a non-empty list of valid share maps with user_id."}
    else
      Multi.new()
      |> Multi.run(:find_or_create_group, fn repo, _changes ->
        if is_nil(expense_params["group_id"]) do
          user_ids =
            ([expense_params["paid_by_id"]] ++
               Enum.map(shares, & &1["user_id"]))
            |> Enum.uniq()

          from(u in User, where: u.id in ^user_ids, lock: "FOR UPDATE")
          |> repo.all()

          case Splitwise.Accounts.find_or_create_group_by_users(user_ids, current_user) do
            {:ok, %{group: group}} ->
              {:ok, Map.put(expense_params, "group_id", group.id)}

            error ->
              error
          end
        else
          {:ok, expense_params}
        end
      end)
      |> Multi.insert(:expense, fn %{find_or_create_group: updated_params} ->
        Expense.changeset(%Expense{}, updated_params)
      end)
      |> Multi.run(:validate_shares, fn _repo, %{expense: expense} ->
        is_equal_split =
          Enum.all?(shares, fn share ->
            is_nil(share["share_percentage"]) and is_nil(share["amount"]) and
              not is_nil(share["user_id"])
          end)

        if is_equal_split do
          share_count = length(shares)
          equal_percentage = 1.0 / share_count

          updated_shares =
            Enum.map(shares, fn share ->
              Map.put(share, "share_percentage", equal_percentage)
            end)

          {:ok, updated_shares}
        else
          has_percentages =
            Enum.any?(shares, fn share -> not is_nil(share["share_percentage"]) end)

          has_amounts = Enum.any?(shares, fn share -> not is_nil(share["amount"]) end)

          if has_percentages and has_amounts do
            {:error, "Cannot mix percentage-based and amount-based shares in the same expense"}
          else
            processed_shares =
              if has_percentages do
                case validate_percentage_shares(shares, expense.amount) do
                  {:ok, valid_shares} -> valid_shares
                  {:error, reason} -> {:error, reason}
                end
              else
                case validate_amount_shares(shares, expense.amount) do
                  {:ok, valid_shares} -> valid_shares
                  {:error, reason} -> {:error, reason}
                end
              end

            case processed_shares do
              {:error, reason} -> {:error, reason}
              valid_shares -> {:ok, valid_shares}
            end
          end
        end
      end)
      |> Multi.run(:create_shares, fn repo, %{expense: expense, validate_shares: shares} ->
        expense_shares =
          Enum.map(shares, fn share ->
            amount =
              if is_nil(share["amount"]) do
                expense.amount * share["share_percentage"]
              else
                share["amount"]
              end

            is_payer = share["user_id"] == expense.paid_by_id

            %{
              expense_id: expense.id,
              user_id: share["user_id"],
              amount: amount,
              share_percentage: share["share_percentage"],
              inserted_at: DateTime.utc_now(),
              updated_at: DateTime.utc_now(),
              remaining_amount: if(is_payer, do: 0.0, else: amount),
              status: if(is_payer, do: "settled", else: "pending")
            }
          end)

        {_count, shares} = repo.insert_all(ExpenseShare, expense_shares, returning: true)
        {:ok, shares}
      end)
      |> Multi.run(:create_initial_payment, fn _repo,
                                               %{expense: expense, create_shares: shares} ->
        payer_share = Enum.find(shares, fn share -> share.user_id == expense.paid_by_id end)

        if payer_share do
          payment_attrs = %{
            amount: expense.amount,
            from_user_id: expense.paid_by_id,
            to_user_id: expense.paid_by_id,
            expense_share_id: payer_share.id,
            status: "completed",
            transaction_id: Ecto.UUID.generate()
          }

          case Payments.create_payment(payment_attrs) do
            {:ok, payment} -> {:ok, payment}
            {:error, changeset} -> {:error, changeset}
          end
        else
          {:error, "Payer's share not found"}
        end
      end)
      |> Multi.run(:expense_activity_log, fn _repo, %{expense: expense} ->
        Splitwise.ActivityLogs.create_activity_log(%{
          action: "expense_created",
          user_id: current_user.id,
          entity_type: "expense",
          entity_id: expense.id,
          expense_id: expense.id,
          group_id: expense.group_id,
          details: %{
            amount: expense.amount,
            description: expense.description,
            group_id: expense.group_id
          }
        })
      end)
      |> Multi.run(:payment_activity_log, fn _repo,
                                             %{
                                               create_initial_payment: payment,
                                               expense: expense
                                             } ->
        Splitwise.ActivityLogs.create_activity_log(%{
          action: "payment_created",
          user_id: expense.paid_by_id,
          entity_type: "payment",
          entity_id: payment.id,
          payment_id: payment.id,
          expense_id: expense.id,
          group_id: expense.group_id,
          details: %{
            amount: payment.amount,
            from_user_id: payment.from_user_id,
            to_user_id: payment.to_user_id,
            expense_share_id: payment.expense_share_id,
            group_id: expense.group_id
          }
        })
      end)
      |> Multi.run(:load_expense, fn _repo, %{expense: expense} ->
        expense = Repo.preload(expense, expense_shares: from(s in ExpenseShare, preload: :user))
        {:ok, expense}
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{load_expense: expense}} ->
          {:ok, expense}

        {:error, :expense, changeset, _} ->
          {:error, changeset}

        {:error, :validate_shares, error, _} ->
          {:error, error}

        {:error, :create_initial_payment, changeset, _} ->
          {:error, changeset}

        {:error, :expense_activity_log, changeset, _} ->
          {:error, changeset}

        {:error, :payment_activity_log, changeset, _} ->
          {:error, changeset}

        {:error, _failed_operation, failed_value, _changes_so_far} ->
          {:error, failed_value}
      end
    end
  end

  defp validate_percentage_shares(shares, total_amount) do
    case Enum.find(shares, fn share -> is_nil(share["share_percentage"]) end) do
      nil ->
        total_percentage =
          Enum.reduce(shares, 0.0, fn share, acc ->
            acc + share["share_percentage"]
          end)

        if abs(total_percentage - 1.0) < 0.01 do
          updated_shares =
            Enum.map(shares, fn share ->
              amount = total_amount * share["share_percentage"]
              Map.put(share, "amount", amount)
            end)

          {:ok, updated_shares}
        else
          {:error, "Share percentages must sum up to 1.0 (100%)"}
        end

      share ->
        {:error, "share_percentage is required for user_id: #{share["user_id"]}"}
    end
  end

  defp validate_amount_shares(shares, total_amount) do
    total_amount =
      if Decimal.is_decimal(total_amount), do: Decimal.to_float(total_amount), else: total_amount

    case Enum.find(shares, fn share -> is_nil(share["amount"]) end) do
      nil ->
        total_share_amount =
          Enum.reduce(shares, 0.0, fn share, acc ->
            amount =
              if Decimal.is_decimal(share["amount"]),
                do: Decimal.to_float(share["amount"]),
                else: share["amount"]

            acc + amount
          end)

        if abs(total_share_amount - total_amount) < 0.01 do
          updated_shares =
            Enum.map(shares, fn share ->
              amount =
                if Decimal.is_decimal(share["amount"]),
                  do: Decimal.to_float(share["amount"]),
                  else: share["amount"]

              percentage = amount / total_amount
              Map.put(share, "share_percentage", percentage)
            end)

          {:ok, updated_shares}
        else
          {:error, "Share amounts must sum up to expense amount"}
        end

      share ->
        {:error, "amount is required for user_id: #{share["user_id"]}"}
    end
  end

  @doc """
  Creates a payment for an expense share and updates the share's status.
  Returns {:ok, payment} if successful, {:error, reason} otherwise.
  """
  def create_payment_for_share(expense_share_id, payment_params, current_user) do
    Multi.new()
    |> Multi.run(:lock_share_and_expense, fn repo, _changes ->
      share =
        from(es in ExpenseShare,
          where: es.id == ^expense_share_id,
          lock: "FOR UPDATE"
        )
        |> repo.one()

      if share do
        expense =
          from(e in Expense,
            where: e.id == ^share.expense_id,
            lock: "FOR UPDATE"
          )
          |> repo.one()

        if expense do
          {:ok, %{share: share, expense: expense}}
        else
          {:error, "Expense not found"}
        end
      else
        {:error, "Expense share not found"}
      end
    end)
    |> Multi.run(:validate_payment, fn _repo,
                                       %{
                                         lock_share_and_expense: %{share: share, expense: expense}
                                       } ->
      cond do
        payment_params["to_user_id"] != expense.paid_by_id ->
          {:error, "Payment must be made to the person who paid the expense"}

        payment_params["from_user_id"] != share.user_id ->
          {:error, "Payment must be made by the person who owes the share"}

        payment_params["amount"] > share.remaining_amount ->
          {:error, "Payment amount cannot be greater than remaining amount"}

        payment_params["amount"] <= 0 ->
          {:error, "Payment amount must be greater than 0"}

        true ->
          {:ok, %{share: share, expense: expense}}
      end
    end)
    |> Multi.run(:create_payment, fn _repo, %{validate_payment: %{share: share}} ->
      payment_attrs =
        Map.merge(payment_params, %{
          "expense_share_id" => share.id,
          "status" => "completed",
          "transaction_id" => Ecto.UUID.generate()
        })

      case Payments.create_payment(payment_attrs) do
        {:ok, payment} -> {:ok, payment}
        {:error, changeset} -> {:error, changeset}
      end
    end)
    |> Multi.run(:update_share, fn repo,
                                   %{
                                     lock_share_and_expense: %{share: share},
                                     validate_payment: %{share: _}
                                   } ->
      payment_amount = payment_params["amount"]
      new_remaining_amount = share.remaining_amount - payment_amount

      is_settled = abs(new_remaining_amount) < 0.01

      share
      |> Ecto.Changeset.change(%{
        remaining_amount: new_remaining_amount,
        status: if(is_settled, do: "settled", else: "pending")
      })
      |> repo.update()
    end)
    |> Multi.run(:check_expense_status, fn repo,
                                           %{
                                             lock_share_and_expense: %{share: share},
                                             update_share: _updated_share
                                           } ->
      shares =
        ExpenseShare
        |> where([es], es.expense_id == ^share.expense_id)
        |> repo.all()

      all_settled = Enum.all?(shares, fn s -> s.status == "settled" end)

      if all_settled do
        expense = repo.get(Expense, share.expense_id)

        expense
        |> Ecto.Changeset.change(%{status: "settled"})
        |> repo.update()
      else
        {:ok, nil}
      end
    end)
    |> Multi.run(:activity_log, fn _repo,
                                   %{
                                     create_payment: payment,
                                     lock_share_and_expense: %{share: _share, expense: expense}
                                   } ->
      Splitwise.ActivityLogs.create_activity_log(%{
        action: "payment_created",
        user_id: current_user.id,
        entity_type: "payment",
        entity_id: payment.id,
        payment_id: payment.id,
        expense_id: expense.id,
        details: %{
          amount: payment.amount,
          from_user_id: payment.from_user_id,
          to_user_id: payment.to_user_id,
          expense_share_id: payment.expense_share_id
        }
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{create_payment: payment, update_share: updated_share}} ->
        {:ok, %{payment: payment, share: updated_share}}

      {:error, :lock_share_and_expense, error, _} ->
        {:error, error}

      {:error, :validate_payment, error, _} ->
        {:error, error}

      {:error, :create_payment, changeset, _} ->
        {:error, changeset}

      {:error, :update_share, changeset, _} ->
        {:error, changeset}

      {:error, :check_expense_status, changeset, _} ->
        {:error, changeset}

      {:error, :activity_log, changeset, _} ->
        {:error, changeset}

      {:error, _failed_operation, failed_value, _changes_so_far} ->
        {:error, failed_value}
    end
  end

  def update_expense_with_shares(%Expense{} = expense, expense_params, shares, current_user)
      when is_list(shares) do
    if shares == [] or Enum.any?(shares, fn s -> !is_map(s) or is_nil(s["user_id"]) end) do
      {:error, "Shares list must be a non-empty list of valid share maps with user_id."}
    else
      paid_by_id = Map.get(expense_params, "paid_by_id", expense.paid_by_id)

      if paid_by_id != expense.paid_by_id do
        {:error, "You cannot change the payer of the expense."}
      else
        Multi.new()
        |> Multi.run(:lock_expense, fn repo, _changes ->
          expense =
            from(e in Expense,
              where: e.id == ^expense.id,
              lock: "FOR UPDATE"
            )
            |> repo.one()

          if expense do
            from(es in ExpenseShare,
              where: es.expense_id == ^expense.id,
              lock: "FOR UPDATE"
            )
            |> repo.all()

            {:ok, expense}
          else
            {:error, "Expense not found"}
          end
        end)
        |> Multi.run(:find_or_create_group, fn repo, %{lock_expense: expense} ->
          if is_nil(expense_params["group_id"]) do
            user_ids =
              ([expense.paid_by_id] ++
                 Enum.map(shares, & &1["user_id"]))
              |> Enum.uniq()

            if Enum.any?(user_ids, &is_nil/1) do
              {:error, "Invalid or missing user_id in shares or payer."}
            else
              from(u in User, where: u.id in ^user_ids, lock: "FOR UPDATE")
              |> repo.all()

              case Splitwise.Accounts.find_or_create_group_by_users(user_ids, current_user) do
                {:ok, %{group: group}} ->
                  {:ok, Map.put(expense_params, "group_id", group.id)}

                error ->
                  error
              end
            end
          else
            {:ok, expense_params}
          end
        end)
        |> Multi.update(:expense, fn %{find_or_create_group: updated_params} ->
          Expense.changeset(expense, Map.put(updated_params, "paid_by_id", expense.paid_by_id))
        end)
        |> Multi.delete_all(
          :delete_old_shares,
          from(es in ExpenseShare, where: es.expense_id == ^expense.id)
        )
        |> Multi.run(:create_shares, fn repo, %{expense: updated_expense} ->
          is_equal_split =
            Enum.all?(shares, fn share ->
              is_nil(share["share_percentage"]) and is_nil(share["amount"]) and
                not is_nil(share["user_id"])
            end)

          shares_to_insert =
            if is_equal_split do
              share_count = length(shares)
              equal_percentage = 1.0 / share_count

              Enum.map(shares, fn share ->
                Map.put(share, "share_percentage", equal_percentage)
              end)
            else
              has_percentages =
                Enum.any?(shares, fn share -> not is_nil(share["share_percentage"]) end)

              has_amounts = Enum.any?(shares, fn share -> not is_nil(share["amount"]) end)

              if has_percentages and has_amounts do
                {:error,
                 "Cannot mix percentage-based and amount-based shares in the same expense"}
              else
                if has_percentages do
                  case validate_percentage_shares(shares, updated_expense.amount) do
                    {:ok, valid_shares} -> valid_shares
                    {:error, reason} -> {:error, reason}
                  end
                else
                  case validate_amount_shares(shares, updated_expense.amount) do
                    {:ok, valid_shares} -> valid_shares
                    {:error, reason} -> {:error, reason}
                  end
                end
              end
            end

          case shares_to_insert do
            {:error, reason} ->
              {:error, reason}

            valid_shares ->
              now = DateTime.utc_now()

              expense_shares =
                Enum.map(valid_shares, fn share ->
                  amount =
                    if is_nil(share["amount"]) do
                      updated_expense.amount * share["share_percentage"]
                    else
                      share["amount"]
                    end

                  is_payer = share["user_id"] == updated_expense.paid_by_id

                  %{
                    expense_id: updated_expense.id,
                    user_id: share["user_id"],
                    amount: amount * 1.0,
                    share_percentage: share["share_percentage"],
                    inserted_at: now,
                    updated_at: now,
                    remaining_amount: if(is_payer, do: 0.0, else: amount * 1.0),
                    status: if(is_payer, do: "settled", else: "pending")
                  }
                end)

              {_count, shares} =
                repo.insert_all(ExpenseShare, expense_shares, returning: true)

              {:ok, shares}
          end
        end)
        |> Multi.run(:activity_log, fn _repo, %{expense: updated_expense} ->
          Splitwise.ActivityLogs.create_activity_log(%{
            action: "expense_updated",
            user_id: current_user.id,
            entity_type: "expense",
            entity_id: updated_expense.id,
            expense_id: updated_expense.id,
            group_id: updated_expense.group_id,
            details: %{
              amount: updated_expense.amount,
              description: updated_expense.description,
              group_id: updated_expense.group_id
            }
          })
        end)
        |> Multi.run(:load_expense, fn repo, %{expense: updated_expense} ->
          expense =
            repo.preload(updated_expense,
              expense_shares: from(s in ExpenseShare, preload: :user)
            )

          {:ok, expense}
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{load_expense: expense}} ->
            {:ok, expense}

          {:error, :expense, changeset, _} ->
            {:error, changeset}

          {:error, :find_or_create_group, error, _} ->
            {:error, error}

          {:error, _failed_operation, failed_value, _changes_so_far} ->
            {:error, failed_value}
        end
      end
    end
  end

  def update_expense(%Expense{} = expense, expense_params, current_user) do
    new_amount = Map.get(expense_params, "amount", expense.amount)

    if expense.status == "settled" and new_amount != expense.amount do
      {:error, "Cannot update amount of a settled expense."}
    else
      if Map.has_key?(expense_params, "amount") do
        {:error, "Please provide shares when updating expense amount."}
      else
        Multi.new()
        |> Multi.run(:lock_expense, fn repo, _changes ->
          expense =
            from(e in Expense,
              where: e.id == ^expense.id,
              lock: "FOR UPDATE"
            )
            |> repo.one()

          if expense do
            {:ok, expense}
          else
            {:error, "Expense not found"}
          end
        end)
        |> Multi.update(:expense, fn %{lock_expense: locked_expense} ->
          Expense.changeset(locked_expense, expense_params)
        end)
        |> Multi.run(:activity_log, fn _repo, %{expense: updated_expense} ->
          Splitwise.ActivityLogs.create_activity_log(%{
            action: "expense_updated",
            user_id: current_user.id,
            entity_type: "expense",
            entity_id: updated_expense.id,
            expense_id: updated_expense.id,
            group_id: updated_expense.group_id,
            details: %{
              amount: updated_expense.amount,
              description: updated_expense.description,
              group_id: updated_expense.group_id
            }
          })
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{expense: updated_expense}} -> {:ok, updated_expense}
          {:error, :expense, changeset, _} -> {:error, changeset}
          {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
        end
      end
    end
  end

  @doc """
  Fetches all expense shares where the given user owes money to others.
  Returns a list of maps containing:
  - expense details
  - amount owed
  - user details of the person they owe money to
  """
  def get_amount_payable(user_id) do
    from(es in ExpenseShare,
      join: e in Expense,
      on: es.expense_id == e.id,
      join: u in User,
      on: e.paid_by_id == u.id,
      join: g in Group,
      on: e.group_id == g.id,
      where: es.user_id == ^user_id and es.status == "pending",
      select: %{
        expense_id: e.id,
        expense_description: e.description,
        expense_amount: e.amount,
        amount_owed: es.amount,
        group_name: g.name,
        owed_to: %{
          user_id: u.id,
          email: u.email,
          name: u.name,
          remaining_amount: es.remaining_amount
        },
        created_at: e.inserted_at
      },
      order_by: [desc: e.inserted_at]
    )
    |> Repo.all()
    |> case do
      [] -> {:ok, []}
      shares -> {:ok, shares}
    end
  end

  @doc """
  Fetches all expense shares where others owe money to the given user.
  Returns a list of maps containing:
  - expense details
  - amount receivable
  - user details of the person who owes money
  """
  def get_amount_receivable(user_id) do
    from(es in ExpenseShare,
      join: e in Expense,
      on: es.expense_id == e.id,
      join: u in User,
      on: es.user_id == u.id,
      join: g in Group,
      on: e.group_id == g.id,
      where: e.paid_by_id == ^user_id and es.status == "pending" and es.user_id != ^user_id,
      select: %{
        expense_id: e.id,
        expense_description: e.description,
        expense_amount: e.amount,
        amount_receivable: es.amount,
        group_name: g.name,
        owed_by: %{
          user_id: u.id,
          email: u.email,
          name: u.name,
          remaining_amount: es.remaining_amount
        },
        created_at: e.inserted_at
      },
      order_by: [desc: e.inserted_at]
    )
    |> Repo.all()
    |> case do
      [] -> {:ok, []}
      shares -> {:ok, shares}
    end
  end

  @doc """
  Creates a comment for an expense.
  Returns {:ok, comment} if successful, {:error, reason} otherwise.
  """
  def create_expense_comment(expense_id, comment_text, current_user) do
    Multi.new()
    |> Multi.run(:lock_expense, fn repo, _changes ->
      # Lock the expense to prevent concurrent modifications
      expense =
        from(e in Expense,
          where: e.id == ^expense_id,
          lock: "FOR UPDATE"
        )
        |> repo.one()

      if expense do
        {:ok, expense}
      else
        {:error, "Expense not found"}
      end
    end)
    |> Multi.insert(:comment, fn %{lock_expense: expense} ->
      Comment.changeset(%Comment{}, %{
        "expense_id" => expense.id,
        "user_id" => current_user.id,
        "content" => comment_text
      })
    end)
    |> Multi.run(:activity_log, fn _repo, %{comment: comment, lock_expense: expense} ->
      Splitwise.ActivityLogs.create_activity_log(%{
        action: "comment_created",
        user_id: current_user.id,
        entity_type: "comment",
        entity_id: comment.id,
        expense_id: expense.id,
        group_id: expense.group_id,
        comment_id: comment.id,
        details: %{
          content: comment.content,
          expense_id: expense.id,
          group_id: expense.group_id
        }
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{comment: comment}} ->
        # Preload the user for the response
        comment = Repo.preload(comment, :user)
        {:ok, comment}

      {:error, :lock_expense, error, _} ->
        {:error, error}

      {:error, :comment, changeset, _} ->
        {:error, changeset}

      {:error, _failed_operation, failed_value, _changes_so_far} ->
        {:error, failed_value}
    end
  end
end
