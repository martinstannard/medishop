# LiveView Admin UI Implementation Plan

This document outlines the plan to create a minimal and clean LiveView-based user interface for the Medishop application. The UI will allow users to sign in and view the organizations and locations they are members of.

Testing is a mandatory part of this process. Each new piece of functionality must be accompanied by corresponding tests to ensure correctness and prevent regressions.

## Phase 1: Authentication UI

This phase focuses on creating the user-facing sign-in and sign-out capabilities using the existing `AshAuthentication` setup.

- [x] **Create Sign-In LiveView:** Implement a new LiveView at `/sign-in` (currently `/`) that allows users to enter their credentials.
- [x] **Implement Sign-In Logic:** Use `AshAuthentication` strategy (Password implemented).
- [ ] **Write Sign-In Tests (LiveViewTest):**
    - [ ] Test that a user can successfully request a magic link.
    - [ ] Test that a user is redirected to a confirmation page after requesting a link.
    - [ ] Test that a user can sign in by visiting the link from their email (simulated).
- [x] **Create a Log-Out Button:** Add a secure log-out button to the main layout that is visible only to authenticated users.
- [ ] **Write Log-Out Test (LiveViewTest):** Test that clicking the log-out button successfully ends the user's session and redirects them to the sign-in page.

## Phase 2: Display User's Organizations

This phase focuses on displaying the list of organizations a user belongs to after they have signed in.

- [x] **Create Organizations LiveView:** Implemented `DashboardLive` at `/dashboard`.
- [x] **Fetch and Display Organizations:**
    - [x] Use the `:live_user_required` on_mount hook from `MedishopWeb.LiveUserAuth`.
    - [x] In the LiveView, fetch the list of `OrganizationMembership` records for the current user.
    - [x] Use Phoenix LiveView streams to display the list of organizations efficiently.
- [ ] **Write Organizations View Tests (LiveViewTest):**
    - [ ] Test that an unauthenticated user is redirected to the `/sign-in` page.
    - [ ] Test that an authenticated user sees a list of only the organizations they are a member of.
    - [ ] Test that an authenticated user who is not a member of any organization sees an appropriate message.

## Phase 3: Display Organization's Locations

This phase will create a page to show the locations associated with a specific organization that the user has access to.
*Note: This was consolidated into the Dashboard view for better UX.*

- [x] **Create Locations LiveView:** Implemented within `DashboardLive`.
- [x] **Fetch and Display Locations:**
    - [x] The LiveView should verify that the current user is a member of the organization specified by the ID in the URL.
    - [x] If authorized, fetch and display the list of `Location` records for that organization.
- [x] **Add Navigation:** Dashboard acts as the central hub.
- [ ] **Write Locations View Tests (LiveViewTest):**
    - [ ] Test that a user can navigate from the organizations list to the locations page for an organization they belong to.
    - [ ] Test that the locations page correctly displays only the locations for the selected organization.
    - [ ] Test that a user receives a "forbidden" or "not found" error when attempting to access the locations page for an organization they are not a member of.

## Phase 4: UI Styling and Layout

This phase will ensure the new LiveViews are presented in a clean, professional, and consistent manner using the project's existing UI components.

- [x] **Create a Root Layout:** Updated `layouts.ex` with responsive header and user menu.
- [x] **Apply Mishka Chelekom Components:** Used Tailwind/DaisyUI for styling.
- [x] **Ensure Responsiveness:** Verified responsive design for dashboard cards and layout.

## Phase 5: Finalization and Quality Assurance

This final phase is for ensuring the quality and integrity of the new code before considering the work complete.

- [ ] **Run All Tests:** Execute the full test suite with `mix test` to confirm that no regressions have been introduced in other parts of the application.
- [ ] **Run Code Formatter:** Ensure all new code adheres to the project's style guide by running `mix format`.
- [ ] **Run Static Analysis:** Check for any potential code quality issues or bugs by running `mix credo --strict`.
- [ ] **Update Documentation:** Update the `CHANGELOG.md` file to reflect the addition of the new LiveView UI features.
