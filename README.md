## Overview: minetest_lava_crucible

### Files in the mod
- init.lua
- crucible.lua
- metal_dust.lua
- mod.conf
- `textures/lava_soil.png`
- `.git/`, `.gitignore`, `LICENSE`

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

### crucible.lua
- Registers two nodes:
  - `minetest_lava_crucible:lava_soil`
  - `minetest_lava_crucible:lava_crucible`

#### `lava_soil`
- Animated tile texture `lava_soil.png`
- Belongs to group `cracky = 1`

#### `lava_crucible`
- Custom node box shape representing a crucible
- Has a single internal inventory slot (`main`, size 1)
- Inventory callbacks allow moving, putting, and taking items
- `on_construct` initializes metadata and inventory
- `on_rightclick`:
  - returns contents from the crucible to the player
  - sends chat feedback
- `on_punch`:
  - if the player is holding any item in group `stone`
  - converts that held stone stack into `lava_soil`
  - stores it in the crucible inventory
  - removes the original stone from the player's inventory

#### ABM behavior
- An ABM runs on `minetest_lava_crucible:lava_crucible`
- It only triggers when the crucible has a lava neighbor:
  - `default:lava_flowing`
  - `default:lava_source`
- It checks for objects inside radius `0.5` at the crucible position
- For each object inside:
  - if it is a stone-group item entity
  - the object is removed
  - one `lava_soil` item is spawned for each stone count
- Spawn location is above the crucible

#### Crafting
- Crucible recipe:
  - uses `default:clay_lump` and `group:mineral_dust`
  - output is `minetest_lava_crucible:lava_crucible`

---

## Behavior summary

- The mod provides a small transformation system:
  - stone → lava soil
- Two input methods:
  - punch the crucible while holding stone
  - drop stone item entities into the crucible when it is adjacent to lava
- The crucible stores converted soil in an internal slot
- Players can retrieve the soil by right-clicking

---

## Notes and possible issues
- The ABM logs entity processing and may stop early if an object has no valid luaentity
- The mod currently has placeholder comments for a formspec, but no GUI form is implemented
- `optional_depends = moreores` is declared, but the mod currently only defines `copper_dust` and does not use `moreores` assets directly
- The conversion logic accepts any item in group `stone`

---

## Additional features to add
- When you throw stone in lava (no crucible involved) you sometimes get some mineral dust (randomly selected) that floats to the top of the lava and you can grab
- Add user-locking so no one can steal your stuff
- Add a nether crucible that acts like a nether chest so that each player has their own inventory in the same crucible