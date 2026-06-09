# Coordinates are the canonical location identity; WardCity is a best-effort label

**Status:** accepted

We empirically sampled nhatot and mogi across 5 provinces. Both suppliers expose property **coordinates** on every listing (nhatot `latitude`/`longitude`; mogi's detail-page Google Maps iframe `q=lat,lng`), whereas administrative names are mid-migration under Vietnam's 2025 reform (3-tier → 2-tier) and ambiguous in legacy data — e.g. `Phường 9` exists in many HCM districts, so `(Ward, City)` is not unique. We therefore make `(latitude, longitude)` the canonical location identity of a `RealEstate` (and the source of the derived `maps.google.com?q=` link), and demote `WardCity` to a best-effort, fuzzy-matched human-readable label for filtering/grouping. Ward/District/Province are stored as raw strings on `RealEstateSource` exactly as the supplier emits them.

## Consequences

- A `RealEstate` may have Coordinates but no matched `WardCity`; it is still mappable and analyzable, never lost.
- Cross-source dedup and spatial stats key off geography, not administrative text.
- We never store a map URL — it is derived from Coordinates on read.
- If a supplier ever omits coordinates (a future `BrowserSource` might), that supplier needs a geocoding fallback before it can satisfy the mandatory address field.
