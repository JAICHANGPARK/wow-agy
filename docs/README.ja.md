# Antigravity AI ガイド & コードスタジオ — WoW Forever (`Interface: 16001`)

🌐 **言語 (Languages)**: [English](../README.md) | [한국어](README.ko.md) | **日本語** | [简体中文](README.zh-CN.md)

**World of Warcraft: Forever**（`## Interface: 16001`）のゲーム内からAlt+Tab不要で **Google Antigravity（`google-antigravity` SDK / `agy` CLI）** を呼び出し、**クエスト・ボス攻略・装備比較の質問（Q&A）** や **Luaアドオン開発・ライブ実行・エラーデバッグ** ができるオールインワンアドオン＆ローカルブリッジです。

---

## Blizzard 公式 UI アドオン開発ポリシーへの準拠

本プロジェクトは **Blizzard Entertainment の公式 UI アドオン開発ポリシー** および利用規約（ToU）を厳格に遵守して設計されています：

- **完全無料・オープンソース（[MIT License](../LICENSE)）**: 有料課金、広告表示、寄付の勧誘は一切ありません。
- **100% 平文の Lua/XML コード**: 難読化・暗号化や外部バイナリ（`.dll`/`.so`）は一切使用していません。
- **画面ピクセルスキャン・メモリ読み取り・入力自動化の排除**: 画面キャプチャによるピクセル解析や音声ファイルを用いたサンドボックス回避ハックは行わず、公式の **`SavedVariables` 同期** と WeakAuras 等と同じ **ユーザー操作による `EditBox` コピー＆ペースト（`Ctrl+C`/`V`）** のみを使用します。
- **戦闘自動化（Bot行為）の禁止**: 自動移動・ターゲット・スキル発動は行わず、`InCombatLockdown()` および `C_Secrets` 制限を遵守します。
- **安全なマクロ管理**: `/run` を含むマクロには注意喚起を表示し、`/agy undo` で直前のマクロ変更をいつでも元に戻せます。

---

## 主な機能

1. **ゲーム内 WoW AI 攻略ガイド（Q&A モード）**
   - チャット欄で `/wowask <質問>` を入力するだけでいつでも質問可能
   - キャラクター情報、現在地座標、**装備中のアイテム（1〜18スロット）**、**専門スキル熟練度**、**現在のターゲット（名前・NPC ID）**、**進行中クエストの目標**を自動添付
   - **公式 `C_TooltipInfo` によるツールチップ性能添付**: アイテムやスキルを **`Shift+クリック` またはドラッグ＆ドロップ** すると、実際のステータス文字列を抽出して正確な装備比較を実行
   - **ワンクリック・マップピン（`📍 マップピン`）＆パーティ共有**: AI回答の座標を標準マップピン（`UiMapPoint`）と矢印で即座に表示

2. **4タブ構成のゲーム内 Lua コーディング IDE**
   - **タブ1（質問 & 開発）** / **タブ2（Live Lua エディタ：`Ctrl+Enter` 即時実行）** / **タブ3（Luaエラーデバッガ）** / **タブ4（スニペット & 公式 `/api`・`/fstack` ツール）**

3. **12言語マルチリンガル対応（デフォルト英語 `enUS` + 日本語 `jaJP` 対応）**
   - 画面右上の **`[🌐 Auto (...)]`** ボタン、または **`/agy lang jaJP`** でリロードなしに日本語UI＆日本語AI回答へ切り替えられます。
   - *※ヒント：英語クライアント（`enUS`）で日本語を表示する場合、日本語フォントアドオン（NihongoPlus等）の併用を推奨します。*

---

## インストールと起動方法

### 1. アドオンのインストール

**macOS / Linux:**
```bash
chmod +x ./scripts/install.sh
./scripts/install.sh "/Applications/World of Warcraft/_forever_"
```

**Windows (PowerShell):**
```powershell
.\scripts\install.ps1 "C:\Program Files (x86)\World of Warcraft\_forever_"
```

### 2. ローカルブリッジデーモンの起動

```bash
# A) agy CLI 自動検出モード（APIキー設定不要）
python3 bridge/daemon.py --wow-dir "/Applications/World of Warcraft/_forever_"

# B) Google Antigravity Python SDK モード（クラウド Gemini / ローカル Gemma 4 / Ollama 対応）
pip install -r requirements.txt
export GEMINI_API_KEY="あなたのAPIキー"  # https://aistudio.google.com/app/api-keys
python3 bridge/daemon.py --backend sdk --wow-dir "/Applications/World of Warcraft/_forever_"
```

---

## ゲーム内での使い方

1. **リロード不要の即時質問（クリップボードブリッジ）**:
   - `/agy` を開き、`/agy lang jaJP` で日本語に設定 → 質問を入力して **`Ctrl+Enter`** → **`Ctrl+C` (`Cmd+C`)** でコピー
   - デスクトップ通知が届いたら **`[回答/コードを貼り付け]`** → **`Ctrl+V` (`Cmd+V`)** → **`[チャットに回答を表示]`** をクリック！
2. **アドオンファイルの生成・修正（`SavedVariables` 同期）**:
   - 指示を入力して **`[送信 / 同期 (/reload)]`**（`Alt+Enter`）を実行し、完了通知後に再度 `/reload` すると反映されます。
