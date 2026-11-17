"""Pure-Python parser and serializer for World of Warcraft SavedVariables & Inbox.lua.

Handles:
- WoW SavedVariables tables (`AntigravityWoWDB = { ... }`)
- Raw UTF-8 Korean strings AND Lua decimal byte escapes (`\\235\\130\\152`)
- Line/block Lua comments, nested array/dict tables, atomic Inbox.lua writes
"""

from __future__ import annotations

import os
import tempfile
import time
from pathlib import Path
from typing import Any


class LuaParseError(ValueError):
    """Raised when a Lua SavedVariables file cannot be parsed."""


class _LuaTokenizer:
    def __init__(self, text: str) -> None:
        self.text = text
        self.pos = 0
        self.length = len(text)

    def _skip_ws_and_comments(self) -> None:
        s = self.text
        n = self.length
        while self.pos < n:
            ch = s[self.pos]
            if ch in " \t\r\n":
                self.pos += 1
                continue
            if ch == "-" and self.pos + 1 < n and s[self.pos + 1] == "-":
                # Check block comment --[[ ... ]]
                if self.pos + 3 < n and s[self.pos + 2 : self.pos + 4] == "[[":
                    end = s.find("]]", self.pos + 4)
                    self.pos = n if end == -1 else end + 2
                else:
                    end = s.find("\n", self.pos + 2)
                    self.pos = n if end == -1 else end + 1
                continue
            break

    def peek_char(self) -> str:
        self._skip_ws_and_comments()
        if self.pos >= self.length:
            return ""
        return self.text[self.pos]

    def consume_char(self, expected: str) -> None:
        self._skip_ws_and_comments()
        if self.pos >= self.length or self.text[self.pos] != expected:
            got = self.text[self.pos : self.pos + 12] if self.pos < self.length else "EOF"
            raise LuaParseError(f"Expected '{expected}' at pos {self.pos}, got {got!r}")
        self.pos += 1

    def parse_identifier(self) -> str:
        self._skip_ws_and_comments()
        start = self.pos
        s = self.text
        n = self.length
        while self.pos < n and (s[self.pos].isalnum() or s[self.pos] == "_"):
            self.pos += 1
        if self.pos == start:
            raise LuaParseError(f"Expected identifier at pos {self.pos}")
        return s[start : self.pos]

    def parse_string(self) -> str:
        self._skip_ws_and_comments()
        s = self.text
        n = self.length
        quote = s[self.pos]
        if quote == "[":
            if self.pos + 1 < n and s[self.pos + 1] == "[":
                end = s.find("]]", self.pos + 2)
                if end == -1:
                    raise LuaParseError("Unterminated [[...]] string")
                val = s[self.pos + 2 : end]
                self.pos = end + 2
                return val
            raise LuaParseError(f"Unexpected '[' at pos {self.pos}")

        if quote not in ('"', "'"):
            raise LuaParseError(f"Expected string quote at pos {self.pos}")

        self.pos += 1
        byte_chunks = bytearray()

        def flush_utf8() -> str:
            if not byte_chunks:
                return ""
            decoded = byte_chunks.decode("utf-8", errors="replace")
            byte_chunks.clear()
            return decoded

        out_parts: list[str] = []
        while self.pos < n:
            ch = s[self.pos]
            if ch == quote:
                self.pos += 1
                if byte_chunks:
                    out_parts.append(flush_utf8())
                return "".join(out_parts)

            if ch == "\\":
                self.pos += 1
                if self.pos >= n:
                    raise LuaParseError("Unterminated escape in Lua string")
                esc = s[self.pos]
                if esc.isdigit():
                    # Up to 3 decimal digits (\ddd) used by Lua for raw UTF-8 bytes
                    digits = esc
                    self.pos += 1
                    for _ in range(2):
                        if self.pos < n and s[self.pos].isdigit():
                            digits += s[self.pos]
                            self.pos += 1
                        else:
                            break
                    byte_val = int(digits, 10) & 0xFF
                    byte_chunks.append(byte_val)
                    continue

                if byte_chunks:
                    out_parts.append(flush_utf8())

                self.pos += 1
                mapping = {
                    "n": "\n",
                    "r": "\r",
                    "t": "\t",
                    "\\": "\\",
                    '"': '"',
                    "'": "'",
                    "a": "\a",
                    "b": "\b",
                    "f": "\f",
                    "v": "\v",
                }
                out_parts.append(mapping.get(esc, esc))
            else:
                if byte_chunks:
                    out_parts.append(flush_utf8())
                out_parts.append(ch)
                self.pos += 1

        raise LuaParseError("Unterminated Lua string literal")

    def parse_number(self) -> int | float:
        self._skip_ws_and_comments()
        start = self.pos
        s = self.text
        n = self.length
        if self.pos < n and s[self.pos] in "+-":
            self.pos += 1
        while self.pos < n and (s[self.pos].isalnum() or s[self.pos] in ".+-"):
            self.pos += 1
        raw = s[start : self.pos]
        if any(c in raw for c in (".", "e", "E")) and not raw.lower().startswith("0x"):
            return float(raw)
        return int(raw, 0)

    def parse_table(self) -> dict[Any, Any] | list[Any]:
        self.consume_char("{")
        entries: dict[Any, Any] = {}
        implicit_idx = 1

        while True:
            ch = self.peek_char()
            if ch == "}":
                self.consume_char("}")
                break
            if not ch:
                raise LuaParseError("Unterminated Lua table")

            if ch == "[":
                # Check if [[ multiline string value ]] vs [key] = value
                if self.pos + 1 < self.length and self.text[self.pos + 1] == "[":
                    val = self.parse_string()
                    entries[implicit_idx] = val
                    implicit_idx += 1
                else:
                    self.consume_char("[")
                    key = self.parse_value()
                    self.consume_char("]")
                    self.consume_char("=")
                    val = self.parse_value()
                    entries[key] = val
            else:
                saved_pos = self.pos
                if ch.isalpha() or ch == "_":
                    ident = self.parse_identifier()
                    if self.peek_char() == "=":
                        self.consume_char("=")
                        entries[ident] = self.parse_value()
                    else:
                        self.pos = saved_pos
                        entries[implicit_idx] = self.parse_value()
                        implicit_idx += 1
                else:
                    entries[implicit_idx] = self.parse_value()
                    implicit_idx += 1

            sep = self.peek_char()
            if sep in (",", ";"):
                self.pos += 1

        if not entries:
            return {}

        # Convert pure 1..N consecutive integer-keyed Lua tables to Python lists
        if all(isinstance(k, int) for k in entries):
            keys_sorted = sorted(entries.keys())
            if keys_sorted == list(range(1, len(entries) + 1)):
                return [entries[i] for i in keys_sorted]

        return entries

    def parse_value(self) -> Any:
        ch = self.peek_char()
        if not ch:
            raise LuaParseError("Unexpected EOF while parsing Lua value")
        if ch == "{":
            return self.parse_table()
        if ch in ('"', "'") or (
            ch == "[" and self.pos + 1 < self.length and self.text[self.pos + 1] == "["
        ):
            return self.parse_string()
        if ch.isdigit() or ch in "+-":
            return self.parse_number()
        ident = self.parse_identifier()
        if ident == "true":
            return True
        if ident == "false":
            return False
        if ident == "nil":
            return None
        raise LuaParseError(f"Unexpected Lua identifier value: {ident!r}")


def parse_saved_variables(lua_source: str) -> dict[str, Any]:
    """Parse top-level assignments in a WoW SavedVariables .lua file."""
    tok = _LuaTokenizer(lua_source)
    globals_dict: dict[str, Any] = {}
    while tok.peek_char():
        name = tok.parse_identifier()
        tok.consume_char("=")
        val = tok.parse_value()
        if tok.peek_char() == ";":
            tok.consume_char(";")
        globals_dict[name] = val
    return globals_dict


def load_saved_variables_file(path: str | Path) -> dict[str, Any]:
    p = Path(path)
    if not p.exists():
        return {}
    content = p.read_text(encoding="utf-8", errors="replace")
    if not content.strip():
        return {}
    return parse_saved_variables(content)


def lua_escape_string(s: str) -> str:
    escaped = (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\r", "")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )
    return f'"{escaped}"'


def dump_lua_value(val: Any, indent: int = 0) -> str:
    pad = "    " * indent
    inner_pad = "    " * (indent + 1)

    if val is None:
        return "nil"
    if isinstance(val, bool):
        return "true" if val else "false"
    if isinstance(val, (int, float)):
        return str(val)
    if isinstance(val, str):
        return lua_escape_string(val)
    if isinstance(val, (list, tuple)):
        if not val:
            return "{}"
        lines = ["{"]
        for item in val:
            lines.append(f"{inner_pad}{dump_lua_value(item, indent + 1)},")
        lines.append(f"{pad}}}")
        return "\n".join(lines)
    if isinstance(val, dict):
        if not val:
            return "{}"
        lines = ["{"]
        for k, v in val.items():
            if isinstance(k, int):
                key_expr = f"[{k}]"
            elif isinstance(k, str) and k.isidentifier():
                key_expr = k
            else:
                key_expr = f"[{lua_escape_string(str(k))}]"
            lines.append(f"{inner_pad}{key_expr} = {dump_lua_value(v, indent + 1)},")
        lines.append(f"{pad}}}")
        return "\n".join(lines)
    return lua_escape_string(str(val))


def write_inbox_lua(
    inbox_path: str | Path,
    messages: list[dict[str, Any]],
    daemon_status: str = "online",
) -> None:
    """Atomically write AddOn/AntigravityWoW/Inbox.lua for WoW /reload ingestion."""
    target = Path(inbox_path)
    target.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "bridgeVersion": "1.0.0",
        "updatedAt": time.strftime("%Y-%m-%d %H:%M:%S"),
        "daemonStatus": daemon_status,
        "messages": messages[-25:],  # Keep Inbox lightweight
    }

    lua_code = (
        "local addonName, ns = ...\n"
        "-- Auto-generated by Antigravity WoW Forever Bridge. Safe to /reload.\n"
        f"ns.InboxPayload = {dump_lua_value(payload, 0)}\n"
    )

    fd, tmp_name = tempfile.mkstemp(
        prefix=".inbox_", suffix=".lua", dir=str(target.parent)
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(lua_code)
        os.replace(tmp_name, target)
    except Exception:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)
        raise
