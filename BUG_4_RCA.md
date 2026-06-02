# Bug #4 Root Cause Analysis: Ender Crucibles Won't Open GUI

**Investigation Date**: June 2, 2026  
**Status**: Investigation in Progress - Awaiting Debug Logs  
**Severity**: High (makes larger ender tiers non-functional)

---

## Executive Summary

Initial code review confirms that **all ender crucible variants (single, double, quad) have properly defined `on_rightclick` handlers** in the mod code. The handlers contain formspec generation and display logic.

**The code appears correct**, which means the issue is likely in one of these categories:
1. Handler is not being called (node definition issue)
2. Handler has a Lua error during execution (formspec generation fails)
3. Handler calls `minetest.show_formspec()` but GUI doesn't display to player

A modified version of the mod with detailed debug logging has been deployed to help identify which scenario is occurring.

---

## Initial Code Analysis

### Node Definition Structure

All ender crucible variants follow the same inheritance pattern:

```
crucible_common (base with on_rightclick handler)
└─ crucible_ender_common (cloned, inherits on_rightclick)
   ├─ crucible_ender_double_common (cloned, on_rightclick DEFINED) ✓
   └─ crucible_ender_quad_common (cloned, on_rightclick DEFINED) ✓
```

### Single Ender (WORKS ✓)
- Node: `lava_crucible:lava_crucible_ender`
- Handler: Inherited from `crucible_ender_common`
- Status: **GUI opens correctly when right-clicked**

### Double Ender (FAILS ✗)
- Cold Node: `lava_crucible:lava_crucible_ender_double`
- Hot Nodes: `lava_crucible_ender_double_hot`, `_hot_empty`, `_hot_done`
- Handler: **Defined in `crucible_ender_double_common`** (lines 1114-1162)
- Handler Details:
  - Checks player validity
  - Gets ender inventory for "double" tier
  - Generates formspec with 2x1 input slots, 2x1 soil output slots
  - Calls `minetest.show_formspec()`
- Status: **Right-click does nothing**

### Quad Ender (FAILS ✗)
- Cold Node: `lava_crucible:lava_crucible_ender_quad`
- Hot Nodes: `lava_crucible_ender_quad_hot`, `_hot_empty`, `_hot_done`
- Handler: **Defined in `crucible_ender_quad_common`** (lines 1264-1322)
- Handler Details:
  - Checks player validity
  - Gets ender inventory for "quad" tier
  - Generates formspec with 4x1 input slots, 4x1 soil output slots
  - Calls `minetest.show_formspec()`
- Status: **Right-click does nothing**

---

## Hypotheses

### Hypothesis 1: `on_rightclick` Not Being Called
**Likelihood**: 25%
**Evidence**: Single ender works, so handler system works in general
**Would show in logs**: No `[lava_crucible] DEBUG: on_rightclick called` messages
**Root Cause**: 
- Node definition issues for double/quad variants
- Possible override of on_rightclick with nil or missing callback

### Hypothesis 2: Handler Called But Lua Error Occurs
**Likelihood**: 60%
**Evidence**: Common cause of handlers appearing to not work
**Would show in logs**: Initial log line `on_rightclick called`, but NOT the completion message
**Possible Error Locations**:
- `get_ender_inventory()` fails (line 1121, 1271)
- Formspec string concatenation fails
- `minetest.show_formspec()` fails (unlikely but possible)

### Hypothesis 3: GUI Requested But Not Displayed
**Likelihood**: 15%
**Evidence**: Least common for this type of handler
**Would show in logs**: Full completion message, but player doesn't see GUI
**Root Cause**: Client-side issue or formspec syntax error

---

## Debug Logging Points Added

Modified crucible.lua now contains the following logging for ender double and quad handlers:

### 1. Handler Invocation
```lua
[lava_crucible] DEBUG: on_rightclick called for lava_crucible_ender_double at pos <pos>
[lava_crucible] DEBUG: Ender double on_rightclick - player: <playername>
```
**Purpose**: Confirm handler is being called

### 2. Inventory Retrieval
Code checks player validity but doesn't log yet - critical next step

### 3. Formspec Generation
```lua
[lava_crucible] DEBUG: Showing formspec for ender_double: <playername>
[lava_crucible] DEBUG: Formspec shown for ender_double: <playername>
```
**Purpose**: Confirm formspec is generated and display is attempted

### 4. Completion
```lua
[lava_crucible] DEBUG: ender_double on_rightclick handler completed successfully
[lava_crucible] DEBUG: ender_quad on_rightclick handler completed successfully
```
**Purpose**: Confirm handler reaches completion without errors

---

## Testing Instructions

To gather debug logs, perform these steps:

### Step 1: Start Luanti Server
```bash
luanti --server ~/.minetest/worlds/1 > /tmp/bug4-debug.log 2>&1 &
```

### Step 2: Connect to Server and Test
1. Connect as a player
2. Place a **single ender crucible** - test that GUI opens (should work ✓)
3. Place a **double ender crucible** - right-click it, observe if GUI opens (currently fails ✗)
4. Place a **quad ender crucible** - right-click it, observe if GUI opens (currently fails ✗)

### Step 3: Extract Relevant Logs
```bash
kill %1  # Stop server
grep "\[lava_crucible\].*DEBUG.*ender" /tmp/bug4-debug.log
```

---

## Expected Log Outputs

### If Handler Is NOT Being Called
```
[No output - handler never prints]
```
→ **Diagnosis**: on_rightclick not registered or being overridden

### If Handler Is Being Called But Fails
```
[lava_crucible] DEBUG: on_rightclick called for lava_crucible_ender_double at pos <pos>
[lava_crucible] DEBUG: Ender double on_rightclick - player: <player>
[lava_crucible] DEBUG: Showing formspec for ender_double: <player>
[lava_crucible] DEBUG: Formspec shown for ender_double: <player>
[Server ERROR]: ... (Lua error message)
```
→ **Diagnosis**: Error occurs during handler execution (check server log for error)

### If Handler Works Successfully
```
[lava_crucible] DEBUG: on_rightclick called for lava_crucible_ender_double at pos <pos>
[lava_crucible] DEBUG: Ender double on_rightclick - player: <player>
[lava_crucible] DEBUG: Showing formspec for ender_double: <player>
[lava_crucible] DEBUG: Formspec shown for ender_double: <player>
[lava_crucible] DEBUG: ender_double on_rightclick handler completed successfully
```
→ **Diagnosis**: Handler works! GUI display failure likely a client-side issue

---

## Preliminary Assessment

Based on code review alone:
- All required callbacks appear to be defined correctly
- Formspec generation logic looks sound
- No obvious bugs in handler implementation

**This suggests the issue is environmental or relies on specific runtime conditions** that only manifest with double/quad tiers but not single tier.

---

## Next Steps After Log Collection

1. **Analyze logs** to determine which scenario occurred
2. **If handler not called**: Investigate node definition for missing/nil callback
3. **If handler fails**: Extract and diagnose Lua error
4. **If handler succeeds**: Investigate formspec syntax or client-side issues

See next section in this document once logs are collected.

---

## Change Log

- **2026-06-02**: Added debug logging to crucible.lua
  - Lines 1117-1119: on_rightclick entry logging for ender_double
  - Lines 1153-1155: Formspec display logging for ender_double
  - Lines 1162: Handler completion logging for ender_double
  - Lines 1267-1269: on_rightclick entry logging for ender_quad
  - Lines 1314-1316: Formspec display logging for ender_quad
  - Lines 1323: Handler completion logging for ender_quad
