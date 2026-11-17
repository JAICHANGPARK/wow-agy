local addonName, ns = ...

-- ============================================================================
-- ErrorCatcher.lua
-- Re-entrancy safe, storm-throttled Lua error catcher compatible with C_Secrets
-- and Blizzard's native ScriptErrorsFrame / BugGrabber handler chain.
-- ============================================================================

local MAX_CAPTURED_ERRORS = 30
local UI_REFRESH_THROTTLE_SEC = 0.5

function ns:RecordLuaError(errMsg, stackStr)
    if self._recordingError then
        return
    end
    if not self.db or type(self.db.errors) ~= "table" then
        return
    end

    self._recordingError = true
    pcall(function()
        local msgText = ns:SafeToString(errMsg, "Unknown Lua Error")
        local rawStack = stackStr
        if not rawStack and debugstack then
            local okStack, ds = pcall(debugstack, 3, 12, 12)
            rawStack = okStack and ds or ""
        end
        local traceText = ns:SafeToString(rawStack, "")

        -- Deduplicate identical errors: increment count and update timestamp
        for i = #self.db.errors, 1, -1 do
            local existing = self.db.errors[i]
            if type(existing) == "table" and existing.message == msgText then
                existing.count = (tonumber(existing.count) or 1) + 1
                existing.lastSeen = self:FormatTimestamp()
                if traceText ~= "" then
                    existing.stack = traceText
                end
                if self.UpdateMinimapBadge then
                    self:UpdateMinimapBadge()
                end
                return
            end
        end

        local addonSource = msgText:match("AddOns[/\\]([^/\\:]+)")
            or traceText:match("AddOns[/\\]([^/\\:]+)")
            or "Unknown"

        table.insert(self.db.errors, {
            id = string.format("err-%d-%d", time and time() or 0, #self.db.errors + 1),
            addon = addonSource:sub(1, 64),
            message = msgText:sub(1, 1000),
            stack = traceText:sub(1, 2000),
            count = 1,
            firstSeen = self:FormatTimestamp(),
            lastSeen = self:FormatTimestamp(),
        })

        self:TrimTable(self.db.errors, MAX_CAPTURED_ERRORS)

        -- Throttle UI updates so an external addon's OnUpdate error storm never freezes FPS
        local now = GetTime and GetTime() or 0
        if not self._lastErrorUiRefresh or (now - self._lastErrorUiRefresh) >= UI_REFRESH_THROTTLE_SEC then
            self._lastErrorUiRefresh = now
            if self.UpdateMinimapBadge then
                self:UpdateMinimapBadge()
            end
            if self.RefreshErrorTab and self.mainFrame and self.mainFrame:IsShown() then
                self:RefreshErrorTab()
            end
        end
    end)
    self._recordingError = false
end

function ns:GetRecentErrors(limit)
    if not self.db or type(self.db.errors) ~= "table" then
        return {}
    end
    local count = tonumber(limit) or 5
    local result = {}
    local startIdx = math.max(1, #self.db.errors - count + 1)
    for i = startIdx, #self.db.errors do
        if type(self.db.errors[i]) == "table" then
            table.insert(result, self.db.errors[i])
        end
    end
    return result
end

function ns:ClearErrors()
    if self.db then
        self.db.errors = {}
    end
    if self.UpdateMinimapBadge then
        pcall(self.UpdateMinimapBadge, self)
    end
    if self.RefreshErrorTab then
        pcall(self.RefreshErrorTab, self)
    end
end

function ns:InitErrorCatcher()
    if self._errorHookInstalled then
        return
    end
    self._errorHookInstalled = true

    if geterrorhandler and seterrorhandler then
        local prevHandler = geterrorhandler()
        seterrorhandler(function(err)
            if not ns._inErrorHandler then
                ns._inErrorHandler = true
                local okStack, stack = false, ""
                if debugstack then
                    okStack, stack = pcall(debugstack, 2, 12, 12)
                end
                pcall(ns.RecordLuaError, ns, err, okStack and stack or "")
                ns._inErrorHandler = false
            end
            if type(prevHandler) == "function" then
                return prevHandler(err)
            end
        end)
    end
end
