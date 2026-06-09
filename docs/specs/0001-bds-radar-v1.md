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

### `ward_cities` — best-effort label reference (post-2025 **2-tier** canonical)
`ward`, `province`, `ward_alternatives:string[]`, `province_alternatives:string[]`. Unique on `(ward, province)` at DB level; app-level validation guards alternative uniqueness. Canonicalizes the Administrative path; **not** the location identity.
- `province` here is the **top-tier province/city** (HCM, Hà Nội) — the post-2025 reform collapsed 3-tier → 2-tier, so the canonical shape is `(ward, province)` with **no district**. (Column is `province`, not `city`, so schema matches the glossary.)
- **Matcher (#6) is best-effort.** Legacy supplier data is still 3-tier; a ward like `Phường 9` is ambiguous under a province (existed in many old districts), so when the chain **exact → alternatives → fuzzy** can't resolve to exactly one row, the matcher returns **no match** (`ward_city_id` stays null) rather than guessing — the RealEstate is still mappable via coords (ADR-0001). The raw `district_or_city` is preserved on the source for humans/debugging but is **not** part of the canonical key.

### `real_estate_sources` — one row per live listing, upserted
- `supplier:string`, `external_id:string` — **unique together** (upsert key)
- `province_id:references` (FK → `provinces`) — **the crawl unit the row was fetched under** (canonical), stamped by the fetch job. This is the **sweep scope key**, NOT the parsed province string below. Index `(supplier, province_id)`.
- `status:string` — `active` | `inactive`. Set `active` on upsert; bulk-set `inactive` by the fetch sweep for rows in `(supplier, province_id)` not re-seen this run (see §5). Drives the default query filter and the Normalize → `real_estates.status` propagation.
- `raw_data:jsonb` — original payload
- pre-parsed: `address:string` (raw full line), `province`, `district_or_city`, `ward`, `street`, `area:decimal` (m²), `price:bigint` (VND), `type:string`, `image_urls:string[]`, `source_url:string`, `latitude:decimal`, `longitude:decimal`
  - ⚠️ the parsed `province` string is **raw supplier text** (drifts: `TPHCM` / `Tp Hồ Chí Minh` / legacy `(Quận X cũ)`); it feeds the Administrative path + WardCity matching but is **never** the sweep key — `province_id` is.
- `last_seen_at:datetime` — bumped to run-start on each re-seen upsert.
- On upsert, parsed fields + `raw_data` refreshed, `status='active'`, `last_seen_at` bumped. The incoming-vs-stored `price` comparison is the **seam** for a future `price_observations(source_id, price, observed_at)` append-table — v1 just overwrites.

### `real_estates` — normalized, deduplicated property
- canonical location: **`latitude` / `longitude`** (identity; powers maps/stats; map link `https://www.google.com/maps?q={lat},{lng}` is *derived*, never stored — ADR-0001)
- `province_id:references` (FK → `provinces`) — **canonical** crawl province, propagated from `source.province_id`. The **province filter keys off this**, so "search HCM" returns **all** of HCM (incl. Thủ Đức + its wards) regardless of raw spelling drift. Always present (every source was fetched under a province).
- denormalized **Administrative path** (raw display strings, copied from source): `province` / `district_or_city` / `ward`. Kept for human display; the **ward filter** keys off `ward_city_id` (canonical) and the **district filter** is a raw best-effort match (post-reform tier abolished, no canonical).
- `area:decimal`, `price:bigint`, `type:string` (enum: condo/house/land/commercial/other), `image_urls`, `source_urls:string[]`
- `ward_city_id:references` (nullable — best-effort match)
- `status:string` — propagated from source by Normalize: a source flipped `inactive` (vanished from feed) flips its `RealEstate` `inactive`. The query API (§6) defaults to `status='active'`.
- v1: **1:1 with `real_estate_sources`** (no cross-source merge yet). Future dedup keys off content (area + price + …), **never coords alone** — VN coords are approximate/decoy, collisions expected (CONTEXT.md).

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
Fetch::MasterJob        cron every 6h
   reads Province.where(schedule_fetch: true) × enabled suppliers
   └─> Fetch::SupplierJob(supplier, province)        # child, isolated + retriable
          1. each_listing up to fetch_page_depth → normalize ALL into memory  (fetch-then-store)
             ↳ any HTTP/parse error here ⇒ raise, ZERO db writes, retry the unit
          2. TRANSACTION:                            # atomic deactivate+upsert (no dark window)
               UPDATE real_estate_sources SET status='inactive'
                 WHERE supplier=? AND fetched_province=?   # scope = the crawl unit
               upsert each Listing → status='active', last_seen_at=now
             COMMIT
          ⇒ re-seen = active; vanished-from-feed = inactive; transient outage = no change

Normalize::MasterJob    cron every 4h   (decoupled from fetch — idempotent, may process unchanged sources)
   reads Province.where(schedule_fetch: true)
   └─> Normalize::ProvinceJob(province)              # ALL suppliers' sources for this province
          v1: copy each source → upsert real_estates (strictly per-source)
          v2: merge sources at this province into deduplicated real_estates
```
- **Fetch shards per `(supplier, province)`** (isolated outbound HTTP, independent retry); **Normalize shards per `province`** (a pure DB→DB transform that must one day see all suppliers together). The two shardings differ *deliberately*: v2 cross-source dedup becomes a change to `Normalize::ProvinceJob`'s loop body, not a re-architecture of the job topology.
- Children **upsert** (idempotent); a **unique-job guard** prevents a slow cycle double-enqueuing the same unit.
- Scheduler: sidekiq-cron. **Throttle: `sidekiq-throttled`, keyed per supplier** (Redis-backed, enforced across all worker processes — solves parallel children hammering one host). nhatot generous; **mogi `concurrency: 1` + slow rate** so its per-listing detail fetches serialize against the single host.

## 6. API (CRUD, JSON-only)

- **JSON in / JSON only out.** Reject non-JSON `Content-Type`.
- **Representers via `roar-rails`** for every response body.
- **Params validated with `dry-validation`** contracts per endpoint (reject → 422 + error representer).
- CRUD-convention resources: `real_estates` (index; **show**), `provinces` (index; update `schedule_fetch`), `ward_cities`. Read-heavy; writes mostly via jobs.
- **`real_estates` index filters** — **province → canonical `province_id`** (reliable, complete); **ward → `ward_city_id`** (canonical, best-effort; null-match rows don't participate); **district → raw `district_or_city`** best-effort; plus `type`, price range, area range, `bbox` (`lat/lng BETWEEN`), and **`status` (default `active`)**.
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
- Ruby on Rails (API-only), PostgreSQL, Puma, Sidekiq, sidekiq-cron, **sidekiq-throttled** (per-supplier rate/concurrency limit), roar-rails, dry-validation, FactoryBot, WebMock/VCR, rubocop, brakeman, bundler-audit. HTML parsing: Nokogiri.

## Open items deferred to v2 (designed-for, not built)
batdongsan `BrowserSource`; cross-source dedup/merge in `real_estates`; `price_observations` history; reverse-geocode fallback for coords→WardCity matching.
