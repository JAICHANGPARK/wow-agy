# wow-agy

[English](../README.md) | [한국어](README.ko.md) | 日本語 | [简体中文](README.zh-CN.md)

`wow-agy` (`WoWAGY`) は、**World of Warcraft: Forever** (`Interface: 16001`) クライアントとローカルの Google Antigravity (`agy` CLI または `google-antigravity` Python SDK) を接続するゲーム内アドオンおよびブリッジツールです。

ゲーム画面から離れずにクエスト手順、ボスのギミック、ドロップ装備の比較などを質問できるほか、Lua コードの即時実行や他アドオンのエラー解析、`Interface/AddOns/` 内のファイル編集を行えます。

## 仕組み

WoW の Lua 5.1 サンドボックスからは外部通信やプロセス起動ができないため、公式 API の範囲内で以下の 2 通りの方法でローカルデーモンと連携します。

1. **クリップボードブリッジ (`/reload` 不要)**: ゲーム内の `EditBox` からリクエスト文字列をコピー (`Ctrl+C` / `Cmd+C`) すると、ローカルデーモンが Antigravity を実行して回答をクリップボードへ戻します。ゲーム側で貼り付け (`Ctrl+V` / `Cmd+V`) するだけで即座に表示・実行できます。
2. **`SavedVariables` 同期**: `/reload` 時に `WTF/Account/.../SavedVariables/WoWAGY.lua` へリクエストを書き出し、デーモンがアドオンファイルを編集して `AddOn/WoWAGY/Inbox.lua` に結果を保存します。

画面ピクセルの読み取り、メモリ参照、キー入力の自動送信、戦闘の自動化は一切行いません。

## 主な機能

- **ゲーム状態を踏まえた Q&A**: キャラクター情報、現在座標、装備中アイテム (1〜18 スロット)、専門スキル、現在のターゲット (名前・NPC ID)、進行中クエスト目標を任意で添付できます。
- **ツールチップ情報の取得**: アイテムやスキルを `Shift+クリック` またはドラッグ＆ドロップすると、`C_TooltipInfo.GetHyperlink` でステータス文字列を取得して添付します。
- **マップピンとチャット共有**: 回答内の座標を標準マップピン (`UiMapPoint` + `C_SuperTrack`) として設置したり、パーティ等に 3 行以内の要約を共有したりできます。
- **Live Lua エディタ**: `/reload` なしで Lua コードを実行 (`loadstring`) し、`print()` 出力と実行時間を確認できます。
- **Lua エラーデバッガ**: `seterrorhandler` チェーンで捕捉したエラーのスタックトレースをそのまま診断・修正依頼に回せます。
- **12 言語対応**: デフォルトは英語 (`enUS`)。公式クライアントロケールの自動検出に加え、`/agy lang jaJP` で日本語 UI と日本語回答へ切り替えられます（英語クライアントで日本語を表示する場合は NihongoPlus 等の日本語フォントアドオンの併用を推奨します）。

## 必要環境

- World of Warcraft: Forever (`Interface: 16001`)
- [`uv`](https://docs.astral.sh/uv/) (推奨。Python 3.15 と依存パッケージを自動管理) または Python 3.13 以上
- Antigravity CLI (`agy`) または `google-antigravity` Python パッケージ

## インストール

```bash
git clone https://github.com/JAICHANGPARK/wow-agy.git
cd wow-agy

# macOS / Linux
chmod +x ./scripts/install.sh
./scripts/install.sh "/Applications/World of Warcraft/_forever_"
```

Windows (PowerShell):

```powershell
.\scripts\install.ps1 "C:\Program Files (x86)\World of Warcraft\_forever_"
```

## 認証設定とブリッジの起動

初回は以下のコマンドで認証を設定・確認できます。

```bash
uv run wow-agy-daemon --setup-auth
uv run wow-agy-daemon --check-auth
```

- `agy` CLI を使う場合: `curl -fsSL https://antigravity.google/cli/install.sh | bash` (Windows PS: `irm https://antigravity.google/cli/install.ps1 | iex`) で導入後、`agy` を一度起動してブラウザで Google ログインします。
- API キーを使う場合: https://aistudio.google.com/app/api-keys で取得し、`--setup-auth` で `.env` (`0600` 権限) に保存します。
- ローカルモデルを使う場合: LiteRT (`--litert-model`) や Ollama / LM Studio (`--local-openai-url`) なら認証不要で動作します。

ブリッジデーモンの起動:

```bash
uv run wow-agy-daemon --wow-dir "/Applications/World of Warcraft/_forever_"
```

## 主なスラッシュコマンド

| コマンド | 説明 |
| :--- | :--- |
| `/agy`, `/wow-agy` | メインウィンドウの開閉 |
| `/wowask <質問>`, `/wowq <質問>` | WoW 攻略・クエスト・装備の質問を登録 |
| `/agy lang <コード\|auto>` | 言語の切り替え (`jaJP`, `enUS`, `koKR`, `zhCN` など) |
| `/agy lua` / `/agy errors` | Live Lua エディタ / エラーデバッガを開く |
| `/agy undo` | 直前に作成・更新したマクロを元に戻す |
| `/agy about` | バージョン・作者・GitHub URL を表示 |
| `/agy sync` | 非戦闘時に `/reload` を実行 |

## 作者・ライセンス

- 作者: JAICHANGPARK (Dreamwalker)
- リポジトリ: https://github.com/JAICHANGPARK/wow-agy
- ライセンス: [MIT](../LICENSE)
