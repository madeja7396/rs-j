# rs-j リリースノート（草案）

対象バージョン: `0.12.13`  
ベース: `bottom v0.12.3`

## 追加

- `--safe_terminal` / `flags.safe_terminal`
  - 互換重視プロファイルを有効化（basic + ASCII 寄り描画）
- `--width_mode` / `flags.width_mode`
  - `normal` / `cjk` / `unicode-approx`
- `--ui-language` / `flags.ui_language`
  - `ja` / `en` を切り替え可能
  - 主要 UI（ヘルプ/ダイアログ/テーブル見出し/ステータス）を日本語化
- プロセス検索の NFKC 正規化
  - 全角/半角・半角カナ揺れを吸収
  - 全角の `AND` / `OR` / 括弧 / 検索接頭辞も解釈

## 変更

- DataTable 系（disk/temp/proc/sort）列幅算出を `display_width` ベースへ変更
- グラフ（軸/凡例/タイトル）幅計算に `width_mode` を適用
- safe terminal 時のグラフ描画記号を ASCII 寄りに変更（`-`, `|`, `+`, `.`）
- ステータス行に `safe_terminal` / `dot_marker` / `width_mode` / `wsl` を表示

## 互換性メモ

- `safe_terminal` は描画互換性優先のため、表現品質（線種/ドット形状）より崩れにくさを優先します。
- WSL では一部メトリクスがネイティブ Windows ツールと一致しない場合があります。

## 検証

- `cargo fmt --all`
- `cargo check`
- `cargo test`（172 unit tests passed）
- `cargo clippy --all-targets --workspace --all-features -- -D warnings`

## 公開前 TODO

- `./scripts/release_prep.sh --tag 0.12.13`
- `./scripts/check_workflow_runs.sh --wait-secs 900`
- `GITHUB_TOKEN=... ./scripts/publish_release.sh --tag 0.12.13`
