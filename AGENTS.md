# Daily Report: OpenProject core-fork instructions

## Project override

This working copy implements Daily Report as a maintained native customization
of exact OpenProject tag `v17.8.0`, not as a plugin or standalone service.
Use the existing Rails application, session, CSRF protection, PostgreSQL,
models and authorization infrastructure. Keep feature data in dedicated
`daily_report_*` tables; do not use journals, comments or custom fields for
report text, and do not introduce FastAPI, OAuth, API synchronization or a
second database.

Work only in the active phase. Feature reads and writes must enforce native
Work Package visibility server-side. Participants may create only their own
entry for a directly or group-assigned Work Package; subsequent participant
edits/deletes are forbidden. Preserve append-only revision/audit history and
do not put report text into logs.

The local development stack runs in WSL2 Docker. Use the tag's actual versions:
Ruby 4.0.6, Bundler 4.0.16, Node 24.15.0 and npm 11. Do not follow the
superseded version values below when they disagree with these requirements.

# OpenProject AI Coding Agent Instructions

> **Note for developers**: You can create `AGENTS.local.md` (or `CLAUDE.local.md`) in this directory to add your own custom instructions or preferences for AI coding agents. These files are git-ignored and will not be committed to the repository.

## Repository Overview

**OpenProject** is a web-based, open-source project management software written in Ruby on Rails with PostgreSQL for data persistence.

- **Size**: Large monorepo (~840MB, ~1M+ lines of code)
- **Backend**: Ruby 3.4.7, Rails ~8.0.3
- **Frontend**: Node.js 24.x (>= 24.15.0), npm 11.x, TypeScript
- **Database**: PostgreSQL (required)
- **Architecture**: Server-rendered HTML with Hotwire (Turbo + Stimulus). Legacy Angular components exist and are being migrated to custom elements. Uses GitHub's Primer Design System via ViewComponent.
- **Editions**: Community, Enterprise (SSO, LDAP, SCIM), and BIM (construction industry, code in `modules/bim/`)

## Critical Setup Requirements

**ALWAYS verify versions before building:**
- Ruby: `3.4.7` (see `.ruby-version`)
- Node: `^24.15.0` (see `package.json` engines)
- Bundler: Latest 2.x

### Local Development Setup

```bash
bundle install                    # Install Ruby gems
cd frontend && npm ci && cd ..   # Install Node packages
bundle exec rails db:migrate      # Setup database
bin/dev                          # Start all services (Rails, frontend, Good Job worker)
# Access at http://localhost:3000
```

### Docker Development Setup

See [`docker/dev/AGENTS.md`](docker/dev/AGENTS.md) for full Docker setup and commands.

## Project Structure

### Key Directories

- `app/` — Rails application code
- `config/` — Rails configuration, routes, locales
- `db/` — Database migrations and seeds
- `docker/dev/` — Docker development environment
- `frontend/` — TypeScript/Angular/Stimulus frontend
- `lib/` — Ruby libraries and extensions
- `lookbook/` — ViewComponent previews (<https://qa.openproject-edge.com/lookbook/>)
- `modules/` — OpenProject plugin modules
- `spec/` — RSpec test suite

### Configuration Files

- `.ruby-version` - Ruby version
- `.rubocop.yml` - Ruby linting rules
- `.erb_lint.yml` - ERB template linting
- `frontend/eslint.config.mjs` - JavaScript/TypeScript linting
- `Gemfile` - Ruby dependencies
- `package.json` / `frontend/package.json` - Node.js dependencies
- `lefthook.yml` - Git hooks configuration

### Linting (Run Before Committing)

```bash
# Ruby
bundle exec rubocop                              # Check all files
bin/dirty-rubocop --uncommitted                  # Check only uncommitted changes

# JavaScript/TypeScript
cd frontend && npx eslint src/ && cd ..

# ERB Templates
erb_lint {files}

# Install Git Hooks (recommended)
bundle exec lefthook install
```

### JavaScript and TypeScript Copyright Headers

All first-party JavaScript and TypeScript files must use the canonical compact
line-comment copyright header generated from `COPYRIGHT_short`:

```typescript
//-- copyright
// OpenProject is an open source project management software.
// ...
//++

```

Use `//-- copyright` and `//++` exactly as shown. Prefix non-empty body lines
with `// `, prefix empty body lines with `//`, and leave one blank line between
the header and the source code. Do not compose or reformat the header manually.

Run `rake copyright:update_typescript` to add or repair headers in `.ts` and
`.tsx` files. Run `rake copyright:update_js` for `.js`, `.mjs`, and `.cjs`
files. Both commands accept an optional path argument.

## Commit Messages
- First line: < 72 characters, then blank line, then detailed description
- Reference work packages when applicable
- Merge strategy: "Merge pull request" (not squash), except single-commit PRs can use "Rebase and merge"

## Additional Documentation

- `docs/development/` — Development documentation
- `docs/development/running-tests/` — Testing guide
- `docs/development/code-review-guidelines/` — Code review standards
- `CONTRIBUTING.md` — Contribution workflow
- `.github/copilot-instructions.md` — Extended agent instructions with troubleshooting
