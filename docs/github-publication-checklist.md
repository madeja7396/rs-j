# GitHub 公開チェックリスト

## リポジトリ準備

- `README.md` に目的・セットアップ・運用方針がある
- `LICENSE`（MIT）と upstream クレジットを確認済み
- `.gitignore` と `.editorconfig` が適用されている
- `docs/release-process.md` にタグ運用ルールが記載されている
- Repository variables を設定済み:
  - `RSJ_ENABLE_PAGES_DEPLOY=1`
  - `RSJ_ENABLE_RELEASE_PIPELINE=1`
- Actions の Workflow permissions が `Read and write permissions`

## 開発環境

- `./scripts/setup_dev_env.sh` が実行できる
- `./scripts/check_env.sh` が成功する
- `./scripts/release_prep.sh --help` が実行できる
- Rust stable + `rustfmt` + `clippy` が使える

## CI

- Linux で workflow が成功
- Windows で workflow が成功
- `Cargo.toml` 導入後に `fmt` / `clippy` / `test` が走る

## 品質

- Windows cmd / PowerShell / WSL の挙動差を確認
- 日本語表示（全角・絵文字・結合文字）の崩れ確認
- 日本語検索（NFKC/半角全角）の期待動作確認

## 公開作業

- `main` が最新 (`git pull --ff-only origin main`)
- `./scripts/release_prep.sh --tag X.Y.Z` が通過（例: `0.12.5`）
- `X.Y.Z` 形式タグを作成して push（例: `0.12.5`）
- `deployment` workflow が起動・成功
- GitHub で description / topics / release notes を設定・公開
