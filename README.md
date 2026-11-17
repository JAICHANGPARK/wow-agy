# Antigravity AI Guide & Code Studio for WoW Forever (`Interface: 16001`)

🌐 **Languages**: **English** | [한국어](docs/README.ko.md) | [日本語](docs/README.ja.md) | [简体中文](docs/README.zh-CN.md)

An all-in-one **in-game World of Warcraft Q&A Strategy Assistant** and **Google Antigravity (`google-antigravity` SDK / `agy` CLI) Lua Vibe-Coding Studio** built specifically for **World of Warcraft: Forever** (`## Interface: 16001`).

Ask gameplay questions (quest routes, boss mechanics, item drops, class builds), attach live item/spell tooltips via Shift+Click, vibe-code or debug `.lua` addons, and test live Lua snippets right inside WoW — without alt-tabbing.

---

## Blizzard Official UI Add-On Policy & ToU Compliance

`AntigravityWoW` is engineered from the ground up to strictly comply with **Blizzard Entertainment's UI Add-On Development Policy** and **Terms of Use**:

- **100% Free & Open Source ([MIT License](LICENSE))**: No paywalls, subscriptions, premium tiers, in-game advertisements, or donation solicitations.
- **100% Visible Plain-Text Lua/XML**: Zero obfuscated code, encrypted payloads, or external `.dll`/`.so` binaries.
- **Zero Memory Reading, Pixel-Scanning, or Input Injection**: Unlike screen-scraping or audio/slot sandbox-circumvention hacks, this project uses **only** Blizzard's standard `SavedVariables` file persistence and user-initiated WeakAuras/SimC-style `EditBox` Copy/Paste (`Ctrl+C` / `Ctrl+V`).
- **Zero Combat Automation / Botting**: Never automates movement, targeting, or spell rotation decisions. Protected UI & macro operations strictly respect `InCombatLockdown()` and WoW Forever's `C_Secrets` combat restrictions.
- **Safe Macro Management**: Displays a security notice if a generated macro includes `/run` or `/script`, backs up overwritten macros automatically, and supports 1-command rollback via `/agy undo`.

---

## Key Features

### 1. In-Game WoW AI Strategy & Q&A Assistant
- **Quick Slash Commands**: Type `/wowask <question>` (or `/wowq`, `/와우질문`) anytime in chat.
- **Rich Live Context**: Automatically attaches character level/class/race, map coordinates, **equipped gear (slots 1–18)**, **professions & skill ranks**, **current target info (name, classification, NPC ID)**, and **active quest objectives**.
- **Official `C_TooltipInfo` Stat Attachment**: `Shift+Click` or **Drag & Drop** any item or spell into the prompt box — its full in-game tooltip stats and effects are extracted via Blizzard's official `C_TooltipInfo.GetHyperlink` API for accurate gear comparisons.
- **1-Click Map Waypoint (`📍 Map Pin`) & Party Share**: Pin coordinates from AI answers directly onto the native WoW map with SuperTrack navigation arrows (`UiMapPoint` + `C_SuperTrack`), or share a 3-line summary to Party/Raid/Guild chat (with anti-spam cooldown).

### 2. In-Game Antigravity Lua Coding IDE (4 Tabs)
- **Tab 1 — Q&A & Coding Terminal**: Chat with Antigravity, run attached Lua snippets in 1 click, generate macros, or sync file edits in `Interface/AddOns/`.
- **Tab 2 — Live Lua Studio**: Write and execute WoW Forever (`16001`) Lua code immediately via `loadstring` (`Ctrl+Enter`) with captured `print()` output and execution timing (`ms`) — no `/reload` required.
- **Tab 3 — Lua Error Debugger**: Non-intrusively chains `seterrorhandler` to record runtime Lua stack traces from any addon, with a 1-click **Ask Antigravity to Fix** button.
- **Tab 4 — Snippets & Official Blizzard Tools**: Manage saved Lua snippets and launch `/api`, `/fstack`, `/etrace`, and `/reload`.

### 3. Global 12-Language Support (Default Fallback: English `enUS`)
Auto-detects all official Blizzard client locales (`GetLocale()`) and supports instant zero-reload switching via the **`[🌐 Auto (...)]`** header button or `/agy lang <code>`:
- **Americas / Global**: `enUS` / `enGB` (Default), `esMX`, `ptBR`
- **Asia**: `koKR` (Korean), `jaJP` (Japanese — manual switch), `zhCN` (Simplified Chinese), `zhTW` (Traditional Chinese)
- **Europe**: `deDE`, `frFR`, `esES`, `ruRU`, `itIT`

---

## Prerequisites

1. **World of Warcraft: Forever** client (`Interface: 16001`)
2. **[`uv`](https://docs.astral.sh/uv/)** *(Recommended — manages **Python 3.15** & `google-antigravity` automatically)* or **Python 3.13+ (3.15 recommended)**:
   - Install `uv` (macOS / Linux): `curl -LsSf https://astral.sh/uv/install.sh | sh`
   - Install `uv` (Windows PS): `powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"`
3. **Antigravity CLI (`agy`)** — **OR** **`google-antigravity` Python SDK**:
   - Install `agy` CLI on macOS / Linux: `curl -fsSL https://antigravity.google/cli/install.sh | bash`
   - Install `agy` CLI on Windows (PowerShell): `irm https://antigravity.google/cli/install.ps1 | iex`
   - Or sync Python SDK via `uv`: `uv sync` *(fallback: `pip install -r requirements.txt`)*

---

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/JAICHANGPARK/wow-addon-agy.git
cd wow-addon-agy
```

### 2. Install the Addon into WoW Forever

**macOS / Linux:**
```bash
chmod +x ./scripts/install.sh
./scripts/install.sh "/Applications/World of Warcraft/_forever_"
```
*(Creates a symlink to `AddOn/AntigravityWoW` and copies `AGENTS.md` into `Interface/AddOns/`.)*

**Windows (PowerShell):**
```powershell
.\scripts\install.ps1 "C:\Program Files (x86)\World of Warcraft\_forever_"
```

---

## Authentication Setup (4 Official Options)

Run the built-in interactive authentication wizard anytime, or verify your current status:

```bash
# Guided interactive setup (launches `agy` login or saves GEMINI_API_KEY to a 0600 `.env` file)
uv run wow-agy-daemon --setup-auth

# Verify current authentication status
uv run wow-agy-daemon --check-auth
```

1. **Option 1 — Antigravity CLI (`agy`) Google Sign-In (No API Key Needed)**:
   - Run `agy` once in your terminal and complete the browser Google OAuth sign-in. The bridge automatically reuses your authenticated `agy` CLI session.
2. **Option 2 — Google AI Studio API Key (`.env` or Environment Variable)**:
   - Create an API key at https://aistudio.google.com/app/api-keys and save it via `python3 bridge/daemon.py --setup-auth` (writes to git-ignored `.env` with `0600` permissions) or `export GEMINI_API_KEY="your-key"`.
3. **Option 3 — Google Cloud / Gemini Enterprise (`Vertex AI` ADC)**:
   - Run `gcloud auth application-default login`, then pass `--vertex --project <GCP_PROJECT_ID>`.
4. **Option 4 — 100% Local On-Device Models (Zero Auth / Zero Cloud Cost)**:
   - Use LiteRT Gemma 4 (`--litert-model`) or local Ollama / LM Studio (`--local-openai-url`) with no account or API key required.

---

## Running the Companion Bridge

Because WoW's Lua sandbox blocks direct network or subprocess calls, run the lightweight local bridge alongside the game:

### Option A: Recommended `uv` Workflow (Auto-installs Python & `google-antigravity` SDK)
```bash
# Sync locked environment (`uv.lock`) and launch the bridge CLI entry point:
uv run wow-agy-daemon --wow-dir "/Applications/World of Warcraft/_forever_"

# On-Device LiteRT Local Model (`litert` extra — No API Key Required):
uv run --extra litert wow-agy-daemon --backend sdk --litert-model ~/.litert-lm/models/gemma4-26b/model.litertlm

# Local Ollama / LM Studio Server (No API Key Required):
uv run wow-agy-daemon --backend sdk --local-openai-url http://localhost:11434/v1 --local-model gemma4:26b
```

### Option B: Standard `python3` Zero-Dependency Mode (with `agy` CLI)
If you already have `agy` CLI signed in and prefer running without installing any packages:
```bash
python3 bridge/daemon.py --wow-dir "/Applications/World of Warcraft/_forever_"
```

### Option C (Optional): Register the WoW Forever MCP Server
Expose live player state, captured Lua errors, and addon scaffolding directly to `agy` CLI or Antigravity IDE:
```bash
agy mcp add wow-forever -- env WOW_FOREVER_DIR="/Applications/World of Warcraft/_forever_" uv --directory "$(pwd)" run wow-agy-mcp
```

---

## How to Use In-Game

Click the **`AGY` minimap button** or type **`/agy`** in chat.

### Workflow 1: Zero-Reload Instant Q&A & Snippets (Clipboard Bridge)
1. Type a question (or click **`🎯 Ask About Target`**, or `Shift+Click` / drag an item into the input box).
2. Press **`Ctrl+Enter`** (or click **`Copy Request (No-Reload)`**) and press **`Ctrl+C` (`Cmd+C` on Mac)**.
3. Wait for the desktop notification confirming the reply is copied to your clipboard.
4. Click **`Paste Reply / Code`**, press **`Ctrl+V` (`Cmd+V`)**, and click **`Show Reply in Chat`** (or **`▶ Run Code`**) — zero loading screens!

### Workflow 2: Full Addon File Editing (`SavedVariables` Sync)
1. Enter your addon creation or bug-fix request and click **`Send / Sync (/reload)`** (or **`Alt+Enter`**).
2. WoW reloads to flush `SavedVariables` to disk while the local bridge edits files inside `Interface/AddOns/`.
3. Once the desktop notification appears, run `/reload` (`Shift+Click` minimap button) to load the newly generated files and `Inbox.lua` summary.

---

## Slash Commands & Shortcuts

| Command / Shortcut | Description |
| :--- | :--- |
| `/agy` or `/antigravity` | Toggle the main Antigravity AI Guide & Studio window |
| `/wowask <q>` or `/wowq <q>` | Ask a WoW gameplay, quest, boss, or gear question |
| `/agy lang <code\|auto>` | Switch UI & AI reply language live (e.g. `enUS`, `koKR`, `jaJP`, `zhCN`, `deDE`) |
| `/agy lua` | Open Tab 2 (`Live Lua Studio`) |
| `/agy errors` | Open Tab 3 (`Error Debugger`) |
| `/agy run <code>` | Execute a one-line Lua snippet immediately |
| `/agy undo` | Revert the most recently created or updated macro |
| `/agy sync` | Safely run `/reload` outside combat |
| `Ctrl+Enter` (Prompt / Editor) | Open Zero-Reload copy packet (Prompt) / Execute Lua snippet (Editor) |
| `ESC → Options → Keybindings` | Bind hotkeys under **AddOns → Antigravity AI Guide & Studio** |

---

## Running Tests

```bash
python3 -m unittest discover -s tests -v
```

## License

Released under the [MIT License](LICENSE).
