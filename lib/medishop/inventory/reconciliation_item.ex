defmodule Medishop.Inventory.ReconciliationItem do
  @moduledoc """
  ReconciliationItem tracks individual product checks within a stock reconciliation session.

  Each item records:
  - What the system showed (system_quantity)
  - What was physically counted (physical_quantity)
  - The discrepancy (calculated)
  - The reason for adjustment if discrepancy exists
  - Link to the created inventory event

  Adjustment reasons:
  - :training_stock - Used for training purposes
  - :breakage - Physical damage or breakage
  - :expired - Past expiration date
  - :theft - Suspected theft or loss
  - :count_error - Previous counting error
  - :system_error - System data entry error
  - :spillage - Spilled or contaminated
  - :other - Other reason (requires adjustment_notes)
  """

  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "reconciliation_items"
    repo Medishop.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [
        :reconciliation_id,
        :product_id,
        :location_inventory_id,
        :system_quantity,
        :physical_quantity,
        :adjustment_reason,
        :adjustment_notes
      ]
    end

    update :update do
      primary? true
      require_atomic? false
      accept [
        :physical_quantity,
        :adjustment_reason,
        :adjustment_notes,
        :inventory_event_id
      ]
    end

    create :bulk_create do
      description "Create multiple reconciliation items at once"
      accept [
        :reconciliation_id,
        :product_id,
        :location_inventory_id,
        :system_quantity,
        :physical_quantity,
        :adjustment_reason,
        :adjustment_notes
      ]
    end

    read :by_reconciliation do
      description "Get all items for a specific reconciliation"
      argument :reconciliation_id, :uuid, allow_nil?: false

      filter expr(reconciliation_id == ^arg(:reconciliation_id))
    end

    read :with_discrepancies do
      description "Get only items with discrepancies"
      argument :reconciliation_id, :uuid, allow_nil?: false

      filter expr(reconciliation_id == ^arg(:reconciliation_id) and system_quantity != physical_quantity)
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

    attribute :system_quantity, :integer do
      description "Quantity shown in system at time of reconciliation"
      allow_nil? false
      public? true
    end

    attribute :physical_quantity, :integer do
      description "Quantity counted during physical stock take"
      allow_nil? false
      public? true
    end

    attribute :adjustment_reason, :atom do
      description "Categorized reason for the discrepancy"
      allow_nil? true
      public? true

      constraints one_of: [
                    :training_stock,
                    :breakage,
                    :expired,
                    :theft,
                    :count_error,
                    :system_error,
                    :spillage,
                    :other
                  ]
    end

    attribute :adjustment_notes, :string do
      description "Additional notes explaining the adjustment"
      allow_nil? true
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :reconciliation, Medishop.Inventory.StockReconciliation do
      allow_nil? false
      public? true
    end

    belongs_to :product, Medishop.Products.Product do
      allow_nil? false
      public? true
    end

    belongs_to :location_inventory, Medishop.Inventory.LocationInventory do
      allow_nil? false
      public? true
    end

    belongs_to :inventory_event, Medishop.Inventory.InventoryEvent do
      allow_nil? true
      public? true
    end
  end

  calculations do
    calculate :discrepancy, :integer, expr(physical_quantity - system_quantity) do
      description "Difference between physical and system quantities (physical - system)"
    end

    calculate :has_discrepancy, :boolean, expr(physical_quantity != system_quantity) do
      description "Whether this item has a discrepancy"
    end
  end

  validations do
    # Ensure adjustment_reason is provided if there's a discrepancy
    validate fn changeset, _context ->
      system_quantity = Ash.Changeset.get_attribute(changeset, :system_quantity)
      physical_quantity = Ash.Changeset.get_attribute(changeset, :physical_quantity)
      adjustment_reason = Ash.Changeset.get_attribute(changeset, :adjustment_reason)

      # Only validate if:
      # 1. We're creating a new record (no data present), OR
      # 2. physical_quantity is being changed and creates/increases discrepancy
      is_create = is_nil(changeset.data.id)

      physical_changed = Ash.Changeset.changing_attribute?(changeset, :physical_quantity)

      should_validate =
        (is_create and system_quantity != physical_quantity) or
          (physical_changed and system_quantity != physical_quantity)

      if should_validate and is_nil(adjustment_reason) do
        {:error,
         field: :adjustment_reason,
         message: "Adjustment reason is required when there is a discrepancy"}
      else
        :ok
      end
    end

    # Ensure adjustment_notes is provided when reason is :other
    validate fn changeset, _context ->
      adjustment_reason = Ash.Changeset.get_attribute(changeset, :adjustment_reason)
      adjustment_notes = Ash.Changeset.get_attribute(changeset, :adjustment_notes)

      if adjustment_reason == :other and
           (is_nil(adjustment_notes) or String.trim(adjustment_notes) == "") do
        {:error,
         field: :adjustment_notes,
         message: "Additional notes are required when adjustment reason is 'other'"}
      else
        :ok
      end
    end
  end

  identities do
    identity :unique_reconciliation_product, [:reconciliation_id, :product_id]
  end
end
