local addonName, ns = ...

ns.ADDON_NAME = addonName or "AntigravityWoW"
ns.VERSION = "1.2.0"
ns.EXPECTED_TOC = 16001

-- 와우 공식 단축키 설정(ESC -> 설정 -> 단축키 -> 애드온) 한국어 레이블 정의
BINDING_HEADER_ANTIGRAVITYWOW = "Antigravity AI 가이드 & 코딩 스튜디오"
BINDING_NAME_ANTIGRAVITYWOW_TOGGLE = "Antigravity 질문 & 코딩 창 열기/닫기"
BINDING_NAME_ANTIGRAVITYWOW_ASK_TARGET = "현재 타겟 몬스터/NPC 즉시 공략·드랍 질문"
BINDING_NAME_ANTIGRAVITYWOW_LIVE_LUA = "Live Lua 코드 에디터 바로 열기"

AntigravityWoW = ns

local DEFAULTS = {
    version = ns.VERSION,
    settings = {
        requestMode = "auto",        -- "auto" (질문+코딩 자동), "qa" (와우 공략/백과 질문), "code" (애드온/매크로 코딩)
        attachPlayerContext = true,
        attachErrors = true,
        attachMouseover = false,
        autoOpenOnNewReply = true,
        minimapAngle = 215,
        hideMinimap = false,
    },
    outbox = {},
    history = {},
    snippets = {},
    errors = {},
    lastInboxMessageId = "",
    lastContextSnapshot = {},
    nextSeq = 1,
}

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then
        dst = {}
    end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function ns:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4285F4[Antigravity]|r " .. tostring(msg))
end

function ns:FormatTimestamp()
    if date then
        return date("%Y-%m-%d %H:%M:%S")
    end
    return tostring(time and time() or 0)
end

function ns:NextRequestId()
    local db = self.db
    local seq = (db and db.nextSeq) or 1
    if db then
        db.nextSeq = seq + 1
    end
    return string.format("req-%d-%04d", time and time() or 0, seq)
end

function ns:TrimTable(tbl, maxItems)
    if type(tbl) ~= "table" then return end
    while #tbl > maxItems do
        table.remove(tbl, 1)
    end
end

-- Inbox.lua로 들어온 새 에이전트 응답(Q&A 답변 / 코딩 / 매크로 / 좌표 핀) 병합
function ns:IngestInbox()
    local payload = self.InboxPayload
    if type(payload) ~= "table" or type(payload.messages) ~= "table" then
        return 0
    end

    local seen = {}
    for _, item in ipairs(self.db.history) do
        if item.id then
            seen[item.id] = true
        end
    end

    local addedCount = 0
    local latestCode = nil

    for _, msg in ipairs(payload.messages) do
        if msg.id and not seen[msg.id] then
            table.insert(self.db.history, {
                id = msg.id,
                requestId = msg.requestId or "",
                role = msg.role or "assistant",
                timestamp = msg.timestamp or payload.updatedAt or self:FormatTimestamp(),
                summary = msg.summary or "",
                content = msg.content or "",
                code = msg.code or "",
                macroName = msg.macroName or "",
                macroBody = msg.macroBody or "",
                waypoint = msg.waypoint,
                filesChanged = msg.filesChanged or {},
            })
            seen[msg.id] = true
            self.db.lastInboxMessageId = msg.id
            addedCount = addedCount + 1

            if msg.code and msg.code ~= "" then
                latestCode = msg.code
            end

            if msg.requestId and msg.requestId ~= "" then
                for _, req in ipairs(self.db.outbox) do
                    if req.id == msg.requestId then
                        req.status = "completed"
                        req.completedAt = msg.timestamp or self:FormatTimestamp()
                    end
                end
            end
        end
    end

    self:TrimTable(self.db.history, 50)

    if latestCode and latestCode ~= "" then
        self.latestInboxCode = latestCode
    end

    return addedCount
end

-- 인게임 질문(Q&A) 또는 코딩 프롬프트를 Outbox(SavedVariables)에 적재
function ns:EnqueuePrompt(promptText, extraMeta)
    if not promptText or strtrim(promptText) == "" then
        self:Print("질문 또는 코딩 지시 내용을 입력해 주세요.")
        return nil
    end

    local meta = extraMeta or {}
    local mode = meta.mode or (self.db and self.db.settings.requestMode) or "auto"
    local reqId = self:NextRequestId()

    local contextData = nil
    if self.db.settings.attachPlayerContext and self.CollectContext then
        contextData = self:CollectContext(self.db.settings.attachMouseover)
        self.db.lastContextSnapshot = contextData
    end

    local attachedErrors = nil
    if self.db.settings.attachErrors and mode ~= "qa" and self.GetRecentErrors then
        attachedErrors = self:GetRecentErrors(5)
    end

    local entry = {
        id = reqId,
        mode = mode,
        status = "pending",
        createdAt = self:FormatTimestamp(),
        prompt = promptText,
        context = contextData,
        errors = attachedErrors,
        meta = meta,
    }

    table.insert(self.db.outbox, entry)
    self:TrimTable(self.db.outbox, 30)

    local modeBadge = ""
    if mode == "qa" then
        modeBadge = "|cff34A853[와우 질문]|r "
    elseif mode == "code" then
        modeBadge = "|cff4285F4[코딩 요청]|r "
    end

    table.insert(self.db.history, {
        id = "user-" .. reqId,
        requestId = reqId,
        role = "user",
        timestamp = entry.createdAt,
        content = modeBadge .. promptText,
    })
    self:TrimTable(self.db.history, 50)

    if self.RefreshUI then
        self:RefreshUI()
    end
    if self.UpdateMinimapBadge then
        self:UpdateMinimapBadge()
    end

    return entry
end

function ns:SafeReloadUI()
    if InCombatLockdown and InCombatLockdown() then
        self:Print("|cffEA4335전투 중에는 /reload를 실행할 수 없습니다.|r 질문은 큐에 저장되었으니 전투 종료 후 리로드해 주세요.")
        return false
    end
    if self.CollectContext then
        self.db.lastContextSnapshot = self:CollectContext(self.db.settings.attachMouseover)
    end
    ReloadUI()
    return true
end

-- 단축키 및 프리셋 버튼 공용: 현재 타겟에 대한 즉시 질문 준비
function ns:QuickAskCurrentTarget()
    if self.ToggleMainFrame then
        self:ToggleMainFrame(true, 1)
    end
    if self.db and self.db.settings then
        self.db.settings.requestMode = "qa"
    end
    if self.RefreshModeButton then
        self:RefreshModeButton()
    end
    local tName = (UnitExists and UnitExists("target") and UnitName("target")) or nil
    if self.promptEditBox then
        if tName then
            self.promptEditBox:SetText(string.format("지금 내가 타겟팅한 '%s' 몬스터/NPC의 주요 특징, 주의할 패턴(공략), 주요 드랍 아이템이나 관련 퀘스트를 알려줘!", tName))
        else
            self.promptEditBox:SetText("현재 내 지역에서 주의해야 할 희귀 몬스터나 주요 파밍 포인트를 알려줘!")
        end
        self.promptEditBox:SetFocus()
    end
end

function ns:EnsureDefaultSnippets()
    if #self.db.snippets > 0 then
        return
    end
    table.insert(self.db.snippets, {
        title = "캐릭터 & Forever 빌드 진단",
        code = table.concat({
            "local ver, build, dateStr, toc = GetBuildInfo()",
            "print('클라이언트:', ver, '빌드:', build, 'TOC:', toc)",
            "print('지역:', GetRealZoneText(), '-', GetSubZoneText())",
            "print('C_Spell 지원 여부:', C_Spell and C_Spell.GetSpellInfo ~= nil)",
        }, "\n"),
    })
    table.insert(self.db.snippets, {
        title = "현재 버프(오라) 목록 출력 (C_UnitAuras)",
        code = table.concat({
            "if not C_UnitAuras then print('C_UnitAuras 미지원') return end",
            "for i = 1, 40 do",
            "    local aura = C_UnitAuras.GetBuffDataByIndex('player', i)",
            "    if not aura then break end",
            "    print(string.format('[%d] %s (spellId=%s)', i, tostring(aura.name), tostring(aura.spellId)))",
            "end",
        }, "\n"),
    })
    table.insert(self.db.snippets, {
        title = "미니 알림 프레임 띄우기 (BackdropTemplate)",
        code = table.concat({
            "if not AGYDemoBanner then",
            "    local f = CreateFrame('Frame', 'AGYDemoBanner', UIParent, 'BackdropTemplate')",
            "    f:SetSize(320, 48)",
            "    f:SetPoint('TOP', 0, -140)",
            "    f:SetBackdrop({ bgFile = 'Interface/Buttons/WHITE8x8', edgeFile = 'Interface/Buttons/WHITE8x8', edgeSize = 1 })",
            "    f:SetBackdropColor(0.08, 0.12, 0.20, 0.92)",
            "    f:SetBackdropBorderColor(0.26, 0.52, 0.96, 1)",
            "    f.txt = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')",
            "    f.txt:SetPoint('CENTER')",
            "    f:EnableMouse(true)",
            "    f:SetScript('OnMouseDown', function(self) self:Hide() end)",
            "end",
            "AGYDemoBanner.txt:SetText('|cff4285F4Antigravity|r Live Lua 작동 중! (클릭 시 닫기)')",
            "AGYDemoBanner:Show()",
        }, "\n"),
    })
end

local eventFrame = CreateFrame("Frame")
pcall(eventFrame.RegisterEvent, eventFrame, "ADDON_LOADED")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_LOGIN")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ns.ADDON_NAME then
        AntigravityWoWDB = CopyDefaults(DEFAULTS, AntigravityWoWDB)
        ns.db = AntigravityWoWDB
        ns:EnsureDefaultSnippets()
        if ns.InitErrorCatcher then
            ns:InitErrorCatcher()
        end
    elseif event == "PLAYER_LOGIN" then
        if not ns.db then
            AntigravityWoWDB = CopyDefaults(DEFAULTS, AntigravityWoWDB)
            ns.db = AntigravityWoWDB
        end
        if ns.CollectContext then
            ns.db.lastContextSnapshot = ns:CollectContext(false)
        end
        local added = ns:IngestInbox()
        if ns.InitMinimapButton then
            ns:InitMinimapButton()
        end
        if ns.InitHyperlinkHook then
            ns:InitHyperlinkHook()
        end
        if ns.InitSettingsCategory then
            ns:InitSettingsCategory()
        end
        if added > 0 then
            ns:Print(string.format("새 Antigravity 답변 %d건이 도착했습니다! |cffFBBC05/agy|r 로 확인하세요.", added))
            if ns.db.settings.autoOpenOnNewReply and added > 0 and #ns.db.outbox > 0 then
                if ns.ToggleMainFrame then
                    ns:ToggleMainFrame(true, 1)
                end
            end
        else
            ns:Print("준비 완료! |cffFBBC05/agy|r (스튜디오) 또는 |cff34A853/와우질문 <궁금한점>|r 을 입력해 보세요.")
        end
    elseif event == "PLAYER_LOGOUT" then
        if ns.db and ns.CollectContext then
            ns.db.lastContextSnapshot = ns:CollectContext(false)
        end
    end
end)

-- 메인 슬래시 커맨드 (/agy, /antigravity)
SLASH_ANTIGRAVITYWOW1 = "/agy"
SLASH_ANTIGRAVITYWOW2 = "/antigravity"
SlashCmdList["ANTIGRAVITYWOW"] = function(msg)
    local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "" or cmd == "open" or cmd == "toggle" then
        if ns.ToggleMainFrame then
            ns:ToggleMainFrame()
        end
    elseif cmd == "code" or cmd == "lua" then
        if ns.ToggleMainFrame then
            ns:ToggleMainFrame(true, 2)
        end
    elseif cmd == "err" or cmd == "errors" then
        if ns.ToggleMainFrame then
            ns:ToggleMainFrame(true, 3)
        end
    elseif cmd == "run" and rest ~= "" then
        if ns.RunLuaSnippet then
            local ok, out = ns:RunLuaSnippet(rest)
            if ok then
                ns:Print("실행 완료: " .. (out ~= "" and out or "(출력 없음)"))
            else
                ns:Print("|cffEA4335실행 오류:|r " .. tostring(out))
            end
        end
    elseif (cmd == "q" or cmd == "qa" or cmd == "ask") and rest ~= "" then
        ns:EnqueuePrompt(rest, { mode = "qa" })
        if ns.ToggleMainFrame then
            ns:ToggleMainFrame(true, 1)
        end
        ns:Print("와우 질문이 등록되었습니다! 창에서 [전송 & 동기화] 또는 [클립보드 패킷 복사(무-리로드)]를 눌러주세요.")
    elseif cmd == "sync" or cmd == "reload" then
        ns:SafeReloadUI()
    elseif cmd == "help" then
        ns:Print("명령어 안내:")
        ns:Print("  |cffFBBC05/agy|r — Antigravity 질문 & 코딩 스튜디오 열기")
        ns:Print("  |cff34A853/와우질문 <질문>|r (또는 |cff34A853/wowask <질문>|r) — 와우 공략/퀘스트/아이템 질문")
        ns:Print("  |cffFBBC05/agy lua|r — Live Lua 코드 에디터 열기")
        ns:Print("  |cffFBBC05/agy errors|r — 캡처된 Lua 에러 디버거 열기")
        ns:Print("  |cffFBBC05/agy run <Lua코드>|r — 한 줄 Lua 코드 즉시 실행")
        ns:Print("  |cffFBBC05/agy sync|r — SavedVariables 동기화 (/reload)")
    else
        ns:EnqueuePrompt(msg)
        if ns.ToggleMainFrame then
            ns:ToggleMainFrame(true, 1)
        end
        ns:Print("요청이 등록되었습니다. 창에서 [전송 & 동기화] 또는 [클립보드 브릿지]를 눌러주세요.")
    end
end

-- 와우 공략·백과 전용 빠른 질문 슬래시 커맨드 (/wowask, /와우질문)
SLASH_ANTIGRAVITYWOWASK1 = "/wowask"
SLASH_ANTIGRAVITYWOWASK2 = "/와우질문"
SlashCmdList["ANTIGRAVITYWOWASK"] = function(msg)
    local q = strtrim(msg or "")
    if q == "" then
        if ns.db and ns.db.settings then
            ns.db.settings.requestMode = "qa"
        end
        if ns.ToggleMainFrame then
            ns:ToggleMainFrame(true, 1)
        end
        ns:Print("와우 Q&A 모드로 창을 열었습니다. 궁금한 퀘스트·던전·아이템(Shift+클릭)을 질문해 보세요!")
        return
    end

    if ns.ToggleMainFrame then
        ns:ToggleMainFrame(true, 1)
    end
    if ns.promptEditBox then
        ns.promptEditBox:SetText(q)
    end
    if ns.db and ns.db.settings then
        ns.db.settings.requestMode = "qa"
    end
    ns:EnqueuePrompt(q, { mode = "qa" })
    ns:Print("와우 질문이 큐에 추가되었습니다! 바로 답변을 받으려면 [전송 & 동기화] 또는 무-리로드 [클립보드 요청 복사]를 누르세요.")
end
