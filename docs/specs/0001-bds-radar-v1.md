# BDS Radar — v1 Spec

Personal Ruby on Rails system that crawls Vietnamese real-estate listings, normalizes the messy data into one shape, and exposes it for visualization/analysis. Glossary: [`CONTEXT.md`](../../CONTEXT.md). Decisions: [`docs/adr/`](../adr/).

Every decision below was settled by **live crawl tests**, not assumption — see the empirical notes inline.

## 1. Scope (locked)

- **v1 Suppliers:** `nhatot` (JSON gateway) + `mogi` (server-rendered HTML). `batdongsan` deferred to v2 (Cloudflare → needs a real browser → `BrowserSource`; proven reachable but heavier infra).
- **v1 coverage:** provinces with `schedule_fetch = true` — seed-enable **Hồ Chí Minh, Hà Nội, Khánh Hòa** (covers Nha Trang).
- Mandatory fields per listing (a Supplier is not built until all 6 are proven parseable from a live response): **address** (Ward + City; Street nullable), **source_url**, **image_urls**, **price**, **area** (m²), **type**.

## 2. Suppliers — proven field mappings

### nhatot — *list-complete*, plain HTTP JSON, no auth
`GET https://gateway.chotot.com/v1/public/ad-listing?cg=1000&st=s,k&region_v2=<code>&limit=20&o=<offset>`

| Mandatory field | nhatot source | Note |
|---|---|---|
| source_url | derived from `list_id` | |
| type | `category` (1010=condo, 1020=house, 1040=land) → canonical enum | structured, no AI |
| price | `price` (VND int), `price_string` (display) | |
| area (m²) | **`size`** | ⚠️ NOT `area` — `area` is the district code (the trap) |
| address | `ward_name` / `area_name` (district) / `region_name` (province) / `street_name` | old 3-tier + `(Quận X cũ)` annotations |
| image_urls | `images[]` (≤10) | |
| **coords** | `latitude` / `longitude` | present on **every** listing, every region |

### mogi — *list + detail*, server-rendered HTML
List: `GET https://mogi.vn/<province-slug>/mua-nha-dat` (paginated). Detail: `GET <listing-url>` (needed for Ward + coords).

| Mandatory field | mogi source | Note |
|---|---|---|
| source_url | list `href` ending `-id<N>` | `external_id` = the `<N>` |
| type | URL path slug (`mua-can-ho`→condo, `mua-nha-…`→house, `mua-dat`→land) | structured; AI only as logged fallback |
| price | `.price` text e.g. `6 tỷ 750 triệu` | needs VN price parser (tỷ=1e9, triệu=1e6) |
| area (m²) | `.prop-attr` `114 m2` | |
| address | **detail page** `.address`: `Đường … , Phường … , Quận … , TPHCM` | list page only has District+City → detail fetch required |
| image_urls | `cloud.mogi.vn/images/...` (filter the dmca badge) | |
| **coords** | detail map iframe `…/place?...q=<lat>,<lng>` | |

## 3. Data model

### `provinces` — crawl-control surface
`name`, `alternatives:string[]` (e.g. `TPHCM`, `Sài Gòn` → HCM), **`schedule_fetch:boolean`** (default false), `fetch_page_depth:integer` (default 5). Seeded from the post-2025 canonical province list. Per-supplier region codes (nhatot `region_v2`, mogi slug) are **hard-coded in each Supplier subclass**, not here (the DB owns *what* to crawl; the Supplier owns *how* to address it).

### `ward_cities` — best-effort label reference
`ward`, `city`, `ward_alternatives:string[]`, `city_alternatives:string[]`. Unique on `(ward, city)` at DB level; app-level validation guards alternative uniqueness. Canonicalizes the Administrative path; **not** the location identity.

### `real_estate_sources` — one row per live listing, upserted
- `supplier:string`, `external_id:string` — **unique together** (upsert key)
- `raw_data:jsonb` — original payload
- pre-parsed: `address:string` (raw full line), `province`, `district_or_city`, `ward`, `street`, `area:decimal` (m²), `price:bigint` (VND), `type:string`, `image_urls:string[]`, `source_url:string`, `latitude:decimal`, `longitude:decimal`
- `last_seen_at:datetime`
- On upsert, parsed fields + `raw_data` refreshed, `last_seen_at` bumped. The incoming-vs-stored `price` comparison is the **seam** for a future `price_observations(source_id, price, observed_at)` append-table — v1 just overwrites.

### `real_estates` — normalized, deduplicated property
- canonical location: **`latitude` / `longitude`** (identity; powers maps/stats; map link `https://www.google.com/maps?q={lat},{lng}` is *derived*, never stored — ADR-0001)
- denormalized **Administrative path**: `province` / `district_or_city` / `ward` — flat search at any slot; province search includes sub-cities (a Thủ Đức listing is tagged `province = Hồ Chí Minh`, so "search HCM" returns Thủ Đức + its wards, no recursive tree)
- `area:decimal`, `price:bigint`, `type:string` (enum: condo/house/land/commercial/other), `image_urls`, `source_urls:string[]`
- `ward_city_id:references` (nullable — best-effort match)
- v1: **1:1 with `real_estate_sources`** (no cross-source merge yet). Future dedup keys off coords + area + price.

## 4. Supplier abstraction (transport vs parsing)

```
Suppliers::Base                 # WRAPPER = transport only
  #get(url, headers:)           #   http client, retry + backoff, 3xx/4xx/5xx handling, throttle
                                #   returns RAW body (does NOT parse — mogi is HTML, not JSON)
  PROVINCE_CODES = {...}        #   (in subclass) hard-coded province→region map + URI/headers

Suppliers::Nhatot < Base
  #each_listing(province, page) #   GET gateway JSON, yield raw hashes (list-complete)
  #normalize(raw) -> Listing    #   -> value object: 6 mandatory fields + coords + admin path

Suppliers::Mogi < Base
  #each_listing(province, page) #   GET list HTML → parse detail URLs → GET each detail (Base#get)
  #normalize(raw) -> Listing    #   list+detail flow hidden behind the same contract
```
One base class. The list-complete vs list+detail difference lives inside each subclass's `each_listing`. `normalize` always returns a `Listing` value object → upserted into `real_estate_sources`.

## 5. Background jobs (master fan-out → per-(supplier × province) children)

```
Fetch::MasterJob        cron @ :00 every 2h
   reads Province.where(schedule_fetch: true) × enabled suppliers
   └─> Fetch::SupplierJob(supplier, province)        # child, isolated + retriable
          each_listing up to fetch_page_depth → normalize → upsert real_estate_sources

Normalize::MasterJob    cron @ :30 every 2h
   └─> Normalize::SupplierJob(...)                    # build/refresh real_estates from sources
```
- Granularity **per `(supplier, province)`** — isolation (one unit failing doesn't abort the rest), parallelism across Sidekiq, independent retry.
- Children **upsert** (idempotent); a **unique-job guard** prevents a slow cycle double-enqueuing the same unit.
- Scheduler: sidekiq-cron (or equivalent).

## 6. API (CRUD, JSON-only)

- **JSON in / JSON only out.** Reject non-JSON `Content-Type`.
- **Representers via `roar-rails`** for every response body.
- **Params validated with `dry-validation`** contracts per endpoint (reject → 422 + error representer).
- CRUD-convention resources: `real_estates` (index with filters: province/district/ward, type, price range, area range, bbox/coords; show), `provinces` (index; update `schedule_fetch`), `ward_cities`. Read-heavy; writes mostly via jobs.
- **OpenAPI (Swagger) maintained as a hand-written YAML** under `docs/openapi.yaml`, kept in sync with endpoints.

## 7. Testing (per user rules)

- **Never stub a function/method's return value. Stub only outbound API requests** (WebMock/VCR against nhatot gateway + mogi HTML fixtures).
- **Layer-boundary mocking:** when testing layer 1 that calls layer 2, mock layer 2 and assert it's triggered once with expected params (e.g. controller → service: expect service called once with params).
- **FactoryBot** for models + canned API responses (fixture payloads from the live samples captured during this grill).
- **Parallel tests** enabled.
- Coverage: parsers (the messy-field cases — price strings, area-vs-size, address path, coords from mogi iframe), Supplier `each_listing`/`normalize`, upsert idempotency, job fan-out (master enqueues N children with expected args), request specs per endpoint, an **e2e** that runs fetch→normalize→API against recorded fixtures.

## 8. CI/CD — GitHub Actions (mirror money-lover)

- `ci.yml`: change-detection gate + concurrency-cancel; stages **lint (rubocop) → unit/integration (parallel) → e2e (server + Sidekiq against fixtures)**. `pull_request` + `push` + `workflow_dispatch`.
- `nightly.yml`: full suite + a **live smoke** hitting nhatot/mogi to detect upstream HTML/JSON drift early.
- `security-scan.yml`: `bundler-audit` + `brakeman`.

## 9. Mobile AI-coding setup (mirror money-lover)

- Project-local `CLAUDE.md` (build guidelines, conventions, pointers to CONTEXT/ADR/specs), `.claude/skills/`, `docs/guidelines/`, `docs/agents/`, local-markdown issue tracker under `.scratch/<feature>/`, so the project is drivable from the Claude Code mobile/web app.

## 10. License & stack

- **BSD 3-Clause**, © 2026 Khoi Hoang (same as money-lover).
- Ruby on Rails (API-only), PostgreSQL, Puma, Sidekiq, sidekiq-cron, roar-rails, dry-validation, FactoryBot, WebMock/VCR, rubocop, brakeman, bundler-audit. HTML parsing: Nokogiri.

## Open items deferred to v2 (designed-for, not built)
batdongsan `BrowserSource`; cross-source dedup/merge in `real_estates`; `price_observations` history; reverse-geocode fallback for coords→WardCity matching.
