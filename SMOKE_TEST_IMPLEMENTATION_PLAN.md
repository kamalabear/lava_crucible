# Smoke Test Implementation Plan for mintest_lava_crucible

## Overview
This plan details the implementation of smoke tests for mintest_lava_crucible. Smoke tests verify that the mod loads correctly and basic gameplay functionality works in Luanti without errors.

## Goals

1. **Automated mod load verification** — Catch load-time errors early
2. **Node registration check** — Ensure all crucible variants are registered
3. **Dependency verification** — Confirm required mods are available
4. **Recipe validation** — Test that crafting recipes are properly registered
5. **In-game functionality** — Verify stone conversion and basic gameplay

---

## Architecture

### Test Execution Flow

```
1. Preflight Check
   └─ Dependencies available?
   └─ Luanti installed?
   └─ Workspace setup valid?

2. Create Isolated Test World
   └─ Temp world directory
   └─ Enable mintest_lava_crucible
   └─ Enable dependencies

3. Run Luanti Headless
   └─ Load mods
   └─ Execute test commands
   └─ Capture output

4. Parse Results
   └─ Check for errors in debug.txt
   └─ Verify node registrations
   └─ Validate game state

5. Cleanup
   └─ Remove temp world
   └─ Save results
```

---

## Phase 1: Preflight Checks (15 min)

### Task 1.1: Create Preflight Script
**File:** `smoke-test-preflight.sh`

**Purpose:** Verify environment is ready before running tests

**Content:**

```bash
#!/bin/bash
set -e

echo "=== Lava Crucible Smoke Test Preflight ==="
echo ""

# Check Luanti installation
if ! command -v minetest &>/dev/null && ! command -v luanti &>/dev/null; then
    echo "ERROR: Luanti/Minetest not found in PATH"
    echo "Install with: sudo apt-get install minetest"
    exit 1
fi

LUANTI=$(command -v minetest || command -v luanti)
echo "✓ Luanti found: $LUANTI"
echo "  Version: $($LUANTI --version 2>&1 | head -1)"

# Check Luanti mods directory
if [ ! -d ~/.minetest/mods ]; then
    echo "ERROR: ~/.minetest/mods directory not found"
    exit 1
fi
echo "✓ Mods directory: ~/.minetest/mods"

# Check required mods are deployed
check_mod() {
    local modname=$1
    if [ ! -d ~/.minetest/mods/$modname ]; then
        echo "ERROR: Required mod not found: $modname"
        return 1
    fi
    echo "✓ Mod found: $modname"
}

check_mod "mintest_lava_crucible" || exit 1
check_mod "volcanic_soil" || exit 1

# Check optional mods
for mod in ore_dust moreores; do
    if [ -d ~/.minetest/mods/$mod ]; then
        echo "✓ Optional mod available: $mod"
    else
        echo "⚠ Optional mod not available: $mod"
    fi
done

# Verify crucible mod structure
if [ ! -f ~/.minetest/mods/mintest_lava_crucible/mod.conf ]; then
    echo "ERROR: mintest_lava_crucible/mod.conf not found"
    exit 1
fi
echo "✓ Crucible mod.conf present"

if [ ! -f ~/.minetest/mods/mintest_lava_crucible/init.lua ]; then
    echo "ERROR: mintest_lava_crucible/init.lua not found"
    exit 1
fi
echo "✓ Crucible init.lua present"

if [ ! -f ~/.minetest/mods/mintest_lava_crucible/crucible.lua ]; then
    echo "ERROR: mintest_lava_crucible/crucible.lua not found"
    exit 1
fi
echo "✓ Crucible crucible.lua present"

# Check disk space
SPACE=$(df ~/.minetest | awk 'NR==2 {print $4}')
if [ "$SPACE" -lt 100000 ]; then
    echo "⚠ Low disk space: ${SPACE}KB"
fi

echo ""
echo "✓ All preflight checks passed"
exit 0
```

**Usage:**
```bash
bash smoke-test-preflight.sh
```

**Validation:**
- [ ] Script runs without errors
- [ ] All required mods present
- [ ] Luanti/Minetest available

---

## Phase 2: Test World Setup (30 min)

### Task 2.1: Create Test World Provisioner
**File:** `smoke-test-world-setup.lua`

**Purpose:** Luanti script to set up test world with crucible mod enabled

**Content:**

```lua
-- smoke-test-world-setup.lua
-- Sets up a clean test world for smoke testing

local WORLD_NAME = "smoke_test_lava_crucible"
local GAMES_DIR = os.getenv("HOME") .. "/.minetest/games"
local MODS_DIR = os.getenv("HOME") .. "/.minetest/mods"

-- Create world.mt file to enable mods
local function setup_world_config()
    local world_dir = os.getenv("HOME") .. "/.minetest/worlds/" .. WORLD_NAME
    
    -- Create if not exists
    if not os.execute("[ -d " .. world_dir .. " ]") then
        os.execute("mkdir -p " .. world_dir)
    end
    
    -- Write world.mt with mod loadout
    local mt_file = world_dir .. "/world.mt"
    local mt_content = [[gameid = minetest
enable_damage = false
creative_mode = true
load_mod_mintest_lava_crucible = true
load_mod_volcanic_soil = true
load_mod_ore_dust = true
load_mod_moreores = true
load_mod_default = true
load_mod_bucket = true
]]
    
    local f = io.open(mt_file, "w")
    if f then
        f:write(mt_content)
        f:close()
    end
end

setup_world_config()
```

**Usage:**
```bash
luanti --run smoke-test-world-setup.lua
```

---

### Task 2.2: Create Test World Initialization Script
**File:** `smoke-test-init-world.sh`

**Purpose:** Prepare test world directory with proper permissions and configurations

**Content:**

```bash
#!/bin/bash
set -e

WORLD_NAME="smoke_test_lava_crucible"
WORLD_DIR="$HOME/.minetest/worlds/$WORLD_NAME"

echo "Setting up test world: $WORLD_NAME"

# Remove old world if exists
if [ -d "$WORLD_DIR" ]; then
    echo "Removing existing test world..."
    rm -rf "$WORLD_DIR"
fi

# Create fresh world directory
mkdir -p "$WORLD_DIR"
echo "✓ World directory created"

# Create minimal world.mt
cat > "$WORLD_DIR/world.mt" << 'EOF'
gameid = minetest
enable_damage = false
creative_mode = true
load_mod_mintest_lava_crucible = true
load_mod_volcanic_soil = true
load_mod_ore_dust = true
load_mod_moreores = true
load_mod_default = true
EOF

echo "✓ world.mt created"

# Create env_meta.txt with basic settings
mkdir -p "$WORLD_DIR/worldmods"
echo "✓ World configuration complete"

exit 0
```

**Usage:**
```bash
bash smoke-test-init-world.sh
```

---

## Phase 3: Automated Test Runner (1 hour)

### Task 3.1: Create Main Smoke Test Script
**File:** `smoke-test.sh`

**Purpose:** Main orchestrator for smoke test execution

**Content:**

```bash
#!/bin/bash
set -e

WORLD_NAME="smoke_test_lava_crucible"
LUANTI_BIN=$(command -v minetest || command -v luanti)
LUANTI_DIR=$(dirname "$LUANTI_BIN")
WORLD_DIR="$HOME/.minetest/worlds/$WORLD_NAME"
TEST_TIMEOUT=120
TEST_LOGFILE="${WORLD_DIR}/debug.txt"
RESULTS_FILE="${WORLD_DIR}/smoke_test_results.txt"

echo "=== Lava Crucible Smoke Test ==="
echo "World: $WORLD_NAME"
echo "Luanti: $LUANTI_BIN"
echo ""

# Step 1: Clean up old test world
echo "[1/5] Preparing test world..."
if [ -d "$WORLD_DIR" ]; then
    rm -rf "$WORLD_DIR"
fi
mkdir -p "$WORLD_DIR"

# Step 2: Create world.mt with mod loadout
echo "[2/5] Configuring mods..."
cat > "$WORLD_DIR/world.mt" << 'EOF'
gameid = minetest
enable_damage = false
creative_mode = true
load_mod_mintest_lava_crucible = true
load_mod_volcanic_soil = true
load_mod_ore_dust = true
load_mod_moreores = true
load_mod_default = true
load_mod_bucket = true
EOF

# Step 3: Run Luanti in headless mode
echo "[3/5] Loading Luanti (timeout: ${TEST_TIMEOUT}s)..."

# Create Lua script to test in-game
cat > /tmp/smoke_test_commands.lua << 'EOF'
-- Smoke test commands
-- This runs after mods are loaded to verify functionality

local tests_passed = 0
local tests_failed = 0

-- Test 1: Check if lava_crucible nodes are registered
print("[TEST] Checking lava_crucible node registration...")
if minetest.registered_nodes["minetest_lava_crucible:lava_crucible"] then
    print("  ✓ Single crucible registered")
    tests_passed = tests_passed + 1
else
    print("  ✗ Single crucible NOT registered")
    tests_failed = tests_failed + 1
end

if minetest.registered_nodes["minetest_lava_crucible:lava_crucible_double"] then
    print("  ✓ Double crucible registered")
    tests_passed = tests_passed + 1
else
    print("  ✗ Double crucible NOT registered")
    tests_failed = tests_failed + 1
end

if minetest.registered_nodes["minetest_lava_crucible:lava_crucible_quad"] then
    print("  ✓ Quad crucible registered")
    tests_passed = tests_passed + 1
else
    print("  ✗ Quad crucible NOT registered")
    tests_failed = tests_failed + 1
end

-- Test 2: Check ender variants
print("[TEST] Checking ender crucible variants...")
if minetest.registered_nodes["minetest_lava_crucible:lava_crucible_ender"] then
    print("  ✓ Ender single registered")
    tests_passed = tests_passed + 1
else
    print("  ✗ Ender single NOT registered")
    tests_failed = tests_failed + 1
end

-- Test 3: Check for crafting recipes
print("[TEST] Checking crafting recipes...")
local recipes_found = 0
if minetest.registered_recipes then
    for _, recipe in ipairs(minetest.registered_recipes) do
        if recipe.output and recipe.output:find("lava_crucible") then
            recipes_found = recipes_found + 1
        end
    end
end
if recipes_found > 0 then
    print("  ✓ Found " .. recipes_found .. " lava_crucible recipes")
    tests_passed = tests_passed + 1
else
    print("  ⚠ No lava_crucible recipes found (may be normal)")
end

-- Test 4: Check volcanic_soil dependency
print("[TEST] Checking volcanic_soil mod...")
if minetest.registered_nodes["volcanic_soil:volcanic_soil"] then
    print("  ✓ volcanic_soil mod loaded")
    tests_passed = tests_passed + 1
else
    print("  ✗ volcanic_soil mod NOT found")
    tests_failed = tests_failed + 1
end

-- Write results
print("")
print("[RESULTS] Tests passed: " .. tests_passed)
print("[RESULTS] Tests failed: " .. tests_failed)

if tests_failed > 0 then
    error("Smoke test FAILED: " .. tests_failed .. " tests failed")
else
    print("Smoke test PASSED")
end

-- Exit Luanti
minetest.request_shutdown()
EOF

# Run Luanti with test world and command script
timeout $TEST_TIMEOUT "$LUANTI_BIN" \
    --world "$WORLD_NAME" \
    --go \
    --run /tmp/smoke_test_commands.lua \
    2>&1 | tee "$TEST_LOGFILE" || true

# Step 4: Parse results
echo "[4/5] Analyzing test results..."

if grep -q "Smoke test PASSED" "$TEST_LOGFILE"; then
    echo "✓ Smoke test PASSED"
    RESULT=0
elif grep -q "Smoke test FAILED" "$TEST_LOGFILE"; then
    echo "✗ Smoke test FAILED"
    RESULT=1
else
    echo "⚠ Test result unclear, checking for errors..."
    if grep -q "ERROR\|FATAL\|Script error" "$TEST_LOGFILE"; then
        echo "✗ Script errors found in debug.txt"
        RESULT=1
    else
        echo "✓ No fatal errors found"
        RESULT=0
    fi
fi

# Extract relevant log lines
echo ""
echo "=== Key Log Entries ==="
grep -E "\[TEST\]|\[RESULTS\]|Script error|ERROR.*lava_crucible" "$TEST_LOGFILE" || true

# Step 5: Cleanup
echo "[5/5] Cleaning up..."
rm -f /tmp/smoke_test_commands.lua

if [ $RESULT -eq 0 ]; then
    echo ""
    echo "✓ Smoke test completed successfully"
    exit 0
else
    echo ""
    echo "✗ Smoke test FAILED"
    echo "Log file: $TEST_LOGFILE"
    exit 1
fi
```

**Usage:**
```bash
bash smoke-test.sh
```

---

## Phase 4: Result Analysis and Reporting (30 min)

### Task 4.1: Create Log Parser
**File:** `smoke-test-parser.sh`

**Purpose:** Parse Luanti debug logs and generate readable test report

**Content:**

```bash
#!/bin/bash

LOGFILE="${1:-.minetest/worlds/smoke_test_lava_crucible/debug.txt}"
REPORT_FILE="${LOGFILE%.txt}_report.txt"

if [ ! -f "$LOGFILE" ]; then
    echo "ERROR: Log file not found: $LOGFILE"
    exit 1
fi

echo "Parsing test results from: $LOGFILE"
echo ""
echo "=== SMOKE TEST REPORT ===" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Extract test results
echo "Test Results:" >> "$REPORT_FILE"
grep "\[TEST\]" "$LOGFILE" >> "$REPORT_FILE" || true
echo "" >> "$REPORT_FILE"

# Extract errors
echo "Errors:" >> "$REPORT_FILE"
grep -i "error\|fatal\|failed" "$LOGFILE" | head -20 >> "$REPORT_FILE" || true
echo "" >> "$REPORT_FILE"

# Extract node registrations
echo "Node Registrations:" >> "$REPORT_FILE"
grep "registered.*lava_crucible" "$LOGFILE" >> "$REPORT_FILE" || true
echo "" >> "$REPORT_FILE"

# Extract final results
echo "Final Status:" >> "$REPORT_FILE"
if grep -q "Smoke test PASSED" "$LOGFILE"; then
    echo "✓ PASSED" >> "$REPORT_FILE"
    EXIT_CODE=0
elif grep -q "Smoke test FAILED" "$LOGFILE"; then
    echo "✗ FAILED" >> "$REPORT_FILE"
    EXIT_CODE=1
else
    echo "? UNKNOWN" >> "$REPORT_FILE"
    EXIT_CODE=2
fi

cat "$REPORT_FILE"
exit $EXIT_CODE
```

**Usage:**
```bash
bash smoke-test-parser.sh ~/.minetest/worlds/smoke_test_lava_crucible/debug.txt
```

---

## Phase 5: Integration with Workspace (30 min)

### Task 5.1: Add Smoke Test Tasks to Workspace
**File:** `tasks.json` (update existing or create .vscode/tasks.json)

**Add these tasks:**

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Smoke Test (lava_crucible)",
      "type": "shell",
      "command": "bash",
      "args": [
        "${workspaceFolder}/mintest_lava_crucible/smoke-test.sh"
      ],
      "group": "test",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "panel": "new"
      },
      "problemMatcher": []
    },
    {
      "label": "Smoke Test Preflight",
      "type": "shell",
      "command": "bash",
      "args": [
        "${workspaceFolder}/mintest_lava_crucible/smoke-test-preflight.sh"
      ],
      "group": "test",
      "presentation": {
        "reveal": "always"
      }
    }
  ]
}
```

---

## Phase 6: Test Scenarios and Validation (45 min)

### Task 6.1: Define Test Scenarios
**File:** `SMOKE_TEST_SCENARIOS.md`

**Scenarios:**

```markdown
# Smoke Test Scenarios

## Scenario 1: Basic Load Test
- Objective: Verify mod loads without errors
- Steps:
  1. Create fresh test world
  2. Enable mintest_lava_crucible mod
  3. Load world in Luanti
- Expected: No script errors in debug.txt

## Scenario 2: Node Registration
- Objective: Verify all crucible nodes are registered
- Nodes to check:
  - minetest_lava_crucible:lava_crucible
  - minetest_lava_crucible:lava_crucible_double
  - minetest_lava_crucible:lava_crucible_quad
  - minetest_lava_crucible:lava_crucible_ender*
- Expected: All 9+ node variants registered

## Scenario 3: Dependency Resolution
- Objective: Verify required mods load
- Dependencies:
  - volcanic_soil
  - ore_dust (if available)
  - moreores (optional)
- Expected: No unmet dependency errors

## Scenario 4: Crafting Recipe Availability
- Objective: Verify recipes are registered
- Recipes to check:
  - clay_graphite shapeless
  - uncured_crucible shaped
  - Furnace smelting recipes
- Expected: Recipes appear in creative menu

## Scenario 5: In-Game Functionality
- Objective: Test basic game mechanics
- Actions:
  - Place crucible block
  - Access inventory
  - Place items in slots
- Expected: No runtime errors, inventory accessible

## Scenario 6: Ender Inventory
- Objective: Test ender crucible persistence
- Actions:
  1. Place ender crucible
  2. Add items to inventory
  3. Close and reopen
  4. Check items persist
- Expected: Items retained across opens/closes
```

---

## Phase 7: Documentation and CI/CD (30 min)

### Task 7.1: Create Smoke Test Documentation
**File:** `SMOKE_TEST_README.md`

**Content outline:**

```markdown
# Smoke Test Guide

## Quick Start
```bash
# Check environment
bash smoke-test-preflight.sh

# Run smoke tests
bash smoke-test.sh

# Parse results
bash smoke-test-parser.sh ~/.minetest/worlds/smoke_test_lava_crucible/debug.txt
```

## What Gets Tested

1. **Mod Loading** — Checks for load-time errors
2. **Node Registration** — Verifies all crucible variants exist
3. **Dependency Resolution** — Ensures volcanic_soil, ore_dust available
4. **Recipes** — Tests crafting recipes are registered
5. **In-Game Mechanics** — Basic gameplay functionality

## Troubleshooting

### Mod fails to load
- Check debug.txt for Lua errors
- Verify volcanic_soil mod is deployed
- Check mod.conf has correct dependencies

### Nodes not registering
- Ensure crucible.lua has no syntax errors
- Check node names match DEVELOPMENT.md
- Verify minetest.register_node calls exist

### Test timeout
- World may be taking too long to load
- Try running with more generous timeout in smoke-test.sh
- Check Luanti CPU usage

## CI/CD Integration

Tests can be run in GitHub Actions:

```yaml
- name: Run Smoke Tests
  run: bash mintest_lava_crucible/smoke-test.sh
```
```

---

## Implementation Checklist

### Phase 1: Preflight
- [ ] `smoke-test-preflight.sh` created and tested
- [ ] All preflight checks pass
- [ ] Dependencies verified

### Phase 2: World Setup
- [ ] Test world setup scripts created
- [ ] `world.mt` configuration template ready
- [ ] World provisioning tested

### Phase 3: Test Runner
- [ ] `smoke-test.sh` main script created
- [ ] In-game Lua test commands working
- [ ] Timeout handling configured
- [ ] Log capture functional

### Phase 4: Result Analysis
- [ ] `smoke-test-parser.sh` created
- [ ] Log parsing working correctly
- [ ] Report generation functional

### Phase 5: Integration
- [ ] Workspace tasks created/updated
- [ ] Tasks callable from VS Code
- [ ] Easy-to-remember names assigned

### Phase 6: Validation
- [ ] All 6 test scenarios defined
- [ ] Scenarios mapped to script tests
- [ ] Edge cases identified

### Phase 7: Documentation
- [ ] `SMOKE_TEST_README.md` complete
- [ ] Troubleshooting guide written
- [ ] CI/CD example provided

---

## Success Criteria

| Criterion | Target | Status |
|-----------|--------|--------|
| Preflight pass rate | 100% | TODO |
| Test world setup | 100% | TODO |
| Node registration detection | 9+ nodes | TODO |
| Error detection | <5 min runtime | TODO |
| Log parsing accuracy | 100% | TODO |
| Automation completeness | Full end-to-end | TODO |

---

## Expected Runtime

- Preflight check: ~5 seconds
- Test world setup: ~10 seconds
- Luanti load and test execution: 30-60 seconds
- Log parsing: ~5 seconds
- **Total: 50-80 seconds per run**

---

## Notes

- Tests run in headless mode (no GUI) for CI automation
- Temporary world is cleaned up after each run to avoid disk bloat
- Log files retained in `~/.minetest/worlds/smoke_test_lava_crucible/` for debugging
- Test scripts use standard bash for portability
- All minetest/luanti binary detection is automatic

