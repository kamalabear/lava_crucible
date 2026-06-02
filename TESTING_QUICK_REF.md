# Quick Reference: Testing lava_crucible

Quick commands for running tests during development.

## Unit Tests (Fast - ~26ms)

Run the unit test suite:

```bash
cd /media/kc/storage/Workspace/mintest_lava_crucible
busted
```

Run specific test file:

```bash
busted spec/crucible_spec.lua
busted spec/ender_spec.lua
```

Watch for changes and re-run:

```bash
# Install: npm install -g busted-watch (optional)
busted --watch
```

## Smoke Tests (Medium - ~1-5 min)

### Preflight (quick environment check)

```bash
cd /media/kc/storage/Workspace
bash .github/scripts/smoke-test-preflight.sh
```

### Basic smoke test (uses default deps resolution)

```bash
cd /media/kc/storage/Workspace
bash .github/scripts/smoke-test.sh lava_crucible mintest_lava_crucible
```

### CI Profile (what GitHub Actions runs)

```bash
cd /media/kc/storage/Workspace
SMOKE_TEST_DEP_SOURCE=hybrid \
SMOKE_TEST_STUB_FIRST_DEPS=moreblocks \
bash .github/scripts/smoke-test.sh lava_crucible mintest_lava_crucible
```

### Verify error detection (guardrail test - should FAIL)

```bash
cd /media/kc/storage/Workspace
bash .github/scripts/smoke-test.sh smoke_fail_mod .github/test-fixtures/smoke_fail_mod
```

(Expected: SMOKE TEST FAILED — this confirms error detection works)

## Manual Testing (Variable)

### Deploy to local Luanti

```bash
cd /media/kc/storage/Workspace
rsync -r --exclude '.git' mintest_lava_crucible/ ~/.minetest/mods/lava_crucible/
```

Then open Luanti and enable the mod.

### Check for Lua syntax errors

```bash
cd /media/kc/storage/Workspace/mintest_lava_crucible
luacheck crucible.lua init.lua metal_dust.lua --config .luacheckrc
```

## All Tests (Unit + Smoke)

```bash
# Unit tests
cd /media/kc/storage/Workspace/mintest_lava_crucible
busted

# Smoke test
cd /media/kc/storage/Workspace
bash .github/scripts/smoke-test.sh lava_crucible mintest_lava_crucible
```

## Test Coverage

| Test Type | Speed | Coverage | Runtime Env |
|-----------|-------|----------|-------------|
| Unit Tests | ⚡ Fast | 85%+ | Mocked Minetest API |
| Smoke Tests | 🐢 Slow | Load/Basic | Real Luanti in Docker |
| Manual Tests | 📊 Variable | ~100% | Real Luanti locally |

## Documentation

- **[TESTING_REQUIREMENTS.md](TESTING_REQUIREMENTS.md)** — What needs to be tested
- **[TEST_PLAN.md](TEST_PLAN.md)** — Complete testing strategy
- **[UNIT_TEST_IMPLEMENTATION_PLAN.md](UNIT_TEST_IMPLEMENTATION_PLAN.md)** — Unit test details
- **[SMOKE_TESTS.md](SMOKE_TESTS.md)** — Comprehensive smoke test guide
- **[BUG_REPORT.md](BUG_REPORT.md)** — Known issues and resolved bugs

## VS Code Tasks

Run from Command Palette (Ctrl+Shift+P):

- **Test: Lua (Workspace)** — Run all unit tests
- **Test: Lua (Changed Files)** — Lint changed files
- **Smoke Test (CI Profile)** — Run smoke test with CI settings
- **Lint Lua (Workspace)** — Check for Lua style issues

## Troubleshooting

**Unit tests fail:**
```bash
cd mintest_lava_crucible
# Check if busted is installed
busted --version
# If not: luarocks install busted
```

**Smoke test fails:**
```bash
# Check Docker
docker ps
# Check that mods are deployed
ls ~/.minetest/mods/lava_crucible/
# Check logs
tail -50 .smoke-test-runtime/tmp/smoke-test-*.log
```

**Lua syntax errors:**
```bash
# Install luacheck if needed
luarocks install luacheck
# Then run checks
luacheck crucible.lua
```
