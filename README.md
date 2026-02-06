# rs-j

`bottom` をベースに、`Windows cmd / PowerShell / WSL` でも破綻しにくく、日本語表示と日本語検索に強い TUI を目指すリポジトリです。

## 現在の状態

このリポジトリは「初期環境整備」フェーズです。  
`docs/shoki-keikaku.md` を実行可能な形に落とし込むための基盤を用意しています。

## セットアップ

```bash
./scripts/setup_dev_env.sh
./scripts/check_env.sh
```

## 上流（bottom）取り込み

```bash
./scripts/bootstrap_bottom_fork.sh
```

このスクリプトは以下を行います。

- `upstream/bottom` に upstream を clone（既存時は fetch）
- 現在の Git リポジトリに `upstream` remote がなければ追加

## 開発方針（要約）

- Windows 端末差異を自動検出して安全側デフォルトへ寄せる
- CJK/絵文字を含む表示崩れを減らす幅計算モードを導入する
- 日本語検索の実用性を上げるため NFKC 正規化を導入する
- WSL 固有制約は UI/ヘルプで明示する

## ドキュメント

- 方針原文: `docs/shoki-keikaku.md`
- 実装ロードマップ: `docs/roadmap.md`
- 公開チェックリスト: `docs/github-publication-checklist.md`

## GitHub 公開手順（最短）

1. `git remote add origin <your-repo-url>`
2. `git add .`
3. `git commit -m "chore: bootstrap rs-j environment"`
4. `git push -u origin main`
