#!/usr/bin/env bash
# Fix staged .ipynb files by removing top-level metadata.widgets
# Creates a .precommit.bak for each processed file. Requires jq.
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "pre-commit: jq is required but not found. Install jq (eg: sudo apt install jq or brew install jq)" >&2
  exit 1
fi

# Get staged added/modified/copied files, null-separated
git diff --cached --name-only -z --diff-filter=ACM | 
while IFS= read -r -d '' f; do
  # only process ipynb files
  case "$f" in
    *.ipynb)
      # if file doesn't exist in working tree (deleted or path changed), skip
      if [ ! -f "$f" ]; then
        continue
      fi

      # backup current working copy before modifying
      cp -- "$f" "$f".precommit.bak

      # write to a temp file and atomically move it back if jq succeeds
      tmp=$(mktemp) || { echo "pre-commit: failed to create temp file" >&2; exit 1; }
      if jq 'del(.metadata.widgets)' "$f" > "$tmp"; then
        mv "$tmp" "$f"
        git add "$f"
      else
        echo "pre-commit: jq failed when processing '$f'" >&2
        rm -f "$tmp"
        exit 1
      fi
      ;;
    *) ;; # ignore other files
  esac
done

exit 0
