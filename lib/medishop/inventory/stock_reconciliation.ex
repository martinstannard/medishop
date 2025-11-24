defmodule Medishop.Inventory.StockReconciliation do
  @moduledoc """
  StockReconciliation resource tracks periodic physical stock take sessions.

  A reconciliation session allows location admins to perform physical counts of inventory
  and compare against system records, generating adjustment events for any discrepancies.

  Status workflow:
  - :in_progress - Reconciliation is currently being performed
  - :completed - Reconciliation finished, adjustments made
  - :cancelled - Reconciliation abandoned without creating adjustments
  """

  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Inventory,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Event],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "stock_reconciliations"
    repo Medishop.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:location_id, :notes]

      # Set default values for new reconciliation
      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :in_progress)
        |> Ash.Changeset.force_change_attribute(:started_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(:total_items_checked, 0)
        |> Ash.Changeset.force_change_attribute(:total_discrepancies, 0)
        |> Ash.Changeset.force_change_attribute(:total_adjustments_made, 0)
      end
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:notes]
    end

    update :complete do
      description "Complete the reconciliation and finalize all adjustments"
      require_atomic? false
      accept [:total_items_checked, :total_discrepancies, :total_adjustments_made]

      validate fn changeset, _context ->
        current_status = Ash.Changeset.get_attribute(changeset, :status)

        if current_status == :in_progress do
          :ok
        else
          {:error,
           field: :status, message: "Can only complete reconciliations that are in progress"}
        end
      end

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :completed)
        |> Ash.Changeset.force_change_attribute(:completed_at, DateTime.utc_now())
      end

      # After completing the reconciliation, create inventory adjustment events for all discrepancies
      change after_action(fn changeset, reconciliation, context ->
        case create_adjustment_events_for_reconciliation(reconciliation, context) do
          {:ok, _events} -> {:ok, reconciliation}
          {:error, error} -> {:error, error}
        end
      end)
    end

    update :cancel do
      description "Cancel an in-progress reconciliation"
      require_atomic? false

      validate fn changeset, _context ->
        current_status = Ash.Changeset.get_attribute(changeset, :status)

        if current_status == :in_progress do
          :ok
        else
          {:error,
           field: :status, message: "Can only cancel reconciliations that are in progress"}
        end
      end

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :cancelled)
        |> Ash.Changeset.force_change_attribute(:completed_at, DateTime.utc_now())
      end
    end

    read :by_location do
      description "Get all reconciliations for a specific location"
      argument :location_id, :uuid, allow_nil?: false

      filter expr(location_id == ^arg(:location_id))
    end

    read :by_status do
      description "Get all reconciliations with a specific status"
      argument :status, :atom, allow_nil?: false

      filter expr(status == ^arg(:status))
    end

    read :in_progress_by_location do
      description "Get in-progress reconciliation for a location"
      argument :location_id, :uuid, allow_nil?: false

      filter expr(location_id == ^arg(:location_id) and status == :in_progress)
      # We expect at most one, but read actions return a list by default unless we use get? true (but get expects primary key usually or unique constraint)
      # We'll just return list and take first.
    end
  end

  policies do
    # Allow all actions for now (we'll add proper authorization later)
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :atom do
      description "Current status of the reconciliation"
      allow_nil? false
      public? true
      constraints one_of: [:in_progress, :completed, :cancelled]
      default :in_progress
    end

    attribute :started_at, :utc_datetime_usec do
      description "When the reconciliation was started"
      allow_nil? false
      public? true
    end

    attribute :completed_at, :utc_datetime_usec do
      description "When the reconciliation was completed or cancelled"
      allow_nil? true
      public? true
    end

    attribute :notes, :string do
      description "Optional notes about this reconciliation session"
      allow_nil? true
      public? true
    end

    attribute :total_items_checked, :integer do
      description "Total number of products checked during this reconciliation"
      allow_nil? false
      public? true
      default 0
    end

    attribute :total_discrepancies, :integer do
      description "Number of items with discrepancies found"
      allow_nil? false
      public? true
      default 0
    end

    attribute :total_adjustments_made, :integer do
      description "Number of adjustment events created"
      allow_nil? false
      public? true
      default 0
    end

    # AshEvents will automatically add:
    # - actor_id (uuid) - user who performed the reconciliation
    # - version (integer) - event version
    # - metadata (map) - additional event metadata

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :location, Medishop.Organizations.Location do
      allow_nil? false
      public? true
    end

    has_many :reconciliation_items, Medishop.Inventory.ReconciliationItem do
      public? true
      destination_attribute :reconciliation_id
    end
  end

  calculations do
    calculate :duration_minutes, :integer, expr(
      if is_nil(completed_at) do
        fragment("EXTRACT(EPOCH FROM (? - ?))", now(), started_at) / 60
      else
        fragment("EXTRACT(EPOCH FROM (? - ?))", completed_at, started_at) / 60
      end
    ) do
      description "Duration of the reconciliation session in minutes"
    end
  end

  # Helper function to create adjustment events for all discrepancies in a reconciliation
  defp create_adjustment_events_for_reconciliation(reconciliation, context) do
    # Load reconciliation items with discrepancies
    {:ok, reconciliation_with_items} =
      reconciliation
      |> Ash.load([reconciliation_items: [:product, :discrepancy, :has_discrepancy]])

    items_with_discrepancies =
      reconciliation_with_items.reconciliation_items
      |> Enum.filter(fn item ->
        # Load calculations if not already loaded
        {:ok, loaded} = Ash.load(item, [:has_discrepancy, :discrepancy])
        loaded.has_discrepancy
      end)

    # Create inventory events for each discrepancy
    results =
      Enum.map(items_with_discrepancies, fn item ->
        # Load the item with calculations if needed
        {:ok, item_loaded} = Ash.load(item, [:discrepancy])

        # Format the reason string combining adjustment_reason and notes
        reason =
          format_adjustment_reason(item.adjustment_reason, item.adjustment_notes)

        # Create the inventory event
        event_result =
          Medishop.Inventory.create_inventory_event(
            %{
              location_id: reconciliation.location_id,
              product_id: item.product_id,
              event_type: :adjustment,
              quantity_change: item_loaded.discrepancy,
              reason: reason,
              reference_type: "StockReconciliation",
              reference_id: reconciliation.id,
              occurred_at: reconciliation.completed_at || DateTime.utc_now()
            },
            actor: Map.get(context, :actor)
          )

        case event_result do
          {:ok, event} ->
            # Update the reconciliation item with the created event ID
            Medishop.Inventory.update_reconciliation_item(item, %{
              inventory_event_id: event.id
            })

            {:ok, event}

          {:error, error} ->
            {:error, error}
        end
      end)

    # Check if any errors occurred
    errors = Enum.filter(results, fn result -> match?({:error, _}, result) end)

    if Enum.empty?(errors) do
      events = Enum.map(results, fn {:ok, event} -> event end)
      {:ok, events}
    else
      {:error, List.first(errors)}
    end
  end

  # Helper function to format adjustment reason into a readable string
  defp format_adjustment_reason(reason, notes) do
    reason_text =
      case reason do
        :training_stock -> "Training Stock"
        :breakage -> "Breakage"
        :expired -> "Expired"
        :theft -> "Theft"
        :count_error -> "Count Error"
        :system_error -> "System Error"
        :spillage -> "Spillage"
        :other -> "Other"
        _ -> "Unknown"
      end

    if notes && String.trim(notes) != "" do
      "#{reason_text}: #{notes}"
    else
      reason_text
    end
  end
end
