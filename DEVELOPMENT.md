# Lava Crucible — Developer's Guide

## File structure

| File | Purpose |
|---|---|
| `init.lua` | Entry point — loads `crucible.lua` then `metal_dust.lua` |
| `crucible.lua` | All node definitions, inventory logic, state machine, ABM, node timer, formspecs, and recipes |
| `metal_dust.lua` | Stub file — dust items were moved to the `ore_dust` mod |
| `mod.conf` | Mod name, display name, description, `depends`, `optional_depends` |
| `settingtypes.txt` | Exposes `lava_crucible_conversion_interval` and `lava_crucible_dust_chance` to the Minetest settings UI |
| `textures/` | All crucible textures (cold/hot/done/empty variants, animated top). Lava soil texture is provided by the `volcanic_soil` mod. |

**Companion mod:** `ore_dust` (separate repository) — defines all `ore_dust:*_dust` items and their crafting recipes. This mod declares `depends = ore_dust` in `mod.conf`.

**Soil mod:** `volcanic_soil` — defines the lava soil node (`volcanic_soil:volcanic_soil`) that is output by the crucible when it processes stone. The crucible declares `depends = volcanic_soil` in `mod.conf`.

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

## Dust and Lump Discovery System

At mod load finalization (`minetest.register_on_mods_loaded()`), lava_crucible automatically **discovers and registers all available dusts and lumps**:

1. **Discovery Phase:**
   - Scans both `minetest.registered_items` and `minetest.registered_nodes` (some dusts register as nodes)
   - Collects all items with names ending in `_dust` or `_lump`
   - Extracts material name: `itemname:gsub("_dust$", ""):match("[^_:]*$")` → e.g., `ore_dust:copper_dust` → `"copper"`

2. **Weight Assignment:**
   - Uses a material lookup table with sensible rarity-based defaults:
     - Common: copper (30), iron (40), coal (18), tin (20)
     - Rare: gold (8), silver (5), mithril (2), diamond (1)
     - Unknown materials: default weight (10)

3. **Registration Validation (Two-Layer Defense):**
   - **Registration-time check:** `register_dust_bonus()` validates item is registered before adding to pool
   - **Selection-time check:** `pick_random_dust()` and `pick_random_lump()` verify items before returning (prevents selection of unregistered items even if they somehow enter the pool)
   - Unregistered items are silently skipped with a debug warning

4. **Automatic Slot Expansion:**
   - Input/output inventory slots are sized based on `#dust_table` and `#lump_table` at node construction
   - New dusts discovered → new slots automatically appear on new crucibles

**Benefits of Dynamic Discovery:**
- ✅ Works with ANY mod that registers dusts (no hardcoding needed)
- ✅ No version compatibility issues (unregistered items just skipped)
- ✅ Two-layer validation prevents "Unknown Item" rendering
- ✅ Automatically weights materials by rarity
- ✅ Extensible: compatible mods just register items ending in `_dust` or `_lump`

**Example Discovery:**
- `ore_dust` mod registers: `ore_dust:copper_dust`, `ore_dust:tin_dust`, etc.
- `technic` mod registers: `technic:coal_dust`, `technic:copper_dust`, etc.
- Lava crucible discovers all of them and assigns appropriate weights
- Pool automatically includes dusts from any mod that follows the naming convention

---

## `dust_table` and adding new dusts

`dust_table` is populated via `discover_and_register_dusts()` at mod load time, which:
1. Automatically discovers all items ending in `_dust`
2. Calls `lava_crucible.register_dust_bonus()` for each with auto-determined weight

Manual registration is also supported for custom behavior:

```lua
-- Automatic discovery (built-in):
-- Runs in register_on_mods_loaded(), discovers all _dust items

-- Manual registration (optional, for advanced use):
lava_crucible.register_dust_bonus("ore_dust:iron_dust", 40)
lava_crucible.register_dust_bonus("technic:lead_dust", 16, {
    grant_mineral_dust_group = true,
})
```

The helper deduplicates by item name, so re-registering an existing item updates its weight instead of creating an extra output slot.

If `grant_mineral_dust_group = true` is passed, the item receives `mineral_dust = 1` group for compatibility checking.

Dust slot counts across all tiers are calculated from `#dust_table` at construction time, so they expand automatically when new entries are discovered.

Compressed stones use a parallel system (`lump_table` and `pick_random_lump()`) for bonus outputs instead of dusts.

Current compressed stone rule:
- Input item: Any item with `_compressed` in the name (e.g., `moreblocks:cobble_compressed`)
- Soil yield: 9 per item
- Bonus chance: same `lava_crucible_dust_chance`
- Bonus pool: Automatically discovered from items ending in `_lump` (e.g., `default:iron_lump`, `default:copper_lump`, `default:gold_lump`, `default:diamond_lump`)

---

## `ore_dust` mod relationship

The `ore_dust` mod (companion repository: `kamalabear/ore_dust`) owns all `ore_dust:*` dust item definitions and their 9-dust-to-ingot crafting recipes. This mod declares `depends = ore_dust`. The `metal_dust.lua` file in this mod is a stub left for historical reference.

Technic dust definitions remain owned by `technic`; lava_crucible only consumes those item names in its weighted output pool and selectively adds the `mineral_dust` group for compatibility.

---

## Future enhancement ideas

- **Lava-throw dust:** when stone is thrown directly into lava (no crucible), occasionally spawn a mineral dust item that floats to the surface for the player to grab
- **More ore likelihood from compressed stone:** 
- **Slow heating:** Crucibles should heat up slowly, not instantly
- **Longer bake time:** The raw crucible bakes very quickly - it should take longer to be done.
- **Document multi-user usage:** Add explanation to USAGE.md of how multiple users can use the different types of crucibles
- **Remove hot crucibles from catalog:**
- **Add sounds**
- **Make crucible types more visually distinct**
- **Recover crucible material:** Allow crucibles to be pulverized into clay graphite dust that can be reconstituted into clay graphite.
- **Make ore_dust optional**
- **GUI fix:** Align input and output in crucible GUI for a cleaner appearance.
- **Dust from compressed stone:** Two options - 1) Add dust, as well as nuggets, to compressed stone drops OR 2) Compressed stone drops dust instead of nuggets, just in greater quantities. POSSIBLE EXTENSION - types of drops are configurable.
- **Melt dust into nuggets:** The crucible must be used to create nuggets from dust.  Dust must be collected in a glass bottle and put back in the crucible to produce an ore bar (and an empty bottle).
- **Replace nuggets with bars**
- **Compresed stone only in Large:**
- **Crucibles are not destroyed by lava:** When trying to move a crucible, hitting it with a pickaxe results in the crucible falling into the lava below it and being destroyed.  Instead, loose crucibles should float on lava.
