# Lava Crucible

Adds craftable crucibles that process stone into lava soil when placed adjacent to lava. Three tiers of crucible are available — single, double, and quad — each upgradeable from the previous and visually distinct in height.

Conversions have a chance to produce weighted mineral dust bonuses. The base pool comes from the companion [`ore_dust`](https://github.com/kamalabear/ore_dust) mod, and `technic` can extend that pool with additional ore-like dusts.

---

## Dependencies

- **Required:** `default`, `ore_dust`
- **Optional:** `moreores` (enables tin, silver, and mithril dust drops)
- **Optional:** `technic` (adds selected technic mineral dusts and marks them as `mineral_dust` items for compatibility)

---

## Documentation

- [User's Guide](USAGE.md) — how to craft, place, and use crucibles; ore dust drops; configuration
- [Developer's Guide](DEVELOPMENT.md) — node naming, state machine, conversion pipeline, inventory system, owner system, and how to extend the mod

---

## License

See [LICENSE](LICENSE).
