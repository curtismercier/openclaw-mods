# openclaw-mods

Community patches, configs, and power-user mods for [OpenClaw](https://github.com/openclaw/openclaw) — the open-source AI agent framework.

## What's here

Patches and modifications that extend OpenClaw beyond its current release. Each mod is self-contained with apply/revert scripts and version tracking, so you can use them safely alongside the official release cycle.

| Mod | Description | Status |
|-----|-------------|--------|
| [per-agent-compaction](patches/per-agent-compaction/) | Per-agent compaction overrides — give different agents different context management strategies | ✅ Tested on v2026.2.9 |
| [upstream-monitor](.github/workflows/upstream-monitor.yml) | GitHub Actions workflow that tracks upstream OpenClaw commits, releases, and your open PRs | ✅ Active |

## Why this exists

OpenClaw moves fast, but sometimes you need a feature before it lands upstream. These mods bridge that gap:

- **Patches** — Monkey patches against compiled dist files, with pre-flight checks that fail loudly when OpenClaw updates break compatibility
- **Configs** — Reference configurations for multi-agent setups, compaction tuning, and advanced workflows
- **Recipes** — Step-by-step guides for common customizations

Every patch here is written with an upstream PR in mind. The goal is to contribute back, not to fork.

## Quick start

```bash
git clone https://github.com/curtismercier/openclaw-mods.git
cd openclaw-mods

# Apply a patch
./patches/per-agent-compaction/apply.sh --apply

# Check status after an OpenClaw update
./patches/per-agent-compaction/apply.sh --status

# Revert before updating OpenClaw
./patches/per-agent-compaction/apply.sh --revert
```

## How patches work

Each patch script:

1. **Pre-flight checks** — Verifies the expected code exists in the target files. If OpenClaw was updated and the code changed, the patch refuses to apply and tells you why.
2. **Backs up** originals to `.backups/` before touching anything.
3. **Records the version** it was applied against in `.patched-version`, so you can detect stale patches after updates.
4. **Reverts cleanly** from backups with `--revert`.

### Update workflow

```bash
# Before updating OpenClaw
./patches/per-agent-compaction/apply.sh --revert

# Update OpenClaw
npm install -g openclaw@latest

# Re-apply (will fail loudly if the patch needs updating)
./patches/per-agent-compaction/apply.sh --apply
```

## Patches

### per-agent-compaction

**Problem:** OpenClaw's compaction settings (`mode`, `reserveTokensFloor`, `maxHistoryShare`, `memoryFlush`) only apply globally via `agents.defaults.compaction`. In multi-agent systems, different agents need different context management — a research agent benefits from high retention, while a quick task agent should compact early.

**Solution:** Adds optional `compaction` config to individual agent entries in `agents.list[]`:

```yaml
agents:
  defaults:
    compaction:
      mode: default
      reserveTokensFloor: 20000
      memoryFlush:
        enabled: true
  list:
    - id: researcher
      compaction:
        reserveTokensFloor: 40000
        maxHistoryShare: 0.8
    - id: executor
      compaction:
        maxHistoryShare: 0.4
        memoryFlush:
          enabled: false
    - id: chat
      # Inherits defaults — no change needed
```

Per-agent fields override defaults. The `memoryFlush` sub-object is shallow-merged, so partial overrides (e.g., just `enabled: false`) don't wipe the default `prompt` or `systemPrompt`.

**Upstream:** PR pending against [openclaw/openclaw](https://github.com/openclaw/openclaw). Closes [#13736](https://github.com/openclaw/openclaw/issues/13736) and [#14446](https://github.com/openclaw/openclaw/issues/14446).

**Tested on:** OpenClaw v2026.2.9

## Upstream Monitor

A GitHub Actions workflow that watches `openclaw/openclaw` and posts digest issues to this repo every 2 hours.

**What it tracks:**
- New commits to `main` — flagged with ⚠️ when they touch agent-scope, schema, compaction, memory, or plugin-sdk
- New releases / tags
- Status of your open PRs (reviews, CI, merge state)

**How it works:**
- Runs on a cron schedule (every 2 hours) or manual dispatch
- Stores a cursor timestamp in a pinned issue (label: `upstream-cursor`)
- Posts digest issues (label: `upstream-digest`) only when there are changes
- No external webhooks or secrets needed — uses the default `GITHUB_TOKEN`

**Setup:** Fork this repo and enable Actions. That's it. The workflow will start posting digest issues automatically.

To customize what gets flagged, edit the `WATCH_PATTERNS` array in `.github/scripts/build-digest.sh`.

## Contributing

Found a bug? Need a different mod? Open an issue or PR. If you've written a patch for your own OpenClaw setup, consider sharing it here.

## License

MIT — same as OpenClaw.
