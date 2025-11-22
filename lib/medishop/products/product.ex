defmodule Medishop.Products.Product do
  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Products,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "products"
    repo Medishop.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:sku, :title, :description, :images, :price, :active]
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:title, :description, :images, :price, :active]
    end

    read :search do
      description "Search products with filters"

      argument :title, :string, allow_nil?: true
      argument :sku, :string, allow_nil?: true
      argument :active, :boolean, allow_nil?: true

      argument :sort_by, :atom,
        allow_nil?: true,
        constraints: [one_of: [:title, :price, :created_at]]

      argument :sort_order, :atom, allow_nil?: true, constraints: [one_of: [:asc, :desc]]

      filter expr(
               if not is_nil(^arg(:title)) do
                 contains(title, ^arg(:title))
               else
                 true
               end and
                 if not is_nil(^arg(:sku)) do
                   sku == ^arg(:sku)
                 else
                   true
                 end and
                 if not is_nil(^arg(:active)) do
                   active == ^arg(:active)
                 else
                   true
                 end
             )

      prepare fn query, _context ->
        sort_by = Ash.Query.get_argument(query, :sort_by) || :created_at
        sort_order = Ash.Query.get_argument(query, :sort_order) || :desc

        case sort_order do
          :asc -> Ash.Query.sort(query, [sort_by])
          :desc -> Ash.Query.sort(query, [{sort_by, :desc}])
        end
      end
    end
  end

  policies do
    # Allow all actions for now (we'll add proper authorization later)
    policy always() do
      authorize_if always()
    end
  end

  validations do
    validate compare(:price, greater_than: 0), message: "Price must be greater than 0"
  end

  attributes do
    uuid_primary_key :id

    attribute :sku, :string do
      description "Product identifier (Stock Keeping Unit)"
      allow_nil? false
      public? true
    end

    attribute :title, :string do
      description "Product name"
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      description "Detailed product description"
      allow_nil? true
      public? true
    end

    attribute :images, {:array, :string} do
      description "Array of image URLs/paths"
      default []
      public? true
    end

    attribute :price, :decimal do
      description "Product price in dollars"
      allow_nil? false
      public? true
    end

    attribute :active, :boolean do
      description "Whether product is available for purchase"
      default true
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :location_inventories, Medishop.Inventory.LocationInventory
  end

  identities do
    identity :unique_sku, [:sku]
  end
end
