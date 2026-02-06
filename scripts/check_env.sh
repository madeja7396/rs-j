#!/usr/bin/env bash
set -euo pipefail

missing=0

check() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "OK   $cmd"
  else
    echo "MISS $cmd"
    missing=1
  fi
}

echo "Checking required commands..."
check git
check rustup
check cargo
check rustc

echo
echo "Version summary:"
git --version || true
rustup --version || true
cargo --version || true
rustc --version || true

if [[ "$missing" -ne 0 ]]; then
  echo
  echo "Environment check failed."
  exit 1
fi

echo
echo "Environment check passed."
