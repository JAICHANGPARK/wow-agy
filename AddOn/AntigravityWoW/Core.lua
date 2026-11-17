local addonName, ns = ...

ns.ADDON_NAME = addonName or "AntigravityWoW"
ns.VERSION = "1.3.0"
ns.EXPECTED_TOC = 16001

AntigravityWoW = ns

local DEFAULTS = {
    version = ns.VERSION,
    settings = {
        locale = "auto",             -- "auto" (GetLocale() -> enUS fallback), or enUS/koKR/jaJP/zhCN/zhTW/deDE/frFR/esES/esMX/ptBR/ruRU/itIT
        requestMode = "auto",        -- "auto", "qa", "code"
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
            local contentText = msg.content or ""
            if msg.id == "welcome-001" and self.L and self.L.WELCOME_BODY then
                contentText = self.L.WELCOME_BODY
            end
            table.insert(self.db.history, {
                id = msg.id,
                requestId = msg.requestId or "",
                role = msg.role or "assistant",
                timestamp = msg.timestamp or payload.updatedAt or self:FormatTimestamp(),
                summary = msg.summary or "",
                content = contentText,
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
        elseif msg.id == "welcome-001" then
            -- Keep welcome-001 localized when user switches UI language
            for _, h in ipairs(self.db.history) do
                if h.id == "welcome-001" and self.L and self.L.WELCOME_BODY then
                    h.content = self.L.WELCOME_BODY
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

function ns:EnqueuePrompt(promptText, extraMeta)
    if not promptText or strtrim(promptText) == "" then
        self:Print(self.L.MSG_EMPTY_PROMPT)
        return nil
    end

    local meta = extraMeta or {}
    local mode = meta.mode or (self.db and self.db.settings.requestMode) or "auto"
    local effLocale = self.GetEffectiveLocale and self:GetEffectiveLocale() or "enUS"
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
        locale = effLocale,
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
        modeBadge = "|cff34A853[Q&A]|r "
    elseif mode == "code" then
        modeBadge = "|cff4285F4[Code]|r "
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
        self:Print(self.L.MSG_COMBAT_RELOAD)
        return false
    end
    if self.CollectContext then
        self.db.lastContextSnapshot = self:CollectContext(self.db.settings.attachMouseover)
    end
    ReloadUI()
    return true
end

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
            self.promptEditBox:SetText(string.format(self.L.PROMPT_TARGET_WITH_NAME, tName))
        else
            self.promptEditBox:SetText(self.L.PROMPT_TARGET_NONE)
        end
        self.promptEditBox:SetFocus()
    end
end

function ns:EnsureDefaultSnippets()
    if #self.db.snippets > 0 then
        return
    end
    table.insert(self.db.snippets, {
        title = "Client & Forever 16001 Build Check",
        code = table.concat({
            "local ver, build, dateStr, toc = GetBuildInfo()",
            "print('Client:', ver, 'Build:', build, 'TOC:', toc, 'Locale:', GetLocale())",
            "print('Zone:', GetRealZoneText(), '-', GetSubZoneText())",
            "print('C_Spell ready:', C_Spell and C_Spell.GetSpellInfo ~= nil)",
        }, "\n"),
    })
    table.insert(self.db.snippets, {
        title = "Scan Active Player Buffs (C_UnitAuras)",
        code = table.concat({
            "if not C_UnitAuras then print('C_UnitAuras unavailable') return end",
            "for i = 1, 40 do",
            "    local aura = C_UnitAuras.GetBuffDataByIndex('player', i)",
            "    if not aura then break end",
            "    print(string.format('[%d] %s (spellId=%s)', i, tostring(aura.name), tostring(aura.spellId)))",
            "end",
        }, "\n"),
    })
    table.insert(self.db.snippets, {
        title = "Spawn Alert Banner (BackdropTemplate)",
        code = table.concat({
            "if not AGYDemoBanner then",
            "    local f = CreateFrame('Frame', 'AGYDemoBanner', UIParent, 'BackdropTemplate')",
            "    f:SetSize(340, 48)",
            "    f:SetPoint('TOP', 0, -140)",
            "    f:SetBackdrop({ bgFile = 'Interface/Buttons/WHITE8x8', edgeFile = 'Interface/Buttons/WHITE8x8', edgeSize = 1 })",
            "    f:SetBackdropColor(0.08, 0.12, 0.20, 0.92)",
            "    f:SetBackdropBorderColor(0.26, 0.52, 0.96, 1)",
            "    f.txt = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')",
            "    f.txt:SetPoint('CENTER')",
            "    f:EnableMouse(true)",
            "    f:SetScript('OnMouseDown', function(self) self:Hide() end)",
            "end",
            "AGYDemoBanner.txt:SetText('|cff4285F4Antigravity|r Live Lua OK! (Click to close)')",
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
        if ns.ApplyBindingTranslations then
            ns:ApplyBindingTranslations()
        end
        ns:EnsureDefaultSnippets()
        if ns.InitErrorCatcher then
            ns:InitErrorCatcher()
        end
    elseif event == "PLAYER_LOGIN" then
        if not ns.db then
            AntigravityWoWDB = CopyDefaults(DEFAULTS, AntigravityWoWDB)
            ns.db = AntigravityWoWDB
        end
        if ns.ApplyBindingTranslations then
            ns:ApplyBindingTranslations()
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
        if added > 0 and #ns.db.outbox > 0 then
            ns:Print(string.format(ns.L.MSG_NEW_REPLIES, added))
            if ns.db.settings.autoOpenOnNewReply and ns.ToggleMainFrame then
                ns:ToggleMainFrame(true, 1)
            end
        else
            ns:Print(ns.L.MSG_READY)
        end
    elseif event == "PLAYER_LOGOUT" then
        if ns.db and ns.CollectContext then
            ns.db.lastContextSnapshot = ns:CollectContext(false)
        end
    end
end)

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
    elseif cmd == "lang" or cmd == "locale" then
        if rest == "" then
            ns:CycleLocale()
        elseif not ns:SetPreferredLocale(strtrim(rest)) then
            ns:Print("Supported locales: auto, enUS, koKR, jaJP, zhCN, zhTW, deDE, frFR, esES, esMX, ptBR, ruRU, itIT")
        end
    elseif cmd == "run" and rest ~= "" then
        if ns.RunLuaSnippet then
            local ok, out = ns:RunLuaSnippet(rest)
            if ok then
                ns:Print("OK: " .. (out ~= "" and out or "(no output)"))
            else
                ns:Print("|cffEA4335Error:|r " .. tostring(out))
            end
        end
    elseif (cmd == "q" or cmd == "qa" or cmd == "ask") and rest ~= "" then
        ns:EnqueuePrompt(rest, { mode = "qa" })
        if ns.ToggleMainFrame then
            ns:ToggleMainFrame(true, 1)
        end
        ns:Print(ns.L.MSG_QUEUED)
    elseif cmd == "sync" or cmd == "reload" then
        ns:SafeReloadUI()
    elseif cmd == "undo" then
        if ns.UndoLastMacro then
            ns:UndoLastMacro()
        end
    elseif cmd == "help" then
        ns:Print("Commands: /agy | /wowask <q> | /agy lua | /agy errors | /agy run <code> | /agy lang <code> | /agy undo | /agy sync")
    else
        ns:EnqueuePrompt(msg)
        if ns.ToggleMainFrame then
            ns:ToggleMainFrame(true, 1)
        end
        ns:Print(ns.L.MSG_QUEUED)
    end
end

-- Multilingual Quick Q&A Slash Commands (/wowask, /와우질문, /wowq)
SLASH_ANTIGRAVITYWOWASK1 = "/wowask"
SLASH_ANTIGRAVITYWOWASK2 = "/와우질문"
SLASH_ANTIGRAVITYWOWASK3 = "/wowq"
SlashCmdList["ANTIGRAVITYWOWASK"] = function(msg)
    local q = strtrim(msg or "")
    if q == "" then
        if ns.db and ns.db.settings then
            ns.db.settings.requestMode = "qa"
        end
        if ns.ToggleMainFrame then
            ns:ToggleMainFrame(true, 1)
        end
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
    ns:Print(ns.L.MSG_QUEUED)
end
