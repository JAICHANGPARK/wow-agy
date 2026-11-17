local addonName, ns = ...

-- ============================================================================
-- Inbox.lua
-- 로컬 Antigravity Bridge 데몬(bridge/daemon.py) 또는 MCP 서버가
-- 와우 공략/백과 Q&A 답변, Lua 코드 스니펫, 매크로, 지도 핀 좌표를 전달하는 파일
-- ============================================================================

ns.InboxPayload = {
    bridgeVersion = "1.1.0",
    updatedAt = "2026-11-17 19:35:00",
    daemonStatus = "ready",
    messages = {
        {
            id = "welcome-001",
            requestId = "init",
            role = "assistant",
            timestamp = "Initial",
            summary = "Antigravity 와우 Q&A 가이드 & 코딩 스튜디오 준비 완료!",
            content = table.concat({
                "|cff4285F4[Antigravity]|r 안녕하세요! **와우 포에버 실시간 질문(Q&A) 백과사전 & 코딩 스튜디오**입니다.",
                "",
                "• |cffFFD100와우 무엇이든 질문하기|r: 퀘스트 길찾기, 보스 공략, 드랍템, 특성 빌드를 물어보세요! (몬스터 타겟팅 후 질문하거나 아이템·퀘스트를 |cffFBBC05Shift+클릭|r해 첨부 가능)",
                "• |cff34A853리로드 없이 바로 답변 보기|r: [클립보드 요청 복사] → 완료 알림 후 [클립보드 답변/코드 붙여넣기]를 누르면 `/reload` 없이 대화창에 답변이 바로 뜹니다!",
                "• |cff4285F4애드온 & Live Lua 코딩|r: 원하는 UI/애드온 제작 지시 및 실시간 Lua 코드 실행도 그대로 지원합니다.",
            }, "\n"),
            code = table.concat({
                "-- [예제] 내 캐릭터 정보와 WoW Forever 빌드 확인 스니펫",
                "local version, build, buildDate, tocVersion = GetBuildInfo()",
                "local name = UnitName('player') or 'Unknown'",
                "local level = UnitLevel('player') or 0",
                "local zone = GetRealZoneText() or 'Unknown'",
                "print(string.format('[AGY 테스트] %s (Lv.%d) @ %s | 빌드 %s (TOC %d)', name, level, zone, version, tocVersion))",
            }, "\n"),
            macroName = "",
            macroBody = "",
            waypoint = {
                mapID = 1453,
                x = 62.5,
                y = 72.0,
                label = "스톰윈드 상업지구 은행 (예시 핀)",
            },
            filesChanged = {},
        },
    },
}
