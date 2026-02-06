#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release_prep.sh [--tag X.Y.Z] [--skip-clippy] [--skip-tests]

Options:
  --tag X.Y.Z     Validate a release tag format (must match X.Y.Z).
  --skip-clippy   Skip clippy.
  --skip-tests    Skip cargo test --lib.
  -h, --help      Show this help.
EOF
}

TAG=""
SKIP_CLIPPY=0
SKIP_TESTS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      TAG="${2:-}"
      shift 2
      ;;
    --skip-clippy)
      SKIP_CLIPPY=1
      shift
      ;;
    --skip-tests)
      SKIP_TESTS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -n "$TAG" ]] && [[ ! "$TAG" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid --tag '$TAG'. Expected X.Y.Z format (e.g. 0.12.5)." >&2
  exit 1
fi

echo "[1/5] Ensuring working tree is clean..."
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit or stash changes first." >&2
  exit 1
fi

echo "[2/5] Ensuring current branch is main..."
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
  echo "Current branch is '$BRANCH'. Switch to 'main' before release prep." >&2
  exit 1
fi

echo "[3/5] Running formatting check..."
cargo fmt --all -- --check

if [[ "$SKIP_CLIPPY" -eq 0 ]]; then
  echo "[4/5] Running clippy..."
  cargo clippy --all-targets --features deploy -- -D warnings
else
  echo "[4/5] Skipping clippy (--skip-clippy)"
fi

if [[ "$SKIP_TESTS" -eq 0 ]]; then
  echo "[5/5] Running tests..."
  cargo test --lib
else
  echo "[5/5] Skipping tests (--skip-tests)"
fi

echo
echo "Release prep checks passed."
if [[ -n "$TAG" ]]; then
  cat <<EOF
Next:
  git tag -a $TAG -m "rs-j $TAG release"
  git push origin $TAG
EOF
fi
