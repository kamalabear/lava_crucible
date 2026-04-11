# Lava Crucible — Developer's Guide

## File structure

| File | Purpose |
|---|---|
| `init.lua` | Entry point — loads `crucible.lua` then `metal_dust.lua` |
| `crucible.lua` | All node definitions, inventory logic, state machine, ABM, node timer, formspecs, and recipes |
| `metal_dust.lua` | Stub file — dust items were moved to the `ore_dust` mod |
| `mod.conf` | Mod name, display name, description, `depends`, `optional_depends` |
| `settingtypes.txt` | Exposes `lava_crucible_conversion_interval` and `lava_crucible_dust_chance` to the Minetest settings UI |
| `textures/` | All crucible and lava soil textures (cold/hot/done/empty variants, animated top) |

**Companion mod:** `ore_dust` (separate repository) — defines all `ore_dust:*_dust` items and their crafting recipes. This mod declares `depends = ore_dust` in `mod.conf`.

**Optional integration:** `technic` can extend the crucible dust pool with selected ore-like technic dusts. Lava Crucible adds `mineral_dust = 1` to those selected technic items via `minetest.override_item()` at mod-load finalization time.

---

## Crafting items and chain

Raw materials and intermediates are a mix of craftitems and nodes. The full chain:

| Item | Registered name | How obtained |
|---|---|---|
| Clay Graphite (craftitem) | `lava_crucible:clay_graphite` | Shapeless: `clay_lump` + `coal_lump` → 1× |
| Obsidian Clay (craftitem) | `lava_crucible:obsidian_clay` | Shapeless: `clay_lump` + `ore_dust:obsidian_dust` → 1× |
| Uncured Crucible (node) | `lava_crucible:uncured_crucible` | Cup shape (5×) of `clay_graphite` |
| Uncured Ender Crucible (node) | `lava_crucible:uncured_ender_crucible` | Cup shape (5×) of `obsidian_clay` |
| Uncured Double Crucible (node) | `lava_crucible:uncured_double_crucible` | Cup shape (5×) of `uncured_crucible` |
| Uncured Double Ender Crucible (node) | `lava_crucible:uncured_ender_double_crucible` | Cup shape (5×) of `uncured_ender_crucible` |
| Uncured Quad Crucible (node) | `lava_crucible:uncured_quad_crucible` | Cup shape (5×) of `uncured_double_crucible` |
| Uncured Quad Ender Crucible (node) | `lava_crucible:uncured_ender_quad_crucible` | Cup shape (5×) of `uncured_ender_double_crucible` |

Each uncured item is then cooked in a furnace to produce the corresponding node:

| Input | Output | Cook time |
|---|---|---|
| `uncured_crucible` | `lava_crucible` | 15 s |
| `uncured_ender_crucible` | `lava_crucible_ender` | 15 s |
| `uncured_double_crucible` | `lava_crucible_double` | 20 s |
| `uncured_ender_double_crucible` | `lava_crucible_ender_double` | 20 s |
| `uncured_quad_crucible` | `lava_crucible_quad` | 25 s |
| `uncured_ender_quad_crucible` | `lava_crucible_ender_quad` | 25 s |

The **cup shape** used for all three uncured recipes:

```
item  ·     item
item  ·     item
·     item  ·
```

Uncured node textures: `crucible_uncured_top.png`, `crucible_uncured_side.png`, `crucible_uncured_bottom.png`.

---

## Node naming conventions

All crucible nodes follow the pattern:

```
lava_crucible:lava_crucible[_ender][_<tier>][_<state>]
```

Ender variants insert `_ender` before the tier suffix. The double and quad ender variants use `lava_crucible:lava_crucible_ender_double` and `lava_crucible:lava_crucible_ender_quad` plus the same state suffixes.

Ender visuals use the nearest player's per-player ender inventory to drive the four visual stages. Each player has an independent detached inventory (name `lava_crucible:ender_<tier>_<player>` for double/quad, `lava_crucible:ender_<player>` for single) that is persistent across sessions via `mod_storage`.

| Tier suffix | Tier |
|---|---|
| *(none)* | Single |
| `_double` | Double |
| `_quad` | Quad |

Ender tiers combine both prefixes: `_ender`, `_ender_double`, `_ender_quad`.

| State suffix | Condition |
|---|---|
| *(none)* | Cold — no adjacent lava |
| `_hot` | Hot, input present |
| `_hot_empty` | Hot, input and output both empty |
| `_hot_done` | Hot, input empty but output has items |

Examples: `lava_crucible_hot`, `lava_crucible_double_hot_empty`, `lava_crucible_quad_hot_done`, `lava_crucible_ender_double_hot`, `lava_crucible_ender_quad_hot_done`.

---

## Node box system

Node boxes are defined as lists of `{x1, y1, z1, x2, y2, z2}` cuboids. Three base shapes exist, one per tier:

| Variable | Tier | Wall top (y) |
|---|---|---|
| `cbox` | Single | `0.0` (half height) |
| `cbox_double` | Double | `0.25` (three-quarter height) |
| `cbox_quad` | Quad | `0.5` (full height) |

Each shape consists of a bottom slab plus four inner walls (thickness 0.1 units, inner bounds ±0.4).

**Filled variants** (`cbox_filled`, `cbox_double_filled`, `cbox_quad_filled`) add a fill slab just below the wall top. These are assigned to the `_hot` (has-input) node variants only, providing visual feedback that the crucible is loaded.

`crucible_common` sets `drawtype = "nodebox"` and `paramtype = "light"`. Tier-specific commons (`crucible_double_common`, `crucible_quad_common`) override `node_box` immediately after cloning.

---

## Inventory lists

Every crucible node has three inventory lists, sized at construction via `on_construct`:

| List | Single size | Double size | Quad size | Writable by player? |
|---|---|---|---|---|
| `input` | 1 | 2 | 4 | Yes (owner / ender: any player) |
| `soil_output` | 1 | 2 | 4 | Take only |
| `dust_output` | `#dust_table` | `#dust_table × 2` | `#dust_table × 4` | Take only |

For **regular** crucibles, `allow_metadata_inventory_put` blocks puts into `soil_output` and `dust_output` entirely, and all three `allow_*` callbacks also block non-owners.

For **ender** crucibles, inventories are **detached** (not node-meta) — one per player per tier: `lava_crucible:ender_<player>` (single), `lava_crucible:ender_double_<player>` (double), `lava_crucible:ender_quad_<player>` (quad). On_put/on_take/on_move callbacks persist changes to `mod_storage`. There is no owner lock — any player can open any ender crucible to access their own inventory.

---

## State machine

`update_crucible_state(pos)` maps each crucible's current condition to the correct node name and calls `minetest.swap_node` if a change is needed.

```
has adjacent lava?
  no  → prefix (cold)
  yes →
    input has items?     → prefix .. "_hot"
    output has items?    → prefix .. "_hot_done"
    otherwise            → prefix .. "_hot_empty"
```

The prefix is derived from the current node name:
- contains `lava_crucible_ender_quad` → `lava_crucible:lava_crucible_ender_quad`
- contains `lava_crucible_ender_double` → `lava_crucible:lava_crucible_ender_double`
- contains `lava_crucible_ender` (single) → `lava_crucible:lava_crucible_ender`
- contains `_quad` → `lava_crucible:lava_crucible_quad`
- contains `_double` → `lava_crucible:lava_crucible_double`
- otherwise → `lava_crucible:lava_crucible`

`crucible_input_empty(meta)` iterates all input slots. `crucible_output_has_items(meta)` iterates all soil and dust slots. Both are slot-count-agnostic and work across all tiers.

---

## Conversion pipeline

Conversion is driven by a **node timer**, not the ABM. The ABM's sole role is state detection and timer bootstrapping.

### Node timer (`on_timer`)

Defined in `crucible_common` for the single tier; overridden in `crucible_double_common` and `crucible_quad_common` for higher tiers.

Each tick:
1. If no adjacent lava → return `false` (stop timer)
2. For each input slot (1 slot for single, 2 for double, 4 for quad):
   - Skip if slot is empty or item is unsupported
   - If item name contains `_compressed` (e.g., `moreblocks:cobble_compressed`, `moreblocks:desert_cobble_compressed`):
     - Attempt to add `lava_soil 9`
     - On success: consume 1 compressed stone item, roll lump bonus
   - Else if item is in group `stone`:
     - Attempt to add `lava_soil 1`
     - On success: consume 1 stone item, roll dust bonus
3. Call `update_crucible_state(pos)`
4. Return `true` if any input slot still has items, `false` otherwise (stops timer)

If `soil_output` is full for every slot, the timer keeps firing (returns `true`) but no input is consumed.

The shared helper `process_input_stack(inv, slot)` handles all per-item conversion logic and is used by single/double/quad timers.

### Timer start rules

The timer is started (`timer:start(conversion_interval)`) only when `not timer:is_started()`, preserving the delay for any already-running conversion. It is started in three places:

| Where | Trigger |
|---|---|
| `on_punch` | Player adds stone via punch, lava is adjacent |
| `on_metadata_inventory_put` | Player drags stone into `input` via GUI, lava is adjacent |
| ABM `action` | Lava appears next to a crucible that already has input |

Dropped item entities are also handled by a second ABM (`interval=1`) via `collect_dropped_stone(pos)`, which pulls valid input items lying above the crucible into `input` if space is available.

### ABM

Runs every `conversion_interval` seconds on all **24** crucible node variants (4 states × 6 node types: single, ender-single, double, ender-double, quad, ender-quad). Its action:
1. Calls `update_crucible_state(pos)`
2. If `not crucible_input_empty(meta)` and timer not started → starts timer

This handles the case where lava is placed next to a pre-loaded crucible.

---

## Owner system

The placing player's name is stored as `meta:set_string("owner", name)` in `after_place_node`. The infotext is updated to `"<Tier> Lava Crucible (owned by <name>)"`.

Ownership is checked (as `owner ~= "" and player:get_player_name() ~= owner`) in:
- `allow_metadata_inventory_move`
- `allow_metadata_inventory_put`
- `allow_metadata_inventory_take`
- `on_punch`
- `on_rightclick`

Crucibles with an empty owner string (e.g. placed before this feature or by non-player entities) are accessible by anyone.

---

## `dust_table` and adding new dusts

`dust_table` remains the runtime source of truth, but new entries are now registered through the public helper `lava_crucible.register_dust_bonus(itemname, weight, options)`.

```lua
lava_crucible.register_dust_bonus("ore_dust:iron_dust", 40)
lava_crucible.register_dust_bonus("technic:lead_dust", 16, {
    grant_mineral_dust_group = true,
})
```

Weights are relative — a weight of 40 against a total of 79 gives roughly a 50% chance. Register all dust entries during mod load, then `lava_crucible` recomputes `dust_total_weight` in `register_on_mods_loaded()` after optional integrations have finished registering their items.

The helper deduplicates by item name, so re-registering an existing item updates its weight instead of creating an extra output slot.

If `moreores` is present, tin/silver/mithril entries are appended at load time. If `technic` is present, lava_crucible adds a curated set of non-alloy technic dusts and can mark those items with `mineral_dust = 1` by passing `grant_mineral_dust_group = true`.

Dust slot counts across all tiers are calculated from `#dust_table` at construction time, so they expand automatically when new entries are added.

There is currently no internal lava_crucible crafting recipe that uses `group:mineral_dust`; `lava_crucible:obsidian_clay` intentionally remains tied to `ore_dust:obsidian_dust`.

Compressed stones use a parallel weighted table (`lump_table`) and `pick_random_lump()` for bonus outputs instead of dusts.

Current compressed stone rule:
- Input item: Any item with `_compressed` in the name (e.g., `moreblocks:cobble_compressed`, `moreblocks:desert_cobble_compressed`)
- Soil yield: 9 per item
- Bonus chance: same `lava_crucible_dust_chance`
- Bonus pool: `default:iron_lump`, `default:copper_lump`, `default:gold_lump`, rare `default:diamond`, and optional `moreores` lumps

---

## `ore_dust` mod relationship

The `ore_dust` mod (companion repository: `kamalabear/ore_dust`) owns all `ore_dust:*` dust item definitions and their 9-dust-to-ingot crafting recipes. This mod declares `depends = ore_dust`. The `metal_dust.lua` file in this mod is a stub left for historical reference.

Technic dust definitions remain owned by `technic`; lava_crucible only consumes those item names in its weighted output pool and selectively adds the `mineral_dust` group for compatibility.

---

## Future enhancement ideas

- **Lava-throw dust:** when stone is thrown directly into lava (no crucible), occasionally spawn a mineral dust item that floats to the surface for the player to grab
