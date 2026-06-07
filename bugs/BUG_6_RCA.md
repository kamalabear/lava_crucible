# BUG_6_RCA

Date: 2026-06-07
Status: Open
Severity: Medium

## Summary

Millet and Jute planted on `volcanic_soil:volcanic_soil_tilled` grow for a short time then disappear before the player can harvest them.

## Environment

- OS: Linux
- Mod: `mintest_lava_crucible` (observed during integration testing)
- Related mod: `volcanic_soil` (provides substrate and growth boosts)
- Date observed: 2026-06-06 / 2026-06-07

## Steps To Reproduce

1. Prepare a tilled volcanic soil plot (`volcanic_soil:volcanic_soil_tilled`).
2. Plant Millet or Jute seed on the tilled soil.
3. Wait for the crop to grow (use accelerated tick or observe over time).
4. Observe the plant reach a mature stage and then disappear (no harvestable drop).

## Investigation Performed

- Reviewed `volcanic_soil` source (`volcanic_soil/volcanic_soil.lua`, `volcanic_soil/api.lua`):
  - Growth boost ABMs accelerate crops by restarting timers or advancing growth stages.
  - Soil fertility cycles are consumed on player `dig` of a *mature* crop (on_dignode handler). There is no code in `volcanic_soil` that removes crops automatically.
  - Harvest-cycle filter (`harvest_cycle_allow_patterns` / `deny_patterns`) only controls whether a *dig* counts as consuming soil fertility; it does not remove crops.

- Searched workspace for references to `millet` / `jute` — no matching nodes found in this workspace. This suggests the crops are provided by an external mod (for example `farming`, `farming_plus`, `farming_plus_extras`, or a third-party crop mod).

- Confirmed smoke-test startup for `volcanic_soil` shows no load errors; the issue is runtime/behavioral, not a startup crash.

## Findings (Hypotheses)

Because `volcanic_soil` itself does not actively remove plants, the disappearing crops are likely caused by one of the following:

1. Crop node definitions (from the external crop mod providing Millet/Jute) have incorrect `on_timer` / `on_construct` / `next_plant` values, and an ABM or timer transition sets the node to an undefined node which becomes `air` or otherwise disappears. (Less likely because `volcanic_soil` checks registration before swapping.)

2. Another mod (possibly a compatibility/harvest cleanup mod or farming helper) is running an ABM or on-step check that removes/cleans up nodes it considers invalid on `volcanic_soil` substrate. This could be triggered by name-pattern matching or by a substrate check failing for those particular crops.

3. The crop mod registers stage nodes that are not in the expected name pattern (for example they include suffixes that match `harvest_cycle_deny_patterns`), causing the soil logic or other tooling to treat them as immature or invalid and trigger cleanup elsewhere.

4. Lighting/timer interactions: `volcanic_soil` can `bypass_light_check`. If the crop node's `on_timer` expects light conditions and those are not met, repeated timer restarts may eventually cause the node to revert or be replaced by a fallback node (rare but possible if crop code does that).

5. Player or automation accidentally dig/replace them in the test scenario (unlikely given report phrasing but worth ruling out).

## Required Reproduction Data

To determine the root cause we need the following from the reporter or test harness:

- The exact mod(s) and versions that provide Millet and Jute (node names, e.g. `farming:millet_3` or `some_mod:jute_stage2`).
- A short server log captured while reproducing, ideally with `debug` verbosity, showing ABM/timer activity and any `set_node` or `add_item` lines near the plant positions.
- If possible, a minimal smoke-test fixture that includes the crop-providing mod and steps to reproduce automatically.

## Proposed Next Steps (investigation)

1. Reproduce locally by adding the crop mod to the workspace smoke-test run and exercise the planting/growth cycle. Run the smoke-test with `SMOKE_TEST_WORKSPACE_FIRST_DEPS` including the crop mod, and record the runtime output.

2. When reproducing, enable debug log filtering around node changes near the planted position. Example approach: run the server and tail the debug output while performing the grow/observe steps.

3. Inspect the registered nodes for the crop (in the running server REPL or by printing `minetest.registered_nodes` entry) to verify `on_timer`, `next_plant`, and groups.

4. Search workspace (and the crop mod) for any code that may remove or replace the crop nodes (look for `minetest.remove_node`, `minetest.set_node(<pos>, {name = "air"})`, `minetest.swap_node` with non-registered target, or ABMs that target the crop node names).

5. If the crop mod is external and the removal is intentional due to incompatibility, open an issue/PR against that mod documenting the behavior.

## Proposed Fixes (once cause identified)

- If crop `next_plant` or timer transitions are misconfigured: patch the crop mod to ensure stage progression targets registered node names; add unit tests for stage transitions.
- If a cleanup ABM in another mod is removing crops: adjust its matching logic to exclude the crop nodes or update patterns to be less aggressive; add unit tests to ensure crops on `volcanic_soil` are preserved.
- If volcanic soil settings (allow/deny patterns) need widening: add a configuration or default pattern to include the crop node patterns so they are treated as harvestable and not filtered out.

## Tests

- Add a smoke test fixture combining `volcanic_soil` and the crop provider mod that reproduces the disappearance reliably, to prevent regressions.
- Add unit tests in the crop mod (if possible) to assert stage progression and no unintended node removals when planted on `volcanic_soil`.

## Acceptance Criteria

1. Reproduction steps that capture the disappearance reliably.
2. Identification of the component responsible for removal (crop mod or other mod).
3. Patch to the responsible component with unit tests where possible.
4. Smoke test verifying the crops grow and remain harvestable on `volcanic_soil`.

## Files / Artifacts to Update

- `bugs/BUG_6_RCA.md` (this file)
- `bugs/BUG_REPORT.md` (link to this RCA)
- Tests: smoke fixture under `.github/test-fixtures/` or `volcanic_soil/tests` depending on root cause

## Notes

This RCA is preliminary: additional runtime data and the crop provider identifiers are required to pinpoint the exact cause. Once the reporter provides the crop mod name (or a repro fixture), I can reproduce and produce a definitive root cause and patch.
