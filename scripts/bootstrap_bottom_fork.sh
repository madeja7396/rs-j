#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/ClementTsang/bottom.git}"
TARGET_DIR="${1:-upstream/bottom}"

mkdir -p "$(dirname "$TARGET_DIR")"

if [[ -d "$TARGET_DIR/.git" ]]; then
  echo "Updating existing upstream clone at $TARGET_DIR ..."
  git -C "$TARGET_DIR" fetch --all --tags --prune
else
  echo "Cloning upstream bottom into $TARGET_DIR ..."
  git clone "$UPSTREAM_URL" "$TARGET_DIR"
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if ! git remote | grep -qx "upstream"; then
    git remote add upstream "$UPSTREAM_URL"
    echo "Added git remote: upstream -> $UPSTREAM_URL"
  else
    echo "Git remote 'upstream' already exists."
  fi
fi

cat <<EOF
Done.

Upstream source path:
  $TARGET_DIR

Suggested next actions:
  1) Decide import strategy (subtree/squash copy/direct fork migration)
  2) Create branch for terminal profile defaults (cmd/PowerShell/WSL)
  3) Add CJK width mode and NFKC process search support
EOF
