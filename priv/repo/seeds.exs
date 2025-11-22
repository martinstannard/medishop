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
alias Medishop.Repo

# Create test users directly via Repo (bypassing authentication for seeds)
# Check if users already exist before creating
admin_user =
  Repo.get_by(User, email: "admin@medishop.test") ||
    Repo.insert!(%User{email: "admin@medishop.test"})

buyer_user =
  Repo.get_by(User, email: "buyer@medishop.test") ||
    Repo.insert!(%User{email: "buyer@medishop.test"})

member_user =
  Repo.get_by(User, email: "member@medishop.test") ||
    Repo.insert!(%User{email: "member@medishop.test"})

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

{:ok, _ghp_eugene} =
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

# Buyer user is org_buyer for Global Health Partners
{:ok, buyer_membership} =
  Organizations.create_membership(
    buyer_user.id,
    org2.id,
    [:org_buyer],
    authorize?: false
  )

# Member user is org_member for both organizations
{:ok, _member_membership_org1} =
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

# Buyer user can buy for GHP Portland only
{:ok, _} =
  Organizations.create_location_membership(buyer_membership.id, ghp_portland.id,
    authorize?: false
  )

IO.puts("\n✅ Seeds completed successfully!")
IO.puts("\nCreated:")
IO.puts("- 3 users (admin@medishop.test, buyer@medishop.test, member@medishop.test)")
IO.puts("- 3 organizations (Acme Medical Supply, Global Health Partners, Test Organization)")
IO.puts("- 5 locations across all organizations")
IO.puts("- 4 organization memberships")
IO.puts("- 3 location memberships")
IO.puts("\nYou can now test the organization and location features!")
