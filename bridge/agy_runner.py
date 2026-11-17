"""Dual-Backend Multilingual Google Antigravity Runner for WoW Forever (Interface: 16001).

Handles both:
1. In-game WoW Forever Q&A / Strategy / Quest / Item Encyclopedia queries (`mode="qa"`)
2. In-game Lua Addon / Macro Vibe-Coding & Error Debugging (`mode="code"` / `"auto"`)

Multilingual Support (Default Fallback: English `enUS`):
- Official Blizzard WoW Locales: `enUS`/`enGB`, `koKR`, `zhCN`, `zhTW`, `deDE`, `frFR`, `esES`, `esMX`, `ptBR`, `ruRU`, `itIT`
- Additional Community Locale: `jaJP` (Japanese)
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

# Language metadata & regional WoW search grounding hints (Default: English enUS)
LOCALE_CONFIG: dict[str, tuple[str, str]] = {
    "enUS": ("English", "Wowhead, Warcraft Wiki (warcraft.wiki.gg)"),
    "enGB": ("English", "Wowhead, Warcraft Wiki (warcraft.wiki.gg)"),
    "koKR": ("Korean (한국어)", "와우 인벤 (WoW Inven), Wowhead, Warcraft Wiki"),
    "jaJP": ("Japanese (日本語)", "Wowhead, Warcraft Wiki, WoW日本語攻略Wiki"),
    "zhCN": ("Simplified Chinese (简体中文)", "NGA艾泽拉斯国家地理, 178魔兽世界, Wowhead"),
    "zhTW": ("Traditional Chinese (繁體中文)", "巴哈姆特 (Bahamut) 魔獸世界哈啦板, Wowhead"),
    "deDE": ("German (Deutsch)", "de.wowhead.com, Buffed.de, Warcraft Wiki"),
    "frFR": ("French (Français)", "fr.wowhead.com, JudgeHype, Mamytwink"),
    "esES": ("Spanish (Español)", "es.wowhead.com, Warcraft Wiki"),
    "esMX": ("Spanish (Español Latinoamericano)", "es.wowhead.com, Warcraft Wiki"),
    "ptBR": ("Portuguese (Português)", "pt.wowhead.com, Warcraft Wiki"),
    "ruRU": ("Russian (Русский)", "ru.wowhead.com, Noob-Club, Warcraft Wiki"),
    "itIT": ("Italian (Italiano)", "it.wowhead.com, Warcraft Wiki"),
}

# Multilingual coding intent keywords across EN / KO / JA / ZH / DE / FR / ES / PT / RU / IT
CODING_KEYWORDS = (
    # English / Technical
    "addon",
    "add-on",
    "lua",
    "macro",
    "snippet",
    "frame",
    "createframe",
    "stack trace",
    "traceback",
    ".toc",
    "savedvariables",
    "loadstring",
    "refactor",
    "debug",
    # Korean
    "코드",
    "코딩",
    "애드온",
    "에드온",
    "루아",
    "프레임",
    "에러",
    "오류",
    "버그",
    "매크로",
    "스니펫",
    "함수",
    "이벤트",
    "디버깅",
    "수정해",
    # Japanese
    "アドオン",
    "マクロ",
    "コード",
    "エラー",
    "スクリプト",
    "デバッグ",
    # Chinese (Simplified & Traditional)
    "插件",
    "代码",
    "程式碼",
    "报错",
    "錯誤",
    "调试",
    "除錯",
    "巨集",
    "编写",
    # European (DE / FR / ES / PT / RU / IT)
    "makro",
    "fehler",
    "erreur",
    "código",
    "codice",
    "аддон",
    "макрос",
    "ошибк",
)


def resolve_locale_info(locale_code: str | None) -> tuple[str, str, str]:
    code = (locale_code or "enUS").strip()
    if code in LOCALE_CONFIG:
        lang_name, sources = LOCALE_CONFIG[code]
        return code, lang_name, sources
    lang_name, sources = LOCALE_CONFIG["enUS"]
    return "enUS", lang_name, sources


def infer_request_mode(user_prompt: str, explicit_mode: str = "auto") -> str:
    if explicit_mode in ("qa", "code"):
        return explicit_mode
    lowered = (user_prompt or "").lower()
    if "```lua" in lowered or "interface/addons" in lowered:
        return "code"
    for kw in CODING_KEYWORDS:
        if kw in lowered:
            return "code"
    return "qa"


def format_markdown_for_wow_chat(text: str) -> str:
    """Convert Markdown headings/bold into clean WoW color escape sequences for ScrollingMessageFrame."""
    cleaned = LUA_BLOCK_RE.sub("", text or "")
    cleaned = MACRO_BLOCK_RE.sub("", cleaned)
    cleaned = WAYPOINT_BLOCK_RE.sub("", cleaned)

    lines: list[str] = []
    for raw_line in cleaned.splitlines():
        line = raw_line.rstrip()
        heading_match = re.match(r"^#{1,4}\s+(.*)$", line)
        if heading_match:
            line = f"|cff4285F4■ {heading_match.group(1).strip()}|r"
        else:
            line = re.sub(r"^\s*[-*]\s+", "• ", line)
            line = re.sub(r"\*\*(.+?)\*\*", r"|cffFFD100\1|r", line)
            line = re.sub(r"`([^`\n]+)`", r"|cff67D8EF\1|r", line)
        lines.append(line)

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
            "label": (label_s or "Waypoint").strip() or "Waypoint",
        }

    wow_chat_text = format_markdown_for_wow_chat(raw)
    if not wow_chat_text and lua_snippet:
        wow_chat_text = "Lua snippet ready! Click |cff34A853[▶ Run Code]|r below to execute."

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
    parts.append(
        f"- Client Build: {client.get('version', '?')} (TOC {client.get('tocVersion', 16001)}, gameLocale={client.get('gameLocale', 'enUS')}, uiLocale={client.get('uiLocale', 'enUS')})"
    )

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
                done_str = " [Complete]" if q.get("isComplete") else ""
                q_lines.append(
                    f"  • [{q.get('questID', '?')}] (Lv.{q.get('level', '?')}) {q.get('title', '')}{done_str}{obj_str}"
                )
        parts.append("\n".join(q_lines))

    mouseover = context.get("mouseoverFrame")
    if isinstance(mouseover, dict):
        parts.append(
            f"- Mouseover UI Frame: {mouseover.get('name')} ({mouseover.get('objectType')}, parent={mouseover.get('parent')})"
        )

    tooltips = context.get("linkedTooltips")
    if isinstance(tooltips, list) and tooltips:
        tip_lines = ["- Linked Item/Spell Tooltips (via C_TooltipInfo):"]
        for t in tooltips[:6]:
            if isinstance(t, dict):
                tip_lines.append(f"  • [{t.get('id', '?')}] {t.get('tooltip', '')}")
        parts.append("\n".join(tip_lines))

    return "\n".join(parts)


def format_enriched_prompt(
    user_prompt: str,
    context: dict[str, Any] | None = None,
    errors: list[dict[str, Any]] | None = None,
    addons_dir: Path | None = None,
    mode: str = "auto",
    locale: str | None = None,
) -> str:
    """Build a multilingual, intent-aware prompt for WoW Q&A Guide or WoW Forever Addon Coding."""
    resolved_mode = infer_request_mode(user_prompt, mode)
    ctx_locale = None
    if isinstance(context, dict) and isinstance(context.get("client"), dict):
        ctx_locale = context["client"].get("uiLocale")
    loc_code, lang_name, regional_sources = resolve_locale_info(locale or ctx_locale or "enUS")

    lang_rule = (
        f"- Response Language: Respond in **{lang_name}** (`{loc_code}`) unless the user explicitly writes their question in a different language (in which case match the user's question language)."
    )

    if resolved_mode == "qa":
        sections: list[str] = [
            "[WoW Forever (Interface: 16001) In-Game Q&A & Strategy Assistant]",
            lang_rule,
            f"- Grounding: Verify quest steps, NPC coordinates, item drop rates, boss mechanics, and WoW Forever seasonal/Legacy trait details via web search ({regional_sources}).",
            "- In-Game Chat Formatting: Your answer renders inside a WoW `ScrollingMessageFrame` (no Markdown tables). Use concise bullet points (`• `) and short paragraphs.",
            "- Map Pin Support: When giving world map coordinates and you know the `UiMapID` (or the player's current `UiMapID` from context), append a waypoint block at the end so the player can click [📍 Map Pin] in-game:\n  ```waypoint:1453,52.4,64.1,Target Location```",
            "- Do NOT modify local addon files unless the user explicitly asks to create or edit an addon.",
        ]
    else:
        sections = [
            "[WoW Forever (Interface: 16001) In-Game Coding & Q&A Request]",
            lang_rule,
            "- Target Client: World of Warcraft: Forever (`## Interface: 16001`).",
            "- Engine: Modern Retail/Midnight `C_*` APIs (`C_Spell`, `C_Item`, `C_UnitAuras`, `C_Container`, `BackdropTemplate`, `Settings`). Never use removed Classic globals (`GetSpellInfo`, `GetItemInfo`, `UnitAura`) or `toc >= 100000` guards.",
            "- Policy: Plain-text Lua/XML only, no combat automation/botting, guard protected calls with `InCombatLockdown()`.",
            "- Output Blocks: Wrap runnable in-game test snippets in ```lua ... ```, macros in ```macro:MacroName ... ```, and map pins in ```waypoint:mapID,x,y,Label```.",
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
    """Executes multilingual Q&A and coding prompts via `agy` CLI or `google-antigravity` SDK."""

    def __init__(
        self,
        addons_dir: Path,
        agents_md_path: Path,
        backend: str = "auto",
        agy_bin: str | None = None,
        continue_session: bool = False,
        litert_model_path: str | None = None,
        local_openai_url: str | None = None,
        local_openai_model: str | None = None,
        use_vertex: bool = False,
        vertex_project: str | None = None,
        vertex_location: str | None = None,
        timeout_sec: int = 180,
    ) -> None:
        self.addons_dir = addons_dir.resolve()
        self.agents_md_path = agents_md_path.resolve()
        self.continue_session = continue_session
        self.timeout_sec = max(10, int(timeout_sec))
        self.litert_model_path = (
            os.path.expanduser(litert_model_path) if litert_model_path else None
        )
        self.local_openai_url = local_openai_url
        self.local_openai_model = local_openai_model
        self.use_vertex = use_vertex or (os.environ.get("AGY_USE_VERTEX", "").lower() == "true")
        self.vertex_project = vertex_project or os.environ.get("GOOGLE_CLOUD_PROJECT")
        self.vertex_location = vertex_location or os.environ.get("GOOGLE_CLOUD_LOCATION", "us-central1")
        self.agy_bin = agy_bin or shutil.which("agy") or os.path.expanduser("~/.local/bin/agy")
        self.has_first_turn = False

        if backend == "auto":
            if self.litert_model_path or self.local_openai_url or self.use_vertex:
                self.backend = "sdk"
            elif self._is_sdk_ready():
                self.backend = "sdk"
            elif self.agy_bin and Path(self.agy_bin).exists():
                self.backend = "cli"
            else:
                self.backend = "sdk"
        else:
            self.backend = backend

    @staticmethod
    def _is_sdk_ready() -> bool:
        if not os.environ.get("GEMINI_API_KEY"):
            return False
        try:
            import google.antigravity  # noqa: F401 # type: ignore[import-not-found]
            return True
        except ImportError:
            return False

    def _snapshot_mtimes(self) -> dict[str, float]:
        snap: dict[str, float] = {}
        if not self.addons_dir.exists():
            return snap
        for p in self.addons_dir.rglob("*"):
            if p.is_file() and p.suffix.lower() in (".lua", ".toc", ".xml"):
                if p.name == "Inbox.lua" and p.parent.name == "WoWAGY":
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

    @staticmethod
    def _format_friendly_error(exc: BaseException, locale: str | None, timeout_sec: int) -> str:
        loc = (locale or "enUS").strip()
        msg = str(exc)
        low = msg.lower()

        is_ko = loc == "koKR"
        if isinstance(exc, (subprocess.TimeoutExpired, asyncio.TimeoutError, TimeoutError)):
            if is_ko:
                return f"|cffEA4335[응답 시간 초과]|r AI 응답이 {timeout_sec}초 내에 완료되지 않았습니다. 질문을 조금 더 짧게 나누거나 `--timeout` 값을 늘려 다시 시도해 주세요."
            return f"|cffEA4335[Timeout]|r Agent did not finish within {timeout_sec}s. Try a shorter prompt or increase `--timeout`."

        if "429" in low or "quota" in low or "rate limit" in low or "resource_exhausted" in low:
            if is_ko:
                return "|cffEA4335[할당량/요청 한도 초과]|r 현재 모델의 API 요청 한도(Quota/Rate Limit)에 도달했습니다. 잠시 후 다시 시도하거나 계정 할당량을 확인해 주세요."
            return "|cffEA4335[Quota / Rate Limit]|r API rate limit or quota reached. Please wait a moment and try again."

        if "401" in low or "403" in low or "api_key_invalid" in low or "unauthenticated" in low or "permission_denied" in low:
            if is_ko:
                return "|cffEA4335[인증 실패]|r Antigravity 인증이 만료되었거나 API 키가 유효하지 않습니다. 터미널에서 `uv run wow-agy-daemon --setup-auth` 를 실행해 재인증해 주세요."
            return "|cffEA4335[Authentication Error]|r Invalid or expired credentials. Run `uv run wow-agy-daemon --setup-auth` in your terminal."

        if isinstance(exc, ConnectionError) or "connection refused" in low or "name or service not known" in low or "network" in low:
            if is_ko:
                return "|cffEA4335[네트워크/로컬 서버 연결 실패]|r 인터넷 연결 또는 로컬 모델 서버(Ollama/LM Studio) 실행 상태를 확인해 주세요."
            return "|cffEA4335[Connection Failed]|r Check your internet connection or verify that your local model server (Ollama/LM Studio) is running."

        if isinstance(exc, FileNotFoundError):
            if is_ko:
                return f"|cffEA4335[파일/실행기 누락]|r 필요한 실행 파일이나 모델 경로를 찾을 수 없습니다: {msg[:240]}"
            return f"|cffEA4335[File Not Found]|r Missing binary or model file: {msg[:240]}"

        if is_ko:
            return f"|cffEA4335[예기치 않은 오류]|r ({type(exc).__name__}) {msg[:300]}"
        return f"|cffEA4335[Unexpected Error]|r ({type(exc).__name__}) {msg[:300]}"

    def run_turn(
        self,
        prompt: str,
        context: dict[str, Any] | None = None,
        errors: list[dict[str, Any]] | None = None,
        mode: str = "auto",
        locale: str | None = None,
    ) -> AgentTurnResult:
        enriched = format_enriched_prompt(
            user_prompt=prompt,
            context=context,
            errors=errors,
            addons_dir=self.addons_dir,
            mode=mode,
            locale=locale,
        )
        before = self._snapshot_mtimes()

        try:
            if self.backend == "cli":
                raw_reply = self._run_via_cli(enriched, locale=locale)
            elif self.backend == "sdk":
                raw_reply = asyncio.run(self._run_via_sdk(enriched, context, errors, locale=locale))
            else:
                raise ValueError(f"Unknown backend: {self.backend}")
        except Exception as exc:
            err_reply = self._format_friendly_error(exc, locale, self.timeout_sec)
            return AgentTurnResult(text=err_reply, raw_text=err_reply)

        after = self._snapshot_mtimes()
        result = extract_artifacts_from_reply(raw_reply)
        result.files_changed = self._diff_mtimes(before, after)
        self.has_first_turn = True
        return result

    def _run_via_cli(self, enriched_prompt: str, locale: str | None = None) -> str:
        if not self.agy_bin or not Path(self.agy_bin).exists():
            raise FileNotFoundError(
                "Antigravity CLI (`agy`) not found. Run `uv run wow-agy-daemon --setup-auth` or pass `--backend sdk`."
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

        try:
            proc = subprocess.run(
                cmd,
                cwd=str(self.addons_dir),
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=self.timeout_sec,
                check=False,
            )
        except subprocess.TimeoutExpired as exc:
            return self._format_friendly_error(exc, locale, self.timeout_sec)

        if proc.returncode != 0:
            stderr_msg = (proc.stderr or "").strip()
            stdout_msg = (proc.stdout or "").strip()
            detail = stderr_msg or stdout_msg
            if any(tok in detail.lower() for tok in ("401", "403", "unauthenticated", "login", "429", "quota")):
                return self._format_friendly_error(RuntimeError(detail), locale, self.timeout_sec)
            return f"|cffEA4335[AGY CLI Error]|r (exit {proc.returncode})\n{detail[:400]}"
        out = (proc.stdout or "").strip()
        return out or "|cffFBBC05[Notice]|r Agent completed without text output."

    async def _run_via_sdk(
        self,
        enriched_prompt: str,
        context: dict[str, Any] | None,
        errors: list[dict[str, Any]] | None,
        locale: str | None = None,
    ) -> str:
        try:
            from google.antigravity import (  # type: ignore[import-not-found]
                Agent,
                LiteRTAgentConfig,
                LocalAgentConfig,
                LocalOpenAIAgentConfig,
            )
        except ImportError:
            return (
                "|cffEA4335[SDK Missing]|r `google-antigravity` package is not installed.\n"
                "Run `uv sync && uv run wow-agy-daemon --backend sdk` (or `pip install -r requirements.txt`), "
                "or use `--backend cli` mode."
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
            """Returns the latest player, gear, professions, target, quests, and Lua error state from WoW Forever."""
            return f"Context: {context}\nErrors: {errors}"

        custom_tools = [scaffold_wow_forever_addon, get_live_wow_state]

        # 1) On-device LiteRT model (e.g. Gemma 4 26B — no API key needed)
        if self.litert_model_path:
            config = LiteRTAgentConfig(
                model_path=self.litert_model_path,
                workspaces=[str(addons_root)],
                system_instructions=system_rules,
                tools=custom_tools,
            )
        # 2) Local OpenAI-compatible server (Ollama / LM Studio — no API key needed)
        elif self.local_openai_url:
            config = LocalOpenAIAgentConfig(
                model=self.local_openai_model,
                base_url=self.local_openai_url,
                workspaces=[str(addons_root)],
                system_instructions=system_rules,
                tools=custom_tools,
            ).lightweight()
        # 3) Gemini Enterprise / Vertex AI (`vertex=True`: Express API Key or Standard ADC)
        elif self.use_vertex:
            api_key = os.environ.get("GEMINI_API_KEY", "").strip()
            if api_key:
                config = LocalAgentConfig(
                    vertex=True,
                    api_key=api_key,
                    workspaces=[str(addons_root)],
                    system_instructions=system_rules,
                    tools=custom_tools,
                )
            elif self.vertex_project:
                config = LocalAgentConfig(
                    vertex=True,
                    project=self.vertex_project,
                    location=self.vertex_location,
                    workspaces=[str(addons_root)],
                    system_instructions=system_rules,
                    tools=custom_tools,
                )
            else:
                return (
                    "|cffEA4335[Vertex Auth Required]|r Run `gcloud auth application-default login` "
                    "and set `GOOGLE_CLOUD_PROJECT`, or run `python3 bridge/daemon.py --setup-auth`."
                )
        # 4) Hosted Gemini via Google Antigravity SDK (`LocalAgentConfig`)
        else:
            if not os.environ.get("GEMINI_API_KEY"):
                return (
                    "|cffEA4335[Auth Required]|r `GEMINI_API_KEY` is not set.\n"
                    "Run `python3 bridge/daemon.py --setup-auth`, create a key at "
                    "https://aistudio.google.com/app/api-keys, or use `--backend cli`."
                )
            config = LocalAgentConfig(
                workspaces=[str(addons_root)],
                system_instructions=system_rules,
                tools=custom_tools,
            )

        chunks: list[str] = []

        async def _chat_with_timeout() -> None:
            async with Agent(config=config) as agent:
                response = await agent.chat(enriched_prompt)
                async for token in response:
                    chunks.append(token)

        try:
            await asyncio.wait_for(_chat_with_timeout(), timeout=float(self.timeout_sec))
        except Exception as exc:
            return self._format_friendly_error(exc, locale, self.timeout_sec)

        out = "".join(chunks).strip()
        return out or "|cffFBBC05[Notice]|r Agent completed without text output."
