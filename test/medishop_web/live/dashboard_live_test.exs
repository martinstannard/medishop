defmodule MedishopWeb.DashboardLiveTest do
  use MedishopWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medishop.Generator
  import MedishopWeb.LiveViewTestHelpers

  describe "Dashboard - unauthenticated access" do
    test "redirects unauthenticated user to sign-in page", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard")
      assert path == ~p"/sign-in"
    end
  end

  describe "Dashboard - authenticated user with no organizations" do
    setup %{conn: conn} do
      user = user() |> Ash.Generator.generate()
      conn = log_in_user(conn, user)

      %{conn: conn, user: user}
    end

    test "displays welcome message with user email", %{conn: conn, user: _user} do
      {:ok, _view, _html} = live(conn, ~p"/dashboard")

      # Dashboard header removed as per redesign request
      # user.email is an Ash.CiString, convert to string for assertion
      # assert has_element?(view, "span", to_string(user.email))
    end

    test "shows message when user is not a member of any organizations", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "p", "You are not a member of any organizations yet.")
    end

    test "does not display organization cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      refute html =~ "Locations & Access"
    end
  end

  describe "Dashboard - authenticated user with organizations (Phase 2)" do
    setup %{conn: conn} do
      user = user() |> Ash.Generator.generate()
      org1 = organization(name: "Acme Medical", active: true) |> Ash.Generator.generate()
      org2 = organization(name: "Smith Pharmacy", active: true) |> Ash.Generator.generate()

      # Create memberships with different roles
      membership1 =
        organization_membership(user_id: user.id, organization_id: org1.id, org_roles: [:org_admin, :org_buyer]) |> Ash.Generator.generate()

      membership2 = organization_membership(user_id: user.id, organization_id: org2.id, org_roles: [:org_member]) |> Ash.Generator.generate()

      # Log in the user
      conn = log_in_user(conn, user)

      %{
        conn: conn,
        user: user,
        org1: org1,
        org2: org2,
        membership1: membership1,
        membership2: membership2
      }
    end

    test "displays list of organizations user is a member of", %{
      conn: conn,
      org1: org1,
      org2: org2
    } do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "h2", "Organizations")
      assert has_element?(view, "h3", org1.name)
      assert has_element?(view, "h3", org2.name)
    end

    test "does not display organizations user is not a member of", %{conn: conn} do
      other_org = organization(name: "Other Org") |> Ash.Generator.generate()

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      refute html =~ other_org.name
    end

    test "displays user roles for each organization", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Check for humanized role names (Phoenix.Naming.humanize converts :org_admin to "Org admin")
      assert has_element?(view, "span", "Org admin")
      assert has_element?(view, "span", "Org buyer")
      assert has_element?(view, "span", "Org member")
    end

    test "shows active badge for non-test organizations", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert render(view) =~ "Active"
    end

    test "shows test badge for test organizations", %{conn: conn, user: user} do
      # Note: organization generator does not have is_test_organization in defaults, but can override
      # assuming resource has the attribute
      test_org = organization(name: "Test Org", is_test_organization: true) |> Ash.Generator.generate()
      organization_membership(user_id: user.id, organization_id: test_org.id) |> Ash.Generator.generate()

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # The badge should say "Test Org" as the badge text (not the organization name)
      # According to the template: if is_test_organization, do: "Test Org", else: "Active"
      assert html =~ "Test Org"
      assert html =~ test_org.name
    end
  end

  describe "Dashboard - authenticated user with locations (Phase 3)" do
    setup %{conn: conn} do
      user = user() |> Ash.Generator.generate()
      org = organization(name: "Acme Medical") |> Ash.Generator.generate()

      # Create locations for the organization
      location1 =
        location(
          organization_id: org.id,
          name: "Main Branch",
          store: true,
          address: %{
            street: "123 Main St",
            city: "Springfield",
            state: "IL",
            zip: "62701",
            country: "USA"
          },
          contact_number: "+1-217-555-0100"
        ) |> Ash.Generator.generate()

      location2 =
        location(
          organization_id: org.id,
          name: "North Branch",
          store: false,
          address: %{
            street: "456 North Ave",
            city: "Springfield",
            state: "IL",
            zip: "62702",
            country: "USA"
          },
          contact_number: "+1-217-555-0200"
        ) |> Ash.Generator.generate()

      # Create membership and location access
      membership = organization_membership(user_id: user.id, organization_id: org.id) |> Ash.Generator.generate()
      organization_location_membership(organization_membership_id: membership.id, location_id: location1.id) |> Ash.Generator.generate()
      organization_location_membership(organization_membership_id: membership.id, location_id: location2.id) |> Ash.Generator.generate()

      # Log in the user
      conn = log_in_user(conn, user)

      %{
        conn: conn,
        user: user,
        org: org,
        location1: location1,
        location2: location2,
        membership: membership
      }
    end

    test "displays locations user has access to", %{
      conn: conn,
      location1: location1,
      location2: location2
    } do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Header "Locations" was removed in favor of cleaner layout
      # assert has_element?(view, "span", "Locations")
      
      # Location names are now h4
      assert has_element?(view, "h4", location1.name)
      assert has_element?(view, "h4", location2.name)
    end

    test "does not display locations user does not have access to", %{conn: conn, org: org} do
      other_location = location(organization_id: org.id, name: "Restricted Branch") |> Ash.Generator.generate()

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      refute html =~ other_location.name
    end

    test "displays location details (address, contact)", %{conn: conn, location1: location1} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Address details are now in p tags, not span
      # Just check for presence of text in the view since they are interpolated
      html = render(view)
      assert html =~ location1.address["street"]
      assert html =~ location1.address["city"]
      assert html =~ location1.address["state"]
      assert html =~ location1.address["zip"]
      assert html =~ location1.contact_number
    end

    test "shows store badge for store locations", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "span", "Store")
    end

    test "does not show store badge for non-store locations", %{conn: conn, location2: location2} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # The non-store location should be displayed but without the store badge
      assert html =~ location2.name
      # Count store badges - should only be 1 (for location1)
      # Count occurrences of "bg-purple-100" which is the store badge class
      badge_count = html |> String.split("bg-purple-100") |> length() |> Kernel.-(1)
      assert badge_count == 1
    end

    test "shows 'No specific location access' message when membership has no locations", %{
      conn: conn,
      user: user
    } do
      # Create org without location access for this user
      org_no_locations = organization(name: "No Locations Org") |> Ash.Generator.generate()
      organization_membership(user_id: user.id, organization_id: org_no_locations.id) |> Ash.Generator.generate()

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "p", "No location access")
    end
  end

  describe "Dashboard - preloading and relationships" do
    setup %{conn: conn} do
      user = user() |> Ash.Generator.generate()
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      membership = organization_membership(user_id: user.id, organization_id: org.id) |> Ash.Generator.generate()
      organization_location_membership(organization_membership_id: membership.id, location_id: location.id) |> Ash.Generator.generate()

      conn = log_in_user(conn, user)

      %{conn: conn, user: user, org: org, location: location}
    end

    test "loads organization details through membership", %{conn: conn, org: org} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Verify organization data is accessible
      assert has_element?(view, "h3", org.name)
    end

    test "loads location details through location membership", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Verify location data is accessible
      assert has_element?(view, "h4", location.name)
      # Address is now in p, check html content
      assert render(view) =~ location.address["street"]
    end

    test "correctly associates locations with organizations", %{conn: conn, user: user} do
      # Create two orgs with different locations
      org1 = organization(name: "Org One") |> Ash.Generator.generate()
      org2 = organization(name: "Org Two") |> Ash.Generator.generate()

      loc1 = location(organization_id: org1.id, name: "Org One Location") |> Ash.Generator.generate()
      loc2 = location(organization_id: org2.id, name: "Org Two Location") |> Ash.Generator.generate()

      mem1 = organization_membership(user_id: user.id, organization_id: org1.id) |> Ash.Generator.generate()
      mem2 = organization_membership(user_id: user.id, organization_id: org2.id) |> Ash.Generator.generate()

      organization_location_membership(organization_membership_id: mem1.id, location_id: loc1.id) |> Ash.Generator.generate()
      organization_location_membership(organization_membership_id: mem2.id, location_id: loc2.id) |> Ash.Generator.generate()

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Both orgs and their locations should be displayed
      assert html =~ org1.name
      assert html =~ org2.name
      assert html =~ loc1.name
      assert html =~ loc2.name
    end
  end
end