# Unit Test Implementation Plan for mintest_lava_crucible

## Overview
This plan details the implementation of the busted test suite for mintest_lava_crucible. The goal is to achieve ≥85% code coverage of testable logic functions within 2-3 implementation sessions.

## Architecture

### File Structure
```
mintest_lava_crucible/
├── .busted                       # Busted configuration (new)
├── spec/
│   ├── spec_helper.lua          # Minetest API mocks and fixtures (new)
│   ├── crucible_spec.lua        # Core logic tests (new)
│   ├── dust_registry_spec.lua   # Dust system tests (new)
│   ├── ender_spec.lua           # Ender crucible tests (new)
│   └── inventory_spec.lua       # Inventory helper tests (new)
├── crucible.lua                 # Source (existing, may need minor refactoring)
├── init.lua                     # Source (existing)
├── metal_dust.lua               # Source (existing)
└── TESTING_REQUIREMENTS.md      # Requirements (created)
```

### Key Design Decisions

1. **Minimal Refactoring**: Extract testable logic into functions where needed, but avoid major rewrites
2. **Stub-First Mocking**: Create comprehensive minetest stubs before writing test cases
3. **Test Isolation**: Each test suite covers one functional area independently
4. **Deterministic**: All tests use fixed inputs and produce reproducible outputs

---

## Phase 1: Setup (30 min)

### Task 1.1: Create `.busted` Configuration
**File:** `.busted`

```lua
return {
  _all = {
    verbose = true,
    output = "utfTerminal",
    helper = "spec/spec_helper.lua",
  },
  default = {
    tags = "-pending",
  },
}
```

**Validation:**
- [ ] File created at project root
- [ ] `busted --help` runs without errors

---

### Task 1.2: Create spec/ Directory
**Command:**
```bash
mkdir -p spec
```

**Validation:**
- [ ] Directory exists
- [ ] Empty `.gitkeep` optional

---

### Task 1.3: Create spec_helper.lua (Minetest Mock Library)
**File:** `spec/spec_helper.lua`

**Purpose:** Provide comprehensive mocks for all Minetest APIs used by crucible.lua

**Content outline:**

```lua
-- spec/spec_helper.lua

-- Global test fixtures
local function setup_minetest_mocks()
    -- Mock minetest global table
    _G.minetest = _G.minetest or {}
    
    -- 1. Item registry mocks
    _G.minetest.registered_items = {}
    _G.minetest.registered_craftitems = {}
    _G.minetest.registered_nodes = {}
    
    -- 2. Mock get_item_group(itemname, group) -> strength
    function _G.minetest.get_item_group(itemname, group)
        local def = _G.minetest.registered_items[itemname]
        if def and def.groups and def.groups[group] then
            return def.groups[group]
        end
        return 0
    end
    
    -- 3. Mock override_item(itemname, def)
    function _G.minetest.override_item(itemname, def)
        if _G.minetest.registered_items[itemname] then
            for k, v in pairs(def) do
                if k == "groups" then
                    -- Merge groups
                    for gname, gval in pairs(v) do
                        _G.minetest.registered_items[itemname].groups[gname] = gval
                    end
                else
                    _G.minetest.registered_items[itemname][k] = v
                end
            end
        end
    end
    
    -- 4. Mock ItemStack constructor
    function _G.ItemStack(str)
        local obj = {
            name = "air",
            count = 0,
            _string = str,
        }
        
        if str and str ~= "" then
            local name, count = str:match("^([^ ]+) (%d+)$")
            if name then
                obj.name = name
                obj.count = tonumber(count) or 1
            else
                obj.name = str
                obj.count = 1
            end
        end
        
        function obj:get_name()
            return self.name
        end
        
        function obj:get_count()
            return self.count
        end
        
        function obj:set_count(count)
            self.count = count
        end
        
        function obj:is_empty()
            return self.name == "air" or self.count == 0
        end
        
        function obj:to_string()
            if self:is_empty() then return "" end
            return self.name .. " " .. self.count
        end
        
        return obj
    end
    
    -- 5. Mock serialize/deserialize
    function _G.minetest.serialize(obj)
        return require("json").encode(obj) -- or implement simple serialization
    end
    
    function _G.minetest.deserialize(str)
        return require("json").decode(str)
    end
    
    -- 6. Mock logging
    function _G.minetest.log(level, msg)
        print("[" .. level .. "] " .. msg)
    end
    
    -- 7. Mock pos_to_string
    function _G.minetest.pos_to_string(pos)
        return "(" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ")"
    end
    
    -- 8. Mock get_node
    function _G.minetest.get_node(pos)
        return _G.test_world[minetest.pos_to_string(pos)] or {name = "air"}
    end
    
    -- 9. Mock get_mod_storage
    local mod_storage_data = {}
    function _G.minetest.get_mod_storage()
        return {
            set_string = function(key, value)
                mod_storage_data[key] = value
            end,
            get_string = function(key)
                return mod_storage_data[key] or ""
            end,
            clear = function()
                for k in pairs(mod_storage_data) do
                    mod_storage_data[k] = nil
                end
            end,
        }
    end
    
    -- 10. Mock register_on_mods_loaded
    _G.minetest._mod_callbacks = {}
    function _G.minetest.register_on_mods_loaded(callback)
        table.insert(_G.minetest._mod_callbacks, callback)
    end
    
    -- Mock trigger for tests
    function _G.minetest.trigger_mods_loaded()
        for _, cb in ipairs(_G.minetest._mod_callbacks) do
            cb()
        end
    end
end

-- Helper function to reset state between tests
local function reset_test_env()
    _G.minetest.registered_items = {}
    _G.minetest.registered_craftitems = {}
    _G.minetest.registered_nodes = {}
    _G.minetest._mod_callbacks = {}
    _G.minetest.get_mod_storage():clear()
    _G.test_world = {}
    
    -- Reset lava_crucible global
    _G.lava_crucible = nil
end

-- Helper to register test items
local function register_test_item(itemname, def)
    _G.minetest.registered_items[itemname] = def or {
        description = itemname,
        groups = {},
    }
end

-- Helper to add lava to world
local function add_lava_at(pos)
    _G.test_world[minetest.pos_to_string(pos)] = {name = "default:lava_source"}
end

-- Setup on load
setup_minetest_mocks()

-- Export helpers
return {
    reset = reset_test_env,
    register_item = register_test_item,
    add_lava_at = add_lava_at,
}
```

**Validation:**
- [ ] File created with all mocks
- [ ] `busted spec/spec_helper.lua` runs without errors
- [ ] All minetest functions are available in test environment

---

## Phase 2: Core Logic Tests (1.5 hours)

### Task 2.1: Extract and Test `clone_table()` Function
**File:** `spec/crucible_spec.lua` (create new)

**Test cases:**
```lua
describe("clone_table()", function()
    it("should create a shallow copy", function()
        -- Test: {a=1, b=2} → {a=1, b=2}
    end)
    
    it("should handle empty tables", function()
        -- Test: {} → {}
    end)
    
    it("should preserve nested tables by reference", function()
        -- Test: {a={x=1}} → copies outer, not inner
    end)
    
    it("should handle nil values", function()
        -- Test: {a=nil, b=2} → {a=nil, b=2}
    end)
end)
```

**Implementation notes:**
- `clone_table()` is a pure function at the top of crucible.lua
- Tests should verify shallow copy behavior
- No mocking needed for this test

---

### Task 2.2: Create Stone Conversion Tests
**File:** `spec/crucible_spec.lua` (add to existing)

**Test cases:**
```lua
describe("convert_stone_to_lava_soil()", function()
    it("should convert stone to lava soil", function()
        -- Setup: Register stone item with stone group
        -- Test: convert_stone_to_lava_soil(stone_itemstack)
        -- Assert: Output is volcanic_soil with same count
    end)
    
    it("should preserve item count", function()
        -- Setup: stone stack with count=5
        -- Test: convert_stone_to_lava_soil()
        -- Assert: Output count == 5
    end)
    
    it("should return nil for non-stone items", function()
        -- Setup: Register dirt item (no stone group)
        -- Test: convert_stone_to_lava_soil(dirt_itemstack)
        -- Assert: Returns nil
    end)
    
    it("should handle nil itemstack", function()
        -- Test: convert_stone_to_lava_soil(nil)
        -- Assert: Returns nil (no error)
    end)
end)
```

---

### Task 2.3: Create Lava Detection Tests
**File:** `spec/crucible_spec.lua` (add to existing)

**Test cases:**
```lua
describe("has_adjacent_lava()", function()
    it("should detect lava above", function()
        local pos = {x=0, y=0, z=0}
        add_lava_at({x=0, y=1, z=0})
        assert.is_true(has_adjacent_lava(pos))
    end)
    
    it("should detect lava below", function()
        local pos = {x=0, y=0, z=0}
        add_lava_at({x=0, y=-1, z=0})
        assert.is_true(has_adjacent_lava(pos))
    end)
    
    it("should check all 6 directions", function()
        -- Test north, south, east, west, up, down
        -- Each should return true when lava present
    end)
    
    it("should return false with no adjacent lava", function()
        local pos = {x=0, y=0, z=0}
        assert.is_false(has_adjacent_lava(pos))
    end)
    
    it("should detect both lava_source and lava_flowing", function()
        -- Test with both node types
    end)
end)
```

---

## Phase 3: Dust Registry Tests (1 hour)

### Task 3.1: Create Dust Registry Test Suite
**File:** `spec/dust_registry_spec.lua` (create new)

**Test cases:**
```lua
describe("lava_crucible.register_dust_bonus()", function()
    it("should register a single dust bonus", function()
        lava_crucible.register_dust_bonus("ore_dust:copper_dust", 1.0)
        assert.equals(dust_table[1].item, "ore_dust:copper_dust")
        assert.equals(dust_table[1].weight, 1.0)
    end)
    
    it("should error on invalid itemname", function()
        assert.has_error(function()
            lava_crucible.register_dust_bonus("", 1.0)
        end)
    end)
    
    it("should error on invalid weight", function()
        assert.has_error(function()
            lava_crucible.register_dust_bonus("ore_dust:copper_dust", -1)
        end)
        assert.has_error(function()
            lava_crucible.register_dust_bonus("ore_dust:copper_dust", 0)
        end)
    end)
    
    it("should update weight if already registered", function()
        lava_crucible.register_dust_bonus("ore_dust:copper_dust", 1.0)
        lava_crucible.register_dust_bonus("ore_dust:copper_dust", 2.0)
        assert.equals(#dust_table, 1)
        assert.equals(dust_table[1].weight, 2.0)
    end)
    
    it("should grant mineral_dust group when requested", function()
        register_test_item("ore_dust:copper_dust", {groups = {}})
        lava_crucible.register_dust_bonus("ore_dust:copper_dust", 1.0, 
            {grant_mineral_dust_group = true})
        minetest.trigger_mods_loaded()
        assert.equals(minetest.registered_items["ore_dust:copper_dust"].groups.mineral_dust, 1)
    end)
end)

describe("recompute_dust_total_weight()", function()
    it("should compute total weight", function()
        lava_crucible.register_dust_bonus("ore_dust:copper_dust", 2.0)
        lava_crucible.register_dust_bonus("ore_dust:tin_dust", 3.0)
        recompute_dust_total_weight()
        assert.equals(dust_total_weight, 5.0)
    end)
    
    it("should handle empty dust table", function()
        dust_table = {}
        recompute_dust_total_weight()
        assert.equals(dust_total_weight, 0)
    end)
end)

describe("apply_mineral_dust_overrides()", function()
    it("should add mineral_dust group to registered items", function()
        -- Test multiple items get group added
    end)
    
    it("should handle unregistered items gracefully", function()
        -- Should log warning, not crash
    end)
end)
```

---

## Phase 4: Ender Crucible Tests (1 hour)

### Task 4.1: Create Ender Tests
**File:** `spec/ender_spec.lua` (create new)

**Test cases:**
```lua
describe("Ender Crucible Functions", function()
    
    describe("is_ender_crucible_node()", function()
        it("should detect ender nodes", function()
            assert.is_true(is_ender_crucible_node("lava_crucible_ender"))
            assert.is_true(is_ender_crucible_node("lava_crucible_ender_double"))
            assert.is_true(is_ender_crucible_node("lava_crucible_ender_quad"))
        end)
        
        it("should reject non-ender nodes", function()
            assert.is_false(is_ender_crucible_node("lava_crucible"))
            assert.is_false(is_ender_crucible_node("lava_crucible_double"))
        end)
    end)
    
    describe("get_ender_tier()", function()
        it("should detect single tier", function()
            assert.equals(get_ender_tier("lava_crucible_ender"), "single")
            assert.equals(get_ender_tier("lava_crucible_ender_hot"), "single")
        end)
        
        it("should detect double tier", function()
            assert.equals(get_ender_tier("lava_crucible_ender_double"), "double")
            assert.equals(get_ender_tier("lava_crucible_ender_double_hot"), "double")
        end)
        
        it("should detect quad tier", function()
            assert.equals(get_ender_tier("lava_crucible_ender_quad"), "quad")
            assert.equals(get_ender_tier("lava_crucible_ender_quad_hot_done"), "quad")
        end)
    end)
    
    describe("mark_ender_user()", function()
        it("should mark new users", function()
            mark_ender_user("PlayerOne")
            assert.is_true(ender_users_seen["PlayerOne"])
        end)
        
        it("should not add duplicates", function()
            mark_ender_user("PlayerOne")
            mark_ender_user("PlayerOne")
            -- Should still be in table once
        end)
        
        it("should save to storage", function()
            mark_ender_user("PlayerOne")
            local stored = minetest.get_mod_storage():get_string("ender_users_seen")
            assert.is_not_nil(stored)
        end)
    end)
    
    describe("save/load_ender_inventory()", function()
        it("should serialize inventory list", function()
            local inv_list = serialize_inv_list({
                item1 = ItemStack("ore_dust:copper_dust 5"),
                item2 = ItemStack("ore_dust:tin_dust 3"),
            }, "items")
            assert.equals(#inv_list, 2)
        end)
        
        it("should save and restore ender inventory", function()
            -- Create inventory, add items, save
            -- Load in new inventory, verify items present
        end)
    end)
end)
```

---

## Phase 5: Inventory Helper Tests (30 min)

### Task 5.1: Create Inventory Tests
**File:** `spec/inventory_spec.lua` (create new)

**Test cases:**
```lua
describe("Inventory Helpers", function()
    
    describe("inventory_input_empty()", function()
        it("should return true when all slots empty", function()
            local inv = mock_inventory({})
            assert.is_true(inventory_input_empty(inv))
        end)
        
        it("should return false when slots have items", function()
            local inv = mock_inventory({ItemStack("ore_dust:copper_dust 1")})
            assert.is_false(inventory_input_empty(inv))
        end)
    end)
    
    describe("inventory_output_has_items()", function()
        it("should detect items in soil_output", function()
            local inv = mock_inventory_with_outputs({soil = {ItemStack("volcanic_soil 1")}})
            assert.is_true(inventory_output_has_items(inv))
        end)
        
        it("should detect items in dust_output", function()
            local inv = mock_inventory_with_outputs({dust = {ItemStack("ore_dust:copper_dust 1")}})
            assert.is_true(inventory_output_has_items(inv))
        end)
        
        it("should return false when empty", function()
            local inv = mock_inventory_with_outputs({})
            assert.is_false(inventory_output_has_items(inv))
        end)
    end)
end)
```

---

## Phase 6: Integration and Validation (30 min)

### Task 6.1: Run Full Test Suite
**Command:**
```bash
cd mintest_lava_crucible
busted spec/
```

**Expected output:**
- All tests pass
- Coverage report shows ≥85% for testable functions
- Runtime <5 seconds

**Validation checklist:**
- [ ] All test files found and executed
- [ ] No import errors
- [ ] All assertions pass
- [ ] Mock fixtures work correctly
- [ ] Coverage meets target

### Task 6.2: Add Coverage Report
**Command:**
```bash
busted spec/ --coverage
```

**Deliverable:**
- Coverage report in `coverage/` directory
- Identify any uncovered functions that should be added
- Document coverage percentage

### Task 6.3: Add to CI/CD (Optional)
**File:** `.github/workflows/test-crucible.yml` (if CI exists)

```yaml
name: Lava Crucible Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install busted
        run: luarocks install busted
      - name: Run tests
        run: cd mintest_lava_crucible && busted spec/
```

---

## Implementation Checklist

### Phase 1: Setup
- [ ] `.busted` configuration created
- [ ] `spec/` directory created
- [ ] `spec_helper.lua` with all mocks completed
- [ ] Mocks tested in isolation

### Phase 2: Core Logic
- [ ] `spec/crucible_spec.lua` created
- [ ] `clone_table()` tests passing
- [ ] `convert_stone_to_lava_soil()` tests passing
- [ ] `has_adjacent_lava()` tests passing

### Phase 3: Dust Registry
- [ ] `spec/dust_registry_spec.lua` created
- [ ] `register_dust_bonus()` tests passing
- [ ] `recompute_dust_total_weight()` tests passing
- [ ] `apply_mineral_dust_overrides()` tests passing

### Phase 4: Ender Crucible
- [ ] `spec/ender_spec.lua` created
- [ ] Ender tier detection tests passing
- [ ] Ender user tracking tests passing
- [ ] Inventory save/load tests passing

### Phase 5: Inventory Helpers
- [ ] `spec/inventory_spec.lua` created
- [ ] Inventory state tests passing

### Phase 6: Integration
- [ ] Full test suite runs: `busted spec/`
- [ ] ≥85% coverage achieved
- [ ] All tests pass
- [ ] Runtime <5 seconds
- [ ] Coverage report generated

---

## Success Criteria

| Criterion | Target | Status |
|-----------|--------|--------|
| All unit tests pass | 100% | TODO |
| Code coverage | ≥85% | TODO |
| Test execution time | <5 sec | TODO |
| Functions tested | 9+ | TODO |
| Test files | 5 | TODO |
| Total test cases | 50+ | TODO |

---

## Notes

- Extract functions gradually if needed—refactoring should be minimal
- Use `before_each()` and `after_each()` for state isolation
- Document any non-obvious mocks in test comments
- Consider adding a `Makefile` target for running tests: `make test`
- If busted dependencies are missing, install with: `luarocks install busted`
