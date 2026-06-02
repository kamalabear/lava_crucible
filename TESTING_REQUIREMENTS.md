# Unit Test Requirements for mintest_lava_crucible

## Overview
This document specifies the unit test requirements for the mintest_lava_crucible mod. Tests will use the `busted` framework and focus on testable logic functions rather than server callbacks.

## Test Scope

### In Scope (Testable Functions)
- Dust registry system (`lava_crucible.register_dust_bonus()`)
- Dust weight computation (`recompute_dust_total_weight()`)
- Dust item group application (`apply_mineral_dust_overrides()`)
- Stone conversion logic (`convert_stone_to_lava_soil()`)
- Lava detection (`has_adjacent_lava()`)
- Ender crucible tier detection (`get_ender_tier()`, `is_ender_crucible_node()`)
- Ender user tracking (`mark_ender_user()`, `save_ender_users_seen()`)
- Inventory serialization (`serialize_inv_list()`)
- Inventory state checks (`inventory_input_empty()`, `inventory_output_has_items()`)
- Table cloning utility (`clone_table()`)

### Out of Scope (Requires Minetest Server)
- Node registration and callbacks
- Metadata inventory operations
- Node callbacks (`on_punch`, `on_timer`, etc.)
- Formspec handling
- Actual crafting recipes
- Client/server RPC calls

## Test File Structure

```
mintest_lava_crucible/
├── .busted                       # Busted configuration
├── spec/
│   ├── spec_helper.lua          # Test fixtures and mocks
│   ├── crucible_spec.lua        # Core logic tests
│   ├── dust_registry_spec.lua   # Dust system tests
│   └── ender_spec.lua           # Ender crucible tests
└── crucible.lua                 # Source code
```

## Test Coverage Goals

| Module | Coverage | Priority |
|--------|----------|----------|
| Dust Registry API | 90%+ | High |
| Stone Conversion | 85%+ | High |
| Ender Tier Detection | 95%+ | Medium |
| Inventory Helpers | 80%+ | Medium |
| Lava Detection | 85%+ | Low |

## Mock Requirements

Since the mod depends on Minetest APIs (`minetest.get_item_group()`, `minetest.registered_items`, `ItemStack`, etc.), tests must mock or stub:

1. **`minetest.get_item_group(itemname, group)`** — Returns group strength (0 or positive integer)
2. **`minetest.registered_items`** — Indexed table of item definitions with `groups` field
3. **`minetest.override_item(itemname, def)`** — Modifies item definition groups
4. **`ItemStack(str)`** — Constructor for inventory stacks
5. **`minetest.serialize()` / `minetest.deserialize()`** — Data serialization
6. **`minetest.get_node(pos)`** — Returns node at position
7. **`minetest.get_mod_storage()`** — Returns mod persistent storage

## Test Categories

### 1. Dust Registry Tests
- Register a single dust bonus
- Register multiple dust bonuses
- Update existing dust bonus weight
- Validate error handling for invalid inputs (empty string, non-string, zero/negative weight)
- Compute total weight correctly
- Grant mineral dust group to items

### 2. Stone Conversion Tests
- Convert stone item to lava soil
- Preserve count during conversion
- Reject non-stone items
- Handle nil itemstack

### 3. Ender Crucible Tests
- Detect single/double/quad tiers correctly
- Detect ender nodes correctly
- Mark new ender users
- Persist ender user list
- Load ender user list from storage
- Prevent duplicate user entries

### 4. Inventory Helper Tests
- Check empty input inventory
- Check for output items
- Serialize and deserialize inventory lists
- Handle nil and empty inventories

### 5. Lava Detection Tests
- Detect lava in all 6 adjacent positions
- Return false when no lava adjacent
- Distinguish between lava source and flowing

## Success Criteria

- [ ] All test files pass with 100% pass rate
- [ ] Coverage report shows ≥85% code coverage for crucible.lua
- [ ] Tests run in <5 seconds total
- [ ] Tests can be run with `busted spec/` from mod directory
- [ ] CI/CD integration via workspace test tasks
