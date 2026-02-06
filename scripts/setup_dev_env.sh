#!/usr/bin/env bash
set -euo pipefail

if ! command -v rustup >/dev/null 2>&1; then
  cat <<'EOF'
rustup が見つかりません。
https://rustup.rs/ から Rust をインストールしてから再実行してください。
EOF
  exit 1
fi

echo "[1/3] Installing stable toolchain..."
rustup toolchain install stable
rustup default stable

echo "[2/3] Installing components..."
rustup component add rustfmt clippy

echo "[3/3] Verifying cargo..."
cargo --version
rustc --version

cat <<'EOF'
Setup complete.

Next:
  ./scripts/check_env.sh

Note:
  Windows cmd / PowerShell ではフォントによって点グラフが崩れる場合があります。
  本プロジェクトでは将来的に端末判定による安全デフォルトを実装予定です。
EOF
