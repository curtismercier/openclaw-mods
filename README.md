# openclaw-mods

Community patches, configs, and power-user mods for [OpenClaw](https://github.com/openclaw/openclaw) — the open-source AI agent framework.

## What's here

Patches and modifications that extend OpenClaw beyond its current release. Each mod is self-contained with apply/revert scripts and version tracking, so you can use them safely alongside the official release cycle.

| Mod | Description | Status |
|-----|-------------|--------|
| [tui-theme](patches/tui-theme/) | Runtime TUI color theming — swap the hardcoded palette without rebuilding | ✅ Tested on v2026.2.16 |
| ~~[per-agent-compaction](patches/per-agent-compaction/)~~ | Per-agent compaction overrides | 🔀 Superseded by [PR #19329](https://github.com/openclaw/openclaw/pull/19329) |
| [upstream-monitor](.github/workflows/upstream-monitor.yml) | GitHub Actions workflow that tracks upstream OpenClaw commits, releases, and your open PRs | Active |

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
./patches/tui-theme/apply.sh --apply neon-vice

# Check status after an OpenClaw update
./patches/tui-theme/apply.sh --status

# Revert before updating OpenClaw
./patches/tui-theme/apply.sh --revert
```

## How patches work

Each patch script:

1. **Pre-flight checks** — Verifies the expected hex values exist in the target files. If OpenClaw was updated and the palette changed, the patch refuses to apply and tells you why.
2. **Backs up** originals to `.backups/` before touching anything.
3. **Records the version** it was applied against in `.patched-version`, so you can detect stale patches after updates.
4. **Reverts cleanly** from backups with `--revert`.

### Update workflow

```bash
# Before updating OpenClaw
./patches/tui-theme/apply.sh --revert

# Update OpenClaw
npm install -g openclaw@latest

# Re-apply (will fail loudly if the patch needs updating)
./patches/tui-theme/apply.sh --apply neon-vice
```

## Patches

### tui-theme

**Problem:** The TUI has a hardcoded color palette in `src/tui/theme/theme.ts` with no runtime override — no env vars, config file, CLI flags, or `/settings` option. Changing colors requires editing TypeScript and rebuilding.

**Solution:** Direct hex replacement in compiled `dist/tui-*.js` bundles. The palette exists as plain string literals, so a targeted `sed` swap is safe and reliable.

Ships with a **neon-vice** theme — GTA fluorescent nights with a deep dark base, hot pink accents, electric cyan, and vivid yellow code blocks.

| Element | Stock | Neon Vice |
|---------|-------|-----------|
| Accent | `#F6C453` gold | `#ff2d95` hot pink |
| Links | `#7DD3A5` green | `#04d9ff` electric cyan |
| Code | `#F0C987` warm gold | `#ffe66d` vivid yellow |
| User msg bg | `#2B2F36` grey-blue | `#1e1e2e` deep purple-dark |
| Code block bg | `#1E232A` | `#11111b` near-black |
| Tool success bg | `#1E2D23` green-dark | `#11161e` cool steel |
| Error | `#F97066` coral | `#ff3860` vivid red |

```bash
./patches/tui-theme/apply.sh --apply neon-vice   # Apply
./patches/tui-theme/apply.sh --revert            # Revert
./patches/tui-theme/apply.sh --status            # Check state
./patches/tui-theme/apply.sh --list              # List themes
```

Pairs with the [Gravicity tmux IDE](https://github.com/curtismercier/gravicity-tmux) `tmux-theme` switcher for unified theming across tmux, Ghostty, and OpenClaw TUI.

**Adding themes:** Define a new color array in `apply.sh` matching `ORIGINAL_COLORS` by index (19 colors), then add a case to the `--apply` handler.

**Tested on:** OpenClaw v2026.2.13 through v2026.2.16

### per-agent-compaction (archived)

> **This patch has been superseded by [PR #19329](https://github.com/openclaw/openclaw/pull/19329)** — a clean upstream implementation with per-agent `compaction` and `contextPruning` overrides, `mode: "off"` support, deep-merge resolvers, and a 38-test suite. The original patch script here was a proof-of-concept that validated the approach. Once the PR is merged, no patch is needed.

## Upstream Monitor

A GitHub Actions workflow that watches `openclaw/openclaw` and posts digest issues to this repo every 2 hours.

**What it tracks:**
- New commits to `main` — flagged with ⚠️ when they touch agent-scope, schema, compaction, memory, or plugin-sdk
- New releases / tags
- Status of your open PRs (reviews, CI, merge state)

**Setup:** Fork this repo and enable Actions. The workflow starts posting digest issues automatically. No external webhooks or secrets needed — uses the default `GITHUB_TOKEN`.

## Contributing

Found a bug? Need a different mod? Open an issue or PR. If you've written a patch for your own OpenClaw setup, consider sharing it here.

## License

MIT — same as OpenClaw.
