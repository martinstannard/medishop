# Changelog

All notable changes to this project will be documented in this file.

## 2025-11-21

### Added
- **Organizations and Locations Feature** (branch: `organisations`)
  - Created Organizations domain (`lib/medishop/organizations.ex`)
  - Organization resource with attributes: name, active, is_test_organization, invoice_email, billing_address, tax_id
  - Location resource with multitenancy support and attributes: name, address, contact_number, store, test_location
  - OrganizationMembership join table linking users to organizations with roles (org_admin, org_member, org_buyer)
  - OrganizationLocationMembership join table assigning users to specific locations
  - OrgRole enum type for organization roles
  - Relationships between Users, Organizations, Locations, and Memberships
  - Development migrations for all new tables
  - Comprehensive seed data in `priv/repo/seeds.exs`:
    - 3 test users (admin, buyer, member)
    - 3 organizations (Acme Medical Supply, Global Health Partners, Test Organization)
    - 5 locations across organizations
    - 4 organization memberships with different roles
    - 3 location memberships for purchasing permissions
  - Configured Organizations domain in `config/config.exs`
  - Simple authorization policies (to be enhanced later)
  - Test files for all resources (`test/medishop/organizations/`)
  - OrganizationsFixtures module for test helpers (`test/support/organizations_fixtures.ex`)

  **Data Model**:
  ```
  User → OrganizationMembership → Organization → Location
                    ↓
        OrganizationLocationMembership → Location
  ```

- **Code Interface Pattern Implementation**
  - Added domain-level code interfaces for all Organizations resources in `lib/medishop/organizations.ex`
  - Created interface functions for Organization: `create_organization/1`, `list_organizations/0`, `get_organization/1`, `update_organization/2`, `destroy_organization/1`
  - Created interface functions for Location: `create_location/1`, `list_locations/0`, `get_location/1`, `get_locations_by_organization/1`, `update_location/2`, `destroy_location/1`
  - Created interface functions for OrganizationMembership: `create_membership/2`, `list_memberships/0`, `get_membership/1`, `get_memberships_for_user/1`, `get_memberships_for_organization/1`, `update_membership/2`, `destroy_membership/1`
  - Created interface functions for OrganizationLocationMembership: `create_location_membership/2`, `list_location_memberships/0`, `get_location_membership/1`, `get_location_memberships_for_user/1`, `get_location_memberships_for_location/1`, `destroy_location_membership/1`
  - Refactored `priv/repo/seeds.exs` to use interface functions instead of direct `Ash.Changeset` calls
  - Refactored `test/support/organizations_fixtures.ex` to use interface functions
  - Updated `CLAUDE.md` with comprehensive code interface documentation:
    - Section on "Using Code Interfaces" with DO/DON'T examples
    - Explanation of interface function benefits (encapsulation, cleaner APIs, discoverability)
    - Instructions for adding code interfaces in domain modules
    - Examples of calling interface functions
    - Guidelines for seeds and tests
    - Important note: interfaces are defined in domain module, not resource files
- Created `CLAUDE.md` with comprehensive guidance for Claude Code instances
  - Project overview with technology stack (Ash Framework 3.0, Phoenix LiveView 1.1, AshAuthentication, Tailwind CSS v4)
  - Essential commands for setup, testing, code quality, assets, and database operations
  - Architecture documentation covering Ash domains, resources, authentication flow, and web layer structure
  - Detailed Ash migration workflow with snapshot system explanation
  - Instructions for `mix ash.codegen --dev` vs `mix ash.codegen` usage
  - Git commit workflow with conventional commit message format
  - Changelog maintenance requirements (this file)
  - Key development patterns for resources, LiveView, and API development
  - Testing guidelines and important project-specific notes
  - Prominent references to `AGENTS.md` for detailed framework-specific guidelines
- Created `CHANGELOG.md` to track project changes over time
- Git commit workflow guidelines in `CLAUDE.md`
  - Instructions to always ask user before committing
  - Conventional commit message format (feat, fix, refactor, etc.)
  - Examples of good commit messages
  - Integration with Ash migration finalization workflow
- References to `AGENTS.md` throughout `CLAUDE.md`
  - Added prominent section at top directing Claude instances to read `AGENTS.md` first
  - Enhanced LiveView Development section with references to detailed guidelines
  - Enhanced Testing section with references to comprehensive testing patterns
  - Added reminder in Important Notes section
