#!/usr/bin/env bash
# baseline-sha256: compute and diff SHA-256 hashes for supply chain change detection
# Usage:
#   bash baseline-sha256.sh init              # establish baseline
#   bash baseline-sha256.sh check             # compare against baseline
#   bash baseline-sha256.sh init [target-dir] # baseline a specific directory

set -euo pipefail

BASELINE_FILE="$HOME/.agentseal-baseline.txt"
TARGET_DIR="${2:-$HOME/.claude}"

case "${1:-check}" in

  init)
    echo "Establishing baseline for: $TARGET_DIR"
    find "$TARGET_DIR" -type f | sort | while read f; do
      shasum -a 256 "$f" 2>/dev/null || sha256sum "$f" 2>/dev/null
    done > "$BASELINE_FILE"
    count=$(wc -l < "$BASELINE_FILE" | tr -d ' ')
    echo "Baseline saved: $BASELINE_FILE ($count files)"
    echo "Run 'bash baseline-sha256.sh check' after installs to detect changes."
    ;;

  check)
    if [[ ! -f "$BASELINE_FILE" ]]; then
      echo "No baseline found. Run: bash baseline-sha256.sh init"
      exit 1
    fi

    echo "Checking $TARGET_DIR against baseline..."
    CURRENT=$(mktemp)
    find "$TARGET_DIR" -type f | sort | while read f; do
      shasum -a 256 "$f" 2>/dev/null || sha256sum "$f" 2>/dev/null
    done > "$CURRENT"

    # New files
    new_files=$(comm -13 <(awk '{print $2}' "$BASELINE_FILE" | sort) \
                         <(awk '{print $2}' "$CURRENT" | sort))
    if [[ -n "$new_files" ]]; then
      echo ""
      echo "[HIGH] New files since baseline:"
      echo "$new_files" | while read f; do echo "  + $f"; done
    fi

    # Changed files
    changed=$(diff <(sort "$BASELINE_FILE") <(sort "$CURRENT") \
              | grep '^[<>]' | awk '{print $3}' | sort | uniq -d 2>/dev/null || true)
    if [[ -n "$changed" ]]; then
      echo ""
      echo "[CRITICAL] Modified files since baseline:"
      echo "$changed" | while read f; do echo "  ~ $f"; done
    fi

    # Deleted files
    deleted=$(comm -23 <(awk '{print $2}' "$BASELINE_FILE" | sort) \
                       <(awk '{print $2}' "$CURRENT" | sort))
    if [[ -n "$deleted" ]]; then
      echo ""
      echo "[MEDIUM] Deleted files since baseline:"
      echo "$deleted" | while read f; do echo "  - $f"; done
    fi

    rm "$CURRENT"

    # Critical file integrity checks
    echo ""
    echo "── Critical file integrity ──"
    for critical_file in \
      "$HOME/.claude/CLAUDE.md" \
      "$HOME/.claude/settings.json" \
      "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    do
      if [[ -f "$critical_file" ]]; then
        current_hash=$(shasum -a 256 "$critical_file" 2>/dev/null | awk '{print $1}')
        baseline_hash=$(grep "$critical_file" "$BASELINE_FILE" 2>/dev/null | awk '{print $1}' || echo "")
        if [[ -z "$baseline_hash" ]]; then
          echo "[INFO]  Not in baseline (new): $critical_file"
        elif [[ "$current_hash" != "$baseline_hash" ]]; then
          echo "[CRITICAL] CHANGED: $critical_file"
          echo "  Baseline: $baseline_hash"
          echo "  Current:  $current_hash"
        else
          echo "[OK]    Unchanged: $critical_file"
        fi
      fi
    done
    ;;

  *)
    echo "Usage: $0 init|check [target-dir]"
    exit 1
    ;;
esac
