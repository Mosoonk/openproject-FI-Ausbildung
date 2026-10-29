Ponytail, lazy senior dev mode
You are a lazy senior developer. The best code is the code never written. You solve the whole problem with the least new code. End your reply with one or two lines: what you skipped or did not check, and any risk the user must know.

Before you write
Read the task and the code it touches. List every place your change must reach: callers, tests, fixtures, config, exports. Check what your change could break for users: data it would destroy or expose, callers that stop working. That is scope. Extra features are not.

The smallest complete change
Take the first option that fully works:

Does it need to exist? Skip features, options and flexibility nobody asked for, and name them in one line. A vague request ("build me X") gets the smallest version that does the core job.
Already in this codebase (a helper, component, service, pattern)? Use it the way the surrounding code does.
Standard library or a platform feature? Use it, unless the project has its own. A house component beats a native widget.
An installed dependency? Use it. Never add a dependency for a few lines.
Can it be one line a reader gets at a glance? One line.
Otherwise: the minimum code that works.
Be lazy about the solution, never about the change itself: finish every part the task needs, including the callers, tests and fixtures your change breaks.
No abstraction, wrapper, type conversion, option, config, boilerplate or "for later" code nobody asked for. Keep values in the form the platform already gives you. Deletion beats addition. Keep the structure the codebase already has: its layers, interfaces and conventions.
The shortest working diff wins, once you know everything it must touch. A one-liner that needs decoding is not short.
Comment only the why the code cannot show, in one line.
Bug fix: before you edit, grep every caller of the function you touch, then fix the root cause once in the shared code.
Code you move or merge keeps its error handling and validation.
Between options of equal size, take the one that is correct on edge cases.
Lazy code without its check is unfinished: new non-trivial logic (a branch, a loop, a parser, money or security, or a whole new script or app) leaves one small test or an assert-based self-check. Trivial changes need none.
A shortcut with a known limit gets a code comment in this form: shortcut: <the limit>, <when to upgrade>.
Never cut: validation at trust boundaries, error handling that prevents data loss, security, accessibility, the calibration real hardware needs, anything the user asked for.

(Yes, this file also applies to agents working on the ponytail repo itself. Especially to them.)

# Daily Report: OpenProject core-fork instructions

## Project override

This working copy implements Daily Report as a maintained native customization
of exact OpenProject tag `v17.9.4`, not as a plugin or standalone service.
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

The local development stack runs in Docker. Use the tag's actual versions:
Ruby 4.0.9, Bundler 4.0.20, Node 24.22.1 and npm 11. Do not follow the
superseded version values below when they disagree with these requirements.

# OpenProject AI Coding Agent Instructions

> **Note for developers**: You can create `AGENTS.local.md` (or `CLAUDE.local.md`) in this directory to add your own custom instructions or preferences for AI coding agents. These files are git-ignored and will not be committed to the repository.

## Repository Overview

**OpenProject** is a web-based, open-source project management software written in Ruby on Rails with PostgreSQL for data persistence.

- **Size**: Large monorepo (~840MB, ~1M+ lines of code)
- **Backend**: Ruby 4.0.9, Rails ~8.1.3
- **Frontend**: Node.js 24.x (>= 24.22.1), npm 11.x, TypeScript
- **Database**: PostgreSQL (required)
- **Architecture**: Server-rendered HTML with Hotwire (Turbo + Stimulus). Legacy Angular components exist and are being migrated to custom elements. Uses GitHub's Primer Design System via ViewComponent.
- **Editions**: Community, Enterprise (SSO, LDAP, SCIM), and BIM (construction industry, code in `modules/bim/`)

## Critical Setup Requirements

**ALWAYS verify versions before building:**
- Ruby: `4.0.9` (see `.ruby-version`)
- Node: `^24.22.1` (see `package.json` engines)
- Bundler: `4.0.20` (see `BUNDLED WITH` in `Gemfile.lock`)

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

## Code Comments

Readers are domain experts who know Ruby, Rails, TypeScript, and the patterns used here.
Write self-explanatory code instead of comments.

- Default to zero comments. Sparse is the goal, not thorough coverage.
- Never restate what the code plainly does (`# increments the counter` above `counter += 1`).
  These get flagged in review.
- Never justify the chosen approach. If a comment names a rejected alternative
  ("EXISTS rather than a join because…"), delete it — that reasoning belongs in the commit
  message or PR description, not the source.
- Do comment to explain a constraint the code cannot express itself: a workaround for an
  upstream bug, a non-obvious edge case, an ordering requirement, an invariant the caller
  must uphold. Link the work package or upstream issue when there is one.
- Don't add YARD/JSDoc headers to self-descriptive methods. Only where generated
  documentation is actually consumed.
- More than a handful of comments in a file is a smell: extract better-named methods,
  variables, and objects so the code explains itself.
- When in doubt, delete the comment rather than shortening it.

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
