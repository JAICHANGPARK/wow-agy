local addonName, ns = ...

ns.ADDON_NAME = addonName or "WoWAGY"
ns.DISPLAY_NAME = "wow-agy"
ns.VERSION = "2026.11.17"
ns.DEFAULT_AUTHOR = "JAICHANGPARK (Dreamwalker)"
ns.DEFAULT_GITHUB = "https://github.com/JAICHANGPARK/wow-agy"
ns.DEFAULT_LICENSE = "MIT"
ns.EXPECTED_TOC = 16001

WoWAGY = ns

function ns:GetAddonMeta(field, fallback)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, val = pcall(C_AddOns.GetAddOnMetadata, self.ADDON_NAME, field)
        if ok and type(val) == "string" and val ~= "" then
            return val
        end
    elseif GetAddOnMetadata then
        local ok, val = pcall(GetAddOnMetadata, self.ADDON_NAME, field)
        if ok and type(val) == "string" and val ~= "" then
            return val
        end
    end
    return fallback or ""
end

function ns:PrintAbout()
    local ver = self:GetAddonMeta("Version", self.VERSION)
    local author = self:GetAddonMeta("Author", self.DEFAULT_AUTHOR)
    local url = self:GetAddonMeta("X-Website", self.DEFAULT_GITHUB)
    local lic = self:GetAddonMeta("X-License", self.DEFAULT_LICENSE)
    self:Print(string.format("|cff34A853%s|r v%s  |  Author: |cffFFD100%s|r  |  License: %s", self.DISPLAY_NAME, ver, author, lic))
    self:Print("GitHub: |cff67D8EF" .. url .. "|r")
end

local DEFAULTS = {
    version = ns.VERSION,
    settings = {
        locale = "auto",             -- "auto" (GetLocale() -> enUS fallback), or enUS/koKR/jaJP/zhCN/zhTW/deDE/frFR/esES/esMX/ptBR/ruRU/itIT
        requestMode = "auto",        -- "auto", "qa", "code"
        model = "auto",              -- "auto" (daemon/AGY default) or specific model ID
        effort = "auto",             -- "auto", "low", "medium", "high", "xhigh", "max"
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

ns.EFFORT_ORDER = { "auto", "low", "medium", "high", "xhigh", "max" }

ns.DEFAULT_MODELS = {
    { id = "gemini-3.8-flash",          label = "Gemini 3.8 Flash (SDK Default)" },
    { id = "gemini-3.8-flash-low",      label = "Gemini 3.8 Flash (Low)" },
    { id = "gemini-3.8-flash-medium",   label = "Gemini 3.8 Flash (Medium)" },
    { id = "gemini-3.8-flash-high",     label = "Gemini 3.8 Flash (High)" },
    { id = "gemini-4-carbon-low",       label = "Gemini 4 Carbon (Low)" },
    { id = "gemini-4-carbon-medium",    label = "Gemini 4 Carbon (Medium)" },
    { id = "gemini-4-carbon-high",      label = "Gemini 4 Carbon (High)" },
    { id = "gemini-4-argon-low",        label = "Gemini 4 Argon (Low)" },
    { id = "gemini-4-argon-medium",     label = "Gemini 4 Argon (Medium)" },
    { id = "gemini-4-argon-high",       label = "Gemini 4 Argon (High)" },
    { id = "gemini-4-hydrogen-low",     label = "Gemini 4 Hydrogen (Low)" },
    { id = "gemini-4-hydrogen-medium",  label = "Gemini 4 Hydrogen (Medium)" },
    { id = "gemini-4-hydrogen-high",    label = "Gemini 4 Hydrogen (High)" },
    { id = "gemini-4-hydrogen-xhigh",   label = "Gemini 4 Hydrogen (XHigh)" },
    { id = "gemini-pro-orchestrator",   label = "Orchestrator (Carbon)" },
    { id = "claude-sonnet-5-5-low",     label = "Claude Sonnet 5.5 (Low)" },
    { id = "claude-sonnet-5-5-medium",  label = "Claude Sonnet 5.5 (Medium)" },
    { id = "claude-sonnet-5-5-high",    label = "Claude Sonnet 5.5 (High)" },
    { id = "claude-opus-5-5-medium",    label = "Claude Opus 5.5 (Medium)" },
    { id = "claude-opus-5-5-high",      label = "Claude Opus 5.5 (High)" },
    { id = "gpt-oss-120b-medium",       label = "GPT-OSS 120B (Medium)" },
}

function ns:IsValidModelId(val)
    if type(val) ~= "string" then
        return false
    end
    local s = strtrim(val)
    if s == "" or #s > 120 or s:sub(1, 1) == "-" then
        return false
    end
    if s == "auto" then
        return true
    end
    return s:match("^[%w%._:/@-]+$") ~= nil
end

function ns:GetSelectedModel()
    local m = self.db and self.db.settings and self.db.settings.model
    if self:IsValidModelId(m) then
        return strtrim(m)
    end
    return "auto"
end

function ns:GetSelectedEffort()
    local e = self.db and self.db.settings and self.db.settings.effort
    if type(e) == "string" then
        local clean = strtrim(e):lower()
        for _, opt in ipairs(self.EFFORT_ORDER) do
            if opt == clean then
                return clean
            end
        end
    end
    return "auto"
end

function ns:GetAvailableModels()
    local list = {
        { id = "auto", label = (self.L and self.L.MODEL_AUTO_LABEL) or "Auto (Default)" },
    }
    local seen = { auto = true }
    local source = self.DEFAULT_MODELS
    if self.InboxPayload and type(self.InboxPayload.availableModels) == "table" and #self.InboxPayload.availableModels > 0 then
        source = self.InboxPayload.availableModels
    end
    for _, item in ipairs(source) do
        if type(item) == "table" and self:IsValidModelId(item.id) and not seen[item.id] then
            seen[item.id] = true
            table.insert(list, {
                id = item.id,
                label = self:SafeToString(item.label, item.id),
            })
        end
    end
    return list
end

function ns:GetModelDisplayLabel(maxChars)
    local m = self:GetSelectedModel()
    local shortName = m
    if m == "auto" then
        shortName = (self.L and self.L.MODEL_AUTO_SHORT) or "Auto"
    else
        local limit = maxChars or 16
        if #shortName > limit then
            shortName = shortName:sub(1, limit - 2) .. ".."
        end
    end
    local fmt = (self.L and self.L.MODEL_BTN_FMT) or "Model: |cffFFD100%s|r"
    return string.format(fmt, shortName)
end

function ns:GetEffortDisplayLabel()
    local e = self:GetSelectedEffort()
    local disp = (e == "auto") and ((self.L and self.L.MODEL_AUTO_SHORT) or "Auto") or e
    local fmt = (self.L and self.L.EFFORT_BTN_FMT) or "Effort: |cff34A853%s|r"
    return string.format(fmt, disp)
end

function ns:SetPreferredModel(modelId, silent)
    local clean = strtrim(self:SafeToString(modelId, ""))
    if clean == "" or clean:lower() == "default" or clean:lower() == "auto" then
        clean = "auto"
    end
    if not self:IsValidModelId(clean) then
        self:Print((self.L and self.L.ERR_INVALID_MODEL) or "Invalid model ID.")
        return false
    end
    if self.db and self.db.settings then
        self.db.settings.model = clean
    end
    if self.RefreshModelButton then
        self:RefreshModelButton()
    end
    if not silent then
        local msgFmt = (self.L and self.L.MSG_MODEL_CHANGED) or "AI Model set to: |cffFFD100%s|r (Effort: |cff34A853%s|r)"
        self:Print(string.format(msgFmt, clean, self:GetSelectedEffort()))
    end
    return true
end

function ns:SetPreferredEffort(effortVal, silent)
    local clean = strtrim(self:SafeToString(effortVal, "")):lower()
    if clean == "" or clean == "default" then
        clean = "auto"
    end
    local valid = false
    for _, opt in ipairs(self.EFFORT_ORDER) do
        if opt == clean then
            valid = true
            break
        end
    end
    if not valid then
        self:Print((self.L and self.L.ERR_INVALID_EFFORT) or "Supported effort values: auto, low, medium, high, xhigh, max")
        return false
    end
    if self.db and self.db.settings then
        self.db.settings.effort = clean
    end
    if self.RefreshModelButton then
        self:RefreshModelButton()
    end
    if not silent then
        local msgFmt = (self.L and self.L.MSG_MODEL_CHANGED) or "AI Model set to: |cffFFD100%s|r (Effort: |cff34A853%s|r)"
        self:Print(string.format(msgFmt, self:GetSelectedModel(), clean))
    end
    return true
end

function ns:CycleEffort(silent)
    local cur = self:GetSelectedEffort()
    local nextEff = "auto"
    for idx, opt in ipairs(self.EFFORT_ORDER) do
        if opt == cur then
            nextEff = self.EFFORT_ORDER[(idx % #self.EFFORT_ORDER) + 1]
            break
        end
    end
    return self:SetPreferredEffort(nextEff, silent)
end

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
    local text = self:SafeToString(msg, "")
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "|cff4285F4[wow-agy]|r " .. text)
    end
end

-- WoW Forever (16001 / Midnight) C_Secrets protection helper
function ns:IsSecretValue(val)
    if issecretvalue then
        local ok, isSec = pcall(issecretvalue, val)
        if ok and isSec then
            return true
        end
    end
    return false
end

function ns:SafeToString(val, fallback)
    if val == nil or self:IsSecretValue(val) then
        return fallback or ""
    end
    local ok, str = pcall(tostring, val)
    if not ok or self:IsSecretValue(str) then
        return fallback or ""
    end
    return str
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
        if type(msg) == "table" and type(msg.id) == "string" and msg.id ~= "" and not seen[msg.id] then
            local contentText = self:SafeToString(msg.content, "")
            if msg.id == "welcome-001" and self.L and self.L.WELCOME_BODY then
                contentText = self.L.WELCOME_BODY
            end
            local safeFiles = type(msg.filesChanged) == "table" and msg.filesChanged or {}
            table.insert(self.db.history, {
                id = msg.id,
                requestId = self:SafeToString(msg.requestId, ""),
                role = self:SafeToString(msg.role, "assistant"),
                timestamp = self:SafeToString(msg.timestamp, payload.updatedAt or self:FormatTimestamp()),
                summary = self:SafeToString(msg.summary, ""),
                content = contentText,
                code = self:SafeToString(msg.code, ""),
                macroName = self:SafeToString(msg.macroName, ""),
                macroBody = self:SafeToString(msg.macroBody, ""),
                waypoint = type(msg.waypoint) == "table" and msg.waypoint or nil,
                filesChanged = safeFiles,
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
    local effModel = meta.model or self:GetSelectedModel()
    local effEffort = meta.effort or self:GetSelectedEffort()
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
        model = effModel,
        effort = effEffort,
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
        WoWAGYDB = CopyDefaults(DEFAULTS, WoWAGYDB)
        ns.db = WoWAGYDB
        if ns.ApplyBindingTranslations then
            ns:ApplyBindingTranslations()
        end
        ns:EnsureDefaultSnippets()
        if ns.InitErrorCatcher then
            ns:InitErrorCatcher()
        end
    elseif event == "PLAYER_LOGIN" then
        if not ns.db then
            WoWAGYDB = CopyDefaults(DEFAULTS, WoWAGYDB)
            ns.db = WoWAGYDB
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

SLASH_WOWAGY1 = "/agy"
SLASH_WOWAGY2 = "/wow-agy"
SLASH_WOWAGY3 = "/wowagy"
SLASH_WOWAGY4 = "/antigravity"
SlashCmdList["WOWAGY"] = function(msg)
    local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "" or cmd == "open" or cmd == "toggle" then
        if ns.ToggleMainFrame then
            ns:ToggleMainFrame()
        end
    elseif cmd == "about" or cmd == "info" or cmd == "version" then
        ns:PrintAbout()
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
    elseif cmd == "model" or cmd == "models" then
        if rest == "" then
            if ns.ShowModelSelectorModal then
                ns:ShowModelSelectorModal()
            end
            ns:Print(string.format("Current Model: |cffFFD100%s|r  |  Effort: |cff34A853%s|r", ns:GetSelectedModel(), ns:GetSelectedEffort()))
        else
            ns:SetPreferredModel(rest)
        end
    elseif cmd == "effort" then
        if rest == "" then
            ns:CycleEffort()
        else
            ns:SetPreferredEffort(rest)
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
        ns:Print("Commands: /agy | /wow-agy | /wowask <q> | /agy model [id] | /agy effort [lvl] | /agy lang <code> | /agy lua | /agy errors | /agy undo | /agy about")
    else
        ns:EnqueuePrompt(msg)
        if ns.ToggleMainFrame then
            ns:ToggleMainFrame(true, 1)
        end
        ns:Print(ns.L.MSG_QUEUED)
    end
end

-- Multilingual Quick Q&A Slash Commands (/wowask, /와우질문, /wowq)
SLASH_WOWAGYASK1 = "/wowask"
SLASH_WOWAGYASK2 = "/와우질문"
SLASH_WOWAGYASK3 = "/wowq"
SlashCmdList["WOWAGYASK"] = function(msg)
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
