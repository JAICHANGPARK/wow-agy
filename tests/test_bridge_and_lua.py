"""Automated tests for AntigravityWoW Lua Addon structure, SavedVariables serde, Daemon, and MCP Server."""

from __future__ import annotations

import json
import re
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from bridge.agy_runner import (
    AgentTurnResult,
    extract_artifacts_from_reply,
    format_enriched_prompt,
    format_markdown_for_wow_chat,
    infer_request_mode,
    scaffold_forever_addon_files,
)
from bridge.daemon import CompanionDaemon
from bridge.lua_serde import (
    dump_lua_value,
    load_saved_variables_file,
    parse_saved_variables,
    write_inbox_lua,
)
from bridge.mcp_server import process_jsonrpc_message

REPO_ROOT = Path(__file__).resolve().parent.parent
ADDON_DIR = REPO_ROOT / "AddOn" / "AntigravityWoW"


class FakeRunner:
    backend = "fake"
    agy_bin = "/usr/bin/true"

    def run_turn(self, prompt: str, context=None, errors=None, mode: str = "auto") -> AgentTurnResult:
        return AgentTurnResult(
            text=f"요청 처리 완료: {prompt}",
            lua_snippet="print('Hello WoW Forever 16001')",
            macro_name="AGY_Test",
            macro_body="/run print('Macro OK')",
            waypoint={"mapID": 1453, "x": 52.4, "y": 64.1, "label": "스톰윈드 NPC"},
            files_changed=["MyCustomAddon/Core.lua"],
        )


class TestAddonAndBridge(unittest.TestCase):
    def test_toc_manifest_and_forever_16001_compliance(self) -> None:
        toc_path = ADDON_DIR / "AntigravityWoW.toc"
        self.assertTrue(toc_path.exists())
        toc_lines = toc_path.read_text(encoding="utf-8").splitlines()

        # Verify WoW Forever Interface 16001 header
        self.assertIn("## Interface: 16001", toc_lines)
        self.assertIn("## SavedVariables: AntigravityWoWDB", toc_lines)

        lua_files = [
            line.strip()
            for line in toc_lines
            if line.strip() and not line.strip().startswith("#")
        ]
        self.assertGreaterEqual(len(lua_files), 8)
        self.assertIn("Settings.lua", lua_files)

        # Verify Bindings.xml is valid XML and references defined actions
        bindings_xml = ADDON_DIR / "Bindings.xml"
        self.assertTrue(bindings_xml.exists())
        tree = ET.parse(bindings_xml)
        binding_names = [el.attrib.get("name") for el in tree.getroot().findall("Binding")]
        self.assertIn("ANTIGRAVITYWOW_TOGGLE", binding_names)
        self.assertIn("ANTIGRAVITYWOW_ASK_TARGET", binding_names)

        forbidden_legacy_calls = [
            r"(?<!\.)\bGetSpellInfo\s*\(",
            r"(?<!\.)\bGetItemInfo\s*\(",
            r"(?<!\.)\bUnitAura\s*\(",
            r"(?<!\.)\bCombatLogGetCurrentEventInfo\s*\(",
            r"\bgoto\s+\w+",
        ]

        for rel_name in lua_files:
            lua_path = ADDON_DIR / rel_name
            self.assertTrue(lua_path.exists(), f"Missing file listed in .toc: {rel_name}")
            src = lua_path.read_text(encoding="utf-8")

            # Must declare file-scoped `local addonName, ns = ...`
            self.assertIn("local addonName, ns = ...", src, f"Missing addon namespace header in {rel_name}")

            # Ensure no removed legacy globals are called in executable code (skip comments/strings test sample)
            code_no_comments = re.sub(r"--[^\n]*", "", src)
            for pat in forbidden_legacy_calls:
                if rel_name == "UI.lua" and "GetSpellInfo" in pat:
                    continue  # UI.lua contains a string literal sample error message
                self.assertIsNone(
                    re.search(pat, code_no_comments),
                    f"Forbidden legacy API pattern {pat} found in {rel_name}",
                )

    def test_lua_saved_variables_roundtrip_and_korean_utf8_escapes(self) -> None:
        # Simulate WoW SavedVariables containing both raw UTF-8 Korean and Lua \ddd byte escapes
        hangul_bytes = "체력바".encode("utf-8")
        escaped_hangul = "".join(f"\\{b}" for b in hangul_bytes)

        sample_sv = f'''
        -- SavedVariables test comment
        AntigravityWoWDB = {{
            ["version"] = "1.0.0",
            ["nextSeq"] = 2,
            ["outbox"] = {{
                {{
                    ["id"] = "req-100-0001",
                    ["status"] = "pending",
                    ["prompt"] = "{escaped_hangul} 위치 옮겨줘",
                    ["context"] = {{
                        ["player"] = {{
                            ["name"] = "아서스",
                            ["level"] = 60,
                        }},
                    }},
                }},
            }},
        }}
        '''
        parsed = parse_saved_variables(sample_sv)
        db = parsed["AntigravityWoWDB"]
        self.assertEqual(db["version"], "1.0.0")
        self.assertEqual(db["outbox"][0]["prompt"], "체력바 위치 옮겨줘")
        self.assertEqual(db["outbox"][0]["context"]["player"]["name"], "아서스")

        # Round-trip dump and re-parse
        dumped = "AntigravityWoWDB = " + dump_lua_value(db)
        reparsed = parse_saved_variables(dumped)
        self.assertEqual(reparsed["AntigravityWoWDB"]["outbox"][0]["prompt"], "체력바 위치 옮겨줘")

    def test_inbox_generation_and_daemon_polling(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            addons_dir = tmp_path / "Interface" / "AddOns"
            inbox_path = addons_dir / "AntigravityWoW" / "Inbox.lua"
            sv_path = tmp_path / "WTF" / "Account" / "TESTACC" / "SavedVariables" / "AntigravityWoW.lua"
            sv_path.parent.mkdir(parents=True, exist_ok=True)

            sv_content = '''
            AntigravityWoWDB = {
                ["outbox"] = {
                    {
                        ["id"] = "req-999-0001",
                        ["status"] = "pending",
                        ["prompt"] = "내 마나 퍼센트 표시 프레임 만들어줘",
                    },
                },
            }
            '''
            sv_path.write_text(sv_content, encoding="utf-8")

            daemon = CompanionDaemon(
                addons_dir=addons_dir,
                inbox_path=inbox_path,
                wow_flavor_dir=tmp_path,
                explicit_sv=sv_path,
                runner=FakeRunner(),  # type: ignore[arg-type]
                enable_clipboard=False,
            )
            daemon.state_file = tmp_path / ".state.json"

            handled = daemon.poll_saved_variables_once()
            self.assertEqual(handled, 1)
            self.assertTrue(inbox_path.exists())

            inbox_src = inbox_path.read_text(encoding="utf-8")
            self.assertIn("ns.InboxPayload =", inbox_src)
            self.assertIn("Hello WoW Forever 16001", inbox_src)
            self.assertIn("AGY_Test", inbox_src)

            # Second poll without mtime/new ID change must not re-run
            handled_again = daemon.poll_saved_variables_once()
            self.assertEqual(handled_again, 0)

    def test_extract_artifacts_and_prompt_enrichment(self) -> None:
        reply = (
            "### 남작 리븐데어 공략\n"
            "- **죽음의 고리**를 주의하세요!\n"
            "```lua\nlocal s = C_Spell.GetSpellInfo(133)\nprint(s and s.name)\n```\n"
            "```macro:FireCheck\n/run local s=C_Spell.GetSpellInfo(133) print(s and s.name)\n```\n"
            "```waypoint:1453,52.4,64.1,스톰윈드 입구```"
        )
        res = extract_artifacts_from_reply(reply)
        self.assertIn("C_Spell.GetSpellInfo(133)", res.lua_snippet)
        self.assertEqual(res.macro_name, "FireCheck")
        self.assertIn("/run", res.macro_body)
        self.assertIsNotNone(res.waypoint)
        assert res.waypoint is not None
        self.assertEqual(res.waypoint["mapID"], 1453)
        self.assertAlmostEqual(res.waypoint["x"], 52.4)
        self.assertIn("|cffFFD100죽음의 고리|r", res.text)
        self.assertIn("• ", res.text)

        # Verify QA mode vs Coding mode inference
        self.assertEqual(infer_request_mode("스트라솔름 남작 군마 드랍률이 몇 퍼센트야?"), "qa")
        self.assertEqual(infer_request_mode("내 체력바 프레임 옮기는 루아 애드온 만들어줘"), "code")

        qa_prompt = format_enriched_prompt(
            "이 몬스터 뭐 드랍해?",
            context={
                "player": {"name": "제이나", "level": 60, "className": "마법사"},
                "target": {"name": "남작 리븐데어", "level": 62, "classification": "elite", "npcID": 10440},
                "professions": [{"name": "마법부여", "rank": 295, "maxRank": 300}],
                "equippedItems": [{"slot": "주장비", "name": "아케이나이트 사신의 도끼", "itemID": 12784}],
                "quests": [{"questID": 5262, "level": 60, "title": "진실이 밝혀지다", "objectives": ["리븐데어 처치: 0/1"]}],
            },
            mode="qa",
        )
        self.assertIn("남작 리븐데어", qa_prompt)
        self.assertIn("마법부여 (295/300)", qa_prompt)
        self.assertIn("아케이나이트 사신의 도끼", qa_prompt)
        self.assertIn("리븐데어 처치: 0/1", qa_prompt)
        self.assertIn("In-Game Q&A", qa_prompt)

        code_prompt = format_enriched_prompt(
            "에러 수정해줘",
            context={"player": {"name": "제이나", "level": 60, "className": "마법사"}},
            errors=[{"addon": "Foo", "count": 2, "message": "bar nil", "stack": "Foo.lua:10"}],
            mode="code",
        )
        self.assertIn("16001", code_prompt)
        self.assertIn("Foo.lua:10", code_prompt)

    def test_mcp_server_jsonrpc_tools(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            import os

            old_addons = os.environ.get("WOW_ADDONS_DIR")
            os.environ["WOW_ADDONS_DIR"] = tmp
            try:
                init_resp = process_jsonrpc_message({"jsonrpc": "2.0", "id": 1, "method": "initialize"})
                self.assertIsNotNone(init_resp)
                assert init_resp is not None
                self.assertEqual(init_resp["result"]["serverInfo"]["name"], "antigravity-wow-forever-mcp")

                tools_resp = process_jsonrpc_message({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
                assert tools_resp is not None
                tool_names = {t["name"] for t in tools_resp["result"]["tools"]}
                self.assertIn("wow_scaffold_forever_addon", tool_names)
                self.assertIn("wow_send_to_inbox", tool_names)

                scaffold_resp = process_jsonrpc_message(
                    {
                        "jsonrpc": "2.0",
                        "id": 3,
                        "method": "tools/call",
                        "params": {
                            "name": "wow_scaffold_forever_addon",
                            "arguments": {
                                "addon_name": "ForeverBuffAlert",
                                "description": "Buff alert for Forever",
                            },
                        },
                    }
                )
                assert scaffold_resp is not None
                self.assertFalse(scaffold_resp["result"]["isError"])
                created_toc = Path(tmp) / "ForeverBuffAlert" / "ForeverBuffAlert.toc"
                self.assertTrue(created_toc.exists())
                self.assertIn("## Interface: 16001", created_toc.read_text(encoding="utf-8"))

                inbox_resp = process_jsonrpc_message(
                    {
                        "jsonrpc": "2.0",
                        "id": 4,
                        "method": "tools/call",
                        "params": {
                            "name": "wow_send_to_inbox",
                            "arguments": {
                                "message": "MCP 테스트 완료!",
                                "lua_code": "print('MCP OK')",
                            },
                        },
                    }
                )
                assert inbox_resp is not None
                self.assertFalse(inbox_resp["result"]["isError"])
                self.assertTrue((Path(tmp) / "AntigravityWoW" / "Inbox.lua").exists())
            finally:
                if old_addons is None:
                    os.environ.pop("WOW_ADDONS_DIR", None)
                else:
                    os.environ["WOW_ADDONS_DIR"] = old_addons


if __name__ == "__main__":
    unittest.main()
