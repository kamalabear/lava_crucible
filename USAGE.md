# Lava Crucible — User's Guide

## What it does

The Lava Crucible processes stone into **lava soil** — a fertile, animated soil block — by submerging stone in lava heat. As a bonus, each conversion has a chance to produce **ore dust**, a crafting ingredient provided by the companion `ore_dust` mod.

---

## Dependencies

- **Required mods:** `default`, `ore_dust`
- **Optional:** `moreores` — enables tin, silver, and mithril dust drops

---

## Getting started

1. **Craft a single crucible** (see Crafting below)
2. **Place it** next to a lava source or flowing lava block (any of the 6 adjacent faces)
3. **Add stone** — either:
   - Punch the crucible while holding any stone-group item (adds the whole stack)
   - Right-click to open the GUI and drag items into the input slot(s)
4. **Wait** — after one full conversion interval the crucible begins processing automatically
5. **Collect output** — right-click to open the GUI and take lava soil and ore dust from the output slots

The crucible is **owner-locked**: only the player who placed it can open it, add input, or take output. Anyone else receives a chat message identifying the owner.

---

## Tiers

Three tiers are available, each crafted from the previous. Higher tiers have more slots and convert more stone per tick.

| Tier | Input slots | Soil output slots | Dust slots | Visual height |
|---|---|---|---|---|
| **Single** | 1 | 1 | 4 (7 with `moreores`) | Half node |
| **Double** | 2 | 2 | 8 (14 with `moreores`) | Three-quarter node |
| **Quad** | 4 | 4 | 16 (28 with `moreores`) | Full node |

Each tier also has a filled bowl appearance when input is present, so you can tell at a glance whether it is loaded.

---

## Crafting

**Single crucible** — clay bowl shape with ore dust at the centre:

```
clay   ·     clay
clay   dust  clay
 ·     clay   ·
```
(`dust` = any item in group `mineral_dust`)

**Double crucible** — place two singles side by side in a crafting grid:

```
single  single
```

**Quad crucible** — place two doubles side by side:

```
double  double
```

---

## Visual states

The crucible top texture changes automatically to reflect its current state:

| Appearance | Meaning |
|---|---|
| Cold, dark | No adjacent lava |
| Animated lava top, bright glow, filled bowl | Processing — lava adjacent and input loaded |
| Lava soil top, dim glow | Done — input exhausted, output has items to collect |
| Glowing empty basin | Hot and empty — lava adjacent but nothing to process |

---

## Ore dust drops

Each conversion has a chance (default 50%) to produce a random ore dust in the dust output slots. The distribution is weighted:

| Dust | Relative frequency | Requires |
|---|---|---|
| Iron dust | Very common | — |
| Copper dust | Common | — |
| Gold dust | Uncommon | — |
| Diamond dust | Rare | — |
| Tin dust | Common | `moreores` |
| Silver dust | Uncommon | `moreores` |
| Mithril dust | Rare | `moreores` |

Dust slots silently skip the bonus if they are full — no input is lost.

---

## Configuration

Add these to your `minetest.conf` to override the defaults:

| Setting | Default | Description |
|---|---|---|
| `lava_crucible_conversion_interval` | `10.0` | Seconds between conversions |
| `lava_crucible_dust_chance` | `0.5` | Probability (0–1) of a dust bonus per conversion |
