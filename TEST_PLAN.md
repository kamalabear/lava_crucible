# Test Plan for mintest_lava_crucible

## Overview
This document outlines the testing strategy for mintest_lava_crucible, including unit tests, integration tests, and smoke tests.

## Test Levels

### Level 1: Unit Tests (Busted)
**Purpose:** Validate core logic functions in isolation  
**Scope:** crucible.lua pure Lua functions  
**Execution:** `busted spec/` from mod directory  
**Target:** ≥85% code coverage  

**Tests included:**
- Dust registry system
- Item group application
- Inventory helpers
- Ender tier detection
- Lava detection logic

**Expected runtime:** <5 seconds

### Level 2: Smoke Test (In-Game)
**Purpose:** Verify mod loads without errors and basic functionality works  
**Scope:** Full mod in Luanti with volcanic_soil and ore_dust dependencies  
**Execution:** Workspace smoke test task or manual test  

**Test cases:**

#### 2.1 Mod Load Test
- [ ] Mod loads without script errors
- [ ] No error messages in debug.txt on startup
- [ ] Crucible nodes appear in creative inventory
- [ ] All node variants registered (cold/hot/empty/done)
- [ ] All ender variants registered

#### 2.2 Node Registry Test
- [ ] Single crucible node: `lava_crucible:lava_crucible`
- [ ] Double crucible node: `lava_crucible:lava_crucible_double`
- [ ] Quad crucible node: `lava_crucible:lava_crucible_quad`
- [ ] Ender variants exist: `_ender`, `_ender_double`, `_ender_quad`
- [ ] State variants exist: `_hot`, `_hot_empty`, `_hot_done`

#### 2.3 Crafting Recipe Test
- [ ] Clay Graphite recipe works: `clay_lump` + `coal_lump` → `lava_crucible:clay_graphite`
- [ ] Obsidian Clay recipe works: `clay_lump` + `ore_dust:obsidian_dust` → `lava_crucible:obsidian_clay`
- [ ] Uncured Crucible shaped recipe works
- [ ] Furnace smelting: `uncured_crucible` → `lava_crucible:lava_crucible`

#### 2.4 Stone Conversion Test
- [ ] Place crucible over lava
- [ ] Punch with stone item
- [ ] Stone converts to volcanic soil
- [ ] Item count is preserved

#### 2.5 Ender Inventory Test
- [ ] Ender crucible can be placed
- [ ] Opening ender crucible shows player inventory
- [ ] Items persist when world reloads
- [ ] Multiple players have independent inventories

#### 2.6 Dependency Test
- [ ] volcanic_soil mod is available
- [ ] ore_dust mod is available (if not optional)
- [ ] Dependency errors are clear if mods missing

#### 2.7 Setting Test
- [ ] `lava_crucible_conversion_interval` setting exists
- [ ] `lava_crucible_dust_chance` setting exists
- [ ] Settings are accessible in Minetest settings menu

**Expected result:** No errors, all nodes visible and accessible, recipes functional

### Level 3: Manual Integration Tests
**Purpose:** Verify complex workflows in a real game environment  
**Scope:** Full gameplay with crafting, conversion, and ender crucibles  
**Environment:** "Volcanic Soil Playground" world  

**Test scenarios:**

#### 3.1 Complete Crafting Chain
- [ ] Obtain clay and coal
- [ ] Craft clay graphite
- [ ] Craft uncured crucible
- [ ] Smelt to get cured crucible
- [ ] Place over lava

#### 3.2 Stone Conversion Workflow
- [ ] Gather stone (cobblestone, etc.)
- [ ] Place crucible over lava
- [ ] Punch with stone to fill input
- [ ] Wait for processing
- [ ] Collect volcanic soil output
- [ ] Verify state changes (cold → hot → done → cold)

#### 3.3 Ender Crucible Workflow
- [ ] Craft obsidian clay (needs obsidian dust from ore_dust)
- [ ] Craft and smelt ender crucible
- [ ] Place over lava
- [ ] Open formspec
- [ ] Add items to input
- [ ] Verify inventory persists across sessions

#### 3.4 Multi-Tier Testing
- [ ] Test double crucible: 2× input, 2× soil output, 2× dust outputs per dust type
- [ ] Test quad crucible: 4× input, 4× soil output, 4× dust outputs per dust type
- [ ] Verify each tier processes correctly

#### 3.5 Dust System Testing
- [ ] Crucible generates copper dust (from moreores if available)
- [ ] Dust outputs appear in separate output list
- [ ] Dust has `mineral_dust` group
- [ ] Multiple dust types coexist without conflict

## Test Execution Matrix

| Level | Type | Tool | Frequency | Owner |
|-------|------|------|-----------|-------|
| 1 | Unit | busted | On commit | CI |
| 2 | Smoke | Luanti + script | Weekly | CI |
| 3 | Manual | Luanti GUI | Release prep | Developer |

## Environment Requirements

### Unit Tests
- `busted` installed (`luarocks install busted`)
- `lua` 5.1+ or `luajit`
- No Minetest server required

### Smoke Tests
- Luanti 5.10+ installed
- `volcanic_soil` mod available
- `ore_dust` mod available
- `moreores` mod recommended

### Manual Tests
- Luanti 5.10+ with GUI
- "Volcanic Soil Playground" world configured
- Creative mode or access to materials

## Success Criteria

| Level | Pass Criteria | Status |
|-------|---------------|--------|
| 1 (Unit) | 100% tests pass, ≥85% coverage | TODO |
| 2 (Smoke) | No load errors, all nodes present | TODO |
| 3 (Manual) | All workflows complete successfully | TODO |

## Known Limitations

- **Formspec testing:** Can't fully test formspec UX in unit tests (manual verification required)
- **ABM timing:** Can't test active block manager timing with unit tests (requires running server)
- **Node timer:** Timer callbacks can't be tested in isolation
- **Multiplayer:** Ender inventory isolation can't be tested without multiple clients

## Regression Tests

When bugs are fixed, add regression tests to prevent reoccurrence:

- [ ] Bug: Item prefix validation (see old BUG_REPORT.md)
- [ ] Bug: [Future bugs recorded here]

## Notes

- Tests should be idempotent (can run multiple times safely)
- Mock `minetest` table completely to avoid dependency on server
- Use `before_each` to reset global state between tests
- Document any non-obvious mocks in spec files
