#!/usr/bin/env python3
"""Antigravity WoW Forever Companion Daemon.

Watches:
1. WoW SavedVariables (`WTF/Account/*/SavedVariables/AntigravityWoW.lua`) for queued prompts
2. System Clipboard (optional `--clipboard`, enabled by default) for `AGY_REQ:{...}` packets
   so players can vibe-code & run Lua snippets in-game WITHOUT `/reload`!

Writes replies & code back into `Interface/AddOns/AntigravityWoW/Inbox.lua` (and clipboard).
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

# Allow running directly as `python3 bridge/daemon.py`
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from bridge.agy_runner import AntigravityBridgeRunner
from bridge.lua_serde import load_saved_variables_file, write_inbox_lua


def auto_detect_wow_flavor_dir() -> Path | None:
    """Try common macOS & Windows World of Warcraft: Forever installation paths."""
    candidates: list[Path] = []
    env_path = os.environ.get("WOW_FOREVER_DIR")
    if env_path:
        candidates.append(Path(env_path).expanduser())

    system = platform.system()
    if system == "Darwin":
        base = Path("/Applications/World of Warcraft")
        candidates.extend(
            [
                base / "_forever_",
                base / "_classic_",
                base / "_classic_era_",
                base / "_retail_",
            ]
        )
    elif system == "Windows":
        for drive in ("C:", "D:", "E:"):
            for prog in ("Program Files (x86)", "Program Files", "Games"):
                base = Path(f"{drive}/{prog}/World of Warcraft")
                candidates.extend(
                    [
                        base / "_forever_",
                        base / "_classic_",
                        base / "_classic_era_",
                        base / "_retail_",
                    ]
                )

    for c in candidates:
        if (c / "Interface" / "AddOns").exists() or (c / "WTF").exists():
            return c
    return None


def read_clipboard() -> str:
    system = platform.system()
    try:
        if system == "Darwin":
            res = subprocess.run(
                ["pbpaste"], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=2
            )
            return res.stdout if res.returncode == 0 else ""
        if system == "Windows":
            res = subprocess.run(
                ["powershell", "-NoProfile", "-Command", "Get-Clipboard -Raw"],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=3,
            )
            return res.stdout if res.returncode == 0 else ""
    except Exception:
        return ""
    return ""


def write_clipboard(text: str) -> bool:
    system = platform.system()
    try:
        if system == "Darwin":
            proc = subprocess.run(
                ["pbcopy"], input=text, text=True, encoding="utf-8", timeout=2
            )
            return proc.returncode == 0
        if system == "Windows":
            proc = subprocess.run(
                ["clip"], input=text, text=True, encoding="utf-16le", timeout=3
            )
            return proc.returncode == 0
    except Exception:
        return False
    return False


def notify_desktop(title: str, message: str) -> None:
    """Display a lightweight OS notification when Antigravity finishes a request."""
    if platform.system() == "Darwin":
        safe_title = title.replace('"', '\\"')
        safe_msg = message.replace('"', '\\"')[:120]
        subprocess.run(
            [
                "osascript",
                "-e",
                f'display notification "{safe_msg}" with title "{safe_title}"',
            ],
            capture_output=True,
            check=False,
        )


def find_saved_variables_files(wow_flavor_dir: Path | None, explicit_sv: Path | None) -> list[Path]:
    if explicit_sv:
        return [explicit_sv] if explicit_sv.exists() else []
    if not wow_flavor_dir:
        return []
    wtf_account = wow_flavor_dir / "WTF" / "Account"
    if not wtf_account.exists():
        return []
    return sorted(wtf_account.glob("*/SavedVariables/AntigravityWoW.lua"))


class CompanionDaemon:
    def __init__(
        self,
        addons_dir: Path,
        inbox_path: Path,
        wow_flavor_dir: Path | None,
        explicit_sv: Path | None,
        runner: AntigravityBridgeRunner,
        enable_clipboard: bool = True,
        poll_interval: float = 1.5,
    ) -> None:
        self.addons_dir = addons_dir
        self.inbox_path = inbox_path
        self.wow_flavor_dir = wow_flavor_dir
        self.explicit_sv = explicit_sv
        self.runner = runner
        self.enable_clipboard = enable_clipboard
        self.poll_interval = poll_interval

        self.state_file = REPO_ROOT / "bridge" / ".daemon_state.json"
        self.processed_ids: set[str] = set()
        self.inbox_messages: list[dict[str, Any]] = []
        self.sv_mtimes: dict[str, float] = {}
        self.last_clipboard_sig: str = ""
        self._load_state()

    def _load_state(self) -> None:
        if not self.state_file.exists():
            return
        try:
            data = json.loads(self.state_file.read_text(encoding="utf-8"))
            self.processed_ids = set(data.get("processed_ids", []))
            self.inbox_messages = list(data.get("inbox_messages", []))[-25:]
        except Exception:
            pass

    def _save_state(self) -> None:
        try:
            payload = {
                "processed_ids": sorted(self.processed_ids)[-200:],
                "inbox_messages": self.inbox_messages[-25:],
            }
            self.state_file.write_text(
                json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
            )
        except Exception as exc:
            print(f"[WARN] 상태 저장 실패: {exc}")

    def _record_and_flush_reply(
        self,
        req_id: str,
        prompt_preview: str,
        turn_result: Any,
    ) -> dict[str, Any]:
        msg_id = f"res-{req_id}"
        msg = {
            "id": msg_id,
            "requestId": req_id,
            "role": "assistant",
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "summary": prompt_preview[:60],
            "content": f"|cff4285F4[Antigravity]|r {turn_result.text}",
            "code": turn_result.lua_snippet or "",
            "macroName": turn_result.macro_name or "",
            "macroBody": turn_result.macro_body or "",
            "waypoint": turn_result.waypoint,
            "filesChanged": turn_result.files_changed or [],
        }
        self.inbox_messages.append(msg)
        self.inbox_messages = self.inbox_messages[-25:]
        write_inbox_lua(self.inbox_path, self.inbox_messages, daemon_status="online")
        self._save_state()
        return msg

    def poll_saved_variables_once(self) -> int:
        handled = 0
        sv_files = find_saved_variables_files(self.wow_flavor_dir, self.explicit_sv)
        for sv_path in sv_files:
            try:
                mtime = sv_path.stat().st_mtime
            except OSError:
                continue

            key = str(sv_path)
            if self.sv_mtimes.get(key) == mtime:
                continue
            self.sv_mtimes[key] = mtime

            try:
                parsed = load_saved_variables_file(sv_path)
            except Exception as exc:
                print(f"[ERROR] SavedVariables 파싱 오류 ({sv_path}): {exc}")
                continue

            db = parsed.get("AntigravityWoWDB")
            if not isinstance(db, dict):
                continue

            outbox = db.get("outbox")
            if not isinstance(outbox, list):
                continue

            for entry in outbox:
                if not isinstance(entry, dict):
                    continue
                req_id = str(entry.get("id", ""))
                status = str(entry.get("status", ""))
                req_mode = str(entry.get("mode", "auto"))
                prompt = str(entry.get("prompt", "")).strip()
                if not req_id or not prompt:
                    continue
                if status != "pending" or req_id in self.processed_ids:
                    continue

                print(f"\n[AGY Bridge] 새 인게임 요청 감지 ({req_id}, mode={req_mode}): {prompt[:80]}")
                self.processed_ids.add(req_id)

                ctx = entry.get("context") if isinstance(entry.get("context"), dict) else None
                errs = entry.get("errors") if isinstance(entry.get("errors"), list) else None

                result = self.runner.run_turn(prompt=prompt, context=ctx, errors=errs, mode=req_mode)
                self._record_and_flush_reply(req_id, prompt, result)
                handled += 1

                print(
                    f"[AGY Bridge] 완료! Inbox 업데이트됨 ({self.inbox_path}). "
                    f"수정된 파일: {len(result.files_changed)}개"
                )
                notify_desktop(
                    "Antigravity WoW 완료",
                    "응답이 준비되었습니다! 게임에서 /reload 하거나 결과를 확인하세요.",
                )
        return handled

    def poll_clipboard_once(self) -> bool:
        if not self.enable_clipboard:
            return False
        clip = read_clipboard().strip()
        if not clip.startswith("AGY_REQ:"):
            return False
        if clip == self.last_clipboard_sig:
            return False
        self.last_clipboard_sig = clip

        raw_json = clip[len("AGY_REQ:") :].strip()
        try:
            payload = json.loads(raw_json)
        except json.JSONDecodeError as exc:
            print(f"[WARN] 클립보드 AGY_REQ JSON 파싱 실패: {exc}")
            return False

        prompt = str(payload.get("prompt", "")).strip()
        if not prompt:
            return False

        req_mode = str(payload.get("mode", "auto"))
        req_id = f"clip-{int(time.time())}"
        print(f"\n[AGY Clipboard] 무-리로드 클립보드 요청 감지 (mode={req_mode}): {prompt[:80]}")

        ctx = payload.get("context") if isinstance(payload.get("context"), dict) else None
        errs = payload.get("errors") if isinstance(payload.get("errors"), list) else None

        result = self.runner.run_turn(prompt=prompt, context=ctx, errors=errs, mode=req_mode)
        self._record_and_flush_reply(req_id, prompt, result)

        # Build AGY_RES packet carrying WoW-formatted Q&A answer + optional ```lua``` + ```macro``` + ```waypoint```
        reply_parts = [f"AGY_RES:{result.text}"]
        if result.lua_snippet:
            reply_parts.append(f"```lua\n{result.lua_snippet}\n```")
        if result.macro_body:
            m_name = result.macro_name or "AGY_Macro"
            reply_parts.append(f"```macro:{m_name}\n{result.macro_body}\n```")
        if result.waypoint:
            wp = result.waypoint
            reply_parts.append(
                f"```waypoint:{wp['mapID']},{wp['x']},{wp['y']},{wp.get('label', '추천 위치')}```"
            )
        clipboard_reply = "\n".join(reply_parts)

        if write_clipboard(clipboard_reply):
            self.last_clipboard_sig = clipboard_reply
            print("[AGY Clipboard] 답변을 클립보드에 복사했습니다! 인게임 [클립보드 답변/코드 붙여넣기]로 리로드 없이 확인하세요.")
        notify_desktop(
            "Antigravity 답변 도착! (무-리로드)",
            "인게임 창에서 [클립보드 답변/코드 붙여넣기](Cmd+V/Ctrl+V)를 눌러 바로 확인하세요.",
        )
        return True

    def serve_forever(self) -> None:
        print("=" * 68)
        print(" Antigravity WoW Forever (Interface: 16001) Companion Bridge")
        print("=" * 68)
        print(f" • Backend        : {self.runner.backend} ({self.runner.agy_bin})")
        print(f" • AddOns 폴더    : {self.addons_dir}")
        print(f" • Inbox 경로     : {self.inbox_path}")
        print(f" • WoW 경로       : {self.wow_flavor_dir or '(수동 지정 안 됨 — 로컬 워크스페이스 모드)'}")
        print(f" • 클립보드 브릿지: {'활성화 (무-리로드 즉시 실행 지원)' if self.enable_clipboard else '비활성화'}")
        print("-" * 68)
        print(" 대기 중... (종료하려면 Ctrl+C)")

        try:
            while True:
                self.poll_saved_variables_once()
                self.poll_clipboard_once()
                time.sleep(self.poll_interval)
        except KeyboardInterrupt:
            print("\n[AGY Bridge] 브릿지 데몬을 종료합니다.")


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Antigravity Companion Bridge for World of Warcraft: Forever (16001)"
    )
    p.add_argument(
        "--wow-dir",
        type=Path,
        default=None,
        help="WoW Forever 클라이언트 폴더 경로 (예: '/Applications/World of Warcraft/_forever_')",
    )
    p.add_argument(
        "--addons-dir",
        type=Path,
        default=None,
        help="직접 지정할 Interface/AddOns 경로 (미지정 시 --wow-dir 또는 레포 내 AddOn 폴더 사용)",
    )
    p.add_argument(
        "--saved-vars",
        type=Path,
        default=None,
        help="직접 지정할 WTF/.../SavedVariables/AntigravityWoW.lua 파일 경로",
    )
    p.add_argument(
        "--backend",
        choices=["auto", "cli", "sdk"],
        default="auto",
        help="Antigravity 실행 엔진 선택 (auto: 설치된 agy CLI 우선, sdk: google-antigravity SDK)",
    )
    p.add_argument(
        "--no-clipboard",
        action="store_true",
        help="무-리로드 클립보드 브릿지 감시 비활성화",
    )
    p.add_argument(
        "--continue-session",
        action="store_true",
        help="agy CLI 실행 시 이전 대화 컨텍스트 이어가기 (--continue)",
    )
    p.add_argument(
        "--once",
        action="store_true",
        help="큐를 1회만 폴링하고 즉시 종료 (테스트용)",
    )
    return p


def main() -> int:
    args = build_arg_parser().parse_args()
    wow_dir = args.wow_dir.expanduser().resolve() if args.wow_dir else auto_detect_wow_flavor_dir()

    if args.addons_dir:
        addons_dir = args.addons_dir.expanduser().resolve()
    elif wow_dir and (wow_dir / "Interface" / "AddOns").exists():
        addons_dir = (wow_dir / "Interface" / "AddOns").resolve()
    else:
        addons_dir = (REPO_ROOT / "AddOn").resolve()

    inbox_path = addons_dir / "AntigravityWoW" / "Inbox.lua"
    agents_md_path = REPO_ROOT / "AGENTS.md"

    runner = AntigravityBridgeRunner(
        addons_dir=addons_dir,
        agents_md_path=agents_md_path,
        backend=args.backend,
        continue_session=args.continue_session,
    )

    daemon = CompanionDaemon(
        addons_dir=addons_dir,
        inbox_path=inbox_path,
        wow_flavor_dir=wow_dir,
        explicit_sv=args.saved_vars.expanduser().resolve() if args.saved_vars else None,
        runner=runner,
        enable_clipboard=not args.no_clipboard,
    )

    if args.once:
        daemon.poll_saved_variables_once()
        daemon.poll_clipboard_once()
        return 0

    daemon.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
