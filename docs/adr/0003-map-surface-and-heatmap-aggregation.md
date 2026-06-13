# The map surface is a vendored Leaflet page on OpenStreetMap raster tiles, with geo-grid heatmap aggregation

**Status:** accepted

The visualization layer (the "Radar" surface) renders live `RealEstate` inventory and a price heatmap. Five choices gate every downstream map slice; we lock them here so the implementation issues build on one substrate. The goal for v1 is a **personal tool with the smallest possible external-dependency surface**: $0, no API keys, and a single auditable hostname leaving our boundary at runtime.

## Decisions

**1. Base tiles: OpenStreetMap raster (`tile.openstreetmap.org`).** Free, no API key, no card on file. It is the one required runtime third party. We honor the [OSM tile usage policy](https://operations.osmfoundation.org/policies/tiles/): a valid `Referer`/User-Agent, no bulk/pre-fetching, and **the "© OpenStreetMap contributors" attribution is mandatory and must stay visible on the map** — a hard requirement inherited by every slice that renders the map. This posture is for **personal use only**; a public or commercial deployment must switch to a paid provider (MapTiler/Mapbox), which is a tile-URL + key change, not a re-architecture.

**2. Map library: Leaflet + Leaflet.heat.** Raster tiles let us use Leaflet without the glyph/sprite/font endpoints that vector styles (MapLibre GL) require — fewer moving parts and zero extra runtime calls.

**3. Aggregation unit: geo-grid bins computed from stored `latitude`/`longitude`.** The heatmap aggregates RealEstates into grid cells derived purely from the coordinates we already store (ADR-0001) — bin by snapping/rounding lat/lng, then aggregate `count` / `median_price` / `price_per_m2` per cell. We do **not** aggregate by ward polygon: `ward_id` is nullable and best-effort (ADR-0001), and polygons would require external boundary GeoJSON for VN's mid-migration post-2025 2-tier wards. Grid needs no boundary data and no geocoding.

**4. Third-party posture: vendor all JS/CSS/icon assets.** Leaflet's JS, CSS, marker images, and the heatmap plugin are vendored into the repo (`public/`), never loaded from a JS CDN at runtime. Consequence: the only required runtime third party across the whole feature is the OSM tile host. Listing **thumbnails** in popups (which hot-link supplier image CDNs — `cloud.mogi.vn`, chotot — already present in `image_urls`) are **opt-in and off by default**, so the default map adds no image-CDN dependency.

**5. Frontend surface: a static Leaflet page served from `public/`.** This preserves the API-only convention (JSON in / JSON only out) — the map is a static client that consumes the existing JSON endpoints. We do **not** stand up a separate React/TS app for v1; that is reserved for if and when the tool goes from personal to product.

## Alternatives rejected

- **Ward-polygon aggregation** — prettier choropleths, but needs external VN 2-tier boundary GeoJSON (scarce/incomplete mid-reform) and breaks for the nullable `ward_id`; geo-grid is dependency-free and always defined where coords exist.
- **MapLibre GL + vector tiles** — nicer styling, but pulls in glyph/sprite/font endpoints and a vector-tile provider; raster + Leaflet keeps the runtime surface to one hostname.
- **JS/CSS from a CDN (unpkg/jsdelivr)** — convenient, but adds a stealth runtime third party and a supply-chain/availability dependency; vendoring removes it.
- **Paid tile providers (MapTiler/Mapbox) / Google Maps** — require keys, a card on file, and higher cost; unjustified for a personal-traffic tool. Left as the documented upgrade path for a public deployment.
- **A separate React/TS frontend app** — heavier build/deploy and breaks the API-only simplicity for no v1 benefit; a static page demos the same data.

## Consequences

- Exactly **one required runtime third party**: `tile.openstreetmap.org`. Easy to audit and to swap.
- The map renders straight from the existing `real_estates` index (points) and the geo-grid `/real_estates/map` endpoint (heatmap) — no new external geo data, no geocoding, no boundary files.
- OSM attribution and a valid `Referer`/User-Agent are load-bearing obligations on every map-rendering slice, not optional polish.
- Going public later is a contained change: swap the tile URL + add a key for a paid provider, and (if desired) replace the static page with a richer frontend — the JSON API and aggregation endpoint are unaffected.
- Thumbnails staying opt-in keeps a slow/down supplier image CDN from degrading the default map view.
