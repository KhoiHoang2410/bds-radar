# Listing lifecycle: a `status` column maintained by a fetch-then-store mark-and-sweep

**Status:** accepted

A listing that is sold or withdrawn simply **drops out of a supplier's feed** — there is no "deleted" signal. Without handling this, `real_estate_sources` rows live forever, Normalize keeps copying them into `real_estates`, and the query API serves **dead inventory as if it were on-market** — a correctness bug for a tool whose purpose is analyzing a *live* market.

We add a `status` (`active` | `inactive`) column to `real_estate_sources` and propagate it to `real_estates`. The query API defaults to `status = active`.

`status` is maintained by `Fetch::SupplierJob(supplier, province)` using a **fetch-then-store** protocol:

1. Fetch **all** pages (and, for mogi, all detail pages) into memory and normalize to `Listing` value objects. Any HTTP/parse error here **raises with zero DB writes** and the unit retries.
2. In **one transaction**: bulk-set `status = inactive` for the crawl scope `(supplier, province_id)`, then upsert every fetched `Listing` with `status = active` and `last_seen_at = now`, then commit.

Net effect: re-seen ⇒ active, vanished-from-feed ⇒ inactive, transient outage ⇒ no change. Normalize then flips a `RealEstate` inactive when its source is inactive.

The sweep scopes on **`province_id`** (the canonical crawl unit, an FK stamped by the job), never on the raw parsed `province` string, which drifts (`TPHCM` / `Tp Hồ Chí Minh` / legacy `(Quận X cũ)`) and would leave drifted rows un-swept as false-actives.

## Alternatives rejected

- **Do nothing (unbounded staleness)** — the market view is quietly wrong and degrades over time.
- **Keep all rows, filter by a `last_seen_at` freshness window at query time** — simpler and fully reversible, but "on-market" becomes a fuzzy time-window heuristic rather than a fact derived from the supplier's own feed; chosen against because the feed *is* the ground truth for liveness.
- **Literal pre-mark: deactivate the scope *before* fetching, then upsert** — has a dark window: if the fetch then fails (supplier 503, Cloudflare, partial page), the rows are never re-activated and a transient outage blacks out an entire province. Fetch-then-store + a single transaction removes the window.

## Consequences

- A transient fetch failure mutates nothing; the previous cycle's `status` stands until a fetch fully succeeds.
- Liveness is a fact from the feed, not a guess from a clock; the default query window needs no tuning.
- The fetch job buffers a unit's listings in memory before writing — trivial at v1 volumes (~100/unit).
- `last_seen_at` is still recorded, leaving room for the deferred `price_observations` history without being load-bearing for liveness.
