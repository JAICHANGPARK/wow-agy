#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WOW_DIR="${1:-${WOW_FOREVER_DIR:-}}"

if [[ -z "$WOW_DIR" ]]; then
  for candidate in \
    "/Applications/World of Warcraft/_forever_" \
    "/Applications/World of Warcraft/_classic_" \
    "/Applications/World of Warcraft/_classic_era_" \
    "/Applications/World of Warcraft/_retail_"; do
    if [[ -d "$candidate" ]]; then
      WOW_DIR="$candidate"
      break
    fi
  done
fi

if [[ -z "$WOW_DIR" || ! -d "$WOW_DIR" ]]; then
  echo "❌ WoW Forever 설치 폴더를 자동으로 찾지 못했습니다."
  echo "사용법: ./scripts/install.sh \"/Applications/World of Warcraft/_forever_\""
  exit 1
fi

ADDONS_DIR="$WOW_DIR/Interface/AddOns"
mkdir -p "$ADDONS_DIR"

TARGET_ADDON="$ADDONS_DIR/AntigravityWoW"
if [[ -L "$TARGET_ADDON" || -d "$TARGET_ADDON" ]]; then
  rm -rf "$TARGET_ADDON"
fi

# 심볼릭 링크로 연결하여 브릿지가 Inbox.lua를 업데이트하면 인게임에 즉시 반영되도록 설정
ln -s "$REPO_DIR/AddOn/AntigravityWoW" "$TARGET_ADDON"
cp "$REPO_DIR/AGENTS.md" "$ADDONS_DIR/AGENTS.md"

echo "✅ AntigravityWoW 애드온 설치 완료!"
echo "   • 연결 경로 : $TARGET_ADDON -> $REPO_DIR/AddOn/AntigravityWoW"
echo "   • 규칙 복사 : $ADDONS_DIR/AGENTS.md"
echo ""
echo "다음 명령어로 로컬 Antigravity 브릿지 데몬을 실행하세요 (uv 권장):"
echo "   uv run wow-agy-daemon --wow-dir \"$WOW_DIR\""
echo "   (또는 python3 \"$REPO_DIR/bridge/daemon.py\" --wow-dir \"$WOW_DIR\")"
echo ""
echo "(선택) Antigravity CLI / IDE에 WoW Forever MCP 서버 등록:"
echo "   agy mcp add wow-forever -- env WOW_FOREVER_DIR=\"$WOW_DIR\" uv --directory \"$REPO_DIR\" run wow-agy-mcp"
