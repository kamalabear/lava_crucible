## Overview: minetest_lava_crucible

### Files in the mod
- init.lua
- crucible.lua
- metal_dust.lua
- mod.conf
- `textures/lava_soil.png`
- `textures/crucible_top.png`
- `textures/crucible_top_hot.png` (animated, 16 frames)
- `textures/crucible_top_hot_empty.png`
- `textures/crucible_top_hot_done.png`
- `textures/crucible_bottom.png`, `crucible_bottom_hot.png`
- `textures/crucible_side.png`, `crucible_side_hot.png`
- `.git/`, `.gitignore`, `LICENSE`
- README.md

---

## What the mod does

### init.lua
- Loads the two main scripts:
  - crucible.lua
  - metal_dust.lua

### mod.conf
- Mod metadata:
  - `name = minetest_lava_crucible`
  - `display_name = Lava Crucible`
  - `description = Adds a crucible that can be used to melt down minerals over lava.`
  - `optional_depends = moreores`

### metal_dust.lua
- Registers a craft item:
  - `minetest_lava_crucible:copper_dust`
- Adds:
  - shapeless recipe: `default:copper_lump` -> `copper_dust`
  - cooking recipe: `default:copper_ingot` -> `default:copper_lump`
- If `moreores` mod is present:
  - Registers additional dusts: `tin_dust`, `silver_dust`, `mithril_dust`
  - Adds shapeless recipes for each: `moreores:<metal>_lump` -> `<metal>_dust`
  - Adds cooking recipes: `moreores:<metal>_ingot` -> `moreores:<metal>_lump`

### crucible.lua
- Registers five nodes:
  - `minetest_lava_crucible:lava_soil`
  - `minetest_lava_crucible:lava_crucible` (cold)
  - `minetest_lava_crucible:lava_crucible_hot` (lava adjacent, input has items)
  - `minetest_lava_crucible:lava_crucible_hot_done` (lava adjacent, input empty, output has items)
  - `minetest_lava_crucible:lava_crucible_hot_empty` (lava adjacent, fully empty)

#### `lava_soil`
- Animated tile texture `lava_soil.png`
- Belongs to group `cracky = 1`
- Stack size: 99

#### `lava_crucible` (and hot variants)
- Custom node box shape representing a crucible
- Has two internal inventory lists:
  - `input` (size 1) - for stone items to be processed
  - `output` (size 4) - for processed lava_soil
- Inventory callbacks prevent putting items into the output slot
- `on_construct` initializes metadata and both inventory lists
- `on_rightclick` opens a GUI formspec showing:
  - Input slot
  - Output row (4 slots)
  - Player inventory for easy item transfer
- `on_punch`:
  - if the player is holding any item in group `stone`
  - adds the stone to the input slot (up to stack capacity)
  - removes the stone from the player's inventory
  - provides feedback if input slot is full

#### Node states
The crucible automatically swaps between four visual states:
| State | Condition |
|---|---|
| `lava_crucible` | no adjacent lava — cold, dark texture |
| `lava_crucible_hot` | lava adjacent + input has items — animated boiling lava top, `light_source=10` |
| `lava_crucible_hot_done` | lava adjacent + input empty + output has items — pixelated lava soil top with mineral particles, `light_source=7` |
| `lava_crucible_hot_empty` | lava adjacent + fully empty — glowing empty basin, `light_source=7` |

#### ABM behavior
- Runs on all four crucible variants every 10 seconds
- Only triggers when the crucible has a lava neighbor:
  - `default:lava_flowing`
  - `default:lava_source`
- Each tick:
  - Checks if input contains stone-group items
  - Converts **one item** from the input to lava_soil
  - Adds that one lava_soil to the output (if space available)
  - If output is full, waits without consuming input
  - Updates the visual state after each conversion

#### Crafting
- Crucible recipe:
  - uses `default:clay_lump` and `group:mineral_dust`
  - output is `minetest_lava_crucible:lava_crucible`

---

## How to use the mod

1. **Craft a crucible** using clay lumps and mineral dust
2. **Place the crucible** adjacent to lava (flowing or source)
3. **Add stone items** by punching the crucible while holding stone or dragging stone items into the input in the GUI
4. **Open the GUI** by right-clicking the crucible to monitor progress
5. **Retrieve processed lava_soil** by dragging from the output slot to your inventory
6. **Conversion happens automatically** every 10 seconds when lava is nearby

---

## Behavior summary

- The mod provides a stone-to-lava_soil transformation system
- Input method: punch crucible with stone items or drag them to the input via GUI
- Processing: **one item converted every 10 seconds** when adjacent to lava; output holds up to 4 stacks
- Output: lava_soil stored in 4 output slots, accessible via GUI
- Visual feedback: crucible top texture changes to reflect current state (cold / processing / done / empty-hot)

---

## Notes and possible issues
- Conversion requires lava adjacency (flowing or source blocks)
- Input slot holds 1 stack (up to 99 items); output holds 4 stacks
- The mod defines `copper_dust` by default; with `moreores` mod installed, additional dusts (`tin_dust`, `silver_dust`, `mithril_dust`) are available
- Conversion logic accepts any item in group `stone`
- Conversion rate: 1 item per 10 seconds

---

## Future enhancement ideas
- When you throw stone in lava (no crucible involved) you sometimes get some mineral dust (randomly selected) that floats to the top of the lava and you can grab
- Add user-locking so no one can steal your stuff
- Add a nether crucible that acts like a nether chest so that each player has their own inventory in the same crucible