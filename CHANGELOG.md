# Changelog

All notable changes to this project will be documented in this file.

## 2025-11-22

### Added
- **LiveView Admin UI - Dashboard**
  - Created `DashboardLive` (`/dashboard`) displaying user organizations and locations
  - Implemented detailed organization cards with location access info
  - Added user dropdown menu with "Dashboard" and "Sign Out" options
- **LiveView Admin UI - Phase 1: Authentication UI**
  - Created `HomeLive` at `/` for user sign-in
  - Implemented password-based authentication form with Mishka components
  - Configured authenticated LiveView session in `router.ex`
- **Medication Purchasing System - Phase 1: Products Domain** (branch: `inventory`)
  - Created Products domain (`lib/medishop/products.ex`)
  - Product resource with attributes: sku (unique), title, description, images (array), price, active
  - Product search functionality with filters: title (partial match), SKU (exact), active status
  - Product sorting by title, price, or created_at (asc/desc)
  - Price validation (must be positive, non-zero)
  - Code interface functions for all CRUD operations and search
  - Comprehensive test suite (`test/medishop/products/product_test.exs`) - 17/17 tests passing
  - Product fixtures (`test/support/products_fixtures.ex`)
  - Database migration for products table
  - Configured Products domain in `config/config.exs`

- **Medication Purchasing System - Phase 2: Inventory Domain** (branch: `inventory`)
  - Created Inventory domain (`lib/medishop/inventory.ex`)
  - LocationInventory resource tracking product stock per location
  - Attributes: location_id, product_id, quantity_available (defaults to 0)
  - Unique constraint on location + product combination
  - Quantity validation (must be non-negative)
  - Relationships: belongs_to Location and Product
  - Filter actions: get_by_location, get_by_product
  - Added `has_many :location_inventories` to Location and Product resources
  - Code interface functions for all CRUD operations
  - Comprehensive test suite (`test/medishop/inventory/location_inventory_test.exs`) - 13/13 tests passing
  - Inventory fixtures (`test/support/inventory_fixtures.ex`)
  - Database migration for location_inventories table with foreign keys and unique index
  - Configured Inventory domain in `config/config.exs`

- **Implementation Planning and Progress Tracking**
  - Created detailed 18-step implementation plan (`docs/medication-purchasing-implementation-plan.md`)
  - Documented three new domains: Products, Inventory, and Shop
  - Defined acceptance criteria and phase breakdown
  - Emphasized mandatory testing requirements (TDD approach, 113+ planned tests)
  - Updated progress tracking with completed Phases 1 and 2
  - All checklist items for Steps 1-8 marked as completed

### Changed
- Updated `docs/PROGRESS.md` with Phase 1 and Phase 2 completion details
- Test summary now shows 67/67 tests passing (100% pass rate)
  - Organizations: 37/37 tests ✅
  - Products: 17/17 tests ✅
  - Inventory: 13/13 tests ✅

### Fixed
- **Database & Seeds Repair**
  - Restored missing database migrations for Organizations and Locations
  - Added `hashed_password` column to users table (fixed in initial migration)
  - Updated seeds to generate users with known password "password" for testing
  - Fixed `Medishop.Accounts` code interface for user registration

### Technical Notes
- Following Ash Framework 3.0 best practices and code interface pattern
- All functionality thoroughly tested before implementation marked complete
- Database migrations generated with `mix ash_postgres.generate_migrations`
- Production migrations finalized with `mix ash.codegen --name add_products_and_inventory`
- All snapshots verified and up to date (no changes detected)
- Next phase: Shop Domain (Carts and Orders) - Steps 9-15

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
