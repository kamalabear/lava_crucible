# Lava Crucible — Agent Guidelines

## Architecture

A Minetest Lua mod. Entry point is `init.lua`; all logic lives in `crucible.lua`. See [DEVELOPMENT.md](DEVELOPMENT.md) for the full developer reference: node naming conventions, state machine, conversion pipeline, inventory system, crafting chain, and owner system.

**Companion mod:** `ore_dust` (repo: `kamalabear/ore_dust`) owns all `ore_dust:*_dust` item definitions. This mod declares `depends = ore_dust` and expects those items to exist. Changes that add new dust types must be made in `ore_dust`, not here.

## Build and Test

No automated test suite. Validate changes by loading the mod in Minetest and exercising the relevant behavior in-game:

1. Edit the mod files.
2. Launch (or restart) Minetest with a world that has this mod active.
3. Exercise the changed behavior manually — craft, place, observe conversions, check inventory.

Use Minetest's built-in `/lua` command or `minetest.log` calls for quick in-game debugging.

## Conventions

**Documentation:** After every change, review and update [DEVELOPMENT.md](DEVELOPMENT.md), [USAGE.md](USAGE.md), and [README.md](README.md) as needed. These three files are the canonical references for developers and users respectively.

**Settings:** Any new config knob must be registered in `settingtypes.txt` and documented in [USAGE.md](USAGE.md).

**`metal_dust.lua`:** This file is a no-op stub kept for historical reference. Do not add logic to it; dust items belong in the `ore_dust` companion mod.

**Node naming:** Follow the pattern `lava_crucible:lava_crucible[_ender][_<tier>][_<state>]`. See [DEVELOPMENT.md § Node naming conventions](DEVELOPMENT.md) before adding node variants.

**Dust table extensions:** To support a new optional mod's dusts, append entries to `dust_table` inside a `minetest.get_modpath("<mod>")` guard, mirroring the existing `moreores` block.

**State machine:** All visual state transitions go through `update_crucible_state(pos)` — do not call `minetest.swap_node` directly.
