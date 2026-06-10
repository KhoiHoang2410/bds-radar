# BDS Radar

Personal Ruby on Rails system that crawls Vietnamese real-estate listings from
multiple public sources, normalizes the messy data into one consistent shape,
and exposes it (JSON API) for visualization and market analysis.

## Read first

- **Glossary:** [`CONTEXT.md`](CONTEXT.md) — domain language + the two data traps.
- **Spec:** [`docs/specs/0001-bds-radar-v1.md`](docs/specs/0001-bds-radar-v1.md) — the v1 build with empirically-proven supplier mappings.
- **Decisions:** [`docs/adr/`](docs/adr/) — coordinates as location identity (0001); listing lifecycle mark-and-sweep (0002).
- **Conventions:** [`CLAUDE.md`](CLAUDE.md) — build + non-negotiable testing rules.

## Stack

Rails 8 (API-only) · PostgreSQL · Puma · Sidekiq (+ sidekiq-cron, sidekiq-throttled) ·
roar (representers) · dry-validation · Nokogiri · Faraday · RSpec · FactoryBot · WebMock/VCR.

## Setup

```sh
bundle install
bin/rails db:create db:migrate
bundle exec rspec            # or: bundle exec rake parallel:spec
```

Requires a running PostgreSQL and Redis. Ruby version is pinned in `.ruby-version`.

## Checks

```sh
bundle exec rubocop
bundle exec brakeman
bundle exec bundle-audit check --update
```

CI (GitHub Actions) runs lint → parallel specs → e2e on every push/PR; a nightly
job runs the full suite plus a live smoke against the suppliers to catch upstream
shape drift early.

## License

BSD 3-Clause © 2026 Khoi Hoang. See [`LICENSE`](LICENSE).
