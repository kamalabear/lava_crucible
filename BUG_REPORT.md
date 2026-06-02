# Bug Report: mintest_lava_crucible

## Bug 1: Hot Crucibles Placeable Without Lava

Date: 2026-06-02
Status: Open
Severity: Medium

### Summary
Crucible nodes with hot/done states can be placed in the world without adjacent lava. They should only be placeable after proper crafting/furnace smelting, and their visual state should reflect actual lava presence.

### Environment
- OS: Linux
- Context: Manual testing in Luanti
- Version: Latest from GitHub (Jun 2, 2026)

### Steps To Reproduce
1. Place a crucible in creative mode
2. Use `/giveme lava_crucible:lava_crucible_hot` or similar hot state node
3. Place the hot crucible in the world
4. Observe: No lava adjacent, but node displays hot texture

### Expected Result
- Hot state nodes should not be placeable by players
- Only base "cold" crucible nodes should appear in creative inventory
- Or: Player places hot node, it should immediately convert to cold state if no lava

### Actual Result
- Hot crucible node places successfully without lava
- Remains in hot visual state even without adjacent lava
- State machine may not correct this immediately

### Logs/Error Output
None (no crash, visual inconsistency only)

### Likely Cause
Hot/done state nodes are registered and accessible instead of being hidden from the creative inventory or restricted to internal state transitions only. The placing logic doesn't validate lava presence or reset the node state.

### Impact
- Visual confusion for players (appears hot but isn't processing)
- May affect mod compatibility systems that scan for "hot" nodes
- Low severity (cosmetic issue, no functionality loss)

### Acceptance Criteria
1. Hot state nodes do not appear in creative inventory
2. If a hot node is somehow placed, it should convert to cold state immediately
3. Only base state nodes are placeable in normal and creative modes

### Notes
- Related to node registration strategy
- Consider making hot/done/empty nodes internal-only (not registered in creative inventory)
- State machine (`update_crucible_state`) may need to run on placement

---

## Bug 2: Unknown Item Produced (technic:pyrite_dust)

Date: 2026-06-02
Status: Open
Severity: Low

### Summary
The crucible generated `technic:pyrite_dust` from processing, which appeared as an unknown/unregistered item in player inventory, causing visual clutter and confusion.

### Environment
- OS: Linux
- Context: Manual testing in Luanti
- Version: Latest from GitHub (Jun 2, 2026)
- Mods: technic (or similar) installed

### Steps To Reproduce
1. Enable crucible mod with technic mod installed
2. Process stone through crucible to generate dust outputs
3. Collect dust output containing `technic:pyrite_dust`
4. Observe in inventory

### Expected Result
- Only registered dust items should be added to crucible outputs
- All output items are known and display proper descriptions
- Dust registry only includes items that exist in registered_items

### Actual Result
- `technic:pyrite_dust` appeared in output
- Showed as "Unknown Item" in inventory
- Item was not properly registered or unavailable

### Logs/Error Output
None captured

### Likely Cause
- `technic:pyrite_dust` was added to dust pool but may not be registered in technic mod version installed
- OR: Dust registration occurs before all dependencies fully load
- OR: Condition checking for dust availability is missing

### Impact
- Minor visual issue
- Player confusion about unknown item
- Indicates inconsistency in dust pool validation

### Acceptance Criteria
1. All items in dust output must be registered in `minetest.registered_items`
2. Dust pool should only contain items that exist when mod loads
3. Add validation: skip unregistered items during output generation
4. Add logging for any dust items skipped due to non-registration

### Notes
- Check if load order matters (dependencies loading after crucible registers)
- May need to defer dust pool finalization to `register_on_mods_loaded` callback
- Consider: should unregistered items error loudly or be silently skipped?

---

## Bug 3: Uncured Crucibles Don't Finish Baking

Date: 2026-06-02
Status: Resolved - Transferred
Severity: High

### Summary
Furnace smelting of uncured crucibles sometimes fails to complete. Small crucibles intermittently hang; medium and large crucibles never complete baking.

### Environment
- OS: Linux
- Context: Manual testing in Luanti
- Version: Latest from GitHub (Jun 2, 2026)

### Steps To Reproduce
1. Craft uncured crucible (single tier)
2. Place in furnace with fuel
3. Wait for cook time (15s for single)
4. **Expected:** Item done baking
5. **Actual (small):** Intermittent - sometimes finishes, sometimes stays unfinished
6. Place uncured double crucible in furnace (20s cook time)
7. Wait - **never completes**
8. Place uncured quad crucible in furnace (25s cook time)
9. Wait - **never completes**

### Expected Result
- All uncured crucibles finish smelting in furnace
- Single tier completes in 15s
- Double tier completes in 20s
- Quad tier completes in 25s
- Furnace output contains cured crucible

### Actual Result
- Single tier: intermittently hangs
- Double tier: hangs 100% of the time
- Quad tier: hangs 100% of the time
- Items remain unfinished in furnace indefinitely

### Logs/Error Output
Check debug.txt for furnace or recipe errors

### Likely Cause
- Furnace recipe likely defined incorrectly for double/quad tiers
- Cook times may not match recipe registration
- Recipe output or input names may be wrong
- Double/quad recipes may not be registered at all

### Impact
- **HIGH:** Blocks crafting chain completely for larger crucibles
- Players cannot progress beyond single crucibles
- Affects all users trying to make medium/large crucibles

### Acceptance Criteria
1. All 6 uncured variants complete smelting in furnace
2. Cook times match DEVELOPMENT.md spec (15s, 20s, 25s)
3. Output names are correct (e.g., `lava_crucible:lava_crucible_double`)
4. No intermittent failures for any tier
5. Furnace logs show no errors

### Notes
- Priority fix - blocks core progression
- Related files: crucible.lua (recipe registration section)
- Verify: `minetest.register_craft` calls for smelting recipes
- Check: All 6 uncured items registered before recipes defined
- Consider: Add debug logging to track which recipes are actually registered

### Investigation Findings

**TRANSFERRED TO: [minetest_lava_powered_furnace/BUG_REPORT.md](../minetest_lava_powered_furnace/BUG_REPORT.md)**

**Root Cause Identified**: This issue is NOT in the lava_crucible mod. Testing confirms:
- ✅ All 6 recipes ARE properly defined and registered in lava_crucible
- ✅ Recipes work fine with regular Luanti furnace
- ❌ Issue only occurs with lava_powered_furnace as fuel source
- ✅ Debug logs verify recipes register 100% successfully

**Conclusion**: The root cause is in the lava_powered_furnace mod's recipe handling, not in the lava_crucible recipe definitions themselves.

**Resolution**: Issue transferred to minetest_lava_powered_furnace project for investigation and fix.

---

## Bug 4: Ender Crucibles Won't Open GUI

Date: 2026-06-02
Status: Resolved - User Error
Severity: High

### Summary
Medium and large (double/quad) ender crucibles fail to open their GUI when right-clicked. Single ender crucibles work correctly.

### Environment
- OS: Linux
- Context: Manual testing in Luanti
- Version: Latest from GitHub (Jun 2, 2026)

### Steps To Reproduce
1. Place single ender crucible
2. Right-click it
3. **Result:** GUI opens correctly ✓
4. Place double ender crucible
5. Right-click it
6. **Result:** No GUI appears ✗
7. Place quad ender crucible
8. Right-click it
9. **Result:** No GUI appears ✗

### Expected Result
- All three ender crucible tiers open a formspec GUI
- Player can access inventory for all tiers
- Double crucible shows 2 input, 2 soil output, 2 dust output slots
- Quad crucible shows 4 input, 4 soil output, 4 dust output slots

### Actual Result
- Single ender crucible: GUI opens ✓
- Double ender crucible: Right-click does nothing
- Quad ender crucible: Right-click does nothing

### Logs/Error Output
Check debug.txt for on_rightclick errors

### Likely Cause
- `on_rightclick` callback may not be registered for double/quad ender nodes
- Formspec generation may fail for double/quad due to slot count mismatch
- Ender inventory lookup may fail for non-single tiers
- Node definitions for `lava_crucible_ender_double*` and `lava_crucible_ender_quad*` may not have `on_rightclick` set

### Impact
- **HIGH:** Makes larger ender crucibles completely non-functional
- Players cannot access inventory
- May prevent dust/soil collection for those tiers

### Acceptance Criteria
1. All three ender tiers open GUI on right-click
2. Formspec displays correct inventory slot counts
3. GUI is responsive and shows inventory state correctly
4. No errors in debug.txt

### Notes
- Check if `on_rightclick` is set in tier-specific node definitions
- Verify formspec generation handles double/quad slot counts
- Compare single tier implementation to double/quad
- May be a copy-paste error in node def or callback assignment

### Investigation Status (2026-06-02 - RESOLVED)

**Root Cause**: User Error - Uncured ender crucible placed instead of cured ender crucible.

**Explanation**:
- Uncured ender crucibles (e.g., `lava_crucible:uncured_ender_double`) cannot be right-clicked to open GUI
- Only CURED ender crucibles (e.g., `lava_crucible:lava_crucible_ender_double`) have the on_rightclick handler
- User had placed uncured variant, so on_rightclick was not defined

**Resolution**: Issue was operator error during testing. Code is correct and functions as designed.

**Testing Verification**:
- ✅ Cured single ender crucible: GUI opens correctly
- ✅ Cured double ender crucible: GUI opens correctly  
- ✅ Cured quad ender crucible: GUI opens correctly
- ✅ All debug logging confirms handlers are invoked and formspecs display properly

---

## Bug 5: Drop-In Feature Is Undocumented

Date: 2026-06-02
Status: Open
Severity: Low

### Summary
The drop-in feature (collecting dropped stone items above crucibles) exists but is not documented in USAGE.md or other user-facing docs.

### Environment
- OS: Linux
- Context: Feature discovery during testing
- Version: Latest from GitHub (Jun 2, 2026)

### Steps To Reproduce
1. Drop stone items above a crucible
2. Observe: They disappear and appear in crucible input inventory
3. **Finding:** This feature works but is undocumented

### Expected Result
- USAGE.md explains the drop-in mechanic
- User knows they can drop items or use GUI
- Behavior is documented with clear examples

### Actual Result
- Feature works but is not documented
- Users discover it by accident or trial-and-error

### Logs/Error Output
N/A

### Likely Cause
- Documentation written before drop-in feature was implemented
- Or: Feature was added but docs weren't updated

### Impact
- Low: Feature works, just not advertised
- Users may not know about convenient drop-in method
- Reduces discoverability

### Acceptance Criteria
1. USAGE.md documents the drop-in behavior
2. Includes example: "Drop stone items above the crucible"
3. Explains: Items are automatically collected into input slots
4. Notes: Works only when input slots have space
5. Documents: Can also use GUI to add items directly

### Notes
- Low priority fix
- Mainly a documentation task
- Add to USAGE.md under "Feeding Items to Crucible" section

