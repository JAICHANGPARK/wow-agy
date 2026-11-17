local addonName, ns = ...

-- ============================================================================
-- Sandbox.lua
-- 인게임 Live Lua 즉시 실행기(loadstring), 매크로 빌더, 지도 핀(Waypoint), 채팅 공유 및
-- 리로드 없는 클립보드 브릿지(AGY_REQ / AGY_RES — 와우 Q&A 답변 + 코딩 + 매크로 겸용)
-- ============================================================================

local function SerializeValueCompact(val, depth)
    depth = depth or 0
    if depth > 3 then
        return '"..."'
    end
    local t = type(val)
    if t == "string" then
        local escaped = val:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "")
        return '"' .. escaped .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "table" then
        local isArray = (#val > 0)
        local parts = {}
        if isArray then
            for i = 1, math.min(#val, 20) do
                table.insert(parts, SerializeValueCompact(val[i], depth + 1))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(val) do
                if type(k) == "string" or type(k) == "number" then
                    local keyStr = tostring(k):gsub('"', '\\"')
                    table.insert(parts, '"' .. keyStr .. '":' .. SerializeValueCompact(v, depth + 1))
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

function ns:RunLuaSnippet(codeStr)
    if not codeStr or strtrim(codeStr) == "" then
        return false, "실행할 Lua 코드가 비어 있습니다."
    end

    local loader = loadstring
    if not loader then
        return false, "현재 클라이언트에서 loadstring을 사용할 수 없습니다."
    end

    local fn, compileErr = loader(codeStr, "AntigravityLiveLua")
    if not fn then
        return false, "[문법 에러] " .. tostring(compileErr)
    end

    local capturedLines = {}
    local origPrint = print

    local function capturedPrint(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring(select(i, ...))
        end
        local line = table.concat(parts, "  ")
        table.insert(capturedLines, line)
        origPrint("|cff34A853[AGY Lua]|r", ...)
    end

    local env = setmetatable({
        print = capturedPrint,
        AGY = ns,
    }, {
        __index = _G,
        __newindex = _G,
    })
    if setfenv then
        setfenv(fn, env)
    end

    local startMs = debugprofilestop and debugprofilestop() or 0
    local results = { pcall(fn) }
    local elapsedMs = (debugprofilestop and debugprofilestop() or 0) - startMs

    local ok = table.remove(results, 1)
    if not ok then
        local runtimeErr = tostring(results[1])
        self:RecordLuaError(runtimeErr, "AntigravityLiveLua")
        return false, "[런타임 에러] " .. runtimeErr
    end

    if #results > 0 then
        local retParts = {}
        for i = 1, #results do
            retParts[i] = tostring(results[i])
        end
        table.insert(capturedLines, "=> 반환값: " .. table.concat(retParts, ", "))
    end

    table.insert(capturedLines, string.format("(실행 완료: %.2f ms)", elapsedMs))
    return true, table.concat(capturedLines, "\n")
end

function ns:CreateOrUpdateMacro(macroName, macroBody, pickupToCursor)
    if InCombatLockdown and InCombatLockdown() then
        self:Print(self.L.MSG_COMBAT_MACRO)
        return false
    end

    local cleanName = strtrim(macroName or "AGY_Macro")
    if cleanName == "" then
        cleanName = "AGY_Macro"
    end
    cleanName = cleanName:sub(1, 16)

    local cleanBody = strtrim(macroBody or "")
    if cleanBody == "" then
        return false
    end
    if #cleanBody > 255 then
        cleanBody = cleanBody:sub(1, 255)
    end

    -- Notify user clearly if the macro contains Lua script commands (/run or /script)
    local lowerBody = cleanBody:lower()
    if lowerBody:find("/run ") or lowerBody:find("/script ") then
        self:Print("|cffFBBC05[Security Notice]|r Macro contains `/run` or `/script`. Review before clicking on your action bar (`/agy undo` to revert).")
    end

    local existingIdx = GetMacroIndexByName and GetMacroIndexByName(cleanName) or 0
    local macroIdx = 0

    if existingIdx and existingIdx > 0 then
        local oldName, oldIcon, oldBody = nil, nil, nil
        if GetMacroInfo then
            oldName, oldIcon, oldBody = GetMacroInfo(existingIdx)
        end
        self.lastMacroBackup = {
            existed = true,
            name = oldName or cleanName,
            icon = oldIcon or "INV_Misc_QuestionMark",
            body = oldBody or "",
        }
        macroIdx = EditMacro(existingIdx, cleanName, "INV_Misc_QuestionMark", cleanBody)
        self:Print(string.format("Macro |cffFBBC05[%s]|r updated! (Type |cff34A853/agy undo|r to revert)", cleanName))
    else
        local numGlobal = GetNumMacros and select(1, GetNumMacros()) or 0
        if numGlobal >= 120 then
            self:Print("|cffEA4335General macro slots (120) are full.|r")
            return false
        end
        self.lastMacroBackup = {
            existed = false,
            name = cleanName,
        }
        macroIdx = CreateMacro(cleanName, "INV_Misc_QuestionMark", cleanBody, nil)
        self:Print(string.format("Macro |cffFBBC05[%s]|r created! (Type |cff34A853/agy undo|r to remove)", cleanName))
    end

    if pickupToCursor and macroIdx and macroIdx > 0 and PickupMacro then
        PickupMacro(macroIdx)
    end

    return true
end

function ns:UndoLastMacro()
    if InCombatLockdown and InCombatLockdown() then
        self:Print(self.L.MSG_COMBAT_MACRO)
        return false
    end
    local bak = self.lastMacroBackup
    if not bak or not bak.name then
        self:Print("No recent macro action to undo.")
        return false
    end
    local idx = GetMacroIndexByName and GetMacroIndexByName(bak.name) or 0
    if idx and idx > 0 then
        if bak.existed then
            EditMacro(idx, bak.name, bak.icon or "INV_Misc_QuestionMark", bak.body or "")
            self:Print(string.format("Restored macro |cffFBBC05[%s]|r to previous content.", bak.name))
        elseif DeleteMacro then
            DeleteMacro(idx)
            self:Print(string.format("Deleted newly created macro |cffFBBC05[%s]|r.", bak.name))
        end
    end
    self.lastMacroBackup = nil
    return true
end

function ns:SetMapWaypoint(wp)
    if type(wp) ~= "table" then
        self:Print("표시할 좌표 정보가 없습니다.")
        return false
    end

    local mapID = tonumber(wp.mapID) or 0
    local x = tonumber(wp.x) or 0
    local y = tonumber(wp.y) or 0
    local label = tostring(wp.label or "Antigravity 안내 위치")

    if mapID <= 0 and C_Map and C_Map.GetBestMapForUnit then
        local ok, curMap = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and curMap then
            mapID = curMap
        end
    end

    if x <= 0 or y <= 0 or x > 100 or y > 100 then
        self:Print("유효한 좌표 범위를 벗어났습니다.")
        return false
    end

    local placed = false
    if mapID > 0 and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        local ok = pcall(function()
            local canSet = (not C_Map.CanSetUserWaypointOnMap) or C_Map.CanSetUserWaypointOnMap(mapID)
            if canSet then
                local pt = UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100)
                C_Map.SetUserWaypoint(pt)
                if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                end
                placed = true
            end
        end)
        placed = ok and placed
    end

    if placed then
        local link = (C_Map.GetUserWaypointHyperlink and C_Map.GetUserWaypointHyperlink()) or ""
        self:Print(string.format("📍 지도 핀 설정 완료: |cffFFD100%s|r (%.1f, %.1f) %s", label, x, y, link))
        return true
    else
        self:Print(string.format("📍 안내 좌표: |cffFFD100%s|r — (%.1f, %.1f) [현재 지역/인스턴스는 순정 핀 미지원]", label, x, y))
        return false
    end
end

-- 최근 AI 공략 답변의 핵심 요약을 파티/공격대/길드 채팅으로 깔끔하게 공유 (최대 3줄 제한으로 도배 방지)
function ns:ShareLatestAnswerToGroup()
    local msg = self.latestAssistantMsg
    if not msg or not msg.content or msg.content == "" then
        return false
    end

    if not SendChatMessage then
        return false
    end

    -- Anti-spam 5s cooldown per Blizzard performance/chat etiquette rules
    local now = GetTime and GetTime() or 0
    if self._lastShareAt and (now - self._lastShareAt) < 5 then
        self:Print("Please wait a few seconds before sharing to chat again.")
        return false
    end
    self._lastShareAt = now

    -- 색상 코드(|c........ 및 |r) 제거
    local plain = tostring(msg.content):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    plain = plain:gsub("^%[Antigravity%]%s*", "")

    local channel = "PARTY"
    if IsInRaid and IsInRaid() then
        channel = "RAID"
    elseif IsInGroup and IsInGroup() then
        channel = "PARTY"
    elseif IsInGuild and IsInGuild() then
        channel = "GUILD"
    else
        -- 솔로 플레이 중일 때는 복사 팝업으로 열어줌
        if self.ShowClipboardModal then
            self:ShowClipboardModal("copy", plain)
        end
        return true
    end

    local sentLines = 0
    for line in (plain .. "\n"):gmatch("(.-)\n") do
        local trimmed = strtrim(line)
        if trimmed ~= "" then
            pcall(SendChatMessage, "[AGY 요약] " .. trimmed:sub(1, 220), channel)
            sentLines = sentLines + 1
            if sentLines >= 3 then
                break
            end
        end
    end
    self:Print(string.format("%s 채널에 핵심 답변(%d줄)을 공유했습니다.", channel, sentLines))
    return true
end

function ns:BuildClipboardPacket(promptText, modeOverride)
    local ctx = nil
    if self.db and self.db.settings.attachPlayerContext then
        ctx = self:CollectContext(self.db.settings.attachMouseover)
    end
    local errs = nil
    local reqMode = modeOverride or (self.db and self.db.settings.requestMode) or "auto"
    if self.db and self.db.settings.attachErrors and reqMode ~= "qa" then
        errs = self:GetRecentErrors(3)
    end

    local payload = {
        protocol = "AGY_WOW_FOREVER_V1",
        toc = 16001,
        locale = (self.GetEffectiveLocale and self:GetEffectiveLocale()) or "enUS",
        mode = reqMode,
        timestamp = self:FormatTimestamp(),
        prompt = promptText or "",
        context = ctx,
        errors = errs,
    }
    return "AGY_REQ:" .. SerializeValueCompact(payload, 0)
end

function ns:ExtractWaypointFromText(text)
    if not text or text == "" then return nil end
    local m, x, y, lbl = text:match("```waypoint:([%d]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,?%s*([^\n`]*)```")
    if m and x and y then
        return {
            mapID = tonumber(m) or 0,
            x = tonumber(x) or 0,
            y = tonumber(y) or 0,
            label = strtrim(lbl or "추천 위치"),
        }
    end
    return nil
end

function ns:ExtractMacroFromText(text)
    if not text or text == "" then return "", "" end
    local mName, mBody = text:match("```macro:([^\n`]+)\r?\n(.-)```")
    if not mBody then
        mBody = text:match("```macro%s*\r?\n(.-)```")
        mName = "AGY_Macro"
    end
    if mBody and strtrim(mBody) ~= "" then
        return strtrim(mName or "AGY_Macro"):sub(1, 16), strtrim(mBody):sub(1, 255)
    end
    return "", ""
end

function ns:ExtractLuaFromClipboard(pastedText)
    if not pastedText or strtrim(pastedText) == "" then
        return ""
    end

    local fenced = pastedText:match("```lua%s*\n(.-)```") or pastedText:match("```%s*\n(.-)```")
    if fenced and strtrim(fenced) ~= "" then
        return strtrim(fenced)
    end

    return strtrim(pastedText)
end

-- 무-리로드 클립보드 답변(Q&A 답변 + Lua 스니펫 + 매크로 + 지도 핀)을 인게임 터미널에 완벽 반영
function ns:IngestClipboardReply(pastedText)
    if not pastedText or strtrim(pastedText) == "" then
        return false
    end

    local raw = strtrim(pastedText)
    if raw:sub(1, 8) == "AGY_RES:" then
        raw = strtrim(raw:sub(9))
    end

    local luaCode = raw:match("```lua%s*\r?\n(.-)```") or ""
    local macroName, macroBody = self:ExtractMacroFromText(raw)
    local wp = self:ExtractWaypointFromText(raw)

    -- 화면 대화창 본문에서는 코드/매크로/좌표 펜스 블록을 깔끔히 분리 제거
    local displayContent = raw
        :gsub("```lua%s*\r?\n.-```", "")
        :gsub("```macro[^\n`]*\r?\n.-```", "")
        :gsub("```waypoint:.-```", "")
    displayContent = strtrim(displayContent)
    if displayContent == "" and luaCode ~= "" then
        displayContent = "클립보드 Lua 코드가 도착했습니다! 아래 [▶ 응답 코드 실행]을 눌러 실행하세요."
    end

    if self.db and self.db.history then
        local msgObj = {
            id = "clip-res-" .. tostring(time and time() or 0) .. "-" .. tostring(#self.db.history + 1),
            requestId = "clipboard",
            role = "assistant",
            timestamp = self:FormatTimestamp(),
            summary = "클립보드 즉시 응답",
            content = "|cff4285F4[Antigravity]|r " .. displayContent,
            code = strtrim(luaCode),
            macroName = macroName,
            macroBody = macroBody,
            waypoint = wp,
            filesChanged = {},
        }
        table.insert(self.db.history, msgObj)
        self:TrimTable(self.db.history, 50)
        self.latestAssistantMsg = msgObj
        if msgObj.code ~= "" then
            self.latestInboxCode = msgObj.code
        end
    end

    if self.RefreshUI then
        self:RefreshUI()
    end
    return true
end
