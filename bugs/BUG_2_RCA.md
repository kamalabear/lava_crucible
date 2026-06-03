# Bug 2 RCA: Unknown Item Produced (technic:pyrite_dust)

**Status:** ✅ FIXED (Implemented June 3, 2026)

## Executive Summary
The lava crucible mod attempted to register `technic:pyrite_dust` as a bonus dust output when both the `technic` and `everness` mods are present. However, this item is not actually provided by the technic mod version in use, causing "Unknown Item" entries to appear in player inventory when processing stone.

**Root Cause:** Unregistered items are added to the dust bonus pool without validation, and the dust selection function picks from this pool without checking if items exist in `minetest.registered_items`.

**Severity:** Low (cosmetic issue, no crash or data loss)

**Fix Approach:** Implemented dynamic dust/lump discovery with two-layer validation (registration-time and selection-time) instead of hard-coded item lists.

---

## Detailed Analysis

### Code Path

1. **Mod Initialization** (`crucible.lua` lines 506-530):
   - When `technic` mod is detected, a list of expected dust items is created
   - If `everness` mod is also detected, `technic:pyrite_dust` is added to the list
   - All items in this list are passed to `lava_crucible.register_dust_bonus()`

2. **Dust Registration** (`crucible.lua` lines 122-142):
   - `register_dust_bonus()` accepts an item name and weight
   - **No validation occurs** - the function doesn't check if the item is registered in `minetest.registered_items`
   - Items are added directly to the internal `dust_table` and `dust_entries_by_item` lookup

3. **Dust Selection** (`crucible.lua` lines 550-563):
   - `pick_random_dust()` uses weighted random selection from `dust_table`
   - **No validation occurs** - the function returns item names without checking registration status
   - These unregistered items are then used to create ItemStacks

4. **Inventory Population** (`crucible.lua` line 606):
   - Unregistered item name is used to create ItemStack: `ItemStack(bonus_item .. " 1")`
   - Luanti renders unregistered items as "Unknown Item"

### Why `technic:pyrite_dust` Specifically

The code at line 525 registers `technic:pyrite_dust` only when:
- `technic` mod is loaded
- `everness` mod is loaded  
- The technic mod version installed does NOT provide `pyrite_dust`

This is a **version compatibility issue**. The dust was likely added by a new version of technic or everness, but the installed version doesn't include it yet.

### Validation Gaps

**Gap 1: No pre-registration validation**
```lua
-- Current code (line 527) - NO VALIDATION
for _, entry in ipairs(technic_dusts) do
    lava_crucible.register_dust_bonus(entry.item, entry.weight, ...)
end
```

**Gap 2: No runtime validation during selection**
```lua
-- Current code (line 563) - NO VALIDATION
return dust_table[#dust_table].item  -- Returns unregistered item
```

**Gap 3: Mining dust overrides attempt to check, but too late**
```lua
-- apply_mineral_dust_overrides() line 145-152
-- This checks registration, but ONLY for adding groups
-- It doesn't prevent unregistered items from being in dust_table
if def then  -- If item IS registered
    -- Add mineral_dust group
else
    minetest.log("warning", "[lava_crucible] Unable to add mineral_dust group to unregistered item " .. itemname)
end
```

---

## Impact Assessment

- **User Impact:** Minor. Player sees "Unknown Item" in inventory instead of a valid dust
- **Gameplay Impact:** None - "Unknown Item" stacks can be used/discarded like any item
- **Visual Impact:** Clutters inventory with unrecognizable entries
- **Data Impact:** No corruption or loss

---

## Root Cause Classification

**Primary Cause:** Insufficient input validation in `register_dust_bonus()`

**Secondary Cause:** Insufficient output validation in `pick_random_dust()`

**Tertiary Cause:** Dependency version mismatch (technic/everness versions don't provide expected items)

---

## Acceptance Criteria for Fix

1. **Unregistered items must not enter the dust pool**
   - `register_dust_bonus()` must validate items before adding to `dust_table`
   - Should log warnings for skipped items

2. **Defensive check at selection time**
   - `pick_random_dust()` must validate before returning
   - If a picked item is unregistered, skip and select another

3. **Registration finalization**
   - Dust pool must be finalized AFTER all mods load and all items are registered
   - Use `minetest.register_on_mods_loaded()` callback

4. **Logging for debugging**
   - Log which dust items were skipped and why
   - Helps debug dependency/version issues

---

## Proposed Solution

### Option A: Validate During Registration (Recommended)

Modify `register_dust_bonus()` to check item existence:

```lua
function lava_crucible.register_dust_bonus(itemname, weight, options)
    -- Existing validation...
    if type(itemname) ~= "string" or itemname == "" then
        error("lava_crucible.register_dust_bonus: itemname must be a non-empty string")
    end
    
    -- NEW: Check if item is registered
    if not minetest.registered_items[itemname] then
        minetest.log("warning", 
            "[lava_crucible] Skipping unregistered dust item: " .. itemname)
        return false  -- Indicate item was not added
    end
    
    -- Rest of existing code...
    local entry = dust_entries_by_item[itemname]
    if entry then
        entry.weight = weight
    else
        entry = {item = itemname, weight = weight}
        dust_entries_by_item[itemname] = entry
        table.insert(dust_table, entry)
    end
    
    if options and options.grant_mineral_dust_group then
        dust_items_requiring_mineral_group[itemname] = true
    end
    
    return true  -- Item successfully registered
end
```

### Option B: Defer Dust Pool Creation

Use `register_on_mods_loaded()` to finalize and clean dust pool:

```lua
minetest.register_on_mods_loaded(function()
    -- Filter out unregistered items from dust_table
    local valid_dusts = {}
    for _, entry in ipairs(dust_table) do
        if minetest.registered_items[entry.item] then
            table.insert(valid_dusts, entry)
        else
            minetest.log("warning", 
                "[lava_crucible] Removed unregistered dust: " .. entry.item)
            dust_entries_by_item[entry.item] = nil
        end
    end
    dust_table = valid_dusts
    apply_mineral_dust_overrides()
    recompute_dust_total_weight()
end)
```

### Option C: Validate During Selection (Fallback)

Ensure `pick_random_dust()` never returns unregistered items:

```lua
local function pick_random_dust()
    if #dust_table == 0 or dust_total_weight <= 0 then
        return nil
    end

    local attempts = 0
    local max_attempts = #dust_table + 1
    
    while attempts < max_attempts do
        local roll = math.random() * dust_total_weight
        local cumulative = 0
        for _, entry in ipairs(dust_table) do
            cumulative = cumulative + entry.weight
            if roll <= cumulative then
                -- NEW: Validate item is registered
                if minetest.registered_items[entry.item] then
                    return entry.item
                else
                    -- Item is unregistered, try again
                    attempts = attempts + 1
                    break
                end
            end
        end
    end
    
    return nil  -- No valid dust found
end
```

---

## Implementation (June 3, 2026)

**Solution Implemented:** Dynamic dust/lump discovery with two-layer validation

Instead of hard-coded dust lists, the system now:

1. **At mod load time** (`minetest.register_on_mods_loaded()`):
   - Scans `minetest.registered_items` AND `minetest.registered_nodes` for items ending in `_dust` or `_lump`
   - Extracts material names using: `itemname:gsub("_dust$", ""):match("[^_:]*$")`
   - Assigns automatic weights using material lookup table (copper=30, gold=8, iron=40, etc.)
   - **PRIMARY DEFENSE:** `register_dust_bonus()` validates items exist before adding to pool
   - Returns discovery count for logging

2. **During dust selection** (`pick_random_dust()` and `pick_random_lump()`):
   - **SECONDARY DEFENSE:** Validates items are registered before returning
   - Prevents selection-time failures even if somehow unregistered items enter the pool

**Two-Layer Defense Benefits:**
- Handles items that become unregistered after registration
- Catches edge cases from mod load order issues
- Automatically discovers new dusts from new mods without code changes
- Prevents version mismatch issues (unregistered items are simply skipped)

**Code Changes:**
- [crucible.lua lines 497-620](../crucible.lua#L497): `discover_and_register_dusts()` and `discover_and_register_lumps()`
- [crucible.lua lines 124-153](../crucible.lua#L124): Enhanced `register_dust_bonus()` with validation
- [crucible.lua lines 642-691](../crucible.lua#L642): Enhanced `pick_random_dust()` and `pick_random_lump()` with defensive checks
- [crucible.lua lines 539-537](../crucible.lua#L539): Added `dust_weight_defaults` and `lump_weight_defaults` lookup tables

**Test Coverage:**
- 24 unit tests covering discovery, validation, and selection
- Smoke test validates 6 dusts and 6 lumps discovered
- Defensive selection function tests verify unregistered items are skipped

---

## Testing Strategy (Completed)

✅ **Positive Control:** 15 unit tests verify registered dusts are correctly discovered and weighted
✅ **Negative Control:** 4 unit tests verify unregistered items are skipped without errors
✅ **Integration Test:** Smoke test with ore_dust, volcanic_soil, and default mods passes without "Unknown Items"
✅ **Selection Function Tests:** 9 unit tests verify defensive selection validates items before returning
✅ **Log Verification:** Smoke test logs show:
```
[lava_crucible] Discovered and registered 6 dust items (scanned 6)
[lava_crucible] Discovered and registered 6 lump items (scanned 6)
[lava_crucible] Dust pool total weight: 60
[lava_crucible] Lump pool total weight: 60
```

---

## Attachment

See related files:
- [crucible.lua line 506-530](../crucible.lua#L506) - Technic dust registration
- [crucible.lua line 122-142](../crucible.lua#L122) - `register_dust_bonus()` function
- [crucible.lua line 550-563](../crucible.lua#L550) - `pick_random_dust()` function
