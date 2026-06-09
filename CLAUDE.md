# BDS Radar

Personal Ruby on Rails system that crawls Vietnamese real-estate listings, normalizes the messy data into one shape, and exposes it for visualization/analysis.

## Read before implementing

- **Glossary:** [`CONTEXT.md`](CONTEXT.md) — domain language (Supplier, RealEstateSource, RealEstate, WardCity, Coordinates, Administrative path). Use these terms; honor the `_Avoid_` lists.
- **Decisions:** [`docs/adr/`](docs/adr/) — e.g. ADR-0001 (coordinates = location identity).
- **Spec:** [`docs/specs/0001-bds-radar-v1.md`](docs/specs/0001-bds-radar-v1.md) — the v1 build, with empirically-proven supplier field mappings.

## Stack

Rails (API-only), PostgreSQL, Puma, Sidekiq + sidekiq-cron, roar-rails (representers), dry-validation, FactoryBot, WebMock/VCR, Nokogiri (HTML), rubocop, brakeman, bundler-audit.

## Conventions

- **JSON in / JSON only out.** Every response body goes through a roar representer; every endpoint validates params with a dry-validation contract.
- **CRUD-convention** resources. OpenAPI (Swagger) maintained by hand as `docs/openapi.yaml`, kept in sync.
- **Suppliers:** `Suppliers::Base` is transport only (HTTP client, retry, status handling, throttle) and returns the raw body — parsing lives in each subclass (nhatot=JSON, mogi=HTML). Per-supplier province→region-code maps and URIs/headers are hard-coded in the subclass.
- **Jobs:** a master job fans out per-`(supplier × province)` children; children upsert idempotently behind a unique-job guard.

## Testing rules (non-negotiable)

- **Never stub a function/method return value. Stub only outbound API requests** (WebMock/VCR; mogi/nhatot fixtures from the live samples).
- **Layer-boundary mocking:** when layer 1 calls layer 2, mock layer 2 and assert it's invoked once with the expected params.
- **FactoryBot** for models + canned responses. **Parallel tests** on.

## Agent skills

### Issue tracker

GitHub Issues on `KhoiHoang2410/bds-radar`, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical role strings (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` + `docs/adr/` at the root. See `docs/agents/domain.md`.
