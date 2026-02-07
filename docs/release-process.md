# Release Process

`rs-j` の公開時に使う運用メモです。

## 1. 事前確認

推奨:

```bash
./scripts/release_prep.sh --tag 0.12.13
```

手動実行する場合:

```bash
git checkout main
git pull --ff-only origin main
cargo fmt --all
cargo clippy --all-targets --features deploy -- -D warnings
cargo test --lib
```

GitHub Actions の公開系ジョブを使う場合:

- Repository variables:
  - `RSJ_ENABLE_PAGES_DEPLOY=1`（docs / gh-pages 公開を有効化）
  - `RSJ_ENABLE_RELEASE_PIPELINE=1`（tag push で deployment を有効化）
  - `RSJ_ENABLE_CODECOV=1`（codecov の coverage ジョブを有効化）
- Repository settings:
  - Actions -> General -> Workflow permissions を `Read and write permissions` に設定

## 2. タグ方針

- GitHub `deployment` workflow の自動起動条件は **`X.Y.Z` 形式タグ** です。
- `v0.1.0` や `0.12.5-alpha.1` のようなタグは `deployment` の `push.tags` 条件に一致しません。

推奨:
- 自動ビルド付き安定リリース: `0.12.13`
- 追加の人間向け識別子が必要なら補助タグを併用:
  - 例: `v0.1.0-alpha.1`（補助タグ）
  - 例: `0.12.13`（CIトリガー用タグ）

## 3. タグ作成と push

```bash
GITHUB_TOKEN=... ./scripts/publish_release.sh --tag 0.12.13
```

`GITHUB_TOKEN` なしで手動公開する場合:

```bash
./scripts/publish_release.sh --tag 0.12.13
```

## 4. GitHub Actions 確認

- `deployment` run が起動していること
- `ci` / `codecov` の状態も確認すること

推奨コマンド:

```bash
./scripts/check_workflow_runs.sh --wait-secs 900
```

失敗時の確認ポイント:
- repository の Actions 設定
- fork の workflow 実行許可
- runner/target の matrix 設定（例: macOS ARM/Intel の不一致）
- reusable workflow の `permissions` 要求（`id-token` / `attestations`）が caller 側で許可されているか

補足:
- `./scripts/release_prep.sh --skip-clippy` / `--skip-tests` で段階実行も可能
- fork では上記 variables 未設定時、`docs` は build のみ実行し、`deployment` / `codecov coverage` はスキップされる
- `check_workflow_runs.sh` は既定で `ci,codecov,docs` を確認する（`--required` で変更可能）
- `check_workflow_runs.sh` は API がレート制限された場合、公開 Actions HTML 解析へ自動フォールバックする
- `publish_release.sh` は `GITHUB_TOKEN` がある場合、GitHub Release の作成/更新まで自動実行する

## 5. Release ページ公開

1. `GITHUB_TOKEN` を設定して以下を実行:

```bash
./scripts/publish_release.sh --tag 0.12.13
```

2. draft 作成後に GitHub の Release ページで本文とアセットを確認して publish
