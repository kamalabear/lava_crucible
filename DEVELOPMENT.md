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

---

## Crafting items and chain

All crafted items are registered as `craftitem` (not nodes). The full chain:

| Item | Registered name | How obtained |
|---|---|---|
| Clay Graphite | `lava_crucible:clay_graphite` | Shapeless: `clay_lump` + `coal_lump` → 2× |
| Uncured Crucible | `lava_crucible:uncured_crucible` | Cup shape (5×) of `clay_graphite` |
| Uncured Double Crucible | `lava_crucible:uncured_double_crucible` | Cup shape (5×) of `uncured_crucible` |
| Uncured Quad Crucible | `lava_crucible:uncured_quad_crucible` | Cup shape (5×) of `uncured_double_crucible` |

Each uncured item is then cooked in a furnace to produce the corresponding node:

| Input | Output | Cook time |
|---|---|---|
| `uncured_crucible` | `lava_crucible` | 15 s |
| `uncured_double_crucible` | `lava_crucible_double` | 20 s |
| `uncured_quad_crucible` | `lava_crucible_quad` | 25 s |

The **cup shape** used for all three uncured recipes:

```
item  ·     item
item  ·     item
·     item  ·
```

Inventory images: `clay_graphite.png`, `uncured_crucible.png` (shared by all three uncured items — distinct art can be added later).

---

## Node naming conventions

All crucible nodes follow the pattern:

```
lava_crucible:lava_crucible[_<tier>][_<state>]
```

| Tier suffix | Tier |
|---|---|
| *(none)* | Single |
| `_double` | Double |
| `_quad` | Quad |

| State suffix | Condition |
|---|---|
| *(none)* | Cold — no adjacent lava |
| `_hot` | Hot, input present |
| `_hot_empty` | Hot, input and output both empty |
| `_hot_done` | Hot, input empty but output has items |

Examples: `lava_crucible_hot`, `lava_crucible_double_hot_empty`, `lava_crucible_quad_hot_done`.

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
| `input` | 1 | 2 | 4 | Yes (owner only) |
| `soil_output` | 1 | 2 | 4 | Take only (owner only) |
| `dust_output` | `#dust_table` | `#dust_table × 2` | `#dust_table × 4` | Take only (owner only) |

`allow_metadata_inventory_put` blocks puts into `soil_output` and `dust_output` entirely. All three `allow_*` callbacks also block non-owners from making any inventory change.

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
   - Skip if slot is empty or item is not in group `stone`
   - Attempt `inv:add_item("soil_output", lava_soil 1)` — skip this slot if soil output is full
   - On success: remove 1 item from input, roll for dust bonus
3. Call `update_crucible_state(pos)`
4. Return `true` if any input slot still has items, `false` otherwise (stops timer)

If `soil_output` is full for every slot, the timer keeps firing (returns `true`) but no input is consumed.

### Timer start rules

The timer is started (`timer:start(conversion_interval)`) only when `not timer:is_started()`, preserving the delay for any already-running conversion. It is started in three places:

| Where | Trigger |
|---|---|
| `on_punch` | Player adds stone via punch, lava is adjacent |
| `on_metadata_inventory_put` | Player drags stone into `input` via GUI, lava is adjacent |
| ABM `action` | Lava appears next to a crucible that already has input |

### ABM

Runs every `conversion_interval` seconds on all 12 crucible node variants. Its action:
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

```lua
local dust_table = {
    {item = "ore_dust:iron_dust",    weight = 40},
    {item = "ore_dust:copper_dust",  weight = 30},
    ...
}
```

Weights are relative — a weight of 40 against a total of 79 gives roughly a 50% chance. To add a new dust, insert a new `{item, weight}` entry. The `dust_total_weight` accumulator and `pick_random_dust()` function handle the rest automatically.

If `moreores` is present, tin/silver/mithril entries are appended at load time. The dust slot counts across all tiers are calculated from `#dust_table` at construction, so they expand automatically when new entries are added.

Items in the `ore_dust` mod belong to group `mineral_dust = 1`, which is also required by the crucible crafting recipe (`group:mineral_dust`).

---

## `ore_dust` mod relationship

The `ore_dust` mod (companion repository: `kamalabear/ore_dust`) owns all dust item definitions and their 9-dust-to-ingot crafting recipes. This mod declares `depends = ore_dust`. The `metal_dust.lua` file in this mod is a stub left for historical reference.

---

## Future enhancement ideas

- **Lava-throw dust:** when stone is thrown directly into lava (no crucible), occasionally spawn a mineral dust item that floats to the surface for the player to grab
- **Nether crucible:** acts like a nether chest — each player has their own private inventory in the same physical node
- **Compressed stone support:** processing compressed stone generates nuggets or shards instead of dust
- **Support dropping stone into the crucible**