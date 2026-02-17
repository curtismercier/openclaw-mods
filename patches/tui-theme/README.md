# tui-theme

Monkey patch for OpenClaw TUI color theming. Swaps the hardcoded palette in compiled dist files with custom themes — no rebuild required.

## Problem

OpenClaw's TUI has a hardcoded color palette in `src/tui/theme/theme.ts` with no runtime override mechanism (no env vars, config file, CLI flags, or `/settings` command). Changing colors requires editing TypeScript source and rebuilding.

## Solution

Direct hex replacement in the compiled `dist/tui-*.js` bundle files. The palette exists as plain string literals, so a targeted `sed` swap is safe and reliable. Backups are created on first apply for clean reverts.

## Themes

### neon-vice

GTA fluorescent nights — deep dark base with vivid neon accents.

| Element | Stock | Neon Vice |
|---------|-------|-----------|
| Text | `#E8E3D5` warm white | `#cdd6f4` cool white |
| Dim | `#7B7F87` grey | `#6c7086` muted |
| Accent | `#F6C453` gold | `#ff2d95` hot pink |
| Accent soft | `#F2A65A` orange | `#c77dff` neon purple |
| Links | `#7DD3A5` green | `#04d9ff` electric cyan |
| Code | `#F0C987` warm gold | `#ffe66d` vivid yellow |
| User msg bg | `#2B2F36` grey-blue | `#1e1e2e` deep purple-dark |
| Tool pending bg | `#1F2A2F` teal-dark | `#1a1528` purple-dark |
| Tool success bg | `#1E2D23` green-dark | `#11161e` cool steel |
| Tool error bg | `#2F1F1F` red-dark | `#2a0f1a` pink-dark |
| Code block bg | `#1E232A` | `#11111b` near-black |
| Error | `#F97066` coral | `#ff3860` vivid red |

Designed to pair with the **neon-vice** tmux/Ghostty theme from the [Gravicity tmux IDE](https://github.com/curtismercier/gravicity-tmux).

## Usage

```bash
# Apply neon-vice theme
./apply.sh --apply neon-vice

# Check current state
./apply.sh --status

# Revert to stock colors
./apply.sh --revert

# List available themes
./apply.sh --list
```

Restart the OpenClaw TUI after applying for changes to take effect.

## After OpenClaw updates

```bash
# Check if your patch is stale
./apply.sh --status

# If version changed, revert and re-apply
./apply.sh --revert
# Update OpenClaw...
./apply.sh --apply neon-vice
```

The script backs up original files on first apply. If OpenClaw updates change the TUI bundle filenames (they include content hashes), the old backups become stale — delete `.backups/` and re-apply.

## Adding themes

Define a new color array in `apply.sh` matching `ORIGINAL_COLORS` by index (19 colors), then add a case to the `--apply` handler.

## Compatibility

| OpenClaw Version | Status |
|-----------------|--------|
| v2026.2.13 | ✅ Tested |
| v2026.2.14–2.15 | ✅ Compatible (same palette) |
| v2026.2.16 | ✅ Tested |

## Changelog

- **v2** (2026-02-17): Verified against v2026.2.16, updated docs with compatibility matrix
- **v1.1** (2026-02-15): Changed `toolSuccessBg` from `#0f2a15` (deep green) to `#11161e` (cool steel) — better contrast
- **v1** (2026-02-15): Initial release with neon-vice theme, 19-color palette swap

## Upstream

Ideally OpenClaw would support runtime theme configuration. Until then, this patch bridges the gap. Potential feature request: `theme` config in `openclaw.json` or a `--theme` CLI flag.
