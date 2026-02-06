了解。**bottomをフォークして「WSL / Windows cmdでも破綻しない」「日本語が強い」**を前面に出すなら、勝ち筋はわりとハッキリしてる。

---

## 定義（あなたの差別化ポイントを分解）

日本語サポートを“強み”にするのは、だいたい次の3層です。

1. **表示**：日本語（全角）・絵文字・結合文字でレイアウトが崩れない
2. **入力**：日本語プロセス名の検索・フィルタが実用的（正規化・大小・半角全角など）
3. **ドキュメント/UI文言**：ヘルプ・設定・警告が日本語で自然（翻訳品質）

その上で **Windows cmd / PowerShell / WSL** は、TUIが壊れる典型原因（フォント/Unicode/端末差）を踏み抜きやすい領域。

---

## 要点（bottomをベースにする時点で既に分かってる地雷）

* bottomは **Linux/macOS/Windowsを公式サポート**してる（＝ベースとして妥当）。([GitHub][1])
* ただし **WSLは仕様上の制限**があり、温度センサが見えない・Task Managerと一致しない等は「アプリのバグというより環境の都合」になりがち。([bottom.pages.dev][2])
* Windowsのcmd/PowerShellでは **グラフの点（ブライユ文字）がフォント非対応で崩れる**ことがあり、bottom側も回避策として `--dot_marker` やフォント設定を案内してる。([bottom.pages.dev][2])

ここから読み取れる設計方針はシンプルで、
**「環境依存で崩れるところを“自動で安全側に倒す”」**＋**「日本語の幅計算・切り詰めをちゃんとやる」**がコア。

---

## 比較（“日本語強化”で一番効くのはどこか）

### A. UI日本語化（文言だけ）

実装は簡単。でも差別化としては弱い（翻訳は誰でもできる）。

### B. 日本語表示が崩れない（幅・切り詰め・整列）

差別化として強い。**TUIの品質＝信用**なので、ここが刺さる。

ただし注意：幅計算は「文字」じゃなくて「フォント＋端末」が絡むので完璧は無理。ratatui側でも、`unicode-width` だけでは絵文字などで正確な列幅が出ない、という議論がある。([GitHub][3])
→ だからこそ **“設定可能”にして逃げ道を用意する**のがプロ。

### C. Windows cmd / WSLで「初期状態から」快適

これが一番プロダクト感が出る。bottomのトラブルシュートは既にここを問題として明示してるので、あなたのforkでは「初回から回避」を狙う。([bottom.pages.dev][2])

---

## 具体例（フォークでやるべき実装を、最小で最大に）

### 1) 端末自動プロファイル（Windows cmd/PowerShell/WT/WSLでデフォルトを変える）

bottomがフォント問題を認めていて `--dot_marker` を案内してるなら、fork側では：

* **Windowsのcmd/PowerShell検出 → dot markerをデフォルトON**
* さらに **“Unicode罫線/ブライユを避ける安全テーマ”** を用意（ASCII寄り）

これで「インストールして起動した瞬間に崩れてる」事故を激減できる。([bottom.pages.dev][2])

### 2) “日本語表示が崩れない”の中核：幅計算を差し替え可能にする

現実的な落とし所：

* `width_mode = "normal" | "cjk" | "unicode-approx"` みたいな設定
* `cjk` では `unicode-width` の `width_cjk` 相当の扱い（曖昧幅を広めに取る）
* 表のカラム幅決定・切り詰め・スクロールを **grapheme cluster（見た目の1文字単位）** 前提に統一

ratatui界隈でも幅は鬼門として認識されているので、ここを丁寧にやるのが“日本語強い”の本体になる。([GitHub][3])

### 3) 日本語検索の実用性：正規化（NFKC）＋大小＋半角全角

プロセス名フィルタは、最低でも：

* **Unicode正規化（NFKC）**で「ｶﾀｶﾅ/カタカナ」「全角英数/半角英数」を寄せる
* 大文字小文字の揺れは casefold 的に処理（英字だけでも効く）
* “表示は元のまま、検索キーだけ正規化”にすると事故りにくい

### 4) WSLの“仕様負け”をUIで吸収する

WSLの温度センサ欠落やTask Managerとの差は、bottomの既知問題として明記されてる。([bottom.pages.dev][2])
forkでは、WSL検出時に「この値はホストと一致しない可能性」みたいな注記を、ヘルプかステータス行に出すとユーザの混乱が減る（サポートコストも下がる）。

### 5) ライセンスとフォーク運用

bottomはMITライセンス。フォークして配布するのは問題ないが、著作権表示とライセンス文は保持する。([GitHub][4])
運用面は、**上流追従をラクにするために** “変更点をfeature/モジュール境界で隔離” しておくのが吉。

---

## まずやると効果がデカい「3つの最短タスク」

1. **Windows cmd/PowerShell自動`dot_marker` + ASCII寄り描画**（初期体験が爆上がり）([bottom.pages.dev][2])
2. **幅計算を差し替え可能にして、CJK/絵文字で表が壊れないようにする**（日本語の強みの芯）([GitHub][3])
3. **検索のNFKC正規化**（日本語プロセス名で“使える”になる）

---

この方針で進めると、あなたのforkは「日本語UI」じゃなくて **“日本語で使っても壊れないTUI”** になる。端末UIは壊れた瞬間に信用が死ぬので、ここを狙うのは合理的。

[1]: https://github.com/ClementTsang/bottom "GitHub - ClementTsang/bottom: Yet another cross-platform graphical process/system monitor."
[2]: https://bottom.pages.dev/nightly/troubleshooting "Troubleshooting - bottom"
[3]: https://github.com/ratatui-org/ratatui/issues/75?utm_source=chatgpt.com "Buffer: unicode-width and emojis · Issue #75 · ratatui ..."
[4]: https://github.com/ClementTsang/bottom/blob/main/LICENSE?utm_source=chatgpt.com "MIT license - ClementTsang/bottom"

