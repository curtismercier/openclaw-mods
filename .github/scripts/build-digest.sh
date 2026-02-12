#!/usr/bin/env bash
# Build a markdown digest from upstream data
set -euo pipefail

COMMITS="${1:-/tmp/commits.jsonl}"
RELEASES="${2:-/tmp/releases.jsonl}"
PRS="${3:-/tmp/our_prs.jsonl}"
REVIEWS="${4:-/tmp/pr_reviews.jsonl}"
CONFLICTS="${5:-/tmp/pr_conflicts.jsonl}"

# High-signal patterns — flag commits touching these paths
WATCH_PATTERNS="agent-scope|schema\.ts|types\.agents|compaction|memoryFlush|plugin-sdk|BREAKING|memory-lancedb"

DATE=$(date -u '+%Y-%m-%d %H:%M UTC')

echo "### 📡 $DATE"
echo ""

# --- Releases ---
if [ -s "$RELEASES" ]; then
  echo "#### 🚀 New Releases"
  echo ""
  jq -rs 'group_by(.tag) | .[] | .[0] | "**\(.tag)** — \(.name) (\(.date))\(if .prerelease then " ⚠️ pre-release" else "" end)\n\n\(.body)\n"' "$RELEASES" 2>/dev/null || true
  echo ""
fi

# --- Commits ---
COMMIT_COUNT=0
if [ -s "$COMMITS" ]; then
  COMMIT_COUNT=$(jq -s 'length' "$COMMITS" 2>/dev/null || echo "0")
fi

if [ "$COMMIT_COUNT" -gt 0 ]; then
  echo "#### 📝 Commits to main ($COMMIT_COUNT new)"
  echo ""
  
  # Categorize: breaking, watched, regular
  BREAKING=""
  WATCHED=""
  REGULAR=""
  
  while IFS= read -r obj; do
    SHA=$(echo "$obj" | jq -r '.sha')
    MSG=$(echo "$obj" | jq -r '.message')
    AUTHOR=$(echo "$obj" | jq -r '.author')
    DATE_SHORT=$(echo "$obj" | jq -r '.date')
    FILES=$(echo "$obj" | jq -r '.files | join(", ")')
    PR_NUM=$(echo "$obj" | jq -r '.pr // empty')
    
    # Build the line
    PR_LINK=""
    if [ -n "$PR_NUM" ]; then
      PR_LINK=" ([#$PR_NUM](https://github.com/openclaw/openclaw/pull/$PR_NUM))"
    fi
    
    # Check categories
    if echo "$MSG" | grep -qiE "BREAKING|breaking change"; then
      BREAKING+="- 🔴 \`$SHA\` $MSG$PR_LINK\n"
    elif echo "$MSG $FILES" | grep -qE "$WATCH_PATTERNS"; then
      WATCHED+="- ⚠️ \`$SHA\` $MSG$PR_LINK\n"
    else
      REGULAR+="- \`$SHA\` $MSG$PR_LINK\n"
    fi
  done < <(jq -c '.' "$COMMITS" 2>/dev/null)
  
  # Print in priority order
  if [ -n "$BREAKING" ]; then
    echo "**🔴 Breaking Changes**"
    echo ""
    echo -e "$BREAKING"
  fi
  
  if [ -n "$WATCHED" ]; then
    echo "**⚠️ Relevant to our work**"
    echo ""
    echo -e "$WATCHED"
  fi
  
  if [ -n "$REGULAR" ]; then
    # Collapse regular commits if more than 10
    REGULAR_COUNT=$(echo -e "$REGULAR" | grep -c "^\-" || true)
    if [ "$REGULAR_COUNT" -gt 10 ]; then
      echo "<details><summary>Other commits ($REGULAR_COUNT)</summary>"
      echo ""
      echo -e "$REGULAR"
      echo "</details>"
    else
      echo -e "$REGULAR"
    fi
  fi
  
  # File area summary
  echo ""
  echo "<details><summary>📁 Areas touched</summary>"
  echo ""
  jq -rs '[.[].files[]] | map(split("/")[0]) | group_by(.) | map({dir: .[0], count: length}) | sort_by(-.count) | .[] | "- **\(.dir)/** (\(.count) files)"' "$COMMITS" 2>/dev/null || echo "- *(details unavailable)*"
  echo ""
  echo "</details>"
  echo ""
  
  # Note if capped
  if [ -f /tmp/commits_note.txt ]; then
    echo ""
    cat /tmp/commits_note.txt
    echo ""
  fi
fi

# --- Our PRs ---
if [ -s "$PRS" ]; then
  echo "#### 🔀 Our PRs"
  echo ""
  
  # Open PRs
  while IFS= read -r obj; do
    NUM=$(echo "$obj" | jq -r '.number')
    TITLE=$(echo "$obj" | jq -r '.title')
    DRAFT=$(echo "$obj" | jq -r '.draft')
    URL=$(echo "$obj" | jq -r '.html_url')
    UPDATED=$(echo "$obj" | jq -r '.updated_at')
    LABELS=$(echo "$obj" | jq -r '.labels | join(", ")')
    REVIEWERS=$(echo "$obj" | jq -r '.requested_reviewers | join(", ")')
    
    STATUS="🟢 Open"
    [ "$DRAFT" = "true" ] && STATUS="📝 Draft"
    
    echo "- **[#$NUM]($URL)** $TITLE — $STATUS"
    
    DETAILS=""
    [ -n "$LABELS" ] && [ "$LABELS" != "null" ] && DETAILS+="  Labels: $LABELS"
    [ -n "$REVIEWERS" ] && [ "$REVIEWERS" != "null" ] && DETAILS+=" | Reviewers: $REVIEWERS"
    [ -n "$DETAILS" ] && echo "  $DETAILS"
    
    # Check conflicts
    if [ -s "$CONFLICTS" ]; then
      if jq -e "select(.pr == $NUM)" "$CONFLICTS" >/dev/null 2>&1; then
        echo "  ⚠️ **Merge conflict detected** — needs rebase"
      fi
    fi
  done < <(jq -c 'select(.state == "open")' "$PRS" 2>/dev/null)
  
  # Merged/closed PRs
  while IFS= read -r obj; do
    NUM=$(echo "$obj" | jq -r '.number')
    TITLE=$(echo "$obj" | jq -r '.title')
    STATE=$(echo "$obj" | jq -r '.state')
    URL=$(echo "$obj" | jq -r '.html_url')
    
    if [ "$STATE" = "merged" ]; then
      echo "- 🟣 **[#$NUM]($URL)** $TITLE — **Merged!** 🎉"
    else
      echo "- ❌ **[#$NUM]($URL)** $TITLE — Closed"
    fi
  done < <(jq -c 'select(.state == "merged" or .state == "closed")' "$PRS" 2>/dev/null)
  
  echo ""
fi

# --- Reviews ---
if [ -s "$REVIEWS" ]; then
  REVIEW_COUNT=$(jq -s 'length' "$REVIEWS" 2>/dev/null || echo "0")
  if [ "$REVIEW_COUNT" -gt 0 ]; then
    echo "#### 💬 New Reviews on Our PRs"
    echo ""
    while IFS= read -r obj; do
      PR_NUM=$(echo "$obj" | jq -r '.pr')
      USER=$(echo "$obj" | jq -r '.user')
      STATE=$(echo "$obj" | jq -r '.state')
      BODY=$(echo "$obj" | jq -r '.body')
      
      REVIEW_ICON="💬"
      [ "$STATE" = "APPROVED" ] && REVIEW_ICON="✅"
      [ "$STATE" = "CHANGES_REQUESTED" ] && REVIEW_ICON="🔄"
      
      echo "- $REVIEW_ICON **#$PR_NUM** — $USER ($STATE)"
      [ -n "$BODY" ] && [ "$BODY" != "null" ] && echo "  > $BODY"
    done < <(jq -c '.' "$REVIEWS" 2>/dev/null)
    echo ""
  fi
fi

# No changes
if [ "$COMMIT_COUNT" = "0" ] && [ ! -s "$RELEASES" ]; then
  echo "*No upstream changes since last check.*"
  echo ""
fi
