#!/usr/bin/env bash
# per-agent-compaction.sh — Monkey patch for per-agent compaction overrides
#
# Patches the compiled OpenClaw dist to support per-agent compaction config
# in agents.list[] entries, overriding agents.defaults.compaction.
#
# Usage:
#   ./per-agent-compaction.sh --apply   # Apply the patch
#   ./per-agent-compaction.sh --revert  # Revert to originals
#   ./per-agent-compaction.sh --check   # Check if patch is applied
#
# Targets OpenClaw v2026.2.9. Fails loudly if files have changed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Set OPENCLAW_DIR to your OpenClaw install if it's not in the default location.
OPENCLAW_DIR="${OPENCLAW_DIR:-$(npm root -g 2>/dev/null)/openclaw}"
DIST="$OPENCLAW_DIR/dist"
VERSION_FILE="$SCRIPT_DIR/.patched-version"
BACKUP_DIR="$SCRIPT_DIR/.backups"

# Target files (hashed names for v2026.2.9)
AGENT_SCOPE_PI="agent-scope-DdQkOxl9.js"
AGENT_SCOPE_REPLY="agent-scope-BimPHsgV.js"
PI_EMBEDDED="pi-embedded-CWm3BvmA.js"
REPLY="reply-DptDUVRg.js"

ALL_FILES=("$AGENT_SCOPE_PI" "$AGENT_SCOPE_REPLY" "$PI_EMBEDDED" "$REPLY")

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[patch]${NC} $1"; }
warn() { echo -e "${YELLOW}[warn]${NC} $1"; }
err()  { echo -e "${RED}[error]${NC} $1" >&2; }
die()  { err "$1"; exit 1; }

get_version() {
  node -e "console.log(require('$OPENCLAW_DIR/package.json').version)" 2>/dev/null || echo "unknown"
}

# --- Pre-flight: verify expected original content exists ---
preflight() {
  local ok=true
  for f in "${ALL_FILES[@]}"; do
    [[ -f "$DIST/$f" ]] || { err "Missing: $DIST/$f"; ok=false; }
  done

  for bundle in "$PI_EMBEDDED" "$REPLY"; do
    grep -q 'cfg?.agents?.defaults?.compaction?.reserveTokensFloor' "$DIST/$bundle" 2>/dev/null \
      || { err "$bundle: resolveCompactionReserveTokensFloor fingerprint missing"; ok=false; }
    grep -q 'cfg?.agents?.defaults?.compaction?.mode === "safeguard"' "$DIST/$bundle" 2>/dev/null \
      || { err "$bundle: resolveCompactionMode fingerprint missing"; ok=false; }
    grep -q 'cfg?.agents?.defaults?.compaction?.memoryFlush' "$DIST/$bundle" 2>/dev/null \
      || { err "$bundle: resolveMemoryFlushSettings fingerprint missing"; ok=false; }
  done

  $ok || die "Pre-flight failed. OpenClaw may have been updated — check version and update this patch."
}

is_patched() {
  grep -q 'resolveAgentCompaction' "$DIST/$AGENT_SCOPE_PI" 2>/dev/null
}

backup() {
  mkdir -p "$BACKUP_DIR"
  for f in "${ALL_FILES[@]}"; do
    cp "$DIST/$f" "$BACKUP_DIR/$f"
  done
  log "Backed up ${#ALL_FILES[@]} files to $BACKUP_DIR/"
}

# --- Apply ---
apply_patch() {
  local version
  version=$(get_version)

  if is_patched; then
    warn "Patch appears to already be applied. Use --revert first to re-apply."
    exit 0
  fi

  preflight
  backup

  log "Patching OpenClaw $version for per-agent compaction..."

  # =========================================================================
  # 1. Patch agent-scope chunks: add compaction to resolveAgentConfig,
  #    inject resolveAgentCompaction, export it
  # =========================================================================
  for scope_file in "$AGENT_SCOPE_PI" "$AGENT_SCOPE_REPLY"; do
    log "  Patching $scope_file"
    local f="$DIST/$scope_file"

    # Add compaction to resolveAgentConfig return object
    sed -i '' 's/sandbox: entry\.sandbox,/compaction: entry.compaction, sandbox: entry.sandbox,/' "$f"

    # Inject resolveAgentCompaction helper before resolveAgentSkillsFilter
    perl -i -0pe 's{(function resolveAgentSkillsFilter)}{function resolveAgentCompaction(cfg, agentId) {\n\tconst perAgent = agentId ? resolveAgentConfig(cfg, agentId)?.compaction : void 0;\n\tconst defaults = cfg?.agents?.defaults?.compaction;\n\tif (!perAgent \&\& !defaults) return void 0;\n\tif (!perAgent) return defaults;\n\tif (!defaults) return perAgent;\n\treturn { ...defaults, ...perAgent, memoryFlush: perAgent.memoryFlush || defaults.memoryFlush ? { ...defaults.memoryFlush, ...perAgent.memoryFlush } : void 0 };\n}\n$1}' "$f"

    # Export it
    sed -i '' 's/resolveAgentConfig as n/resolveAgentConfig as n, resolveAgentCompaction as n2/' "$f"
  done

  # =========================================================================
  # 2. Patch both bundle files
  # =========================================================================
  for bundle in "$PI_EMBEDDED" "$REPLY"; do
    log "  Patching $bundle"
    local f="$DIST/$bundle"

    # Import resolveAgentCompaction from agent-scope chunk
    sed -i '' 's/resolveAgentConfig as n,/resolveAgentConfig as n, resolveAgentCompaction as n2,/' "$f"

    # --- resolveCompactionReserveTokensFloor: add agentId param, use merged config ---
    sed -i '' 's/function resolveCompactionReserveTokensFloor(cfg) {/function resolveCompactionReserveTokensFloor(cfg, agentId) {/' "$f"
    sed -i '' 's/const raw = cfg?.agents?.defaults?.compaction?.reserveTokensFloor;/const _crf = cfg ? n2(cfg, agentId) : void 0; const raw = _crf?.reserveTokensFloor;/' "$f"

    # --- resolveCompactionMode: add agentId param, use merged config ---
    sed -i '' 's/function resolveCompactionMode(cfg) {/function resolveCompactionMode(cfg, agentId) {/' "$f"
    sed -i '' 's/return cfg?.agents?.defaults?.compaction?.mode === "safeguard" ? "safeguard" : "default";/const _cm = cfg ? n2(cfg, agentId) : void 0; return _cm?.mode === "safeguard" ? "safeguard" : "default";/' "$f"

    # --- buildEmbeddedExtensionPaths: pass agentId through ---
    sed -i '' 's/if (resolveCompactionMode(params\.cfg) === "safeguard")/if (resolveCompactionMode(params.cfg, params.agentId) === "safeguard")/' "$f"
    sed -i '' 's/const compactionCfg = params\.cfg?.agents?.defaults?.compaction;/const compactionCfg = params.cfg ? n2(params.cfg, params.agentId) : void 0;/' "$f"

    # --- resolveMemoryFlushSettings: add agentId param, use merged config ---
    sed -i '' 's/function resolveMemoryFlushSettings(cfg) {/function resolveMemoryFlushSettings(cfg, agentId) {/' "$f"
    sed -i '' 's/const defaults = cfg?.agents?.defaults?.compaction?.memoryFlush;/const _fc = cfg ? n2(cfg, agentId) : void 0; const defaults = _fc?.memoryFlush;/' "$f"
    sed -i '' 's/normalizeNonNegativeInt(cfg?.agents?.defaults?.compaction?.reserveTokensFloor)/normalizeNonNegativeInt(_fc?.reserveTokensFloor)/' "$f"

    # --- Callsites: pass sessionAgentId to resolveCompactionReserveTokensFloor ---
    sed -i '' 's/minReserveTokens: resolveCompactionReserveTokensFloor(params\.config)/minReserveTokens: resolveCompactionReserveTokensFloor(params.config, sessionAgentId)/g' "$f"

    # --- Callsites: add agentId to buildEmbeddedExtensionPaths calls ---
    # Pattern 1 (compact.ts): model\n\t\t\t});
    perl -i -0pe 's{(buildEmbeddedExtensionPaths\(\{\s*cfg: params\.config,\s*sessionManager,\s*provider,\s*modelId,\s*)model(\s*\})}{${1}model,\n\t\t\t\tagentId: sessionAgentId${2}}g' "$f"
    # Pattern 2 (attempt.ts): model: params.model\n\t\t\t});
    perl -i -0pe 's{(buildEmbeddedExtensionPaths\(\{\s*cfg: params\.config,\s*sessionManager,\s*provider: params\.provider,\s*modelId: params\.modelId,\s*)model: params\.model(\s*\})}{${1}model: params.model,\n\t\t\t\tagentId: sessionAgentId${2}}g' "$f"

    # --- runMemoryFlushIfNeeded: extract agentId from sessionKey ---
    sed -i '' 's/const memoryFlushSettings = resolveMemoryFlushSettings(params\.cfg);/const _mfAgentId = params.sessionKey ? d(params.sessionKey) : void 0; const memoryFlushSettings = resolveMemoryFlushSettings(params.cfg, _mfAgentId);/g' "$f"
  done

  # =========================================================================
  # 3. Record patched version
  # =========================================================================
  cat > "$VERSION_FILE" <<EOF
# Per-agent compaction patch metadata
patched_version=$version
patched_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
patched_files=${ALL_FILES[*]}
EOF

  log "Patch applied to OpenClaw $version"
  log "Version recorded in $VERSION_FILE"
  log ""
  log "Restart gateway to activate: openclaw gateway restart"
}

# --- Revert ---
revert_patch() {
  [[ -d "$BACKUP_DIR" ]] || die "No backups found at $BACKUP_DIR"

  for f in "${ALL_FILES[@]}"; do
    if [[ -f "$BACKUP_DIR/$f" ]]; then
      cp "$BACKUP_DIR/$f" "$DIST/$f"
      log "Restored $f"
    else
      warn "No backup for $f"
    fi
  done

  rm -f "$VERSION_FILE"
  log "Patch reverted. Restart gateway to deactivate."
}

# --- Check ---
check_patch() {
  local version
  version=$(get_version)

  if is_patched; then
    log "Patch IS applied"
    if [[ -f "$VERSION_FILE" ]]; then
      local patched_ver
      patched_ver=$(grep '^patched_version=' "$VERSION_FILE" | cut -d= -f2)
      if [[ "$patched_ver" != "$version" ]]; then
        warn "Patched on v$patched_ver but running v$version — patch may need reapplying!"
        exit 2
      fi
      log "Version match: $version"
    fi
  else
    log "Patch is NOT applied (running v$version)"
    [[ -f "$VERSION_FILE" ]] && { warn "Version file exists but patch not detected — OpenClaw was likely updated"; exit 2; }
    exit 1
  fi
}

# --- Main ---
case "${1:-}" in
  --apply)  apply_patch ;;
  --revert) revert_patch ;;
  --check|--status)  check_patch ;;
  *)
    echo "Usage: $0 --apply | --revert | --status"
    echo "  --apply   Apply per-agent compaction patch"
    echo "  --revert  Restore original files from backup"
    echo "  --status  Check if patch is applied and version matches"
    exit 1
    ;;
esac
