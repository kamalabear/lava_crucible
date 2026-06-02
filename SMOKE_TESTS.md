# Smoke Tests for lava_crucible

This document explains how to run smoke tests for the lava_crucible mod.

## Overview

Smoke tests verify that the mod loads successfully in Luanti without errors and that basic dependencies are resolved correctly. Tests run in a Docker container to ensure a clean, isolated environment.

## Prerequisites

- Docker (user must be in docker group)
- Git
- Curl
- Bash 4+
- The workspace cloned and set up

## Quick Start

### Run Preflight Checks

Verify your environment is ready:

```bash
cd /media/kc/storage/Workspace
bash .github/scripts/smoke-test-preflight.sh
```

Expected output:
```
[preflight] OK: found command: git
[preflight] OK: found command: curl
[preflight] OK: found command: docker
[preflight] OK: docker daemon is accessible
[preflight] complete
```

### Run Smoke Test for lava_crucible

Basic test with default configuration:

```bash
cd /media/kc/storage/Workspace
bash .github/scripts/smoke-test.sh lava_crucible mintest_lava_crucible
```

### Run with Specific Dependency Configuration

**CI Profile** (stubs for moreblocks, workspace for lava_crucible deps):

```bash
cd /media/kc/storage/Workspace
export SMOKE_TEST_DEP_SOURCE=hybrid
export SMOKE_TEST_STUB_FIRST_DEPS=moreblocks
export SMOKE_TEST_WORKSPACE_FIRST_DEPS=
bash .github/scripts/smoke-test.sh lava_crucible mintest_lava_crucible
```

**Development Profile** (use local Luanti install mods when available):

```bash
cd /media/kc/storage/Workspace
export SMOKE_TEST_DEP_SOURCE=local
bash .github/scripts/smoke-test.sh lava_crucible mintest_lava_crucible
```

**Strict Stubs** (minimal stubs only, ignores workspace):

```bash
cd /media/kc/storage/Workspace
export SMOKE_TEST_DEP_SOURCE=strict
bash .github/scripts/smoke-test.sh lava_crucible mintest_lava_crucible
```

## Environment Variables

### Execution Control

- `SMOKE_TEST_TIMEOUT` — Boot timeout in seconds (default: 30)
- `SMOKE_TEST_IMAGE` — Docker image name (default: `luanti-smoke-test:latest`)

### Dependency Resolution

- `SMOKE_TEST_DEP_SOURCE` — Strategy for resolving dependencies
  - `strict` — Use only stubs, ignore workspace/local
  - `workspace` — Try workspace first, then stubs
  - `local` — Try local Luanti install first, then stubs
  - `hybrid` — Configurable precedence (default)

- `SMOKE_TEST_STUB_FIRST_DEPS` — CSV list of deps to prefer stubs for (e.g., `moreblocks,moreores`)
- `SMOKE_TEST_WORKSPACE_FIRST_DEPS` — CSV list of deps to prefer workspace for

### Docker & Build

- `SMOKE_TEST_REPO_URL` — Git URL for Luanti server repo (default: minetest fork)
- `SMOKE_TEST_REPO_REF` — Git branch/tag to build from (default: master)
- `SMOKE_TEST_RUNTIME_DIR` — Directory for temp files and logs (default: `.smoke-test-runtime`)
- `SMOKE_TEST_LOCAL_LUANTI_DIR` — Path to local Luanti installation (default: `~/.minetest`)

## Test Scenarios

### Scenario 1: Basic Load Test

**What it tests:**
- Mod loads without errors
- All required dependencies are available
- Crucible nodes are registered

**Run:**
```bash
bash .github/scripts/smoke-test.sh lava_crucible mintest_lava_crucible
```

**Expected:** SMOKE TEST PASSED: No errors in startup log for lava_crucible.

### Scenario 2: With Minimal Stubs

**What it tests:**
- Mod loads with minimal environment (no real mods)
- Dependency resolution works with stubs

**Run:**
```bash
SMOKE_TEST_DEP_SOURCE=strict bash .github/scripts/smoke-test.sh lava_crucible mintest_lava_crucible
```

**Expected:** SMOKE TEST PASSED (or warning about optional mods not available)

### Scenario 3: CI Profile

**What it tests:**
- Mod loads with CI-like environment (stubs for moreblocks, workspace for lava_crucible deps)
- Matches CI/CD test conditions

**Run:**
```bash
SMOKE_TEST_DEP_SOURCE=hybrid \
SMOKE_TEST_STUB_FIRST_DEPS=moreblocks \
bash .github/scripts/smoke-test.sh lava_crucible mintest_lava_crucible
```

**Expected:** SMOKE TEST PASSED

### Scenario 4: Intentional Failure Guardrail

**What it tests:**
- Smoke test infrastructure correctly detects errors
- Failure detection logic works

**Run:**
```bash
bash .github/scripts/smoke-test.sh smoke_fail_mod .github/test-fixtures/smoke_fail_mod
```

**Expected:** SMOKE TEST FAILED: Error(s) found in startup log. (This is correct!)

## Troubleshooting

### Docker daemon not accessible

**Error:**
```
Docker daemon is not accessible from this shell.
```

**Solution:**
```bash
newgrp docker
# or
sudo usermod -aG docker $USER
```

Then log out and log back in.

### Mod not found

**Error:**
```
ERROR: cannot find mod directory
```

**Solution:** Ensure mod is at the correct path:
```bash
ls /media/kc/storage/Workspace/mintest_lava_crucible/mod.conf
```

### Docker image build fails

**Error:**
```
failed to build docker image
```

**Solution:** 
- Ensure Docker has sufficient disk space
- Check internet connection (image is built from source)
- Try deleting old images: `docker rmi luanti-smoke-test:latest` and retry

### Timeout during boot

**Error:**
```
timeout: sending signal TERM to command
```

**Solution:** Increase timeout:
```bash
SMOKE_TEST_TIMEOUT=60 bash .github/scripts/smoke-test.sh lava_crucible mintest_lava_crucible
```

## Output and Logs

Smoke test logs are saved in `.smoke-test-runtime/tmp/`:

```bash
ls -lh .smoke-test-runtime/tmp/smoke-test-*.log
```

### Viewing Logs

```bash
# Show latest test log
tail -100 .smoke-test-runtime/tmp/smoke-test-*.log | tail -100

# Search for warnings in logs
grep -i "warn" .smoke-test-runtime/tmp/smoke-test-*.log
```

## Integration with VS Code

### Task: Run Smoke Test

The workspace includes a VS Code task. Run with Ctrl+Shift+B:

```json
{
  "label": "Smoke Test (CI Profile)",
  "type": "shell",
  "command": "SMOKE_TEST_DEP_SOURCE=hybrid SMOKE_TEST_STUB_FIRST_DEPS=moreblocks bash ${workspaceFolder}/.github/scripts/smoke-test.sh lava_crucible ${relativeFileDirname}",
  "group": "test"
}
```

## CI/CD Integration

### GitHub Actions

Example workflow for automated testing:

```yaml
name: Smoke Test

on: [push, pull_request]

jobs:
  smoke-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run preflight checks
        run: bash .github/scripts/smoke-test-preflight.sh
      - name: Run smoke test
        env:
          SMOKE_TEST_DEP_SOURCE: hybrid
          SMOKE_TEST_STUB_FIRST_DEPS: moreblocks
        run: bash .github/scripts/smoke-test.sh lava_crucible mintest_lava_crucible
```

## Performance Notes

- **First run:** ~3-5 minutes (builds Docker image from source)
- **Subsequent runs:** ~30-60 seconds (reuses cached image)
- **Total timeout:** 30 seconds per boot (adjustable with SMOKE_TEST_TIMEOUT)

## What Gets Tested

✅ **Tested:**
- Mod loads without syntax errors
- Required dependencies can be resolved
- Crucible nodes are registered
- No ModError or ServerError on startup
- Lua script errors are caught

❌ **Not Tested (yet):**
- Gameplay mechanics (node conversion, inventory, etc.)
- Furnace recipe execution
- Ender crucible functionality
- Network multiplayer issues

Future extended smoke tests could add gameplay validation using Minetest Lua scripting APIs.

## See Also

- [TESTING_REQUIREMENTS.md](TESTING_REQUIREMENTS.md) — Unit testing with Busted
- [TEST_PLAN.md](TEST_PLAN.md) — Complete testing strategy
- [BUG_REPORT.md](BUG_REPORT.md) — Known issues
