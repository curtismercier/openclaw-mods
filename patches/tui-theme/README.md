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
| Background (user msg) | `#2B2F36` grey-blue | `#1e1e2e` deep purple-dark |
| Background (tool pending) | `#1F2A2F` teal-dark | `#1a1528` purple-dark |
| Background (tool success) | `#1E2D23` green-dark | `#0f2a15` deeper green |
| Background (tool error) | `#2F1F1F` red-dark | `#2a0f1a` pink-dark |
| Background (code block) | `#1E232A` | `#11111b` near-black |
| Accent | `#F6C453` gold | `#ff2d95` hot pink |
| Accent soft | `#F2A65A` orange | `#c77dff` neon purple |
| Links | `#7DD3A5` green | `#04d9ff` electric cyan |
| Code | `#F0C987` warm gold | `#ffe66d` vivid yellow |
| Success | `#7DD3A5` green | `#04d9ff` cyan |
| Error | `#F97066` coral | `#ff3860` vivid red |

Designed to pair with the **neon-vice** tmux/Ghostty theme from the [tmux IDE config](https://github.com/curtismercier/gravicity-tmux).

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

## Integration with tmux-theme

If using the Gravicity tmux IDE, the `tmux-theme` switcher can automatically apply/revert this patch alongside tmux and Ghostty theme changes. See the [tmux IDE docs](https://github.com/curtismercier/gravicity-tmux) for setup.

Local integration path: `~/.tmux/themes/openclaw-theme-patch.sh`

## After OpenClaw updates

```bash
# Check if your patch is stale
./apply.sh --status

# If version changed, revert and re-apply
./apply.sh --revert
# Update OpenClaw...
./apply.sh --apply neon-vice
```

The script backs up original files on first apply. If OpenClaw updates change the TUI bundle filenames (they include content hashes), the old backups become stale — just delete `.backups/` and re-apply.

## Adding themes

Define a new color array in `apply.sh` matching `ORIGINAL_COLORS` by index (19 colors), then add a case to the `--apply` handler. PRs welcome.

## Upstream

Ideally OpenClaw would support runtime theme configuration. Until then, this patch bridges the gap.

Relevant for: [openclaw/openclaw](https://github.com/openclaw/openclaw) — potential feature request for `theme` config in `openclaw.json` or a `--theme` CLI flag.
