# Handoff — BDS Radar implementation run

**Repo:** `KhoiHoang2410/bds-radar` (GitHub). Local: `/Users/hnkhoi/HNKhoi/project/bds-radar`. Branch `main` tracks `origin/main`.
**Date:** 2026-06-10.

## What the next session is for

1. **First, ask the user once** whether they want to grill on anything further (design, an issue's scope, an open question). The design tree is already fully resolved — so this is a quick check, not a re-litigation.
2. **If no grilling needed:** implement **all 8 issues**, opening a PR per issue, while the user is asleep (AFK).
3. **PR base strategy (user's instruction):**
   - An issue whose **"Blocked by" is satisfied by `main`** → branch from `main`, PR base = `main`.
   - An issue that **depends on another issue still in flight** → **stacked PR**: branch from the dependency's branch and set that branch as the PR base (a *dependent PR*), so review/merge order is explicit. Re-target to `main` after the parent merges if needed.

## Don't re-derive — read these first

- **Spec (the build):** `docs/specs/0001-bds-radar-v1.md` — data model w/ columns, Supplier abstraction, job topology, API, testing rules, CI, license. Includes **empirically-proven** supplier field mappings.
- **Glossary:** `CONTEXT.md` — domain terms + the two traps (nhatot `area`≠m² use `size`; `(Ward,City)` not unique in legacy data).
- **Decision:** `docs/adr/0001-coordinates-as-location-identity.md`.
- **Conventions:** `CLAUDE.md` (build + non-negotiable testing rules) and `docs/agents/*` (issue tracker, triage labels, domain doc rules).
- **Issues:** `gh issue list --label ready-for-agent`. #1–#8, dependency chain in each issue's "Blocked by". Spine = **#3 (nhatot tracer bullet)**.

## Build / grab order

`#1 → #2 → #3`, then **#5 and #6 in parallel off #3**, then `#7 (needs #3+#6) → #8 (needs #7)`. #4 needs #3.

So PR bases, assuming you implement in order and parents may not be merged yet:
- #1 → base `main`
- #2 → base #1's branch (until #1 merges)
- #3 → base #2's branch
- #4, #5 → base #3's branch
- #6 → base #1's branch (independent of #2/#3)
- #7 → base #3's branch (also needs #6 — note the cross-dependency in the PR body)
- #8 → base #7's branch

## Critical constraints (will fail review if violated)

- **Tests: never stub a function/method's return value — stub only outbound HTTP** (WebMock/VCR). Layer-boundary mocking: assert layer 2 is called once with expected params. FactoryBot + parallel tests.
- **Use the captured live samples as fixtures** — nhatot gateway JSON and mogi list+detail HTML were verified live during the grill (shapes documented in spec §2). Re-fetch fresh fixtures if needed: nhatot `gateway.chotot.com/v1/public/ad-listing?cg=1000&st=s,k&region_v2=13000&limit=20`; mogi `mogi.vn/ho-chi-minh/mua-nha-dat` + a detail page.
- **JSON-only API**, roar-rails representers, dry-validation contracts, OpenAPI kept in sync per touched endpoint.
- **CI must be green** before marking a PR ready (#1 establishes the workflows).

## Gotchas already discovered

- nhatot `area` field = administrative district; property m² is `size`.
- mogi list page lacks Ward + coords → **must fetch the detail page**; coords live in the detail map iframe `q=lat,lng`; filter the dmca badge image.
- batdongsan is **v2 only** (Cloudflare; needs a real browser / `BrowserSource`) — do not attempt in these 8.
- "Nha Trang" = a city under **Khánh Hòa** province (nhatot `region_v2=7044`); the enabled Province row is Khánh Hòa.
- Province search must include sub-cities: a Thủ Đức listing is tagged `province=Hồ Chí Minh` — verify this in #7/#8 tests.

## Suggested skills

- **`tdd`** — red-green-refactor for each issue (matches the strict testing rules).
- **`github`** — PR creation, stacked-PR bases, CI status checks via `gh`.
- **`verify`** — after a slice, confirm the fetch→store→read path actually works (esp. #3).
- **`to-test-cases`** — optional, to derive per-flow test cases from the spec before implementing.
- **`code-review`** / **`security-review`** — before marking PRs ready.

## State

- No application code yet — repo holds docs only (`CONTEXT.md`, `docs/{adr,specs,agents}`, `CLAUDE.md`). #1 scaffolds the Rails app.
- Memory updated: see `project-bds-radar` and `parse-before-implement-rule` in auto-memory.
