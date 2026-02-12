# per-agent-compaction

Per-agent compaction overrides for OpenClaw — give different agents different context management strategies.

**Tested on:** OpenClaw v2026.2.9
**Upstream PR:** [curtismercier/openclaw#feat/per-agent-compaction](https://github.com/curtismercier/openclaw/tree/feat/per-agent-compaction)
**Closes:** [#13736](https://github.com/openclaw/openclaw/issues/13736), [#14446](https://github.com/openclaw/openclaw/issues/14446)

## Problem

Compaction settings (`mode`, `reserveTokensFloor`, `maxHistoryShare`, `memoryFlush`) only apply globally via `agents.defaults.compaction`. In multi-agent systems, different agents need different strategies — a research agent benefits from high retention while a task agent should compact early.

## What it does

Adds optional `compaction` config to individual agent entries in `agents.list[]`:

```yaml
agents:
  defaults:
    compaction:
      mode: default
      reserveTokensFloor: 20000
      memoryFlush:
        enabled: true
        softThresholdTokens: 50000
  list:
    - id: researcher
      compaction:
        reserveTokensFloor: 40000  # Higher floor — preserve more context
        maxHistoryShare: 0.8       # Compact later
    - id: executor
      compaction:
        maxHistoryShare: 0.4       # Compact earlier
        memoryFlush:
          enabled: false           # No pre-compaction flush needed
    - id: chat
      # No compaction override — inherits defaults
```

### Merge behavior

- **Top-level fields** (`mode`, `reserveTokensFloor`, `maxHistoryShare`): per-agent wins, falls back to default
- **`memoryFlush` sub-object**: shallow-merged one level deeper — a partial override like `{ enabled: false }` preserves the default `prompt`, `systemPrompt`, and `softThresholdTokens`
- **No per-agent config**: inherits global defaults unchanged

## Usage

```bash
# Set your OpenClaw install path (auto-detected via npm root -g)
# export OPENCLAW_DIR=/path/to/openclaw

# Apply
./apply.sh --apply

# Check status (especially after OpenClaw updates)
./apply.sh --status

# Revert
./apply.sh --revert
```

After applying, restart your gateway:
```bash
openclaw gateway restart
```

## How it works

The patch modifies 4 compiled dist files:

| File | Changes |
|------|---------|
| `agent-scope-*.js` (×2) | Adds `compaction` to `resolveAgentConfig()`, injects `resolveAgentCompaction()` merge helper |
| `pi-embedded-*.js` | Updates compaction mode/reserve/safeguard resolution + callsites |
| `reply-*.js` | Updates memory flush resolution + callsites |

Pre-flight checks verify the expected original code exists before patching. If OpenClaw was updated and the target code changed, the script refuses to apply and tells you why.

## Files

```
per-agent-compaction/
├── README.md      # This file
└── apply.sh       # Patch script (--apply / --revert / --status)
```

After applying:
```
per-agent-compaction/
├── .backups/              # Original files (created on --apply)
├── .patched-version       # Version + timestamp record
├── README.md
└── apply.sh
```
