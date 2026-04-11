## Overview: minetest_lava_crucible

### Files in the mod
- init.lua
- crucible.lua
- metal_dust.lua
- mod.conf
- `textures/lava_soil.png`
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
- Registers two nodes:
  - `minetest_lava_crucible:lava_soil`
  - `minetest_lava_crucible:lava_crucible`

#### `lava_soil`
- Animated tile texture `lava_soil.png`
- Belongs to group `cracky = 1`
- Stack size: 99

#### `lava_crucible`
- Custom node box shape representing a crucible
- Has two internal inventory slots:
  - `input` (size 1) - for stone items to be processed
  - `output` (size 1) - for processed lava_soil
- Inventory callbacks allow moving, putting, and taking items
- `on_construct` initializes metadata and both inventory slots
- `on_rightclick` opens a GUI formspec showing:
  - Input slot with visual background
  - Output slot with visual background
  - Player inventory for easy item transfer
- `on_punch`:
  - if the player is holding any item in group `stone`
  - adds the stone to the input slot (up to stack capacity)
  - removes the stone from the player's inventory
  - provides feedback if input slot is full

#### ABM behavior
- An ABM runs on `minetest_lava_crucible:lava_crucible` every 10 seconds
- Only triggers when the crucible has a lava neighbor:
  - `default:lava_flowing`
  - `default:lava_source`
- Reads from the `input` slot:
  - Checks if input contains stone-group items
  - Checks if output slot is empty
  - Converts all stone items to lava_soil (1:1 ratio)
  - Moves converted items to output slot
  - Clears input slot
- Logs conversion actions

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
- Processing: automatic conversion when adjacent to lava
- Output: lava_soil stored in output slot, accessible via GUI
- GUI provides visual feedback and easy item management

---

## Notes and possible issues
- Conversion requires lava adjacency (flowing or source blocks)
- Input and output slots are limited to 1 stack each (99 items max)
- The mod defines `copper_dust` by default; with `moreores` mod installed, additional dusts (`tin_dust`, `silver_dust`, `mithril_dust`) are available
- Conversion logic accepts any item in group `stone`

---

## Future enhancement ideas
- When you throw stone in lava (no crucible involved) you sometimes get some mineral dust (randomly selected) that floats to the top of the lava and you can grab
- Add user-locking so no one can steal your stuff
- Add a nether crucible that acts like a nether chest so that each player has their own inventory in the same crucible