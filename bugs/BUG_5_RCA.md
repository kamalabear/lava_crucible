# BUG 5 RCA — Drop-In Feature Is Undocumented

Date: 2026-06-03
Status: Open (moved from BUG_REPORT.md)

## Summary

The project implements a drop-in mechanic that automatically collects valid stone item entities dropped slightly above a crucible and inserts them into the crucible's `input` inventory when space exists. This behaviour was not documented in `USAGE.md`, causing the discovery to be accidental during testing.

## Root Cause

Documentation lag: the feature was implemented in code but documentation was not updated to reflect the new behaviour.

## Evidence

- The function `collect_dropped_stone(pos)` in `crucible.lua` iterates nearby object entities (via `minetest.get_objects_inside_radius`) and, for any `__builtin:item` with a stone-group itemname (or compressed stone), attempts to `inv:add_item("input", stack)` and remove or update the entity accordingly.
- An ABM registered at the end of `crucible.lua` runs every second (`interval = 1`) and calls `collect_dropped_stone(pos)` for non-ender crucibles, enabling the observed drop-in behaviour.

## Impact

- Low severity: the feature is useful and works correctly, but users are unlikely to discover it without documentation.

## Resolution / Proposed Fix

1. Documentation update: add a short entry to `USAGE.md` (and optionally `README.md`) describing the drop-in mechanic. Suggested wording:

   - "Drop stone-group items directly above a placed crucible to automatically add them to the input slot (requires input slot space). Supports regular stone-group items and `_compressed` variants. Items are collected by the crucible ABM and will be inserted within ~1s."

2. Optional: add a one-line code comment above `collect_dropped_stone` in `crucible.lua` referencing the docs, e.g., "-- See BUG_5_RCA.md / USAGE.md: ABM-driven drop-in behaviour collects item entities above crucibles."

3. Create a small docs-only commit that inserts the new note under "Feeding Items to Crucible" or the "Getting started" section in `USAGE.md` and reference this bug number.

## Acceptance Criteria

1. `USAGE.md` includes the drop-in mechanic note and an example usage.
2. `README.md` references the user guide (already points to `USAGE.md`) so users can find it.
3. Manual verification: dropping a stone item entity just above an empty-input crucible results in the item being moved into the input inventory within ~1 second.

## Action Items

- Apply a documentation patch to `USAGE.md` adding the suggested wording (low-effort).  
- Optionally add the brief code comment in `crucible.lua` to make the behavior easier to find for maintainers.

---

Moved from: `bugs/BUG_REPORT.md`
