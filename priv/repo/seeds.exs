# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Medishop.Repo.insert!(%Medishop.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Medishop.Organizations
alias Medishop.Accounts.User
alias Medishop.Products
alias Medishop.Repo

# Create test users directly via Repo (bypassing authentication for seeds)
# Check if users already exist before creating
admin_user =
  case Repo.get_by(User, email: "admin@medishop.test") do
    nil ->
      {:ok, user} =
        Medishop.Accounts.register_user("admin@medishop.test", "password", authorize?: false)

      user

    user ->
      user
  end

buyer_user =
  case Repo.get_by(User, email: "buyer@medishop.test") do
    nil ->
      {:ok, user} =
        Medishop.Accounts.register_user("buyer@medishop.test", "password", authorize?: false)

      user

    user ->
      user
  end

member_user =
  case Repo.get_by(User, email: "member@medishop.test") do
    nil ->
      {:ok, user} =
        Medishop.Accounts.register_user("member@medishop.test", "password", authorize?: false)

      user

    user ->
      user
  end

# Create organizations using interface functions
{:ok, org1} =
  Organizations.create_organization(%{
    name: "Acme Medical Supply",
    active: true,
    is_test_organization: false,
    invoice_email: "billing@acmemedical.test",
    billing_address: %{
      street: "123 Healthcare Blvd",
      city: "Seattle",
      state: "WA",
      zip: "98101",
      country: "USA"
    },
    tax_id: "12-3456789"
  })

{:ok, org2} =
  Organizations.create_organization(%{
    name: "Global Health Partners",
    active: true,
    is_test_organization: false,
    invoice_email: "accounts@globalhealth.test",
    billing_address: %{
      street: "456 Wellness Way",
      city: "Portland",
      state: "OR",
      zip: "97201",
      country: "USA"
    },
    tax_id: "98-7654321"
  })

{:ok, test_org} =
  Organizations.create_organization(%{
    name: "Test Organization",
    active: true,
    is_test_organization: true,
    invoice_email: "test@medishop.test",
    billing_address: %{
      street: "789 Test St",
      city: "Testville",
      state: "CA",
      zip: "90001",
      country: "USA"
    },
    tax_id: "00-0000000"
  })

# Create locations for Acme Medical Supply using interface functions
{:ok, acme_seattle} =
  Organizations.create_location(%{
    organization_id: org1.id,
    name: "Acme Seattle Downtown",
    address: %{
      street: "100 Pike Street",
      city: "Seattle",
      state: "WA",
      zip: "98101",
      country: "USA"
    },
    contact_number: "+1-206-555-0100",
    store: true,
    test_location: false
  })

{:ok, acme_bellevue} =
  Organizations.create_location(%{
    organization_id: org1.id,
    name: "Acme Bellevue",
    address: %{
      street: "200 Bellevue Way",
      city: "Bellevue",
      state: "WA",
      zip: "98004",
      country: "USA"
    },
    contact_number: "+1-425-555-0200",
    store: true,
    test_location: false
  })

# Create locations for Global Health Partners using interface functions
{:ok, ghp_portland} =
  Organizations.create_location(%{
    organization_id: org2.id,
    name: "GHP Portland Main",
    address: %{
      street: "300 SW Broadway",
      city: "Portland",
      state: "OR",
      zip: "97201",
      country: "USA"
    },
    contact_number: "+1-503-555-0300",
    store: true,
    test_location: false
  })

{:ok, ghp_eugene} =
  Organizations.create_location(%{
    organization_id: org2.id,
    name: "GHP Eugene",
    address: %{
      street: "400 Willamette St",
      city: "Eugene",
      state: "OR",
      zip: "97401",
      country: "USA"
    },
    contact_number: "+1-541-555-0400",
    store: false,
    test_location: false
  })

# Create location for test organization using interface function
{:ok, _test_location} =
  Organizations.create_location(%{
    organization_id: test_org.id,
    name: "Test Location",
    address: %{
      street: "999 Test Ave",
      city: "Testville",
      state: "CA",
      zip: "90001",
      country: "USA"
    },
    contact_number: "+1-555-555-5555",
    store: false,
    test_location: true
  })

# Create organization memberships using interface functions
# Admin user is org_admin for Acme Medical Supply
{:ok, admin_membership} =
  Organizations.create_membership(
    admin_user.id,
    org1.id,
    [:org_admin, :org_buyer],
    authorize?: false
  )

# Admin user is also a member of Global Health Partners (multitenancy demo)
{:ok, admin_ghp_membership} =
  Organizations.create_membership(
    admin_user.id,
    org2.id,
    [:org_member],
    authorize?: false
  )

# Buyer user is org_buyer for Global Health Partners
{:ok, buyer_membership} =
  Organizations.create_membership(
    buyer_user.id,
    org2.id,
    [:org_buyer],
    authorize?: false
  )

# Member user is org_member for both organizations
{:ok, member_membership_org1} =
  Organizations.create_membership(
    member_user.id,
    org1.id,
    [:org_member],
    authorize?: false
  )

{:ok, _member_membership_org2} =
  Organizations.create_membership(
    member_user.id,
    org2.id,
    [:org_member],
    authorize?: false
  )

# Create location memberships using interface functions
# Admin user can buy for both Acme locations
{:ok, _} =
  Organizations.create_location_membership(admin_membership.id, acme_seattle.id,
    authorize?: false
  )

{:ok, _} =
  Organizations.create_location_membership(admin_membership.id, acme_bellevue.id,
    authorize?: false
  )

# Admin user has access to GHP Portland as a member
{:ok, _} =
  Organizations.create_location_membership(admin_ghp_membership.id, ghp_portland.id,
    authorize?: false
  )

# Buyer user can buy for both GHP locations
{:ok, _} =
  Organizations.create_location_membership(buyer_membership.id, ghp_portland.id,
    authorize?: false
  )

{:ok, _} =
  Organizations.create_location_membership(buyer_membership.id, ghp_eugene.id, authorize?: false)

# Member user has specific access to Acme Seattle
{:ok, _} =
  Organizations.create_location_membership(member_membership_org1.id, acme_seattle.id,
    authorize?: false
  )

# Create products using interface functions
IO.puts("\nCreating products...")

{:ok, _aspirin} =
  Products.create_product(%{
    sku: "MED-ASP-100",
    title: "Aspirin 100mg Tablets",
    description: "Pain relief and fever reducer. 100 tablets per bottle.",
    price: Decimal.new("9.99"),
    active: true,
    images: []
  })

{:ok, _ibuprofen} =
  Products.create_product(%{
    sku: "MED-IBU-200",
    title: "Ibuprofen 200mg Capsules",
    description: "Anti-inflammatory pain reliever. 50 capsules per bottle.",
    price: Decimal.new("12.99"),
    active: true,
    images: []
  })

{:ok, _acetaminophen} =
  Products.create_product(%{
    sku: "MED-ACE-500",
    title: "Acetaminophen 500mg Tablets",
    description: "Extra strength pain reliever and fever reducer. 100 tablets.",
    price: Decimal.new("11.49"),
    active: true,
    images: []
  })

{:ok, _amoxicillin} =
  Products.create_product(%{
    sku: "MED-AMX-500",
    title: "Amoxicillin 500mg Capsules",
    description: "Antibiotic for bacterial infections. 30 capsules per bottle.",
    price: Decimal.new("24.99"),
    active: true,
    images: []
  })

{:ok, _lisinopril} =
  Products.create_product(%{
    sku: "MED-LIS-10",
    title: "Lisinopril 10mg Tablets",
    description: "Blood pressure medication. 90 tablets per bottle.",
    price: Decimal.new("15.99"),
    active: true,
    images: []
  })

{:ok, _metformin} =
  Products.create_product(%{
    sku: "MED-MET-500",
    title: "Metformin 500mg Tablets",
    description: "Diabetes medication. 60 tablets per bottle.",
    price: Decimal.new("18.99"),
    active: true,
    images: []
  })

{:ok, _atorvastatin} =
  Products.create_product(%{
    sku: "MED-ATO-20",
    title: "Atorvastatin 20mg Tablets",
    description: "Cholesterol-lowering medication. 30 tablets per bottle.",
    price: Decimal.new("22.99"),
    active: true,
    images: []
  })

{:ok, _omeprazole} =
  Products.create_product(%{
    sku: "MED-OME-20",
    title: "Omeprazole 20mg Capsules",
    description: "Acid reflux and heartburn relief. 42 capsules per bottle.",
    price: Decimal.new("16.49"),
    active: true,
    images: []
  })

{:ok, _losartan} =
  Products.create_product(%{
    sku: "MED-LOS-50",
    title: "Losartan 50mg Tablets",
    description: "Blood pressure medication. 90 tablets per bottle.",
    price: Decimal.new("19.99"),
    active: true,
    images: []
  })

{:ok, _gabapentin} =
  Products.create_product(%{
    sku: "MED-GAB-300",
    title: "Gabapentin 300mg Capsules",
    description: "Nerve pain and seizure medication. 90 capsules per bottle.",
    price: Decimal.new("21.99"),
    active: true,
    images: []
  })

{:ok, _levothyroxine} =
  Products.create_product(%{
    sku: "MED-LEV-50",
    title: "Levothyroxine 50mcg Tablets",
    description: "Thyroid hormone replacement. 90 tablets per bottle.",
    price: Decimal.new("13.99"),
    active: true,
    images: []
  })

{:ok, _amlodipine} =
  Products.create_product(%{
    sku: "MED-AML-5",
    title: "Amlodipine 5mg Tablets",
    description: "Calcium channel blocker for blood pressure. 90 tablets.",
    price: Decimal.new("14.99"),
    active: true,
    images: []
  })

# Create some inactive products
{:ok, _discontinued} =
  Products.create_product(%{
    sku: "MED-OLD-001",
    title: "Discontinued Product",
    description: "This product is no longer available.",
    price: Decimal.new("5.00"),
    active: false,
    images: []
  })

IO.puts("\n✅ Seeds completed successfully!")
IO.puts("\nCreated:")
IO.puts("- 3 users (admin@medishop.test, buyer@medishop.test, member@medishop.test)")
IO.puts("- 3 organizations (Acme Medical Supply, Global Health Partners, Test Organization)")
IO.puts("- 5 locations across all organizations")
IO.puts("- 6 organization memberships (Enriched)")
IO.puts("- 6 location memberships (Enriched)")
IO.puts("- 13 products (12 active, 1 inactive)")
IO.puts("\nYou can now test the shopping cart and purchase flow!")
IO.puts("Login credentials: password = 'password' for all test users")
