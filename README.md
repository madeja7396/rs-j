# rs-j

`bottom` をベースに、`Windows cmd / PowerShell / WSL` でも破綻しにくく、日本語表示と日本語検索に強い TUI を目指す fork です。

## 状態

上流 `bottom` の `main` を取り込み済みです。  
これ以降は `bottom` 本体コード（`src/` など）に対して、以下の改善を段階的に入れます。

- Windows 端末差異を検出して安全側デフォルトへ寄せる
- CJK/絵文字表示崩れを減らす幅計算モードを導入する
- 日本語検索の実用性を上げるため NFKC 正規化を導入する
- WSL 固有制約は UI/ヘルプで明示する

## 実装ハイライト（2026-02-06 時点）

- 端末互換プロファイル:
  - Windows cmd / PowerShell 相当環境を検出して `dot_marker` を自動有効化
  - `--safe_terminal` で `basic` + ASCII 寄り描画（`-`, `|`, `+`, `.`）に自動退避
  - ステータス行に `safe_terminal` / `dot_marker` / `width_mode` / `wsl` を表示
- 日本語表示品質:
  - `--width_mode normal|cjk|unicode-approx` を追加
  - DataTable・グラフ・基本ウィジェットの幅計算を `display_width` ベースで統一
- 日本語検索品質:
  - プロセス検索の非 regex パスで NFKC 正規化を適用
  - 全角/半角・半角カナ揺れ、全角クエリ演算子（`AND`/`OR`/括弧/接頭辞）を解釈

## セットアップ

```bash
./scripts/setup_dev_env.sh
./scripts/check_env.sh
```

## 実行

```bash
cargo run --release -- --help
```

例:

```bash
cargo run --release -- --safe_terminal --width_mode cjk
```

## 公開前チェック

```bash
./scripts/release_prep.sh --tag 0.12.5
```

## 上流同期

```bash
git fetch upstream
git merge upstream/main
```

## 上流とライセンス

- Upstream: [`ClementTsang/bottom`](https://github.com/ClementTsang/bottom)
- この fork は upstream と同じ MIT ライセンスです（`LICENSE`）

## ドキュメント

- 方針原文: `docs/shoki-keikaku.md`
- 実装ロードマップ: `docs/roadmap.md`
- 公開チェックリスト: `docs/github-publication-checklist.md`
- リリース手順: `docs/release-process.md`
- リリースノート草案: `docs/release-notes.md`

## CI 補足

- fork 既定では公開系 workflow は安全側（`docs` は build のみ、`deployment` はスキップ）
- 公開を有効化する場合は Repository variables を設定:
  - `RSJ_ENABLE_PAGES_DEPLOY=1`
  - `RSJ_ENABLE_RELEASE_PIPELINE=1`
- push 後の主要 workflow 確認:
  - `./scripts/check_workflow_runs.sh --wait-secs 900`
