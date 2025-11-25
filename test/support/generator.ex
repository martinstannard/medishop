defmodule Medishop.Generator do
  use Ash.Generator

  def user(overrides \\ []) do
    Ash.Generator.changeset_generator(
      Medishop.Accounts.User,
      :register,
      defaults: [
        email: sequence(:email, &"user#{&1}@example.com"),
        password: "password"
      ],
      overrides: overrides,
      authorize?: false
    )
  end

  def organization(overrides \\ []) do
    Ash.Generator.changeset_generator(
      Medishop.Organizations.Organization,
      :create,
      defaults: [
        name: sequence(:name, &"Test Organization #{&1}")
      ],
      overrides: overrides,
      authorize?: false
    )
  end

  def location(overrides \\ []) do
    organization_id =
      overrides[:organization_id] ||
        organization() |> Ash.Generator.generate() |> Map.get(:id)

    Ash.Generator.changeset_generator(
      Medishop.Organizations.Location,
      :create,
      defaults: [
        name: sequence(:name, &"Test Location #{&1}"),
        store: true,
        address: %{
          street: "123 Test St",
          city: "Test City",
          state: "TC",
          zip: "12345",
          country: "USA"
        },
        contact_number: "+1-555-555-5555",
        organization_id: organization_id
      ],
      overrides: overrides,
      authorize?: false
    )
  end

  def organization_membership(overrides \\ []) do
    user_id =
      overrides[:user_id] ||
        user() |> Ash.Generator.generate() |> Map.get(:id)

    organization_id =
      overrides[:organization_id] ||
        organization()
        |> Ash.Generator.generate()
        |> Map.get(:id)

    Ash.Generator.changeset_generator(
      Medishop.Organizations.OrganizationMembership,
      :create,
      defaults: [
        organization_id: organization_id,
        user_id: user_id,
        org_roles: [:org_member]
      ],
      overrides: overrides,
      authorize?: false
    )
  end

  def organization_location_membership(overrides \\ []) do
    # This one is tricky because it needs an organization_membership_id
    # which implies a user and an organization.
    # And a location_id which must belong to that organization (ideally).
    # For simplicity, if IDs aren't provided, we generate them, but linking them correctly
    # might require the caller to be careful or us to be smarter.
    
    # If no membership provided, create one.
    membership_id = overrides[:organization_membership_id]
    
    {membership_id, org_id} =
      if membership_id do
         {membership_id, nil} # We don't easily know the org_id, hopefully caller handles location
      else
         org = organization() |> Ash.Generator.generate()
         user = user() |> Ash.Generator.generate()
         mem = organization_membership(organization_id: org.id, user_id: user.id) |> Ash.Generator.generate()
         {mem.id, org.id}
      end

    location_id =
      overrides[:location_id] ||
        (
           # If we created the org, use it. If not, create a new org/location (might be inconsistent if membership was provided but location wasn't)
           # Best effort: if we have org_id, use it.
           org_id_to_use = org_id || organization() |> Ash.Generator.generate() |> Map.get(:id)
           location(organization_id: org_id_to_use) |> Ash.Generator.generate() |> Map.get(:id)
        )

    Ash.Generator.changeset_generator(
      Medishop.Organizations.OrganizationLocationMembership,
      :create,
      defaults: [
        organization_membership_id: membership_id,
        location_id: location_id
      ],
      overrides: overrides,
      authorize?: false
    )
  end

  def product(overrides \\ []) do
    Ash.Generator.changeset_generator(
      Medishop.Products.Product,
      :create,
      defaults: [
        sku: sequence(:sku, &"SKU-#{&1}"),
        title: sequence(:title, &"Test Product #{&1}"),
        images: [],
        price: Decimal.new("10.00"),
        active: true,
        unit_of_measure: :tablets,
        storage_location: :cupboard
      ],
      overrides: overrides,
      authorize?: false
    )
  end

  def location_inventory(overrides \\ []) do
    # Assuming manual creation via create_location_inventory is allowed/standard for tests
    location_id =
      overrides[:location_id] ||
        location() |> Ash.Generator.generate() |> Map.get(:id)

    product_id =
      overrides[:product_id] ||
        product() |> Ash.Generator.generate() |> Map.get(:id)

    Ash.Generator.changeset_generator(
      Medishop.Inventory.LocationInventory,
      :create, # Assuming the action name is :create, checked fixture calling create_location_inventory
      defaults: [
        location_id: location_id,
        product_id: product_id
      ],
      overrides: overrides,
      authorize?: false
    )
  end

  def inventory_event(overrides \\ []) do
    location_id =
      overrides[:location_id] ||
        location() |> Ash.Generator.generate() |> Map.get(:id)

    product_id =
      overrides[:product_id] ||
        product() |> Ash.Generator.generate() |> Map.get(:id)

    Ash.Generator.changeset_generator(
      Medishop.Inventory.InventoryEvent,
      :create,
      defaults: [
        location_id: location_id,
        product_id: product_id,
        event_type: :purchase_received,
        quantity_change: 10,
        occurred_at: DateTime.utc_now()
      ],
      overrides: overrides,
      authorize?: false
    )
  end

  def cart(overrides \\ []) do
    location_id =
      overrides[:location_id] ||
        location() |> Ash.Generator.generate() |> Map.get(:id)

    Ash.Generator.changeset_generator(
      Medishop.Shop.Cart,
      :create,
      defaults: [
        location_id: location_id
      ],
      overrides: overrides,
      authorize?: false
    )
  end

  def cart_item(overrides \\ []) do
     cart_id =
      overrides[:cart_id] ||
        cart() |> Ash.Generator.generate() |> Map.get(:id)

     product_id =
      overrides[:product_id] ||
        product() |> Ash.Generator.generate() |> Map.get(:id)

     # Price logic: fixture fetched product to get price.
     # Here we can default to something or try to be smart.
     # Ideally caller provides price or we just use a default.
     # If product_id is generated here, we can't easily get its price without fetching.
     # Let's default to 10.00 if not provided, assuming default product price.
     price = overrides[:price_at_addition] || Decimal.new("10.00")

    Ash.Generator.changeset_generator(
      Medishop.Shop.CartItem,
      :create,
      defaults: [
        cart_id: cart_id,
        product_id: product_id,
        quantity: 1,
        price_at_addition: price
      ],
      overrides: overrides,
      authorize?: false
    )
  end

  def order(overrides \\ []) do
    # Create directly
    location_id =
      overrides[:location_id] ||
        location() |> Ash.Generator.generate() |> Map.get(:id)
    
    user_id =
       overrides[:user_id] ||
         user() |> Ash.Generator.generate() |> Map.get(:id)

    Ash.Generator.changeset_generator(
      Medishop.Shop.Order,
      :create,
      defaults: [
        location_id: location_id,
        user_id: user_id,
        status: :pending,
        subtotal: Decimal.new("100.00"),
        total: Decimal.new("100.00")
      ],
      overrides: overrides,
      authorize?: false
    )
  end

  # Helper for creating order from cart? 
  # Generators usually focus on the resource itself. 
  # creating from cart is a specific action on Order that takes a cart.
  # We can add it if needed, but let's stick to resource generators first.

  def order_item(overrides \\ []) do
    order_id =
      overrides[:order_id] ||
        order() |> Ash.Generator.generate() |> Map.get(:id)

    product_id =
      overrides[:product_id] ||
        product() |> Ash.Generator.generate() |> Map.get(:id)

    unit_price = overrides[:unit_price] || Decimal.new("10.00")
    quantity = overrides[:quantity] || 1
    line_total = overrides[:line_total] || Decimal.mult(unit_price, Decimal.new(quantity))

    Ash.Generator.changeset_generator(
      Medishop.Shop.OrderItem,
      :create,
      defaults: [
        order_id: order_id,
        product_id: product_id,
        quantity: quantity,
        unit_price: unit_price,
        line_total: line_total
      ],
      overrides: overrides,
      authorize?: false
    )
  end

  def supplier(overrides \\ []) do
    Ash.Generator.changeset_generator(
      Medishop.Products.Supplier,
      :create,
      defaults: [
        name: sequence(:name, &"Supplier #{&1}"),
        address: "123 Supplier St",
        contact_email: sequence(:email, &"supplier#{&1}@example.com"),
        contact_number: "+1-555-000-0000"
      ],
      overrides: overrides,
      authorize?: false
    )
  end

  def stock_reconciliation(overrides \\ []) do
    location_id =
      overrides[:location_id] ||
        location() |> Ash.Generator.generate() |> Map.get(:id)

    Ash.Generator.changeset_generator(
      Medishop.Inventory.StockReconciliation,
      :create,
      defaults: [
        location_id: location_id,
        notes: "Test reconciliation"
      ],
      overrides: overrides,
      authorize?: false
    )
  end

  def reconciliation_item(overrides \\ []) do
    reconciliation_id =
      overrides[:reconciliation_id] ||
        stock_reconciliation() |> Ash.Generator.generate() |> Map.get(:id)

    product_id =
      overrides[:product_id] ||
        product() |> Ash.Generator.generate() |> Map.get(:id)

    # For location_inventory_id, we need a location_inventory record
    # If reconciliation_id was generated, we have a location_id from that
    # If provided, we don't know the location_id easily unless caller provides it
    location_inventory_id =
      overrides[:location_inventory_id] ||
        location_inventory(product_id: product_id) |> Ash.Generator.generate() |> Map.get(:id)

    system_quantity = overrides[:system_quantity] || 10
    physical_quantity = overrides[:physical_quantity] || 10

    Ash.Generator.changeset_generator(
      Medishop.Inventory.ReconciliationItem,
      :create,
      defaults: [
        reconciliation_id: reconciliation_id,
        product_id: product_id,
        location_inventory_id: location_inventory_id,
        system_quantity: system_quantity,
        physical_quantity: physical_quantity
      ],
      overrides: overrides,
      authorize?: false
    )
  end
end