# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Important: Read AGENTS.md First

**Before working on this project, always read `AGENTS.md` for detailed guidelines:**
- Phoenix v1.8 specific patterns and conventions
- Elixir language best practices and common pitfalls
- LiveView development guidelines and streams usage
- HEEx template syntax and interpolation rules
- Tailwind CSS v4 configuration and usage
- UI/UX design principles for this project
- Testing patterns with Phoenix.LiveViewTest
- Mix task usage and debugging

`AGENTS.md` contains comprehensive, framework-specific guidelines that complement the architecture and workflow information in this file.

## Project Overview

Medishop is a Phoenix 1.8 web application built with:
- **Ash Framework 3.0**: Domain-driven design with resources, domains, and actions
- **AshAuthentication**: Magic link authentication with token management
- **AshPostgres**: PostgreSQL data layer for Ash resources
- **AshJsonApi**: JSON:API endpoints with OpenAPI/Swagger documentation
- **AshAdmin**: Auto-generated admin interface at `/admin` (dev only)
- **Phoenix LiveView 1.1**: Server-rendered interactive UI
- **Mishka Chelekom**: Comprehensive UI component library (60+ components)
- **Tailwind CSS v4**: Utility-first styling with new import syntax

## Essential Commands

### Setup and Development
```bash
mix setup                    # Install deps, setup Ash resources, build assets
mix phx.server              # Start development server (localhost:4000)
iex -S mix phx.server       # Start with interactive shell
```

### Testing
```bash
mix test                    # Run all tests
mix test test/path/file.exs # Run specific test file
mix test --failed          # Re-run only failed tests
```

### Code Quality (Pre-commit)
```bash
mix precommit              # Run before committing: compile with warnings as errors,
                          # unlock unused deps, format, and test
```

### Assets
```bash
mix assets.build          # Build CSS and JS for development
mix assets.deploy         # Build and minify for production
```

### Database (via Ash)
```bash
mix ash.setup             # Create database and run migrations
mix ash.reset             # Drop and recreate database
mix ash.codegen           # Generate migrations from Ash resource changes (production-ready)
mix ash.codegen --dev     # Generate migrations for development (see Snapshots section)
```

## Architecture

### Ash Framework Structure

Medishop uses Ash Framework's domain-driven architecture:

- **Domains** (`lib/medishop/`): Group related resources
  - `Medishop.Accounts`: User authentication and token management
  - Each domain uses `use Ash.Domain` and declares its resources

- **Resources** (`lib/medishop/*/`): Define data schemas, actions, and business logic
  - `Medishop.Accounts.User`: User resource with magic link authentication
  - `Medishop.Accounts.Token`: Authentication tokens
  - Resources use `use Ash.Resource` with extensions (AshPostgres, AshAuthentication, etc.)
  - Actions are defined in resource `actions` blocks (not Phoenix controllers)

- **Data Layer**: AshPostgres provides PostgreSQL integration
  - Migrations stored in `priv/resource_snapshots/` as JSON snapshots
  - Generate migrations with `mix ash.codegen` after resource changes

### Authentication Flow

- **AshAuthentication** with magic link strategy (passwordless)
- Email-based sign-in via `Medishop.Accounts.User.request_magic_link` action
- Token-based session management with `Medishop.Accounts.Token` resource
- Auth routes defined in router using `auth_routes`, `sign_in_route`, `reset_route`
- LiveView auth via `MedishopWeb.LiveUserAuth` on_mount hooks:
  - `:live_user_required` - authenticated user must be present
  - `:live_user_optional` - authenticated user may be present
  - `:live_no_user` - authenticated user must not be present

### Web Layer Structure

- **Router** (`lib/medishop_web/router.ex`):
  - `:browser` pipeline with session and CSRF protection
  - `:api` pipeline with bearer token authentication
  - `ash_authentication_live_session :authenticated_routes` for protected LiveViews
  - JSON:API routes at `/api/json` with Swagger UI at `/api/json/swaggerui`

- **Components** (`lib/medishop_web/components/`):
  - `core_components.ex`: Phoenix default components
  - `mishka_components.ex`: Entry point for Mishka Chelekom UI library
  - 60+ pre-built components (buttons, forms, cards, tables, etc.)
  - Components imported app-wide via `use MedishopWeb.Components.MishkaComponents` in `medishop_web.ex`

- **Layouts** (`lib/medishop_web/components/layouts/`):
  - Aliased as `Layouts` in all LiveViews/Components
  - Always wrap LiveView content with `<Layouts.app flash={@flash} ...>`

### Configuration

- Standard Phoenix config structure in `config/`
- Ash configuration in `config/config.exs` (policies, pagination, transactions)
- `.formatter.exs` includes Ash-specific import_deps and Spark.Formatter plugin
- Tailwind v4 configured in `assets/css/app.css` with `@import "tailwindcss"` syntax

## Key Development Patterns

### Git Commit Workflow (CRITICAL)

**When you believe work is ready to be committed, always ask the user first:**

1. **Never commit proactively** - always ask permission before creating commits
2. **Ask when appropriate**:
   - After completing a feature or bug fix
   - After updating the changelog
   - When production migrations have been generated
   - When tests are passing and code is working

3. **Example prompt to user**:
   > "I've completed [description of work] and updated the changelog. The changes are tested and working. Would you like me to commit these changes to git?"

4. **Good commit message format**:
   ```
   <type>: <short summary in imperative mood>

   <optional detailed description>

   - Additional bullet points if needed
   - Reference to issue numbers if applicable

   🤖 Generated with Claude Code
   Co-Authored-By: Claude <noreply@anthropic.com>
   ```

5. **Commit message types**:
   - `feat`: New feature or functionality
   - `fix`: Bug fix
   - `refactor`: Code restructuring without behavior change
   - `docs`: Documentation changes
   - `test`: Adding or modifying tests
   - `chore`: Maintenance tasks (deps, config, etc.)
   - `perf`: Performance improvements
   - `style`: Code style/formatting changes

6. **Commit message examples**:
   ```
   feat: add Product resource with inventory tracking

   - Created Medishop.Products.Product resource
   - Added attributes: name, description, price, inventory_count
   - Configured AshPostgres data layer
   - Generated migrations and snapshots
   - Added JSON:API endpoints at /api/json/products

   🤖 Generated with Claude Code
   Co-Authored-By: Claude <noreply@anthropic.com>
   ```

   ```
   fix: resolve magic link email sending in development

   Updated Swoosh adapter configuration in config/dev.exs to use
   local mailbox instead of test adapter.

   🤖 Generated with Claude Code
   Co-Authored-By: Claude <noreply@anthropic.com>
   ```

7. **What to commit**:
   - Source code changes in `lib/`
   - Test files in `test/`
   - Ash snapshots in `priv/resource_snapshots/`
   - Migrations in `priv/repo/migrations/`
   - Configuration changes in `config/`
   - Updated `CHANGELOG.md`
   - Asset changes in `assets/` if applicable

8. **Never commit without asking** - even if everything seems ready

### Changelog Maintenance (REQUIRED)

**After completing ANY work session, update CHANGELOG.md:**

1. **Always update the changelog** when you finish a piece of work (bug fix, new feature, refactoring, etc.)
2. **Format**: Use date-based sections with descriptive summaries
3. **Location**: `CHANGELOG.md` in the project root (create if it doesn't exist)
4. **Structure**: Follow this format:

```markdown
# Changelog

## 2025-11-21

### Added
- New Product resource with attributes for name, description, price, and inventory
- JSON:API endpoints for products at `/api/json/products`
- Admin interface integration for product management

### Changed
- Updated User resource to include `role` field for authorization
- Modified authentication flow to support admin users

### Fixed
- Resolved issue with magic link emails not sending in development
- Fixed navigation bar responsive layout on mobile devices

## 2025-11-20

### Added
- Initial project setup with Ash Framework and Phoenix LiveView
```

5. **What to include**:
   - **Added**: New features, resources, components, or functionality
   - **Changed**: Modifications to existing functionality
   - **Fixed**: Bug fixes and corrections
   - **Removed**: Deleted features or code (if applicable)
   - **Technical details**: Mention file paths, resource names, or component names for clarity

6. **When to update**:
   - At the end of each work session
   - Before asking user to finalize with production migrations
   - After implementing any significant feature or fix
   - **Never skip this step** - it helps track project evolution and assists future Claude instances

### Ash Migration Workflow (CRITICAL)

**When working on ANY resource changes, follow this workflow:**

1. **Start with development migrations**: Always use `mix ash.codegen --dev` for initial work
2. **Iterate freely**: Make changes, run `mix ash.codegen --dev`, test, repeat
3. **Test thoroughly**: Ensure the resource changes work as expected
4. **Ask before finalizing**: When you believe the work is complete, ask the user:
   > "I've completed the resource changes and tested them with development migrations. Would you like me to generate production-ready migrations with `mix ash.codegen` so we can commit these changes?"
5. **Generate production migrations only after approval**: Run `mix ash.codegen` (without --dev)
6. **Never generate production migrations proactively** - always confirm with the user first

### Working with Ash Resources and Snapshots

Ash uses a **snapshot-based migration system** instead of traditional migration files. Snapshots are JSON representations of your resource schemas stored in `priv/resource_snapshots/repo/<resource_name>/`.

#### How Snapshots Work

1. **Snapshots are version history**: Each time you run `mix ash.codegen`, Ash:
   - Compares current resource definitions with the latest snapshot
   - Detects schema changes (new fields, modified types, etc.)
   - Generates a new timestamped snapshot (e.g., `20251121101114.json`)
   - Creates corresponding Ecto migrations in `priv/repo/migrations/`

2. **Snapshots track state, not changes**: Unlike traditional migrations that describe changes, snapshots describe the complete state of your resources at a point in time. Ash diffs snapshots to generate migrations.

#### Development vs Production Migrations

**ALWAYS start with `mix ash.codegen --dev` for any resource changes**:
- Creates migrations marked as "development only"
- Allows you to experiment without committing to permanent migration history
- Can be squashed or replaced later with production migrations
- Safe for iterative development when you're still refining the data model
- **This should be your default when working on resources**

**Switch to `mix ash.codegen` (without --dev) only when**:
- You're ready to commit changes to version control
- The schema change should be permanent and tracked in migration history
- You're working on a feature branch ready for review
- In production environments (CI/CD pipelines)
- **IMPORTANT**: Before switching, ask the user if they're ready to create production migrations

#### Typical Workflow

**During active development:**
```bash
# 1. Modify resource attributes/relationships
# 2. Generate development migration
mix ash.codegen --dev
# 3. Apply migration to local database
mix ash.migrate
# 4. Test changes
# 5. Repeat steps 1-4 as needed
```

**When ready to finalize (ask user first):**
```bash
# Step 1: Ask user if ready for production migrations
# "I've completed the resource changes and tested them with development
# migrations. Would you like me to generate production-ready migrations?"

# After user approval:
# - Optionally reset database to clean up dev migrations: mix ash.reset
mix ash.codegen

# Step 2: Update CHANGELOG.md with the changes made

# Step 3: Ask user about committing
# "I've generated production migrations and updated the changelog.
# Would you like me to commit these changes to git?"

# After user approval:
git add lib/ priv/ CHANGELOG.md
git commit -m "$(cat <<'EOF'
feat: add new fields to User resource

- Added role field for authorization
- Added last_login_at timestamp
- Updated migrations and snapshots

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**Example conversation flow:**
1. You: "I've completed the resource changes and tested them with development migrations. Would you like me to generate production-ready migrations with `mix ash.codegen`?"
2. User approves → run `mix ash.codegen` and update changelog
3. You: "I've generated production migrations and updated the changelog. The changes are tested and working. Would you like me to commit these changes to git?"
4. User approves → create git commit with descriptive message

#### Important Notes

- **Always use --dev flag first** - start all resource work with `mix ash.codegen --dev`, then ask the user before generating production migrations
- **Never edit snapshots manually** - always modify resource definitions and regenerate
- **Commit snapshots to git** - they're part of your schema history
- **Migration files are generated from snapshots** - don't edit them manually either
- If you have multiple --dev migrations, you may want to `mix ash.reset` and regenerate a single clean migration before committing
- **Ask before finalizing** - when you think the resource changes are complete and tested, ask the user if they want to generate production migrations with `mix ash.codegen`

### Adding New Resources

1. Define the resource module with `use Ash.Resource`
2. Add to appropriate domain's `resources` block
3. Configure data layer (e.g., `postgres do ... end`)
4. Define attributes, actions, and relationships
5. Run `mix ash.codegen --dev` (for experimentation) or `mix ash.codegen` (when ready to commit)
6. Run `mix ash.migrate` to create the database table
7. First snapshot for the resource will be created in `priv/resource_snapshots/repo/<resource_name>/`

### LiveView Development

**See `AGENTS.md` for comprehensive LiveView guidelines.** Key points:
- Use streams for collections (never use regular list assigns for large collections)
- Always add unique DOM IDs to key elements for testing
- Import Mishka components via `MedishopWeb.Components.MishkaComponents`
- Layouts module is pre-aliased as `Layouts`
- Always wrap content with `<Layouts.app flash={@flash} ...>`
- HEEx syntax: use `{...}` for attribute interpolation, `<%= ... %>` for block constructs
- Read AGENTS.md sections on LiveView streams, HEEx templates, and Phoenix HTML guidelines

### API Development

- JSON:API endpoints auto-generated from Ash resources with `ash_json_api` extension
- Add `json_api` block to resources to expose them via API
- OpenAPI documentation auto-generated at `/api/json/open_api`
- Use SwaggerUI at `/api/json/swaggerui` for API exploration

## Important Notes

- **Read AGENTS.md**: Always consult `AGENTS.md` for detailed Elixir, Phoenix, LiveView, and testing guidelines
- **Git Commits**: Never commit without asking the user first - always seek permission before creating commits
- **Changelog**: Always update `CHANGELOG.md` after completing work - this is mandatory, not optional
- **HTTP Client**: Use `:req` (Req) for HTTP requests, avoid `:httpoison`, `:tesla`, `:httpc`
- **Tailwind v4**: No `tailwind.config.js` needed; uses new `@import` syntax in `app.css`
- **Component Library**: Mishka Chelekom provides 60+ components; use them instead of building from scratch
- **No DaisyUI**: Despite DaisyUI overrides in auth routes, manually write Tailwind-based components for custom design
- **Admin Interface**: AshAdmin available at `/admin` in development for resource management
- **Live Dashboard**: Available at `/dev/dashboard` in development

## Testing

**See `AGENTS.md` for comprehensive testing guidelines.** Key points:
- Use `Phoenix.LiveViewTest` for LiveView testing
- Use `LazyHTML` for HTML assertions (included)
- Reference element IDs from templates in tests (e.g., `#product-form`)
- Test against actual HTML output, not mental models
- Use `element/2`, `has_element/2` instead of raw HTML assertions
- Use `render_submit/2` and `render_change/2` for form testing
- Read AGENTS.md "LiveView tests" section for detailed patterns and examples
