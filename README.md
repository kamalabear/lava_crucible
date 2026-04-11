# Lava Crucible

Adds craftable crucibles that process stone into lava soil when placed adjacent to lava. Three tiers of crucible are available, each upgradeable from the previous.

---

## Dependencies

- **Required:** `default`, `ore_dust`
- **Optional:** `moreores` (enables additional ore dusts)

---

## How to use

1. **Craft a crucible** using clay lumps and ore dust (see Crafting below)
2. **Place it** next to a lava source or flowing lava block
3. **Add stone** by punching the crucible while holding any stone-group item, or drag items into the input slot via the GUI (right-click)
4. **Wait** — after one conversion interval, the crucible will begin converting stone to lava soil automatically
5. **Collect** lava soil (and any ore dust bonuses) from the output slots via the GUI

The crucible is **owner-locked**: only the player who placed it can open the GUI, add input, or take output. The owner's name is shown in the infotext.

---

## Tiers

Three tiers of crucible can be crafted, each visually distinct in height:

| Tier | Node | Inputs | Soil outputs | Dust slots | Height |
|---|---|---|---|---|---|
| Single | `lava_crucible` | 1 | 1 | `#dust_table` | Half |
| Double | `lava_crucible_double` | 2 | 2 | `#dust_table × 2` | Three-quarter |
| Quad | `lava_crucible_quad` | 4 | 4 | `#dust_table × 4` | Full |

Higher tiers process one item per input slot per conversion tick, so a quad crucible converts up to 4 stones per interval.

When input is present, the crucible's node box gains a fill slab that makes the contents visually apparent.

---

## Crafting

**Single crucible** — clay bowl shape with ore dust centre:

```
clay  ·    clay
clay  dust clay
·     clay  ·
```

**Double crucible** — combine two singles side by side:

```
single  single
```

**Quad crucible** — combine two doubles side by side:

```
double  double
```

---

## Node states

Each tier has four visual states that update automatically:

| State | Condition |
|---|---|
| Cold (dark) | No adjacent lava |
| Hot — processing (`light_source=10`, animated top, filled bowl) | Lava adjacent + input has items |
| Hot — done (`light_source=7`) | Lava adjacent + input empty + output has items |
| Hot — empty (`light_source=7`) | Lava adjacent + fully empty |

---

## Conversion behaviour

- Conversion is driven by a **node timer** started when input is added (via punch or GUI) while lava is adjacent
- There is a full conversion interval delay before the **first** conversion — items are not processed instantly
- The timer restarts automatically after each conversion as long as input remains
- If the soil output is full, the timer keeps firing but no input is consumed until space frees up
- An **ABM** also monitors crucibles at the conversion interval: if lava appears next to a crucible that already has input, it starts the timer

---

## Ore dust bonus

Each conversion has a configurable chance to also produce a random weighted ore dust in the dust output slots:

| Dust | Weight | Requires |
|---|---|---|
| Iron dust | 40 | — |
| Copper dust | 30 | — |
| Gold dust | 8 | — |
| Diamond dust | 1 | — |
| Tin dust | 20 | `moreores` |
| Silver dust | 5 | `moreores` |
| Mithril dust | 2 | `moreores` |

Dust items are provided by the companion **`ore_dust`** mod.

---

## Configuration (minetest.conf)

| Setting | Default | Description |
|---|---|---|
| `lava_crucible_conversion_interval` | `10.0` | Seconds between conversions |
| `lava_crucible_dust_chance` | `0.5` | Probability (0–1) of a dust bonus per conversion |

---

## Files

| File | Purpose |
|---|---|
| `init.lua` | Loads `crucible.lua` and `metal_dust.lua` |
| `crucible.lua` | All node definitions, inventory logic, ABM, timer, recipes |
| `metal_dust.lua` | Stub (dust items moved to `ore_dust` mod) |
| `mod.conf` | Mod metadata and dependency declarations |
| `textures/` | All crucible and lava soil textures |

---

## Future enhancement ideas
- When you throw stone in lava (no crucible involved) you sometimes get some mineral dust (randomly selected) that floats to the top of the lava and you can grab
- Add user-locking so no one can steal your stuff
- Add a nether crucible that acts like a nether chest so that each player has their own inventory in the same crucible
- Add support for compressed stone - would generate nuggets (or shards) instead of dust