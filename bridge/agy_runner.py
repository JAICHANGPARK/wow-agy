"""Dual-Backend Google Antigravity Runner for WoW Forever (Interface: 16001).

Handles both:
1. In-game WoW Forever Q&A / Strategy / Quest / Item Encyclopedia queries (`mode="qa"`)
2. In-game Lua Addon / Macro Vibe-Coding & Error Debugging (`mode="code"` / `"auto"`)

Supports:
- `cli` backend: Uses the installed `agy` CLI (`agy -p ... --mode accept-edits`)
- `sdk` backend: Uses `google.antigravity` Python SDK (`Agent`, `LocalAgentConfig`)
"""

from __future__ import annotations

import asyncio
import os
import re
import shutil
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class AgentTurnResult:
    text: str
    raw_text: str = ""
    lua_snippet: str = ""
    macro_name: str = ""
    macro_body: str = ""
    waypoint: dict[str, Any] | None = None
    files_changed: list[str] = field(default_factory=list)


LUA_BLOCK_RE = re.compile(r"```lua\s*\n(.*?)```", re.DOTALL | re.IGNORECASE)
MACRO_BLOCK_RE = re.compile(r"```macro(?::([^\n`]+))?\s*\n(.*?)```", re.DOTALL | re.IGNORECASE)
WAYPOINT_BLOCK_RE = re.compile(
    r"```waypoint:(\d+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,?\s*([^\n`]*)```",
    re.IGNORECASE,
)

CODING_KEYWORDS = (
    "코드",
    "애드온",
    "에드온",
    "lua",
    "루아",
    "프레임",
    "에러",
    "오류",
    "버그",
    "매크로",
    "스니펫",
    "함수",
    ".toc",
    "createframe",
    "이벤트",
    "디버깅",
    "수정해",
    "만들어줘",
)


def infer_request_mode(user_prompt: str, explicit_mode: str = "auto") -> str:
    if explicit_mode in ("qa", "code"):
        return explicit_mode
    lowered = (user_prompt or "").lower()
    if "```lua" in lowered or "interface/addons" in lowered:
        return "code"
    for kw in CODING_KEYWORDS:
        if kw in lowered:
            # Distinguish "매크로 알려줘" / "애드온 만들어줘" -> code vs pure gameplay questions
            return "code"
    return "qa"


def format_markdown_for_wow_chat(text: str) -> str:
    """Convert Markdown headings/bold into clean WoW color escape sequences for ScrollingMessageFrame."""
    # Remove fenced code/macro/waypoint blocks from chat prose so chat stays super readable
    cleaned = LUA_BLOCK_RE.sub("", text or "")
    cleaned = MACRO_BLOCK_RE.sub("", cleaned)
    cleaned = WAYPOINT_BLOCK_RE.sub("", cleaned)

    lines: list[str] = []
    for raw_line in cleaned.splitlines():
        line = raw_line.rstrip()
        # Convert ### Heading -> colored section header
        heading_match = re.match(r"^#{1,4}\s+(.*)$", line)
        if heading_match:
            line = f"|cff4285F4■ {heading_match.group(1).strip()}|r"
        else:
            # Convert bullet `- ` or `* ` to `• `
            line = re.sub(r"^\s*[-*]\s+", "• ", line)
            # Convert **bold** to WoW gold |cffFFD100bold|r
            line = re.sub(r"\*\*(.+?)\*\*", r"|cffFFD100\1|r", line)
            # Convert `inline_code` to cyan |cff67D8EFinline_code|r
            line = re.sub(r"`([^`\n]+)`", r"|cff67D8EF\1|r", line)
        lines.append(line)

    # Collapse 3+ consecutive blank lines
    joined = "\n".join(lines).strip()
    joined = re.sub(r"\n{3,}", "\n\n", joined)
    return joined


def extract_artifacts_from_reply(reply_text: str) -> AgentTurnResult:
    """Extract runnable ```lua```, ```macro:Name```, and ```waypoint:...``` blocks, plus WoW-formatted text."""
    raw = (reply_text or "").strip()

    lua_matches = LUA_BLOCK_RE.findall(raw)
    lua_snippet = lua_matches[-1].strip() if lua_matches else ""

    macro_name = ""
    macro_body = ""
    macro_matches = MACRO_BLOCK_RE.findall(raw)
    if macro_matches:
        raw_name, raw_body = macro_matches[-1]
        macro_name = (raw_name or "AGY_Macro").strip()[:16]
        macro_body = raw_body.strip()[:255]

    waypoint: dict[str, Any] | None = None
    wp_matches = WAYPOINT_BLOCK_RE.findall(raw)
    if wp_matches:
        map_id_s, x_s, y_s, label_s = wp_matches[-1]
        waypoint = {
            "mapID": int(map_id_s),
            "x": float(x_s),
            "y": float(y_s),
            "label": (label_s or "추천 위치").strip() or "추천 위치",
        }

    wow_chat_text = format_markdown_for_wow_chat(raw)
    if not wow_chat_text and lua_snippet:
        wow_chat_text = "요청하신 Lua 코드를 작성했습니다. 아래 |cff34A853[▶ 응답 코드 실행]|r 또는 에디터 열기 버튼을 눌러 확인하세요."

    return AgentTurnResult(
        text=wow_chat_text,
        raw_text=raw,
        lua_snippet=lua_snippet,
        macro_name=macro_name,
        macro_body=macro_body,
        waypoint=waypoint,
    )


def _format_context_section(context: dict[str, Any] | None) -> str:
    if not context or not isinstance(context, dict):
        return ""

    parts: list[str] = ["\n[Live In-Game Player State]"]
    player = context.get("player") or {}
    loc = context.get("location") or {}
    client = context.get("client") or {}
    parts.append(
        f"- Character: {player.get('name', '?')} (Lv.{player.get('level', '?')} {player.get('race', '')} {player.get('className', '')})"
    )
    parts.append(
        f"- Location: {loc.get('zone', '?')} / {loc.get('subZone', '')} (UiMapID={loc.get('mapID', 0)}, coords={loc.get('x', 0)}, {loc.get('y', 0)})"
    )
    parts.append(f"- Client Build: {client.get('version', '?')} (TOC {client.get('tocVersion', 16001)})")

    target = context.get("target")
    if isinstance(target, dict) and target.get("name"):
        parts.append(
            f"- Current Target: {target.get('name')} (Lv.{target.get('level', '?')}, "
            f"type={target.get('classification', 'normal')}/{target.get('creatureType', '')}, npcID={target.get('npcID', 0)})"
        )

    profs = context.get("professions")
    if isinstance(profs, list) and profs:
        prof_str = ", ".join(
            f"{p.get('name', '?')} ({p.get('rank', 0)}/{p.get('maxRank', 0)})"
            for p in profs
            if isinstance(p, dict)
        )
        if prof_str:
            parts.append(f"- Professions: {prof_str}")

    equipped = context.get("equippedItems")
    if isinstance(equipped, list) and equipped:
        eq_str = ", ".join(
            f"{it.get('slot', '?')}:{it.get('name', '?')}(id={it.get('itemID', 0)})"
            for it in equipped[:18]
            if isinstance(it, dict)
        )
        if eq_str:
            parts.append(f"- Equipped Gear: {eq_str}")

    quests = context.get("quests")
    if isinstance(quests, list) and quests:
        q_lines: list[str] = ["- Active Quests:"]
        for q in quests[:8]:
            if isinstance(q, dict):
                objs = q.get("objectives")
                obj_str = f" -> {', '.join(str(o) for o in objs)}" if isinstance(objs, list) and objs else ""
                done_str = " [완료 가능]" if q.get("isComplete") else ""
                q_lines.append(
                    f"  • [{q.get('questID', '?')}] (Lv.{q.get('level', '?')}) {q.get('title', '')}{done_str}{obj_str}"
                )
        parts.append("\n".join(q_lines))

    mouseover = context.get("mouseoverFrame")
    if isinstance(mouseover, dict):
        parts.append(
            f"- Mouseover UI Frame: {mouseover.get('name')} ({mouseover.get('objectType')}, parent={mouseover.get('parent')})"
        )

    return "\n".join(parts)


def format_enriched_prompt(
    user_prompt: str,
    context: dict[str, Any] | None = None,
    errors: list[dict[str, Any]] | None = None,
    addons_dir: Path | None = None,
    mode: str = "auto",
) -> str:
    """Build an intent-aware prompt for either WoW Q&A Guide mode or WoW Forever Addon Coding mode."""
    resolved_mode = infer_request_mode(user_prompt, mode)

    if resolved_mode == "qa":
        sections: list[str] = [
            "[WoW Forever (Interface: 16001) In-Game Q&A & Strategy Assistant]",
            "- Role: 친절하고 정확한 월드 오브 워크래프트: 포에버(WoW Forever / 클래식 기반 시즌 서버) 전문 인게임 공략 가이드 & 백과사전입니다.",
            "- Grounding: 퀘스트 동선, NPC 좌표, 아이템 드랍처/드랍률, 던전·레이드 보스 공략, 포에버 전용 특성/유산(Legacy) 시스템 등은 필요시 웹 검색(Wowhead, Warcraft Wiki, 와우 인벤)을 활용해 정확한 정보를 답변하세요.",
            "- In-Game Chat Formatting: 답변은 와우 인게임 대화창(`ScrollingMessageFrame`)에 바로 출력됩니다. 마크다운 표(Table)는 쓰지 말고, 핵심 위주의 짧은 한국어 불릿(`• `)으로 정리하세요.",
            "- Map Pin Support: 특정 위치/NPC 좌표를 안내할 때 `UiMapID`(현재 지역과 같다면 플레이어의 `UiMapID` 활용)와 좌표(`0~100` 기준 `x, y`)를 안다면 답변 맨 끝에 다음 블록을 추가하세요(유저가 인게임 버튼 하나로 지도 핀을 찍을 수 있습니다):\n  ```waypoint:1453,52.4,64.1,목표 이름```",
            "- Do NOT modify local addon files unless the user explicitly asks to create or edit an addon.",
        ]
    else:
        sections = [
            "[WoW Forever (Interface: 16001) In-Game Coding & Q&A Request]",
            "- Target Client: World of Warcraft: Forever (`## Interface: 16001`).",
            "- Engine: Modern Retail/Midnight `C_*` APIs (`C_Spell`, `C_Item`, `C_UnitAuras`, `C_Container`, `BackdropTemplate`). Never use removed Classic globals (`GetSpellInfo`, `GetItemInfo`, `UnitAura`) or `toc >= 100000` guards.",
            "- Policy: Plain-text Lua/XML only, no combat automation/botting, guard protected calls with `InCombatLockdown()`.",
            "- Output Tip: 인게임에서 바로 테스트할 수 있는 Lua 코드는 ```lua ... ``` 블록으로, 매크로는 ```macro:매크로이름 ... ``` 블록으로, 지도 좌표 핀은 ```waypoint:mapID,x,y,설명``` 블록으로 감싸주세요. 설명은 한국어로 간결하게 작성하세요.",
        ]
        if addons_dir:
            sections.append(f"- Local AddOns Workspace: {addons_dir}")

    ctx_block = _format_context_section(context)
    if ctx_block:
        sections.append(ctx_block)

    if resolved_mode != "qa" and errors and isinstance(errors, list):
        err_lines = ["\n[Captured In-Game Lua Errors]"]
        for idx, err in enumerate(errors[-5:], 1):
            if isinstance(err, dict):
                err_lines.append(
                    f"{idx}. [{err.get('addon', 'Unknown')}] (x{err.get('count', 1)}) {err.get('message', '')}\n"
                    f"   Stack: {str(err.get('stack', ''))[:500]}"
                )
        sections.append("\n".join(err_lines))

    sections.append(f"\n[Player Question / Request]\n{user_prompt}")
    return "\n".join(sections)


def scaffold_forever_addon_files(addons_dir: Path, addon_name: str, description: str = "") -> list[str]:
    """Create a clean WoW Forever (Interface: 16001) starter addon folder."""
    safe_name = re.sub(r"[^A-Za-z0-9_]", "", addon_name or "")
    if not safe_name:
        raise ValueError("Addon name must contain alphanumeric characters.")

    target_dir = addons_dir / safe_name
    target_dir.mkdir(parents=True, exist_ok=True)

    toc_path = target_dir / f"{safe_name}.toc"
    core_path = target_dir / "Core.lua"

    notes = description or f"{safe_name} — Generated by Antigravity for WoW Forever"
    toc_content = (
        f"## Interface: 16001\n"
        f"## Title: {safe_name}\n"
        f"## Notes: {notes}\n"
        f"## Version: 0.1.0\n"
        f"## SavedVariables: {safe_name}DB\n\n"
        f"Core.lua\n"
    )
    core_content = (
        f"local addonName, ns = ...\n\n"
        f"local f = CreateFrame('Frame')\n"
        f"pcall(f.RegisterEvent, f, 'PLAYER_LOGIN')\n"
        f"f:SetScript('OnEvent', function(_, event)\n"
        f"    if event == 'PLAYER_LOGIN' then\n"
        f"        {safe_name}DB = {safe_name}DB or {{}}\n"
        f"        DEFAULT_CHAT_FRAME:AddMessage('|cff4285F4[{safe_name}]|r Loaded on WoW Forever (16001).')\n"
        f"    end\n"
        f"end)\n"
    )

    created: list[str] = []
    if not toc_path.exists():
        toc_path.write_text(toc_content, encoding="utf-8")
        created.append(str(toc_path.relative_to(addons_dir)))
    if not core_path.exists():
        core_path.write_text(core_content, encoding="utf-8")
        created.append(str(core_path.relative_to(addons_dir)))
    return created


class AntigravityBridgeRunner:
    """Executes Q&A and coding prompts against `agy` CLI or `google-antigravity` Python SDK."""

    def __init__(
        self,
        addons_dir: Path,
        agents_md_path: Path,
        backend: str = "auto",
        agy_bin: str | None = None,
        continue_session: bool = False,
    ) -> None:
        self.addons_dir = addons_dir.resolve()
        self.agents_md_path = agents_md_path.resolve()
        self.continue_session = continue_session
        self.agy_bin = agy_bin or shutil.which("agy") or os.path.expanduser("~/.local/bin/agy")
        self.has_first_turn = False

        if backend == "auto":
            if self.agy_bin and Path(self.agy_bin).exists():
                self.backend = "cli"
            else:
                self.backend = "sdk"
        else:
            self.backend = backend

    def _snapshot_mtimes(self) -> dict[str, float]:
        snap: dict[str, float] = {}
        if not self.addons_dir.exists():
            return snap
        for p in self.addons_dir.rglob("*"):
            if p.is_file() and p.suffix.lower() in (".lua", ".toc", ".xml"):
                if p.name == "Inbox.lua" and p.parent.name == "AntigravityWoW":
                    continue
                try:
                    snap[str(p.relative_to(self.addons_dir))] = p.stat().st_mtime
                except OSError:
                    pass
        return snap

    def _diff_mtimes(self, before: dict[str, float], after: dict[str, float]) -> list[str]:
        changed: list[str] = []
        for rel_path, mtime in after.items():
            if rel_path not in before or mtime > before[rel_path]:
                changed.append(rel_path)
        return sorted(changed)

    def run_turn(
        self,
        prompt: str,
        context: dict[str, Any] | None = None,
        errors: list[dict[str, Any]] | None = None,
        mode: str = "auto",
    ) -> AgentTurnResult:
        enriched = format_enriched_prompt(
            user_prompt=prompt,
            context=context,
            errors=errors,
            addons_dir=self.addons_dir,
            mode=mode,
        )
        before = self._snapshot_mtimes()

        if self.backend == "cli":
            raw_reply = self._run_via_cli(enriched)
        elif self.backend == "sdk":
            raw_reply = asyncio.run(self._run_via_sdk(enriched, context, errors))
        else:
            raise ValueError(f"Unknown backend: {self.backend}")

        after = self._snapshot_mtimes()
        result = extract_artifacts_from_reply(raw_reply)
        result.files_changed = self._diff_mtimes(before, after)
        self.has_first_turn = True
        return result

    def _run_via_cli(self, enriched_prompt: str) -> str:
        if not self.agy_bin or not Path(self.agy_bin).exists():
            raise RuntimeError(
                "Antigravity CLI (`agy`)를 찾을 수 없습니다. `agy`를 설치하거나 `--backend sdk` 옵션을 사용하세요."
            )

        cmd = [
            self.agy_bin,
            "-p",
            enriched_prompt,
            "--mode",
            "accept-edits",
            "--add-dir",
            str(self.addons_dir),
        ]
        if self.continue_session and self.has_first_turn:
            cmd.append("--continue")

        proc = subprocess.run(
            cmd,
            cwd=str(self.addons_dir),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )
        if proc.returncode != 0:
            stderr_msg = (proc.stderr or "").strip()
            stdout_msg = (proc.stdout or "").strip()
            return f"|cffEA4335[AGY CLI 오류]|r (exit {proc.returncode})\n{stderr_msg or stdout_msg}"
        return (proc.stdout or "").strip()

    async def _run_via_sdk(
        self,
        enriched_prompt: str,
        context: dict[str, Any] | None,
        errors: list[dict[str, Any] | None],
    ) -> str:
        try:
            from google.antigravity import Agent, LocalAgentConfig  # type: ignore[import-not-found]
        except ImportError:
            return (
                "|cffEA4335[SDK 미설치]|r `google-antigravity` 패키지가 설치되어 있지 않습니다.\n"
                "`pip install google-antigravity` 를 실행하거나 기본 `--backend cli` 모드를 사용하세요."
            )

        if not os.environ.get("GEMINI_API_KEY"):
            return (
                "|cffEA4335[API 키 필요]|r `GEMINI_API_KEY` 환경변수가 설정되어 있지 않습니다.\n"
                "Google AI Studio (https://aistudio.google.com/app/api-keys) 에서 API 키를 발급해 설정하거나\n"
                "`--backend cli` 모드로 실행해 주세요."
            )

        system_rules = ""
        if self.agents_md_path.exists():
            system_rules = self.agents_md_path.read_text(encoding="utf-8")

        addons_root = self.addons_dir

        def scaffold_wow_forever_addon(addon_name: str, description: str = "") -> str:
            """Scaffolds a new WoW Forever (Interface: 16001) addon folder in Interface/AddOns.

            Args:
                addon_name: Folder and .toc name for the new addon (alphanumeric, e.g. 'MyBuffTracker').
                description: Short description for the .toc Notes field.
            """
            created = scaffold_forever_addon_files(addons_root, addon_name, description)
            return f"Created WoW Forever (16001) addon files: {', '.join(created)}"

        def get_live_wow_state() -> str:
            """Returns the latest player, target, active quests, location, and Lua error state from WoW Forever."""
            return f"Context: {context}\nErrors: {errors}"

        config = LocalAgentConfig(
            workspaces=[str(addons_root)],
            system_instructions=system_rules,
            tools=[scaffold_wow_forever_addon, get_live_wow_state],
        )

        chunks: list[str] = []
        async with Agent(config=config) as agent:
            response = await agent.chat(enriched_prompt)
            async for token in response:
                chunks.append(token)
        return "".join(chunks).strip()
