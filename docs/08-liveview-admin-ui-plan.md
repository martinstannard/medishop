# LiveView Admin UI Implementation Plan

This document outlines the plan to create a minimal and clean LiveView-based user interface for the Medishop application. The UI will allow users to sign in and view the organizations and locations they are members of.

Testing is a mandatory part of this process. Each new piece of functionality must be accompanied by corresponding tests to ensure correctness and prevent regressions.

## Phase 1: Authentication UI

This phase focuses on creating the user-facing sign-in and sign-out capabilities using the existing `AshAuthentication` setup.

- [ ] **Create Sign-In LiveView:** Implement a new LiveView at `/sign-in` that allows users to enter their email address to request a magic link.
- [ ] **Implement Sign-In Logic:** Use the `AshAuthentication.Strategy.MagicLink.Request` action to handle the magic link request.
- [ ] **Write Sign-In Tests (LiveViewTest):**
    - [ ] Test that a user can successfully request a magic link.
    - [ ] Test that a user is redirected to a confirmation page after requesting a link.
    - [ ] Test that a user can sign in by visiting the link from their email (simulated).
- [ ] **Create a Log-Out Button:** Add a secure log-out button to the main layout that is visible only to authenticated users.
- [ ] **Write Log-Out Test (LiveViewTest):** Test that clicking the log-out button successfully ends the user's session and redirects them to the sign-in page.

## Phase 2: Display User's Organizations

This phase focuses on displaying the list of organizations a user belongs to after they have signed in.

- [ ] **Create Organizations LiveView:** Implement a new LiveView at `/organizations` that is protected and requires an authenticated user.
- [ ] **Fetch and Display Organizations:**
    - [ ] Use the `:live_user_required` on_mount hook from `MedishopWeb.LiveUserAuth`.
    - [ ] In the LiveView, fetch the list of `OrganizationMembership` records for the current user.
    - [ ] Use Phoenix LiveView streams to display the list of organizations efficiently.
- [ ] **Write Organizations View Tests (LiveViewTest):**
    - [ ] Test that an unauthenticated user is redirected to the `/sign-in` page.
    - [ ] Test that an authenticated user sees a list of only the organizations they are a member of.
    - [ ] Test that an authenticated user who is not a member of any organization sees an appropriate message.

## Phase 3: Display Organization's Locations

This phase will create a page to show the locations associated with a specific organization that the user has access to.

- [ ] **Create Locations LiveView:** Implement a new LiveView at `/organizations/:id/locations` that requires an authenticated user.
- [ ] **Fetch and Display Locations:**
    - [ ] The LiveView should verify that the current user is a member of the organization specified by the ID in the URL.
    - [ ] If authorized, fetch and display the list of `Location` records for that organization.
- [ ] **Add Navigation:** Add a link from each organization in the `/organizations` list to its corresponding locations page.
- [ ] **Write Locations View Tests (LiveViewTest):**
    - [ ] Test that a user can navigate from the organizations list to the locations page for an organization they belong to.
    - [ ] Test that the locations page correctly displays only the locations for the selected organization.
    - [ ] Test that a user receives a "forbidden" or "not found" error when attempting to access the locations page for an organization they are not a member of.

## Phase 4: UI Styling and Layout

This phase will ensure the new LiveViews are presented in a clean, professional, and consistent manner using the project's existing UI components.

- [ ] **Create a Root Layout:** Implement a root layout (`:root`) and an app layout (`:app`) in `lib/medishop_web/components/layouts.ex` to provide a consistent header, footer, and navigation structure.
- [ ] **Apply Mishka Chelekom Components:** Use the pre-built components from the Mishka Chelekom library to style forms, buttons, lists, and other UI elements for a clean and minimal aesthetic.
- [ ] **Ensure Responsiveness:** Verify that all new pages are responsive and usable on both desktop and mobile screen sizes.

## Phase 5: Finalization and Quality Assurance

This final phase is for ensuring the quality and integrity of the new code before considering the work complete.

- [ ] **Run All Tests:** Execute the full test suite with `mix test` to confirm that no regressions have been introduced in other parts of the application.
- [ ] **Run Code Formatter:** Ensure all new code adheres to the project's style guide by running `mix format`.
- [ ] **Run Static Analysis:** Check for any potential code quality issues or bugs by running `mix credo --strict`.
- [ ] **Update Documentation:** Update the `CHANGELOG.md` file to reflect the addition of the new LiveView UI features.
