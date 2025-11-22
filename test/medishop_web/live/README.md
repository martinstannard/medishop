# LiveView Tests

This directory contains LiveView integration tests for the Medishop application.

## Current Status

**DashboardLive Tests**: ✅ COMPLETE - All 18 tests passing
**Authentication Setup**: ✅ Implemented with AshAuthentication.Plug.Helpers

## Authentication Setup - SOLVED ✅

The correct way to authenticate users in LiveView tests with AshAuthentication is to use `AshAuthentication.Plug.Helpers.store_in_session/2`:

```elixir
def log_in_user(conn, user) do
  # Generate JWT token for the user
  {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)
  user = Ash.Resource.put_metadata(user, :token, token)

  # Store user in session using AshAuthentication helpers
  conn
  |> Plug.Test.init_test_session(%{})
  |> AshAuthentication.Plug.Helpers.store_in_session(user)
end
```

This is the official AshAuthentication approach and works perfectly with `ash_authentication_live_session` in the router.

## Test Coverage

**Phase 2 (Organizations) - 6 tests:**
- ✅ Displays list of organizations user is member of
- ✅ Does not display organizations user is not member of
- ✅ Displays user roles for each organization
- ✅ Shows active badge for non-test organizations
- ✅ Shows test badge for test organizations

**Phase 3 (Locations) - 7 tests:**
- ✅ Displays locations user has access to
- ✅ Does not display locations user lacks access to
- ✅ Displays location details (address, contact)
- ✅ Shows store badge for store locations
- ✅ Does not show store badge for non-store locations
- ✅ Shows "No specific location access" when appropriate

**Preloading & Relationships - 3 tests:**
- ✅ Loads organization details through membership
- ✅ Loads location details through location membership
- ✅ Correctly associates locations with organizations

**Unauthenticated Access - 1 test:**
- ✅ Redirects unauthenticated user to sign-in page

**No Organizations - 2 tests:**
- ✅ Displays welcome message with user email
- ✅ Shows "not a member of any organizations" message

## Running Tests

```bash
# Run all LiveView tests
mix test test/medishop_web/live/

# Run specific test file
mix test test/medishop_web/live/dashboard_live_test.exs

# Run with specific seed for reproducibility
mix test test/medishop_web/live/dashboard_live_test.exs --seed 0
```

## Files

- `dashboard_live_test.exs` - Main test file (18 tests)
- `../support/live_view_test_helpers.ex` - Authentication helper (needs fixing)
