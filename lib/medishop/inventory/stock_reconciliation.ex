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
end
