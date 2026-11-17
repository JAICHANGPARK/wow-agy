local addonName, ns = ...

-- ============================================================================
-- ErrorCatcher.lua
-- 블리자드 기본 에러 핸들러 및 BugGrabber와 충돌하지 않는 체인 방식 Lua 에러 수집기
-- ============================================================================

local MAX_CAPTURED_ERRORS = 30

function ns:RecordLuaError(errMsg, stackStr)
    if not self.db or type(self.db.errors) ~= "table" then
        return
    end

    local msgText = tostring(errMsg or "Unknown Lua Error")
    local traceText = tostring(stackStr or (debugstack and debugstack(3, 12, 12)) or "")

    -- 동일 에러 중복 발생 시 카운트 증가 및 최신 시각 갱신
    for i = #self.db.errors, 1, -1 do
        local existing = self.db.errors[i]
        if existing.message == msgText then
            existing.count = (existing.count or 1) + 1
            existing.lastSeen = self:FormatTimestamp()
            existing.stack = traceText
            if self.UpdateMinimapBadge then
                self:UpdateMinimapBadge()
            end
            return
        end
    end

    -- 에러 발생 추정 애드온 이름 파싱 (예: Interface/AddOns/Foo/Bar.lua:42:)
    local addonSource = msgText:match("AddOns[/\\]([^/\\:]+)") or traceText:match("AddOns[/\\]([^/\\:]+)") or "Unknown"

    table.insert(self.db.errors, {
        id = string.format("err-%d-%d", time and time() or 0, #self.db.errors + 1),
        addon = addonSource,
        message = msgText,
        stack = traceText,
        count = 1,
        firstSeen = self:FormatTimestamp(),
        lastSeen = self:FormatTimestamp(),
    })

    self:TrimTable(self.db.errors, MAX_CAPTURED_ERRORS)

    if self.UpdateMinimapBadge then
        self:UpdateMinimapBadge()
    end
    if self.RefreshErrorTab then
        self:RefreshErrorTab()
    end
end

function ns:GetRecentErrors(limit)
    if not self.db or type(self.db.errors) ~= "table" then
        return {}
    end
    local count = limit or 5
    local result = {}
    local startIdx = math.max(1, #self.db.errors - count + 1)
    for i = startIdx, #self.db.errors do
        table.insert(result, self.db.errors[i])
    end
    return result
end

function ns:ClearErrors()
    if self.db then
        self.db.errors = {}
    end
    if self.UpdateMinimapBadge then
        self:UpdateMinimapBadge()
    end
    if self.RefreshErrorTab then
        self:RefreshErrorTab()
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
            local stack = debugstack and debugstack(2, 12, 12) or ""
            pcall(function()
                ns:RecordLuaError(err, stack)
            end)
            if type(prevHandler) == "function" then
                return prevHandler(err)
            end
        end)
    end
end
