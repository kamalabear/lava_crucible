# BUG 1 RCA — Hot Crucibles Placeable Without Lava

Date: 2026-06-07
Status: Open (RCA created)

## Summary

Hot/done-state crucible nodes (for example `lava_crucible:lava_crucible_hot`) can be placed by players (for example via creative `/giveme`) and remain visually "hot" even when no adjacent lava is present. This is a cosmetic inconsistency and may confuse players and automation that inspects node states.

## Root Cause

All visual state variants of crucibles (cold, hot, hot_empty, hot_done — and ender equivalents) are fully registered as placeable nodes. There is no defensive placement-time validation to ensure a placed node reflects the actual environment (adjacent lava). The state-machine function `update_crucible_state(pos)` performs swaps during runtime, but it is not invoked automatically to correct externally placed hot-state nodes immediately upon placement.

Key observations:
- `crucible.lua` registers the base and state nodes explicitly: `lava_crucible:lava_crucible`, `lava_crucible:lava_crucible_hot`, `lava_crucible:lava_crucible_hot_empty`, `lava_crucible:lava_crucible_hot_done` (and ender variants). These nodes are created by cloning `crucible_common` and thus are accessible in creative inventory unless explicitly hidden.
- `crucible_common.after_place_node` sets owner/infotext but does not call `update_crucible_state(pos)` to normalize state on placement.
- The `update_crucible_state(pos)` function exists and maps runtime conditions to the appropriate node variants, but relies on ABMs, timers, or other events to run — it does not automatically run at the moment a player places a node into the world.

## Evidence

- Node registrations near [crucible.lua:954-1000] register `lava_crucible:lava_crucible` and `lava_crucible:lava_crucible_hot*` variants.
- `crucible_common.after_place_node` (in the `crucible_common` table) sets ownership and infotext but does not call `update_crucible_state(pos)`.
- The ABM and timers will eventually correct a misplaced hot node if the state machine runs, but the immediate misplacement remains and can be exploited via creative or `/giveme` commands.

## Impact

- Severity: Medium (cosmetic/confusing; may affect systems that scan for hot-state nodes).  
- User effect: Players can place visually-hot crucibles without lava; this can mislead players about functionality and processing state.

## Proposed Resolution Options

Option A (Recommended): Prevent hot-state nodes from being placeable and normalize on placement

- Set `groups.not_in_creative_inventory = 1` for all internal state variants (`*_hot`, `*_hot_empty`, `*_hot_done`) so they do not appear in creative inventory.  
- Update `crucible_common.after_place_node` (or add `on_place`) to call `update_crucible_state(pos)` immediately after placement so any externally placed node will be normalized to the correct base/cold/hot variant based on adjacent lava.

Option B: Allow registration but enforce placement-time validation

- Keep nodes registered but implement `on_place`/`after_place_node` logic that checks `has_adjacent_lava(pos)` and replaces the node with the appropriate variant (or swap to cold) if conditions don't match.  
- Log a debug message when normalization occurs for easier QA.

Option C: Make state nodes unplaceable (less compatible)

- Register state nodes with `node_box` and `walkable` but do not expose them to players and ensure `drop` resolves to the base item. This is stricter and may have edge-case compatibility consequences for map editors and legacy worlds — use only if A/B are insufficient.

## Acceptance Criteria

1. Hot/done state nodes do not appear in creative inventory.  
2. If a hot node is placed (via `/giveme` or creative), it is normalized immediately to the correct node for the environment (either swapped to cold or run `update_crucible_state(pos)` so the next ABM/tick reflects the correct state).  
3. Unit or integration test demonstrating placement normalization passes.  

## Action Items

1. Implement the recommended fix (Option A) — add `groups.not_in_creative_inventory = 1` to hot-state node definitions and call `update_crucible_state(pos)` from `crucible_common.after_place_node` (or `on_place`).  
2. Add a unit test to verify that placing `lava_crucible:lava_crucible_hot` in creative results in the node being normalized (converted) to the appropriate variant when no adjacent lava exists.  
3. Add a short entry to `BUG_REPORT.md` referencing this RCA and the PR that implements the fix.

---

Prepared by: Copilot — Investigation on 2026-06-07
