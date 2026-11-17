local addonName, ns = ...

-- ============================================================================
-- Inbox.lua
-- Auto-updated by the local Antigravity Companion Bridge (`bridge/daemon.py`)
-- or MCP Server (`bridge/mcp_server.py`). Safe to /reload.
-- ============================================================================

ns.InboxPayload = {
    bridgeVersion = "1.3.0",
    updatedAt = "2026-11-17 20:35:00",
    daemonStatus = "ready",
    messages = {
        {
            id = "welcome-001",
            requestId = "init",
            role = "assistant",
            timestamp = "Initial",
            summary = "Antigravity AI Guide & Studio Ready!",
            content = "|cff4285F4[Antigravity]|r Welcome to Antigravity AI Guide & Studio for WoW Forever (16001)!",
            code = table.concat({
                "-- [Sample] Inspect character & WoW Forever (16001) build info",
                "local version, build, buildDate, tocVersion = GetBuildInfo()",
                "local name = UnitName('player') or 'Unknown'",
                "local level = UnitLevel('player') or 0",
                "local zone = GetRealZoneText() or 'Unknown'",
                "print(string.format('[AGY Test] %s (Lv.%d) @ %s | Build %s (TOC %d, Locale %s)', name, level, zone, version, tocVersion, GetLocale()))",
            }, "\n"),
            macroName = "",
            macroBody = "",
            waypoint = {
                mapID = 1453,
                x = 62.5,
                y = 72.0,
                label = "Stormwind Trade District (Sample Pin)",
            },
            filesChanged = {},
        },
    },
}
