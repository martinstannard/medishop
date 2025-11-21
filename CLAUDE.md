# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
mix ash.codegen           # Generate migrations from Ash resource changes
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

### Working with Ash Resources

When modifying data schemas:
1. Update the resource definition in `lib/medishop/domain_name/resource_name.ex`
2. Run `mix ash.codegen` to generate migrations from resource changes
3. Migrations are stored as JSON snapshots in `priv/resource_snapshots/`
4. Run `mix ash.setup` to apply migrations

### Adding New Resources

1. Define the resource module with `use Ash.Resource`
2. Add to appropriate domain's `resources` block
3. Configure data layer (e.g., `postgres do ... end`)
4. Define attributes, actions, and relationships
5. Run `mix ash.codegen` to generate database schema

### LiveView Development

- Use streams for collections (see AGENTS.md LiveView guidelines)
- Always add unique DOM IDs to key elements for testing
- Import Mishka components via `MedishopWeb.Components.MishkaComponents`
- Layouts module is pre-aliased as `Layouts`

### API Development

- JSON:API endpoints auto-generated from Ash resources with `ash_json_api` extension
- Add `json_api` block to resources to expose them via API
- OpenAPI documentation auto-generated at `/api/json/open_api`
- Use SwaggerUI at `/api/json/swaggerui` for API exploration

## Important Notes

- **HTTP Client**: Use `:req` (Req) for HTTP requests, avoid `:httpoison`, `:tesla`, `:httpc`
- **Tailwind v4**: No `tailwind.config.js` needed; uses new `@import` syntax in `app.css`
- **Component Library**: Mishka Chelekom provides 60+ components; use them instead of building from scratch
- **No DaisyUI**: Despite DaisyUI overrides in auth routes, manually write Tailwind-based components for custom design
- **Admin Interface**: AshAdmin available at `/admin` in development for resource management
- **Live Dashboard**: Available at `/dev/dashboard` in development

## Testing

- Use `Phoenix.LiveViewTest` for LiveView testing
- Use `LazyHTML` for HTML assertions (included)
- Reference element IDs from templates in tests
- Test against actual HTML output, not mental models
- See AGENTS.md for comprehensive LiveView testing guidelines
