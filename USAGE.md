# Lava Crucible — User's Guide

## What it does

The Lava Crucible processes stone into **lava soil** — a fertile, animated soil block — by submerging stone in lava heat. As a bonus, each conversion has a chance to produce **mineral dust**. The default pool comes from the companion `ore_dust` mod, and installing `technic` expands that pool with additional ore-like technic dusts.

---

## Dependencies

- **Required mods:** `default`, `ore_dust`, `volcanic_soil`
- **Optional:** `moreores` — enables tin, silver, and mithril dust drops
- **Optional:** `technic` — adds selected technic dusts to crucible output and makes those items behave as `mineral_dust`

---

## Getting started

1. **Craft a single crucible** (see Crafting below)
2. **Place it** next to a lava source or flowing lava block (any of the 6 adjacent faces)
3. **Add stone** — either:
   - Punch the crucible while holding any stone-group item (adds the whole stack)
   - Right-click to open the GUI and drag items into the input slot(s)
   - Drop items directly above the crucible: item entities lying slightly above the crucible will be collected automatically into the input slot (if space is available). Supports regular stone-group items and `_compressed` variants; collection occurs within ~1s.
4. **Wait** — after one full conversion interval the crucible begins processing automatically
5. **Collect output** — right-click to open the GUI and take lava soil and bonus drops from the output slots

The crucible is **owner-locked**: only the player who placed it can open it, add input, or take output. Anyone else receives a chat message identifying the owner.

---

## Sizes

Three crucible sizes are available in both regular and Ender variants, with the larger sizes crafted by combining smaller crucibles. Larger sizes have more slots and convert faster.

| Size | Input slots | Soil output slots | Dust slots | Visual height |
|---|---|---|---|---|
| **Single** | 1 | 1 | 1× current dust pool size | Half node |
| **Double** | 2 | 2 | 2× current dust pool size | Three-quarter node |
| **Quad** | 4 | 4 | 4× current dust pool size | Full node |

The current dust pool starts with 4 base `ore_dust` entries, grows to 7 with `moreores`, and grows further when `technic` is installed.

Each size also has a filled bowl appearance when input is present, so you can tell at a glance whether it is loaded. Ender variants are tinted purple and share the same three sizes.

---

## Crafting

All crucibles follow the same cup shape in the crafting grid:

```
item  ·     item
item  ·     item
·     item   ·
```

**Step 1 — Clay Graphite** (shapeless): `clay_lump` + `coal_lump` → `clay_graphite`

**Step 1b — Obsidian Clay** (shapeless): `clay_lump` + `obsidian_dust` → `obsidian_clay`

**Step 2 — Uncured Crucible** — cup shape using `clay_graphite`:

```
graphite  ·         graphite
graphite  ·         graphite
·         graphite  ·
```

**Step 3 — Single Crucible** — bake `uncured_crucible` in a furnace (15 seconds)

---

**Ender path (small variant)**

**Step 2E — Uncured Ender Crucible** — same cup shape, but using `obsidian_clay`:

```
obs.clay  ·         obs.clay
obs.clay  ·         obs.clay
·         obs.clay  ·
```

**Step 3E — Ender Lava Crucible** — bake `uncured_ender_crucible` in a furnace (15 seconds)

---

**Uncured Double Ender Crucible** — cup shape using 5× `uncured_ender_crucible`:

```
ndr.ender  ·           unc.ender
unc.ender  ·           unc.ender
·          unc.ender   ·
```

**Double Ender Crucible** — bake `uncured_ender_double_crucible` in a furnace (20 seconds)

---

**Uncured Quad Ender Crucible** — cup shape using 5× `uncured_ender_double_crucible`:

```
unc.e.dbl  ·            unc.e.dbl
unc.e.dbl  ·            unc.e.dbl
·          unc.e.dbl    ·
```

**Quad Ender Crucible** — bake `uncured_ender_quad_crucible` in a furnace (25 seconds)

---

**Uncured Double Crucible** — cup shape using 5× `uncured_crucible`:

```
uncured  ·        uncured
uncured  ·        uncured
·        uncured  ·
```

**Double Crucible** — bake `uncured_double_crucible` in a furnace (20 seconds)

---

**Uncured Quad Crucible** — cup shape using 5× `uncured_double_crucible`:

```
unc.dbl  ·         unc.dbl
unc.dbl  ·         unc.dbl
·        unc.dbl   ·
```

**Quad Crucible** — bake `uncured_quad_crucible` in a furnace (25 seconds)

---

## Visual states

The crucible top texture changes automatically to reflect its current state:

| Appearance | Meaning |
|---|---|
| Cold, dark | No adjacent lava - place next to lava to use |
| Glowing empty basin | Hot and empty — lava adjacent but nothing to process - add stone to get started |
| Animated lava top, bright glow, filled bowl | Processing — lava adjacent and input loaded |
| Lava soil top, dim glow | Done — input exhausted, output has items to collect |

For Ender Lava Crucibles, the visual state reflects the **nearest player's** per-player inventory. Each player has their own independent ender inventory shared across all ender crucible nodes of the same tier — just like an ender chest. The crucible's four-stage display updates automatically as you approach.

---

## Compressed stone support

Crucibles support compressed stones as a high-yield input. Any item with `_compressed` in its name triggers the compressed processing rules:

| Input item | Soil produced per item | Bonus output |
|---|---|---|
| Regular stone-group item | 1 lava soil | Weighted ore dust |
| `moreblocks:*_compressed` (e.g., `cobble_compressed`, `desert_cobble_compressed`) | 9 lava soil | Weighted ore lump (same chance) |

Compressed stones use the same bonus chance setting as normal stone (`lava_crucible_dust_chance`) but the bonus pool changes from dust to lump-style outputs.

---

## Ore dust drops

For regular stone input, each conversion has a chance (default 50%) to produce a random ore dust in the dust output slots. The distribution is weighted:

| Dust | Relative frequency | Requires |
|---|---|---|
| Iron dust | Very common | — |
| Copper dust | Common | — |
| Gold dust | Uncommon | — |
| Diamond dust | Rare | — |
| Tin dust | Common | `moreores` |
| Silver dust | Uncommon | `moreores` |
| Mithril dust | Rare | `moreores` |

If the dust stack is full, any additional dust from conversion will be lost.

For compressed stone input, bonus outputs are weighted ore lumps/rare gemstone items (`iron_lump`, `copper_lump`, `gold_lump`, rare `diamond`, plus optional moreores lumps).

---

## Configuration

Add these to your `minetest.conf` to override the defaults:

| Setting | Default | Description |
|---|---|---|
| `lava_crucible_conversion_interval` | `10.0` | Seconds between conversions |
| `lava_crucible_dust_chance` | `0.5` | Probability (0–1) of a dust bonus per conversion |
