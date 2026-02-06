# 実装ロードマップ

`docs/shoki-keikaku.md` の内容を、fork 実装向けに分解した実行計画です。

## 進捗メモ（2026-02-06）

- Phase 2 着手:
  - Windows cmd/PowerShell 風環境を検出して `dot_marker` を自動有効化
  - `--dot_marker` と `config.flags.dot_marker` は自動判定より優先
  - WSL 検出時に起動メッセージで既知制約を通知
  - `--safe_terminal` / `flags.safe_terminal` で互換重視プロファイル（basic + dot）を適用
  - safe profile 時はグラフ軸/交点/ドットを ASCII 寄り記号へ切替（`-`, `|`, `+`, `.`）
  - ステータス行に端末判定結果（safe/dot/width_mode/wsl）を常時表示
- Phase 3 着手:
  - `width_mode`（`normal` / `cjk` / `unicode-approx`）を CLI と config に追加
  - プロセス検索クエリの幅計算に `width_mode` を適用
  - テーブルのヘッダー/セル切り詰めに `width_mode` を適用
  - ヘルプダイアログの行幅見積もりと kill ダイアログの名前切り詰めにも適用
  - basic CPU/MEM の PipeGauge ラベル配置と battery タブ幅にも適用
  - 時系列グラフの軸ラベル/タイトル/凡例レイアウト幅にも `width_mode` を適用
  - DataTable 系（disk/temp/proc/sort）の列幅算出、basic table carousel、network 凡例パディングにも `display_width` を適用
- Phase 4 着手:
  - regex 未使用時の文字列検索に NFKC 正規化を適用
  - `ignore_case` 有効時は正規化後の大文字小文字差を吸収
  - 全角/半角・半角カナ揺れの回帰テストを追加
  - 全角の構文トークン（`AND`/`OR`/括弧/接頭辞）も NFKC 経由で解釈
- Phase 5 着手:
  - `README.md` に実装ハイライト・upstream/ライセンス情報・実行例を追記
  - `docs/release-notes.md` に初回公開向けリリースノート草案を追加
  - `docs/release-process.md` にタグ運用（`X.Y.Z`）と公開手順を明文化
- Phase 6 着手:
  - `scripts/release_prep.sh` を追加し、公開前チェックをワンコマンド化
  - `README.md` / `docs/release-process.md` / `docs/github-publication-checklist.md` を同スクリプト前提で整理
- Phase 7 着手:
  - fork 既定で公開系 workflow を安全側に寄せる（docs build-only / deployment skip）
  - `RSJ_ENABLE_PAGES_DEPLOY` / `RSJ_ENABLE_RELEASE_PIPELINE` で公開系 workflow を明示有効化
- Phase 8 着手:
  - `scripts/check_workflow_runs.sh` を追加し、push 後の主要 workflow 状態確認を自動化
  - `README.md` / `docs/release-process.md` / `docs/github-publication-checklist.md` へ導線を追加
- Phase 9 着手:
  - `codecov` workflow を fork 既定で安全側（coverage job skip）に調整
  - `check_workflow_runs.sh` の失敗判定バグを修正
- Phase 10 着手:
  - `deployment` workflow に常時実行の初期ジョブを追加し、fork 既定での startup_failure を解消
  - `RSJ_ENABLE_RELEASE_PIPELINE` 未設定時は明示メッセージで skip 理由を表示
  - `build_releases.yml` 呼び出しに必要な `permissions`（`id-token` / `attestations`）を caller に付与
- 未完了:
  - GitHub Release のタグ作成と公開（Phase 5）

## Phase 0: リポジトリ初期化

- 開発スクリプトと CI を整備する
- Rust ツールチェインを固定する
- 公開前チェックリストを定義する

完了条件:
- `./scripts/check_env.sh` が成功する
- GitHub Actions で workflow が起動する

## Phase 1: upstream 取り込み

- `bottom` の upstream を取得する
- 取り込み方式を確定する（subtree もしくは fork 直接運用）
- 変更点を隔離するためのディレクトリ/モジュール境界を決める

完了条件:
- upstream 差分を定期同期できる手順が文書化されている

## Phase 2: 端末安全デフォルト

- Windows cmd / PowerShell / Windows Terminal / WSL を判定
- 非互換フォント環境で dot marker と ASCII 寄り描画へ自動退避
- 初回起動時メッセージに切替理由を表示

完了条件:
- Windows 系端末で初期表示崩れが再現しない

## Phase 3: 日本語表示品質

- 幅計算モード（`normal` / `cjk` / `unicode-approx`）を追加
- 切り詰め・スクロールを grapheme cluster 前提へ統一
- 表示回帰テスト（日本語/絵文字/結合文字）を追加

完了条件:
- CJK を含む主要ビューで列崩れが許容範囲内

## Phase 4: 日本語検索品質

- フィルタ入力に NFKC 正規化を導入
- casefold 相当の比較で英字揺れを吸収
- 正規化は検索キーのみ適用し、表示文字列は保持

完了条件:
- 半角/全角・カナ揺れを含む検索テストが通過

## Phase 5: 公開

- README とリリースノートを更新
- ライセンス表記と upstream クレジットを確認
- GitHub release を作成

完了条件:
- `main` への push と release 公開が完了

## Phase 6: 公開運用の標準化

- 公開前チェックをスクリプト化して手順ぶれを抑える
- リリース手順書とチェックリストを同一フローへ統一する

完了条件:
- `./scripts/release_prep.sh --tag X.Y.Z` が公開前の標準コマンドとして文書化されている

## Phase 7: CI 公開フロー安定化

- fork で write 権限がない場合でも workflow が失敗しない構成にする
- 公開系 workflow を repository variables で明示制御する

完了条件:
- `docs` / `deployment` の startup failure が解消される

## Phase 8: CI 可視化の自動化

- 指定 SHA の workflow 状態（`ci` / `codecov` / `docs`）をまとめて確認できるようにする
- 完了まで待機できる CLI を提供し、公開作業の確認漏れを減らす

完了条件:
- `./scripts/check_workflow_runs.sh --wait-secs 900` が運用手順に組み込まれている

## Phase 9: Codecov 安定化

- fork 既定で codecov 失敗がリリース判定を塞がない構成にする
- workflow 状態監視スクリプトの失敗判定を正しく機能させる

完了条件:
- `codecov` workflow が fork 既定で安定して完了する

## Phase 10: Deployment 起動安定化

- fork 既定でも deployment workflow がジョブ0件で落ちない構成にする
- release pipeline 無効時の理由を workflow ログ上で明示する

完了条件:
- tag push 時の `deployment` が `startup_failure` にならない
