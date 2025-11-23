defmodule Medishop.Inventory.InventoryEvent do
  @moduledoc """
  InventoryEvent resource representing immutable inventory movements using event sourcing.

  Tracks all inventory changes (purchases, usage, disposal, expiration, adjustments) with complete audit trail.
  Uses AshEvents extension for automatic actor attribution, versioning, and event replay capabilities.

  Event types:
  - :purchase_received - Stock added from order delivery
  - :administered - Medication given to patient
  - :expired - Medication past expiration date
  - :disposed - Medication disposed (damaged, recalled, contaminated)
  - :adjustment - Manual correction of inventory levels
  """

  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Inventory,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Event],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "inventory_events"
    repo Medishop.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [
        :location_id,
        :product_id,
        :event_type,
        :quantity_change,
        :batch_number,
        :expiration_date,
        :reference_type,
        :reference_id,
        :reason,
        :occurred_at
      ]

      # Set occurred_at to current time if not provided
      change fn changeset, _context ->
        if Ash.Changeset.get_attribute(changeset, :occurred_at) do
          changeset
        else
          Ash.Changeset.force_change_attribute(changeset, :occurred_at, DateTime.utc_now())
        end
      end
    end

    read :by_location_and_product do
      argument :location_id, :uuid, allow_nil?: false
      argument :product_id, :uuid, allow_nil?: false

      filter expr(location_id == ^arg(:location_id) and product_id == ^arg(:product_id))
    end

    read :by_location do
      argument :location_id, :uuid, allow_nil?: false

      filter expr(location_id == ^arg(:location_id))
    end

    read :by_product do
      argument :product_id, :uuid, allow_nil?: false

      filter expr(product_id == ^arg(:product_id))
    end
  end

  policies do
    # Allow all actions for now (will implement proper authorization later)
    # Per requirements: all users with location access can create and read events
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :event_type, :atom do
      allow_nil? false
      constraints one_of: [:purchase_received, :administered, :expired, :disposed, :adjustment]
      public? true
    end

    attribute :quantity_change, :integer do
      allow_nil? false
      public? true
    end

    attribute :batch_number, :string do
      public? true
    end

    attribute :expiration_date, :date do
      public? true
    end

    attribute :reference_type, :string do
      public? true
    end

    attribute :reference_id, :uuid do
      public? true
    end

    attribute :reason, :string do
      public? true
    end

    attribute :occurred_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    # AshEvents will automatically add these fields:
    # - actor_id (uuid) - tracks who made the change
    # - version (integer) - event version for ordering
    # - metadata (map) - additional event metadata
    # - created_at (utc_datetime_usec) - when recorded in system

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :location, Medishop.Organizations.Location do
      allow_nil? false
      public? true
    end

    belongs_to :product, Medishop.Products.Product do
      allow_nil? false
      public? true
    end

    # Actor relationship will be automatically added by AshEvents
    # belongs_to :actor, Medishop.Accounts.User
  end

  calculations do
    # For aggregation purposes - returns the quantity_change
    calculate :net_change, :integer, expr(quantity_change)
  end

  # Validations
  validations do
    # Ensure reason is provided for disposed and adjustment events
    validate fn changeset, _context ->
      event_type = Ash.Changeset.get_attribute(changeset, :event_type)
      reason = Ash.Changeset.get_attribute(changeset, :reason)

      if event_type in [:disposed, :adjustment] and is_nil(reason) do
        {:error, field: :reason, message: "Reason is required for #{event_type} events"}
      else
        :ok
      end
    end
  end
end
