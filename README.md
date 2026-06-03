# Lava Crucible

Adds craftable crucibles that process stone into lava soil when placed adjacent to lava. Three tiers of crucible are available — single, double, and quad — each upgradeable from the previous and visually distinct in height.

Conversions have a chance to produce weighted mineral dust bonuses. The dust pool is **dynamically discovered** at mod load time from any mod that registers items ending in `_dust` or `_lump` — no configuration needed. The system automatically weights materials by rarity (copper, iron common; gold rare; etc.).

---

## Dependencies

- **Required:** `default`, `ore_dust`, `volcanic_soil` (provides the lava soil output node)
- **Optional:** `moreores` (enables tin, silver, and mithril dust drops)
- **Optional:** `technic` (adds selected technic mineral dusts and marks them as `mineral_dust` items for compatibility)

---

## Documentation

- [User's Guide](USAGE.md) — how to craft, place, and use crucibles; ore dust drops; configuration
- [Developer's Guide](DEVELOPMENT.md) — node naming, state machine, conversion pipeline, inventory system, owner system, and how to extend the mod

---

## License

See [LICENSE](LICENSE).
