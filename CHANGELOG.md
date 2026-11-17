# Changelog

All notable changes to `wow-agy` (`WoWAGY`) are documented in this file.

This project uses Calendar Versioning (`YYYY.MM.DD`).

## [2026.11.17] - 2026-11-17

Initial public release of `wow-agy` for **World of Warcraft: Forever** (`Interface: 16001`).

### Added

- **In-Game Addon (`AddOn/WoWAGY`, `Interface: 16001`)**:
  - Built natively on modern WoW Forever `C_*` APIs (`C_Spell`, `C_Item`, `C_UnitAuras`, `C_Container`, `C_TooltipInfo`, `C_Secrets`, `Settings`, `BackdropTemplate`).
  - Added 3-tab Studio UI (`Ask & Chat`, `Live Lua`, `Errors`) with slash commands `/agy`, `/wow-agy`, `/wowagy`, `/wowask`, `/와우질문`, `/wowq`, `/agy about`, `/agy undo`, and `/agy lang <code>`.
  - Added context-aware player snapshot collection (character info, zone coordinates, equipped items in slots 1 to 18, profession skill ranks, current target name and NPC ID, and active quest objectives).
  - Added `Shift+Click` hyperlink and item/spell drag-and-drop hooks backed by `C_TooltipInfo.GetHyperlink` stat extraction.
  - Added one-click native map waypoints (`UiMapPoint` + `C_SuperTrack`) and 3-line summary sharing to Party, Raid, or Guild chat with a 5-second anti-spam cooldown.
  - Added Live Lua 5.1 sandbox runner (`loadstring`) with captured `print()` output (capped at 200 lines) and execution timing.
  - Added combat-safe macro creation and update helper (`InCombatLockdown()` guard, `/run` and `/script` inspection warning, and `/agy undo` backup restore).
  - Added re-entrancy guarded and throttled runtime Lua error catcher (`seterrorhandler` chain) to inspect stack traces from any installed addon.
  - Added draggable minimap button, modern `AddonCompartmentFunc` menu entry, and native `Settings` panel integration.
  - Added in-game AI model and reasoning effort selector (header button modal, `Settings` panel controls, `/agy model [id]`, `/agy effort [level]`, and automatic `agy models` discovery sync).
  - Added 12 UI and response languages (`enUS` default, `koKR`, `jaJP`, `zhCN`, `zhTW`, `deDE`, `frFR`, `esES`, `esMX`, `ptBR`, `ruRU`, `itIT`).

- **Local Companion Bridge & MCP Server (`bridge/`)**:
  - Added `SavedVariables` file watcher and zero-reload clipboard packet bridge (`AGY_REQ:` / `AGY_RES:` JSON codec) in `bridge/daemon.py`.
  - Added mid-flush `SavedVariables` recovery, atomic state writes (`0600` permissions), and parameterized clipboard commands (`pbcopy`/`pbpaste`, Windows PowerShell `Get-Clipboard`/`Set-Clipboard`, Linux `wl-copy`/`xclip`).
  - Added multi-backend Antigravity runner (`bridge/agy_runner.py`) supporting `agy` CLI (default OAuth session), `google-antigravity` Python SDK (Cloud Gemini API, Vertex AI ADC/Express), and local offline engines (`gemma-local` via LiteRT-LM and `local-openai` for Ollama, LM Studio, or vLLM).
  - Added interactive credential helper (`--setup-auth`, `--check-auth`) in `bridge/auth.py` with `0600` `.env` file permissions.
  - Added stdio JSON-RPC 2.0 MCP server (`bridge/mcp_server.py`) exposing WoW Forever workspace inspection, `16001` static lint checks, SavedVariables queue reader, and `Inbox.lua` writer.

- **Tooling, Packaging & Documentation**:
  - Configured `uv`-first Python 3.15 workflow (`pyproject.toml`, `uv.lock`, `.python-version`) alongside standard `pip` compatibility (`requirements.txt`).
  - Added macOS/Linux (`scripts/install.sh`) and Windows PowerShell (`scripts/install.ps1`) addon symlink installers.
  - Added multilingual documentation (`README.md`, `docs/README.ko.md`, `docs/README.ja.md`, `docs/README.zh-CN.md`), `AGENTS.md` coding rules for `Interface: 16001`, MIT `LICENSE`, and automated unit/Lua 5.1 integration test suite (`tests/test_bridge_and_lua.py`).
