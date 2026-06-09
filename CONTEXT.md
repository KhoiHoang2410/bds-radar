# BDS Radar

A personal system that crawls Vietnamese real-estate listings from multiple public sources, normalizes the messy Vietnamese data into one consistent shape, and lets the owner visualize and analyze a market area.

## Language

### Sources & fetching

**Supplier**:
A real-estate website we crawl (e.g. nhatot, mogi). Each Supplier has its own transport and parser, and owns its hard-coded province→region-code map (nhatot `region_v2` numeric, mogi province slug) plus URI/headers. Addresses coverage at the province level.
_Avoid_: Vendor, provider, site

**Province**:
The crawl-control surface: a canonical post-2025 VN province/city with `schedule_fetch` (only true provinces are crawled), `alternatives`, and per-province depth. Top slot of the Administrative path. The DB owns *what* to crawl; the Supplier owns *how* to address it.

**HttpSource**:
A Supplier reachable over plain HTTP — either a JSON API (nhatot) or server-rendered HTML (mogi). Fits the shared fetch wrapper.

**BrowserSource**:
A Supplier reachable only by driving a real browser that passes a bot-challenge (e.g. batdongsan / Cloudflare). Deferred to v2; named now so the abstraction leaves room for it.

### Records

**Listing**:
One advertisement as it exists at a Supplier — one property offered for sale by one poster. The unit we fetch.
_Avoid_: Ad, post, item

**RealEstateSource**:
Our stored copy of one fetched Listing, keeping the original `raw_data` plus pre-parsed fields (address, area, type, images, source_url, coords). **Upserted on a unique `(supplier, external_id)`** — one row per live listing, refreshed each fetch with `last_seen_at` bumped. The upsert's price-comparison point is the seam where a future `price_observations` append-table hooks in (v1 just overwrites).
_Avoid_: Raw listing, source record

**RealEstate**:
A normalized, deduplicated property built from one or more RealEstateSource rows. In v1 it is a 1:1 copy of RealEstateSource (no merging yet) until real duplicate patterns are understood.
_Avoid_: Property, normalized listing

### Property types

Canonical vocabulary for `RealEstate.type`. Every Supplier maps its own raw categories into exactly one of these.

**condo** — chung cư / căn hộ.
**house** — nhà ở / nhà riêng / nhà mặt phố / biệt thự (all detached & attached housing collapsed).
**land** — đất / đất nền.
**commercial** — văn phòng / mặt bằng kinh doanh / nhà xưởng.
**other** — fallback for unmapped or AI-uncertain listings.

> AI type-inference is a logged fallback only — both v1 Suppliers expose type via structured signals (nhatot `category`, mogi URL/breadcrumb).

### Mandatory fields

The six fields every Listing MUST yield before a Supplier may be implemented: **address** (Ward + City; Street nullable), **source_url**, **image_urls**, **price**, **area** (m²), **type**. A Supplier whose response cannot produce all six is not built.

### Address

**Coordinates**:
A `(latitude, longitude)` pair — the **canonical location identity** of a RealEstate. Universal across suppliers (nhatot lat/long fields; mogi map-iframe `q=`), reform-proof, and what powers maps/heatmaps/area-stats. The clickable map link is *derived* (`https://www.google.com/maps?q={lat},{lng}`), never stored.

**Administrative path**:
The denormalized 3-slot location label on each RealEstate: **province** (top-level city/tỉnh) → **district_or_city** (district / sub-city; e.g. `Thành phố Thủ Đức`) → **ward**. Carried on every supplier record, so search is a flat filter at any slot. Searching a province returns everything beneath it (a Thủ Đức listing is tagged `province = Hồ Chí Minh`, so "search HCM" includes Thủ Đức and all its wards) — no recursive tree needed.

**WardCity**:
A reference table that **canonicalizes** the Administrative path and holds alternative spellings (e.g. `TPHCM` / `Tp Hồ Chí Minh` / `Sài Gòn` → one province). A **best-effort human-readable label**, NOT the location identity (that is Coordinates). A RealEstate may have Coordinates but no matched WardCity.
_Avoid_: Location, region, area

> ⚠️ **Naming trap (nhatot):** in the nhatot payload the field literally named `area` is the administrative **district**, NOT the property size. Property size lives in `size`. In our domain, **Area always means square-meters**; administrative place is **Ward/City/District**, never "area".

> ⚠️ **(Ward, City) is not unique in legacy supplier data.** The 2025 administrative reform (3-tier → 2-tier) is mid-migration; suppliers still emit ambiguous numbered wards (e.g. `Phường 9` in many HCM districts). Hence Coordinates, not ward names, are the identity. Ward/District/Province are stored as raw strings on RealEstateSource exactly as the supplier emits them.
