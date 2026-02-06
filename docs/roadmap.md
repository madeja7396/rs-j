# 実装ロードマップ

`docs/shoki-keikaku.md` の内容を、fork 実装向けに分解した実行計画です。

## 進捗メモ（2026-02-06）

- Phase 2 着手:
  - Windows cmd/PowerShell 風環境を検出して `dot_marker` を自動有効化
  - `--dot_marker` と `config.flags.dot_marker` は自動判定より優先
  - WSL 検出時に起動メッセージで既知制約を通知
  - `--safe_terminal` / `flags.safe_terminal` で互換重視プロファイル（basic + dot）を適用
  - safe profile 時はグラフ軸/交点/ドットを ASCII 寄り記号へ切替（`-`, `|`, `+`, `.`）
- Phase 3 着手:
  - `width_mode`（`normal` / `cjk` / `unicode-approx`）を CLI と config に追加
  - プロセス検索クエリの幅計算に `width_mode` を適用
  - テーブルのヘッダー/セル切り詰めに `width_mode` を適用
  - ヘルプダイアログの行幅見積もりと kill ダイアログの名前切り詰めにも適用
  - basic CPU/MEM の PipeGauge ラベル配置と battery タブ幅にも適用
  - 時系列グラフの軸ラベル/タイトル/凡例レイアウト幅にも `width_mode` を適用
- Phase 4 着手:
  - regex 未使用時の文字列検索に NFKC 正規化を適用
  - `ignore_case` 有効時は正規化後の大文字小文字差を吸収
  - 全角/半角・半角カナ揺れの回帰テストを追加
  - 全角の構文トークン（`AND`/`OR`/括弧/接頭辞）も NFKC 経由で解釈
- 未完了:
  - 端末判定結果をステータス行から参照可能にする（ヘルプには表示済み）
  - grapheme cluster 前提の幅モードを全ウィジェットへ展開

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
