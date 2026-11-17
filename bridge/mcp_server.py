#!/usr/bin/env python3
"""WoW Forever (Interface: 16001) Model Context Protocol (MCP) Stdio Server.

Zero external dependency JSON-RPC 2.0 MCP server so you can register it directly in
Antigravity CLI (`agy mcp add wow-forever -- python3 /path/to/bridge/mcp_server.py`)
or Antigravity IDE!

Tools provided to Antigravity:
- `wow_get_player_context`     : Live player, location, quests & mouseover frame from SavedVariables
- `wow_get_lua_errors`         : Captured runtime Lua error stack traces from WoW Forever
- `wow_list_addons`            : Installed addons & TOC versions in Interface/AddOns
- `wow_scaffold_forever_addon` : Scaffolds a clean `## Interface: 16001` addon folder
- `wow_send_to_inbox`          : Sends a message, runnable Lua snippet, or macro into Inbox.lua
"""

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from bridge.agy_runner import scaffold_forever_addon_files
from bridge.daemon import auto_detect_wow_flavor_dir, find_saved_variables_files
from bridge.lua_serde import load_saved_variables_file, write_inbox_lua


MCP_PROTOCOL_VERSION = "2024-11-05"


def _resolve_paths() -> tuple[Path | None, Path, Path]:
    wow_env = os.environ.get("WOW_FOREVER_DIR")
    wow_dir = Path(wow_env).expanduser().resolve() if wow_env else auto_detect_wow_flavor_dir()

    addons_env = os.environ.get("WOW_ADDONS_DIR")
    if addons_env:
        addons_dir = Path(addons_env).expanduser().resolve()
    elif wow_dir and (wow_dir / "Interface" / "AddOns").exists():
        addons_dir = (wow_dir / "Interface" / "AddOns").resolve()
    else:
        addons_dir = (REPO_ROOT / "AddOn").resolve()

    inbox_path = addons_dir / "WoWAGY" / "Inbox.lua"
    return wow_dir, addons_dir, inbox_path


def _load_latest_db(wow_dir: Path | None) -> dict[str, Any]:
    explicit_sv_env = os.environ.get("WOW_SAVED_VARS")
    explicit_sv = Path(explicit_sv_env).expanduser().resolve() if explicit_sv_env else None
    sv_files = find_saved_variables_files(wow_dir, explicit_sv)
    if not sv_files:
        return {}
    latest = max(sv_files, key=lambda p: p.stat().st_mtime)
    parsed = load_saved_variables_file(latest)
    db = parsed.get("WoWAGYDB") or parsed.get("AntigravityWoWDB")
    return db if isinstance(db, dict) else {}


TOOLS_SPEC: list[dict[str, Any]] = [
    {
        "name": "wow_get_player_context",
        "description": (
            "Reads the latest World of Warcraft: Forever (Interface: 16001) player character "
            "info, level, class, zone, map coordinates, tracked quests, and mouseover UI frame."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "wow_get_lua_errors",
        "description": (
            "Returns captured runtime Lua error messages, addon sources, occurrence counts, "
            "and stack traces recorded in-game by wow-agy (WoWAGY)."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "limit": {
                    "type": "integer",
                    "description": "Maximum number of recent errors to return (default 10).",
                }
            },
        },
    },
    {
        "name": "wow_list_addons",
        "description": "Lists installed WoW addons in Interface/AddOns along with their .toc Interface versions.",
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "wow_scaffold_forever_addon",
        "description": (
            "Scaffolds a new World of Warcraft: Forever (`## Interface: 16001`) addon folder "
            "with compliant .toc and Core.lua boilerplate."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "addon_name": {
                    "type": "string",
                    "description": "Alphanumeric folder and .toc name (e.g., 'ForeverManaBar').",
                },
                "description": {
                    "type": "string",
                    "description": "Short summary for the .toc Notes header.",
                },
            },
            "required": ["addon_name"],
        },
    },
    {
        "name": "wow_send_to_inbox",
        "description": (
            "Pushes a chat message, runnable Lua snippet, or macro into WoWAGY/Inbox.lua "
            "so the player receives it in-game upon `/reload`."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "message": {
                    "type": "string",
                    "description": "Concise explanation message to show in the in-game AGY terminal.",
                },
                "lua_code": {
                    "type": "string",
                    "description": "Optional Lua 5.1 snippet (Forever 16001 compatible) for 1-click in-game execution.",
                },
                "macro_name": {
                    "type": "string",
                    "description": "Optional WoW macro name (max 16 chars).",
                },
                "macro_body": {
                    "type": "string",
                    "description": "Optional WoW macro body (max 255 chars).",
                },
                "waypoint_map_id": {
                    "type": "integer",
                    "description": "Optional WoW UiMapID for setting a map waypoint pin in-game.",
                },
                "waypoint_x": {
                    "type": "number",
                    "description": "Optional waypoint X coordinate (0-100).",
                },
                "waypoint_y": {
                    "type": "number",
                    "description": "Optional waypoint Y coordinate (0-100).",
                },
                "waypoint_label": {
                    "type": "string",
                    "description": "Optional label for the map waypoint pin.",
                },
            },
            "required": ["message"],
        },
    },
]


def handle_tool_call(name: str, arguments: dict[str, Any]) -> str:
    wow_dir, addons_dir, inbox_path = _resolve_paths()

    if name == "wow_get_player_context":
        db = _load_latest_db(wow_dir)
        snap = db.get("lastContextSnapshot")
        if not snap:
            outbox = db.get("outbox")
            if isinstance(outbox, list) and outbox:
                last_req = outbox[-1]
                if isinstance(last_req, dict):
                    snap = last_req.get("context")
        return json.dumps(
            {
                "wowDir": str(wow_dir) if wow_dir else None,
                "addonsDir": str(addons_dir),
                "context": snap or "No SavedVariables snapshot found yet (run /reload in-game first).",
            },
            ensure_ascii=False,
            indent=2,
        )

    if name == "wow_get_lua_errors":
        db = _load_latest_db(wow_dir)
        errs = db.get("errors")
        limit = int(arguments.get("limit", 10))
        if not isinstance(errs, list) or not errs:
            return "현재 캡처된 인게임 Lua 에러가 없습니다."
        return json.dumps(errs[-limit:], ensure_ascii=False, indent=2)

    if name == "wow_list_addons":
        items: list[dict[str, Any]] = []
        if addons_dir.exists():
            for d in sorted(addons_dir.iterdir()):
                if not d.is_dir():
                    continue
                toc_file = d / f"{d.name}.toc"
                iface = "unknown"
                if toc_file.exists():
                    for line in toc_file.read_text(encoding="utf-8", errors="replace").splitlines():
                        if line.lower().startswith("## interface:"):
                            iface = line.split(":", 1)[1].strip()
                            break
                items.append({"name": d.name, "interface": iface})
        return json.dumps({"addonsDir": str(addons_dir), "addons": items}, ensure_ascii=False, indent=2)

    if name == "wow_scaffold_forever_addon":
        addon_name = str(arguments.get("addon_name", "")).strip()
        desc = str(arguments.get("description", "")).strip()
        created = scaffold_forever_addon_files(addons_dir, addon_name, desc)
        return json.dumps(
            {"addonsDir": str(addons_dir), "createdFiles": created},
            ensure_ascii=False,
            indent=2,
        )

    if name == "wow_send_to_inbox":
        existing_msgs: list[dict[str, Any]] = []
        if inbox_path.exists():
            try:
                raw = inbox_path.read_text(encoding="utf-8")
                marker = "ns.InboxPayload ="
                idx = raw.find(marker)
                if idx != -1:
                    parsed = load_saved_variables_file("InboxPayload = " + raw[idx + len(marker) :])
                    payload = parsed.get("InboxPayload")
                    if isinstance(payload, dict) and isinstance(payload.get("messages"), list):
                        existing_msgs = list(payload["messages"])
            except Exception:
                existing_msgs = []

        wp_obj: dict[str, Any] | None = None
        if arguments.get("waypoint_x") and arguments.get("waypoint_y"):
            wp_obj = {
                "mapID": int(arguments.get("waypoint_map_id") or 0),
                "x": float(arguments["waypoint_x"]),
                "y": float(arguments["waypoint_y"]),
                "label": str(arguments.get("waypoint_label") or "추천 위치"),
            }

        msg_id = f"mcp-{int(time.time() * 1000)}"
        new_msg = {
            "id": msg_id,
            "requestId": "mcp",
            "role": "assistant",
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "summary": str(arguments.get("message", ""))[:60],
            "content": f"|cff4285F4[Antigravity MCP]|r {arguments.get('message', '')}",
            "code": str(arguments.get("lua_code", "")),
            "macroName": str(arguments.get("macro_name", "")),
            "macroBody": str(arguments.get("macro_body", "")),
            "waypoint": wp_obj,
            "filesChanged": [],
        }
        existing_msgs.append(new_msg)
        write_inbox_lua(inbox_path, existing_msgs, daemon_status="mcp-connected")
        return f"Delivered message ({msg_id}) to {inbox_path}. Run `/reload` in WoW Forever to view."

    raise ValueError(f"Unknown MCP tool: {name}")


def process_jsonrpc_message(req: dict[str, Any]) -> dict[str, Any] | None:
    method = req.get("method", "")
    req_id = req.get("id")

    # Notifications do not carry an id and expect no response
    if req_id is None:
        return None

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "protocolVersion": MCP_PROTOCOL_VERSION,
                "capabilities": {"tools": {}},
                "serverInfo": {
                    "name": "antigravity-wow-forever-mcp",
                    "version": "1.0.0",
                },
            },
        }

    if method == "ping":
        return {"jsonrpc": "2.0", "id": req_id, "result": {}}

    if method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {"tools": TOOLS_SPEC},
        }

    if method == "tools/call":
        params = req.get("params") or {}
        tool_name = str(params.get("name", ""))
        tool_args = params.get("arguments") or {}
        try:
            text_out = handle_tool_call(tool_name, tool_args)
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {
                    "content": [{"type": "text", "text": text_out}],
                    "isError": False,
                },
            }
        except Exception as exc:
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {
                    "content": [{"type": "text", "text": f"Error: {exc}"}],
                    "isError": True,
                },
            }

    return {
        "jsonrpc": "2.0",
        "id": req_id,
        "error": {"code": -32601, "message": f"Method not found: {method}"},
    }


def serve_stdio() -> int:
    for line in sys.stdin:
        raw = line.strip()
        if not raw:
            continue
        try:
            req = json.loads(raw)
        except json.JSONDecodeError:
            continue
        resp = process_jsonrpc_message(req)
        if resp is not None:
            sys.stdout.write(json.dumps(resp, ensure_ascii=False) + "\n")
            sys.stdout.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(serve_stdio())
