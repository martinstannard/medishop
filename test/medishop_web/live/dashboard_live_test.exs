defmodule MedishopWeb.DashboardLiveTest do
  use MedishopWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medishop.OrganizationsFixtures
  import MedishopWeb.LiveViewTestHelpers

  describe "Dashboard - unauthenticated access" do
    test "redirects unauthenticated user to sign-in page", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard")
      assert path == ~p"/sign-in"
    end
  end

  describe "Dashboard - authenticated user with no organizations" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      %{conn: conn, user: user}
    end

    test "displays welcome message with user email", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "h1", "Dashboard")
      # user.email is an Ash.CiString, convert to string for assertion
      assert has_element?(view, "span", to_string(user.email))
    end

    test "shows message when user is not a member of any organization", %{conn: conn} do
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
      user = user_fixture()
      org1 = organization_fixture(%{name: "Acme Medical"})
      org2 = organization_fixture(%{name: "Smith Pharmacy"})

      # Create memberships with different roles
      membership1 =
        organization_membership_fixture(user.id, org1.id, %{org_roles: [:org_admin, :org_buyer]})

      membership2 = organization_membership_fixture(user.id, org2.id, %{org_roles: [:org_member]})

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

      assert has_element?(view, "h2", "My Organizations")
      assert has_element?(view, "h3", org1.name)
      assert has_element?(view, "h3", org2.name)
    end

    test "does not display organizations user is not a member of", %{conn: conn} do
      other_org = organization_fixture(%{name: "Other Org"})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      refute html =~ other_org.name
    end

    test "displays user roles for each organization", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Check for humanized role names (Phoenix.Naming.humanize converts :org_admin to "Org admin")
      assert has_element?(view, "span.badge", "Org admin")
      assert has_element?(view, "span.badge", "Org buyer")
      assert has_element?(view, "span.badge", "Org member")
    end

    test "shows active badge for non-test organizations", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "span.badge-success", "Active")
    end

    test "shows test badge for test organizations", %{conn: conn, user: user} do
      test_org = organization_fixture(%{name: "Test Org", is_test_organization: true})
      organization_membership_fixture(user.id, test_org.id)

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # The badge should say "Test Org" as the badge text (not the organization name)
      # According to the template: if is_test_organization, do: "Test Org", else: "Active"
      assert html =~ "Test Org"
      assert html =~ test_org.name
    end
  end

  describe "Dashboard - authenticated user with locations (Phase 3)" do
    setup %{conn: conn} do
      user = user_fixture()
      org = organization_fixture(%{name: "Acme Medical"})

      # Create locations for the organization
      location1 =
        location_fixture(org.id, %{
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
        })

      location2 =
        location_fixture(org.id, %{
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
        })

      # Create membership and location access
      membership = organization_membership_fixture(user.id, org.id)
      organization_location_membership_fixture(membership.id, location1.id)
      organization_location_membership_fixture(membership.id, location2.id)

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

      assert has_element?(view, "h4", "Locations & Access")
      assert has_element?(view, "span", location1.name)
      assert has_element?(view, "span", location2.name)
    end

    test "does not display locations user does not have access to", %{conn: conn, org: org} do
      other_location = location_fixture(org.id, %{name: "Restricted Branch"})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      refute html =~ other_location.name
    end

    test "displays location details (address, contact)", %{conn: conn, location1: location1} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "span", location1.address["street"])
      assert has_element?(view, "span", location1.address["city"])
      assert has_element?(view, "span", location1.address["state"])
      assert has_element?(view, "span", location1.address["zip"])
      assert has_element?(view, "span", location1.contact_number)
    end

    test "shows store badge for store locations", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "span.badge-info", "Store")
    end

    test "does not show store badge for non-store locations", %{conn: conn, location2: location2} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # The non-store location should be displayed but without the store badge
      assert html =~ location2.name
      # Count store badges - should only be 1 (for location1)
      badge_count = html |> String.split("badge-info") |> length() |> Kernel.-(1)
      assert badge_count == 1
    end

    test "shows 'No specific location access' message when membership has no locations", %{
      conn: conn,
      user: user
    } do
      # Create org without location access for this user
      org_no_locations = organization_fixture(%{name: "No Locations Org"})
      organization_membership_fixture(user.id, org_no_locations.id)

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "p", "No specific location access assigned.")
    end
  end

  describe "Dashboard - preloading and relationships" do
    setup %{conn: conn} do
      user = user_fixture()
      org = organization_fixture()
      location = location_fixture(org.id)

      membership = organization_membership_fixture(user.id, org.id)
      organization_location_membership_fixture(membership.id, location.id)

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
      assert has_element?(view, "span", location.name)
      assert has_element?(view, "span", location.address["street"])
    end

    test "correctly associates locations with organizations", %{conn: conn, user: user} do
      # Create two orgs with different locations
      org1 = organization_fixture(%{name: "Org One"})
      org2 = organization_fixture(%{name: "Org Two"})

      loc1 = location_fixture(org1.id, %{name: "Org One Location"})
      loc2 = location_fixture(org2.id, %{name: "Org Two Location"})

      mem1 = organization_membership_fixture(user.id, org1.id)
      mem2 = organization_membership_fixture(user.id, org2.id)

      organization_location_membership_fixture(mem1.id, loc1.id)
      organization_location_membership_fixture(mem2.id, loc2.id)

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Both orgs and their locations should be displayed
      assert html =~ org1.name
      assert html =~ org2.name
      assert html =~ loc1.name
      assert html =~ loc2.name
    end
  end
end
