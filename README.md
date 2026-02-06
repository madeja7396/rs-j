# rs-j

`bottom` をベースに、`Windows cmd / PowerShell / WSL` でも破綻しにくく、日本語表示と日本語検索に強い TUI を目指す fork です。

## 状態

上流 `bottom` の `main` を取り込み済みです。  
これ以降は `bottom` 本体コード（`src/` など）に対して、以下の改善を段階的に入れます。

- Windows 端末差異を検出して安全側デフォルトへ寄せる
- CJK/絵文字表示崩れを減らす幅計算モードを導入する
- 日本語検索の実用性を上げるため NFKC 正規化を導入する
- WSL 固有制約は UI/ヘルプで明示する

## セットアップ

```bash
./scripts/setup_dev_env.sh
./scripts/check_env.sh
```

## 実行

```bash
cargo run --release -- --help
```

## 上流同期

```bash
git fetch upstream
git merge upstream/main
```

## ドキュメント

- 方針原文: `docs/shoki-keikaku.md`
- 実装ロードマップ: `docs/roadmap.md`
- 公開チェックリスト: `docs/github-publication-checklist.md`
