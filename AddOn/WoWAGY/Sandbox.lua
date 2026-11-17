local addonName, ns = ...

-- ============================================================================
-- Sandbox.lua
-- Hardened Live Lua Runner (loadstring), Macro Builder with Undo & pcalls,
-- Map Waypoint Setter, Anti-Spam Chat Share, and JSON-Safe Clipboard Codec
-- ============================================================================

local MAX_PRINT_LINES = 200

local function EscapeJsonString(s)
    local str = ns:SafeToString(s, "")
    str = str
        :gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\r", "")
        :gsub("\n", "\\n")
        :gsub("\t", "\\t")
        :gsub("[%z\1-\31]", function(c)
            return string.format("\\u%04x", string.byte(c))
        end)
    return '"' .. str .. '"'
end

local function SerializeValueCompact(val, depth, seen)
    depth = depth or 0
    if depth > 4 or ns:IsSecretValue(val) then
        return '"..."'
    end
    local t = type(val)
    if t == "string" then
        return EscapeJsonString(val)
    elseif t == "number" then
        -- Guard against inf / -inf / nan which are invalid in strict JSON
        if val ~= val or val == math.huge or val == -math.huge then
            return "0"
        end
        return tostring(val)
    elseif t == "boolean" then
        return tostring(val)
    elseif t == "table" then
        seen = seen or {}
        if seen[val] then
            return '"[Circular]"'
        end
        seen[val] = true

        local isArray = (#val > 0)
        local parts = {}
        if isArray then
            for i = 1, math.min(#val, 20) do
                table.insert(parts, SerializeValueCompact(val[i], depth + 1, seen))
            end
            seen[val] = nil
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(val) do
                if (type(k) == "string" or type(k) == "number") and not ns:IsSecretValue(k) then
                    local keyJson = EscapeJsonString(tostring(k))
                    table.insert(parts, keyJson .. ":" .. SerializeValueCompact(v, depth + 1, seen))
                end
            end
            seen[val] = nil
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

function ns:RunLuaSnippet(codeStr)
    if type(codeStr) ~= "string" or strtrim(codeStr) == "" then
        return false, self.L.ERR_EMPTY_LUA
    end

    local loader = loadstring
    if not loader then
        return false, self.L.ERR_NO_LOADSTRING
    end

    local fn, compileErr = loader(codeStr, "AntigravityLiveLua")
    if not fn then
        return false, self.L.ERR_SYNTAX_PREFIX .. self:SafeToString(compileErr, "Syntax Error")
    end

    local capturedLines = {}
    local truncated = false
    local origPrint = print

    local function capturedPrint(...)
        if #capturedLines >= MAX_PRINT_LINES then
            if not truncated then
                truncated = true
                table.insert(capturedLines, string.format(ns.L.ERR_OUTPUT_TRUNC, MAX_PRINT_LINES))
            end
            return
        end
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = ns:SafeToString(select(i, ...), "<secret>")
        end
        local line = table.concat(parts, "  ")
        table.insert(capturedLines, line)
        pcall(origPrint, "|cff34A853[AGY Lua]|r", line)
    end

    local env = setmetatable({
        print = capturedPrint,
        AGY = ns,
    }, {
        __index = _G,
        __newindex = _G,
    })
    if setfenv then
        pcall(setfenv, fn, env)
    end

    local startMs = debugprofilestop and debugprofilestop() or 0
    local results = { pcall(fn) }
    local elapsedMs = (debugprofilestop and debugprofilestop() or 0) - startMs

    local ok = table.remove(results, 1)
    if not ok then
        local runtimeErr = self:SafeToString(results[1], "Unknown Runtime Error")
        self:RecordLuaError(runtimeErr, "AntigravityLiveLua")
        return false, self.L.ERR_RUNTIME_PREFIX .. runtimeErr
    end

    if #results > 0 then
        local retParts = {}
        for i = 1, #results do
            retParts[i] = self:SafeToString(results[i], "<secret>")
        end
        table.insert(capturedLines, "=> " .. table.concat(retParts, ", "))
    end

    table.insert(capturedLines, string.format("(%.2f ms)", elapsedMs))
    return true, table.concat(capturedLines, "\n")
end

function ns:CreateOrUpdateMacro(macroName, macroBody, pickupToCursor)
    if InCombatLockdown and InCombatLockdown() then
        self:Print(self.L.MSG_COMBAT_MACRO)
        return false
    end

    local cleanName = strtrim(self:SafeToString(macroName, "AGY_Macro"))
    if cleanName == "" then
        cleanName = "AGY_Macro"
    end
    cleanName = cleanName:sub(1, 16)

    local cleanBody = strtrim(self:SafeToString(macroBody, ""))
    if cleanBody == "" then
        self:Print(self.L.ERR_MACRO_EMPTY)
        return false
    end
    if #cleanBody > 255 then
        cleanBody = cleanBody:sub(1, 255)
    end

    local lowerBody = cleanBody:lower()
    if lowerBody:find("/run ") or lowerBody:find("/script ") then
        self:Print("|cffFBBC05[Security Notice]|r Macro contains `/run` or `/script`. Review before clicking (`/agy undo` to revert).")
    end

    local existingIdx = GetMacroIndexByName and GetMacroIndexByName(cleanName) or 0
    local macroIdx = 0

    if existingIdx and existingIdx > 0 then
        local oldName, oldIcon, oldBody = nil, nil, nil
        if GetMacroInfo then
            local okInfo, n, ic, bd = pcall(GetMacroInfo, existingIdx)
            if okInfo then
                oldName, oldIcon, oldBody = n, ic, bd
            end
        end
        local okEdit, editedIdx = pcall(EditMacro, existingIdx, cleanName, "INV_Misc_QuestionMark", cleanBody)
        if not okEdit then
            self:Print("|cffEA4335[Macro Error]|r " .. self:SafeToString(editedIdx, "EditMacro failed"))
            return false
        end
        self.lastMacroBackup = {
            existed = true,
            name = oldName or cleanName,
            icon = oldIcon or "INV_Misc_QuestionMark",
            body = oldBody or "",
        }
        macroIdx = editedIdx or existingIdx
        self:Print(string.format("Macro |cffFBBC05[%s]|r updated! (Type |cff34A853/agy undo|r to revert)", cleanName))
    else
        local numGlobal = GetNumMacros and select(1, GetNumMacros()) or 0
        if numGlobal >= 120 then
            self:Print(self.L.ERR_MACRO_FULL)
            return false
        end
        local okCreate, createdIdx = pcall(CreateMacro, cleanName, "INV_Misc_QuestionMark", cleanBody, nil)
        if not okCreate then
            self:Print("|cffEA4335[Macro Error]|r " .. self:SafeToString(createdIdx, "CreateMacro failed"))
            return false
        end
        self.lastMacroBackup = {
            existed = false,
            name = cleanName,
        }
        macroIdx = createdIdx or 0
        self:Print(string.format("Macro |cffFBBC05[%s]|r created! (Type |cff34A853/agy undo|r to remove)", cleanName))
    end

    if pickupToCursor and macroIdx and macroIdx > 0 and PickupMacro then
        pcall(PickupMacro, macroIdx)
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
        self:Print(self.L.ERR_MACRO_NO_UNDO)
        return false
    end
    local idx = GetMacroIndexByName and GetMacroIndexByName(bak.name) or 0
    if idx and idx > 0 then
        if bak.existed then
            pcall(EditMacro, idx, bak.name, bak.icon or "INV_Misc_QuestionMark", bak.body or "")
            self:Print(string.format("Restored macro |cffFBBC05[%s]|r.", bak.name))
        elseif DeleteMacro then
            pcall(DeleteMacro, idx)
            self:Print(string.format("Deleted macro |cffFBBC05[%s]|r.", bak.name))
        end
    end
    self.lastMacroBackup = nil
    return true
end

function ns:SetMapWaypoint(wp)
    if type(wp) ~= "table" then
        self:Print(self.L.ERR_NO_WAYPOINT)
        return false
    end

    local mapID = tonumber(wp.mapID) or 0
    local x = tonumber(wp.x) or 0
    local y = tonumber(wp.y) or 0
    local label = self:SafeToString(wp.label, "Waypoint")

    if mapID <= 0 and C_Map and C_Map.GetBestMapForUnit then
        local ok, curMap = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and curMap then
            mapID = curMap
        end
    end

    if x <= 0 or y <= 0 or x > 100 or y > 100 then
        self:Print(string.format(self.L.ERR_BAD_COORDS, x, y))
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
        local okLink, link = false, ""
        if C_Map.GetUserWaypointHyperlink then
            okLink, link = pcall(C_Map.GetUserWaypointHyperlink)
        end
        self:Print(string.format(self.L.MSG_WAYPOINT_SET, label, x, y, (okLink and link) or ""))
        return true
    else
        self:Print(string.format(self.L.ERR_WAYPOINT_UNSUP, label, x, y))
        return false
    end
end

function ns:ShareLatestAnswerToGroup()
    local msg = self.latestAssistantMsg
    if not msg or not msg.content or msg.content == "" then
        self:Print(self.L.ERR_NO_SHARE_MSG)
        return false
    end

    if not SendChatMessage then
        return false
    end

    local now = GetTime and GetTime() or 0
    if self._lastShareAt and (now - self._lastShareAt) < 5 then
        self:Print(string.format(self.L.ERR_SHARE_COOLDOWN, 5 - (now - self._lastShareAt)))
        return false
    end
    self._lastShareAt = now

    local plain = self:SafeToString(msg.content, ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    plain = plain:gsub("^%[Antigravity%]%s*", "")

    local channel = "PARTY"
    if IsInRaid and IsInRaid() then
        channel = "RAID"
    elseif IsInGroup and IsInGroup() then
        channel = "PARTY"
    elseif IsInGuild and IsInGuild() then
        channel = "GUILD"
    else
        if self.ShowClipboardModal then
            self:ShowClipboardModal("copy", plain)
        end
        return true
    end

    local sentLines = 0
    for line in (plain .. "\n"):gmatch("(.-)\n") do
        local trimmed = strtrim(line)
        if trimmed ~= "" then
            pcall(SendChatMessage, "[AGY] " .. trimmed:sub(1, 220), channel)
            sentLines = sentLines + 1
            if sentLines >= 3 then
                break
            end
        end
    end
    return true
end

function ns:BuildClipboardPacket(promptText, modeOverride)
    local ctx = nil
    if self.db and self.db.settings.attachPlayerContext then
        local okCtx, collected = pcall(self.CollectContext, self, self.db.settings.attachMouseover)
        if okCtx then
            ctx = collected
        end
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
        model = (self.GetSelectedModel and self:GetSelectedModel()) or "auto",
        effort = (self.GetSelectedEffort and self:GetSelectedEffort()) or "auto",
        timestamp = self:FormatTimestamp(),
        prompt = self:SafeToString(promptText, ""),
        context = ctx,
        errors = errs,
    }
    return "AGY_REQ:" .. SerializeValueCompact(payload, 0, {})
end

function ns:ExtractWaypointFromText(text)
    if type(text) ~= "string" or text == "" then return nil end
    local m, x, y, lbl = text:match("```waypoint:([%d]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,?%s*([^\n`]*)```")
    if m and x and y then
        return {
            mapID = tonumber(m) or 0,
            x = tonumber(x) or 0,
            y = tonumber(y) or 0,
            label = strtrim(lbl or "Waypoint"),
        }
    end
    return nil
end

function ns:ExtractMacroFromText(text)
    if type(text) ~= "string" or text == "" then return "", "" end
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
    if type(pastedText) ~= "string" or strtrim(pastedText) == "" then
        return ""
    end

    local fenced = pastedText:match("```lua%s*\r?\n(.-)```") or pastedText:match("```%s*\r?\n(.-)```")
    if fenced and strtrim(fenced) ~= "" then
        return strtrim(fenced)
    end

    return strtrim(pastedText)
end

function ns:IngestClipboardReply(pastedText)
    if type(pastedText) ~= "string" or strtrim(pastedText) == "" then
        self:Print(self.L.ERR_CLIP_EMPTY)
        return false
    end

    local raw = strtrim(pastedText)
    if raw:sub(1, 8) == "AGY_RES:" then
        raw = strtrim(raw:sub(9))
    end

    local luaCode = raw:match("```lua%s*\r?\n(.-)```") or ""
    local macroName, macroBody = self:ExtractMacroFromText(raw)
    local wp = self:ExtractWaypointFromText(raw)

    local displayContent = raw
        :gsub("```lua%s*\r?\n.-```", "")
        :gsub("```macro[^\n`]*\r?\n.-```", "")
        :gsub("```waypoint:.-```", "")
    displayContent = strtrim(displayContent)
    if displayContent == "" and luaCode ~= "" then
        displayContent = "Lua snippet ready -> [" .. self.L.BTN_RUN_REPLY .. "]"
    end

    if self.db and type(self.db.history) == "table" then
        local msgObj = {
            id = "clip-res-" .. tostring(time and time() or 0) .. "-" .. tostring(#self.db.history + 1),
            requestId = "clipboard",
            role = "assistant",
            timestamp = self:FormatTimestamp(),
            summary = "Clipboard Reply",
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
        pcall(self.RefreshUI, self)
    end
    return true
end
