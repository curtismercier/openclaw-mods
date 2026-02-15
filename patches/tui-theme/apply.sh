#!/usr/bin/env bash
# tui-theme.sh — Monkey patch for OpenClaw TUI color theming
#
# Patches compiled dist to swap the hardcoded TUI palette with a custom theme.
# No rebuild required. Backups are created on first apply and used for clean reverts.
#
# Usage:
#   ./apply.sh --apply <theme>   # Apply a theme (default: neon-vice)
#   ./apply.sh --revert          # Revert to original colors
#   ./apply.sh --status          # Show current patch state
#   ./apply.sh --list            # List available themes
#
# Environment:
#   OPENCLAW_DIR   Override OpenClaw install path (default: npm global)

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OPENCLAW_DIR="${OPENCLAW_DIR:-$(npm root -g 2>/dev/null)/openclaw}"
DIST="$OPENCLAW_DIR/dist"
VERSION_FILE="$SCRIPT_DIR/.patched-version"
BACKUP_DIR="$SCRIPT_DIR/.backups"
THEMES_DIR="$SCRIPT_DIR/themes"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[patch]${NC} $1"; }
warn() { echo -e "${YELLOW}[warn]${NC} $1"; }
err()  { echo -e "${RED}[error]${NC} $1" >&2; }
die()  { err "$1"; exit 1; }

get_version() {
  node -e "console.log(require('$OPENCLAW_DIR/package.json').version)" 2>/dev/null || echo "unknown"
}

# ── Original palette (baseline for patching) ────────────────────────────────
# These are the stock OpenClaw TUI colors we search for and replace.
ORIGINAL_COLORS=(
  "#E8E3D5"   # text
  "#7B7F87"   # dim
  "#F6C453"   # accent
  "#F2A65A"   # accentSoft
  "#3C414B"   # border
  "#2B2F36"   # userBg
  "#F3EEE0"   # userText
  "#9BA3B2"   # systemText
  "#1F2A2F"   # toolPendingBg
  "#1E2D23"   # toolSuccessBg
  "#2F1F1F"   # toolErrorBg
  "#E1DACB"   # toolOutput
  "#8CC8FF"   # quote
  "#3B4D6B"   # quoteBorder
  "#F0C987"   # code
  "#1E232A"   # codeBlock
  "#343A45"   # codeBorder
  "#7DD3A5"   # link
  "#F97066"   # error
)

# ── Theme definitions ───────────────────────────────────────────────────────
# Each theme array must match ORIGINAL_COLORS by index.

NEON_VICE=(
  "#cdd6f4"   # text
  "#6c7086"   # dim
  "#ff2d95"   # accent (hot pink)
  "#c77dff"   # accentSoft (neon purple)
  "#2a2a3c"   # border
  "#1e1e2e"   # userBg (deeper dark)
  "#cdd6f4"   # userText
  "#7f849c"   # systemText
  "#1a1528"   # toolPendingBg (deep purple-dark)
  "#11161e"   # toolSuccessBg (cool steel)
  "#2a0f1a"   # toolErrorBg (deep pink-dark)
  "#cdd6f4"   # toolOutput
  "#00e5ff"   # quote (electric cyan)
  "#2a2a4a"   # quoteBorder
  "#ffe66d"   # code (vivid yellow)
  "#11111b"   # codeBlock (near black)
  "#2a2a3c"   # codeBorder
  "#04d9ff"   # link (electric cyan)
  "#ff3860"   # error (vivid red)
)

# ── Functions ────────────────────────────────────────────────────────────────

find_tui_files() {
  find "$DIST" -name "tui-*.js" -not -name "*cli*" -not -name "*.backup" 2>/dev/null
}

preflight() {
  [ -d "$DIST" ] || die "OpenClaw dist not found at $DIST"

  local count=0
  while IFS= read -r f; do
    count=$((count + 1))
  done < <(find_tui_files)

  [ "$count" -gt 0 ] || die "No tui-*.js files found in $DIST"

  # Verify at least one original color exists (either original or already patched)
  local found=0
  while IFS= read -r f; do
    if grep -q "${ORIGINAL_COLORS[0]}\|${ORIGINAL_COLORS[2]}" "$f" 2>/dev/null; then
      found=1
      break
    fi
  done < <(find_tui_files)

  if [ "$found" -eq 0 ] && [ ! -d "$BACKUP_DIR" ]; then
    die "Cannot find expected palette in tui files. OpenClaw version may have changed."
  fi

  log "Pre-flight OK — $(get_version)"
}

backup() {
  mkdir -p "$BACKUP_DIR"
  while IFS= read -r f; do
    local base
    base=$(basename "$f")
    if [ ! -f "$BACKUP_DIR/$base" ]; then
      cp "$f" "$BACKUP_DIR/$base"
      log "Backed up $base"
    fi
  done < <(find_tui_files)
}

do_revert() {
  [ -d "$BACKUP_DIR" ] || die "No backups found at $BACKUP_DIR"

  local count=0
  for backup_file in "$BACKUP_DIR"/tui-*.js; do
    [ -f "$backup_file" ] || continue
    local base
    base=$(basename "$backup_file")
    if [ -f "$DIST/$base" ]; then
      cp "$backup_file" "$DIST/$base"
      count=$((count + 1))
    fi
  done

  rm -f "$VERSION_FILE"
  log "Reverted $count file(s) to original palette"
}

do_apply() {
  local theme_name="$1"
  local theme_array_name="$2"

  # Always revert first for clean state
  if [ -d "$BACKUP_DIR" ]; then
    do_revert
  fi

  backup

  local file_count=0
  while IFS= read -r f; do
    local swap_count=0
    local i=0
    while [ "$i" -lt "${#ORIGINAL_COLORS[@]}" ]; do
      local from="${ORIGINAL_COLORS[$i]}"
      eval "local to=\"\${${theme_array_name}[$i]}\""
      if [ "$from" != "$to" ]; then
        sed -i '' "s/$from/$to/g" "$f"
        swap_count=$((swap_count + 1))
      fi
      i=$((i + 1))
    done
    log "Patched $(basename "$f") ($swap_count color swaps)"
    file_count=$((file_count + 1))
  done < <(find_tui_files)

  echo "$theme_name|$(get_version)|$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$VERSION_FILE"
  log "Applied theme: $theme_name ($file_count files)"
}

do_status() {
  if [ -f "$VERSION_FILE" ]; then
    local info
    info=$(cat "$VERSION_FILE")
    local theme ver ts
    theme=$(echo "$info" | cut -d'|' -f1)
    ver=$(echo "$info" | cut -d'|' -f2)
    ts=$(echo "$info" | cut -d'|' -f3)
    echo -e "Theme:   ${CYAN}$theme${NC}"
    echo -e "Patched: v$ver on $ts"
    echo -e "Current: v$(get_version)"
    if [ "$(echo "$info" | cut -d'|' -f2)" != "$(get_version)" ]; then
      warn "OpenClaw version changed since patch was applied. Re-apply recommended."
    fi
  else
    echo "No theme patch applied (using stock colors)"
  fi

  if [ -d "$BACKUP_DIR" ]; then
    echo "Backups: $(ls "$BACKUP_DIR"/tui-*.js 2>/dev/null | wc -l | tr -d ' ') file(s)"
  fi
}

do_list() {
  echo "Available themes:"
  echo -e "  ${CYAN}neon-vice${NC}   — GTA fluorescent nights: deep dark base, hot pink, electric cyan, neon green"
  echo ""
  echo "To add a theme, define a color array in apply.sh matching ORIGINAL_COLORS by index."
}

# ── Main ─────────────────────────────────────────────────────────────────────

ACTION="${1:-}"
THEME_ARG="${2:-neon-vice}"

case "$ACTION" in
  --apply)
    case "$THEME_ARG" in
      neon-vice)
        preflight
        do_apply "neon-vice" NEON_VICE
        echo ""
        log "Restart OpenClaw TUI to see changes."
        ;;
      *)
        die "Unknown theme: $THEME_ARG (run --list to see available themes)"
        ;;
    esac
    ;;
  --revert)
    do_revert
    ;;
  --status)
    do_status
    ;;
  --list)
    do_list
    ;;
  *)
    echo "Usage: $(basename "$0") <action> [theme]"
    echo ""
    echo "Actions:"
    echo "  --apply <theme>   Apply a TUI theme (default: neon-vice)"
    echo "  --revert          Restore original colors"
    echo "  --status          Show current patch state"
    echo "  --list            List available themes"
    echo ""
    echo "Environment:"
    echo "  OPENCLAW_DIR      Override OpenClaw install path"
    exit 1
    ;;
esac
