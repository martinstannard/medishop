# Changelog

All notable changes to this project will be documented in this file.

## 2025-11-21

### Added
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
