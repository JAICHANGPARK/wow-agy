local addonName, ns = ...

-- ============================================================================
-- UI.lua
-- Multilingual In-Game Antigravity AI Guide & Code Studio (WoW Forever 16001)
-- Default Fallback: English (enUS), Live-Switchable Across 12 Languages!
-- ============================================================================

local COLORS = {
    bgMain       = { 0.06, 0.08, 0.12, 0.95 },
    bgPanel      = { 0.09, 0.12, 0.17, 0.95 },
    bgInput      = { 0.04, 0.06, 0.09, 0.98 },
    border       = { 0.22, 0.28, 0.38, 1.00 },
    borderActive = { 0.26, 0.52, 0.96, 1.00 },
    btnNormal    = { 0.14, 0.19, 0.27, 1.00 },
    btnPrimary   = { 0.18, 0.42, 0.82, 1.00 },
    btnGreen     = { 0.14, 0.52, 0.28, 1.00 },
    btnWarn      = { 0.62, 0.42, 0.08, 1.00 },
    btnPurple    = { 0.38, 0.22, 0.58, 1.00 },
}

local MODE_CYCLE = { "auto", "qa", "code" }
local MODE_KEY_MAP = {
    auto = "MODE_AUTO",
    qa   = "MODE_QA",
    code = "MODE_CODE",
}

local function ApplyBackdrop(frame, bg, border)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local c = bg or COLORS.bgPanel
    local b = border or COLORS.border
    frame:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
    frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4] or 1)
end

local function CreateFlatButton(parent, text, width, height, baseColor, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 110, height or 26)
    local normalCol = baseColor or COLORS.btnNormal
    ApplyBackdrop(btn, normalCol, COLORS.border)

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.label:SetPoint("CENTER", 0, 0)
    btn.label:SetText(text or "")

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(
            COLORS.borderActive[1],
            COLORS.borderActive[2],
            COLORS.borderActive[3],
            1
        )
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], 1)
    end)
    if onClick then
        btn:SetScript("OnClick", onClick)
    end
    return btn
end

local function CreateScrollEditBox(parent, width, height, isReadOnly)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetSize(width, height)
    ApplyBackdrop(container, COLORS.bgInput, COLORS.border)

    local scroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    editBox:SetWidth(width - 40)
    editBox:SetMaxLetters(0)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    editBox:SetScript("OnTabPressed", function(self)
        if not isReadOnly then
            self:Insert("    ")
        end
    end)

    editBox:SetScript("OnCursorChanged", function(_, _, y, _, cursorHeight)
        local vs = scroll:GetVerticalScroll()
        local h = scroll:GetHeight()
        if h and h > 0 then
            local offset = -y
            if offset < vs then
                scroll:SetVerticalScroll(math.max(0, offset))
            elseif (offset + cursorHeight) > (vs + h) then
                scroll:SetVerticalScroll(offset + cursorHeight - h + 8)
            end
        end
    end)

    container:EnableMouse(true)
    container:SetScript("OnMouseDown", function()
        editBox:SetFocus()
    end)

    scroll:SetScrollChild(editBox)
    container.scroll = scroll
    container.editBox = editBox
    return container
end

local function CreateCheckToggle(parent, labelText, initialValue, onToggle)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetChecked(initialValue and true or false)

    local txt = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    txt:SetText(labelText)
    cb.labelText = txt

    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        if onToggle then
            onToggle(checked)
        end
    end)
    return cb
end

function ns:ShowClipboardModal(mode, initialText)
    if not self.clipModal then
        local m = CreateFrame("Frame", "AntigravityClipboardModal", UIParent, "BackdropTemplate")
        m:SetSize(580, 350)
        m:SetPoint("CENTER", 0, 40)
        m:SetFrameStrata("DIALOG")
        m:EnableMouse(true)
        m:SetMovable(true)
        m:RegisterForDrag("LeftButton")
        m:SetScript("OnDragStart", m.StartMoving)
        m:SetScript("OnDragStop", m.StopMovingOrSizing)
        ApplyBackdrop(m, COLORS.bgMain, COLORS.borderActive)

        m.title = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        m.title:SetPoint("TOPLEFT", 14, -12)

        m.hint = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        m.hint:SetPoint("TOPLEFT", 14, -34)
        m.hint:SetWidth(552)
        m.hint:SetJustifyH("LEFT")

        m.boxWrap = CreateScrollEditBox(m, 552, 215, false)
        m.boxWrap:SetPoint("TOPLEFT", 14, -64)

        m.showChatBtn = CreateFlatButton(m, self.L.BTN_SHOW_IN_CHAT, 215, 28, COLORS.btnPrimary, function()
            local raw = m.boxWrap.editBox:GetText()
            if ns:IngestClipboardReply(raw) then
                m:Hide()
                ns:ToggleMainFrame(true, 1)
            end
        end)
        m.showChatBtn:SetPoint("BOTTOMLEFT", 14, 14)

        m.runBtn = CreateFlatButton(m, self.L.BTN_RUN_REPLY, 145, 28, COLORS.btnGreen, function()
            local raw = m.boxWrap.editBox:GetText()
            local luaCode = ns:ExtractLuaFromClipboard(raw)
            if luaCode == "" then
                return
            end
            if ns.codeEditorBox then
                ns.codeEditorBox:SetText(luaCode)
            end
            local ok, out = ns:RunLuaSnippet(luaCode)
            if ns.codeOutputBox then
                ns.codeOutputBox:SetText(out)
            end
            m:Hide()
            ns:ToggleMainFrame(true, 2)
            if not ok then
                ns:Print("|cffEA4335Error:|r " .. tostring(out))
            end
        end)
        m.runBtn:SetPoint("LEFT", m.showChatBtn, "RIGHT", 8, 0)

        m.toEditorBtn = CreateFlatButton(m, self.L.BTN_TO_EDITOR, 105, 28, COLORS.btnNormal, function()
            local raw = m.boxWrap.editBox:GetText()
            local luaCode = ns:ExtractLuaFromClipboard(raw)
            if ns.codeEditorBox then
                ns.codeEditorBox:SetText(luaCode)
            end
            m:Hide()
            ns:ToggleMainFrame(true, 2)
        end)
        m.toEditorBtn:SetPoint("LEFT", m.runBtn, "RIGHT", 8, 0)

        m.closeBtn = CreateFlatButton(m, self.L.BTN_CLOSE, 70, 28, COLORS.btnNormal, function()
            m:Hide()
        end)
        m.closeBtn:SetPoint("BOTTOMRIGHT", -14, 14)

        self.clipModal = m
    end

    local m = self.clipModal
    m.showChatBtn.label:SetText(self.L.BTN_SHOW_IN_CHAT)
    m.runBtn.label:SetText(self.L.BTN_RUN_REPLY)
    m.toEditorBtn.label:SetText(self.L.BTN_TO_EDITOR)
    m.closeBtn.label:SetText(self.L.BTN_CLOSE)

    if mode == "copy" then
        m.title:SetText(self.L.CLIP_COPY_TITLE)
        m.hint:SetText(self.L.CLIP_COPY_HINT)
        m.boxWrap.editBox:SetText(initialText or "")
        m:Show()
        m.boxWrap.editBox:SetFocus()
        m.boxWrap.editBox:HighlightText()
    else
        m.title:SetText(self.L.CLIP_PASTE_TITLE)
        m.hint:SetText(self.L.CLIP_PASTE_HINT)
        m.boxWrap.editBox:SetText("")
        m:Show()
        m.boxWrap.editBox:SetFocus()
    end
end

function ns:RefreshModeButton()
    if not self.modeBtn or not self.db then return end
    local cur = self.db.settings.requestMode or "auto"
    local key = MODE_KEY_MAP[cur] or "MODE_AUTO"
    self.modeBtn.label:SetText(self.L[key])
end

-- Live language refresh across all visible widgets without needing /reload
function ns:RebuildUIForLocale()
    if self.IngestInbox then
        self:IngestInbox()
    end
    if not self.mainFrame or not self.uiRefs then
        return
    end
    local r = self.uiRefs
    local L = self.L

    r.headerTitle:SetText("|cff4285F4Antigravity|r |cff34A853AI Guide & Studio|r  |cff9aa0a6" .. L.APP_SUBTITLE .. "|r")
    r.langBtn.label:SetText(self:GetLocaleDisplayLabel())

    self.tabButtons[1].label:SetText(L.TAB_1)
    self.tabButtons[2].label:SetText(L.TAB_2)
    self.tabButtons[3].label:SetText(L.TAB_3)
    self.tabButtons[4].label:SetText(L.TAB_4)

    r.pinBtn.label:SetText(L.BTN_WAYPOINT)
    r.quickRunBtn.label:SetText(L.BTN_RUN_REPLY)
    r.openInEditorBtn.label:SetText(L.BTN_TO_EDITOR)
    r.makeMacroBtn.label:SetText(L.BTN_MAKE_MACRO)
    r.shareAnsBtn.label:SetText(L.BTN_SHARE)
    r.pasteRunBtn.label:SetText(L.BTN_PASTE_CLIP)

    r.targetAskBtn.label:SetText(L.PRESET_TARGET)
    r.questAskBtn.label:SetText(L.PRESET_QUEST)
    r.buildAskBtn.label:SetText(L.PRESET_BUILD)

    r.cbCtx.labelText:SetText(L.OPT_ATTACH_CTX)
    r.cbErr.labelText:SetText(L.OPT_ATTACH_ERR)
    r.cbMouse.labelText:SetText(L.OPT_ATTACH_MOUSE)

    r.sendBtn.label:SetText(L.BTN_SEND_RELOAD)
    r.queueOnlyBtn.label:SetText(L.BTN_QUEUE_ONLY)
    r.clipCopyBtn.label:SetText(L.BTN_COPY_CLIP)
    r.clearChatBtn.label:SetText(L.BTN_CLEAR_CHAT)

    r.editorHeader:SetText(L.EDITOR_HEADER)
    r.runCodeBtn.label:SetText(L.BTN_RUN_LUA)
    r.saveSnippetBtn.label:SetText(L.BTN_SAVE_SNIPPET)
    r.toMacroBtn.label:SetText(L.BTN_RUN_MACRO)
    r.askRefactorBtn.label:SetText(L.BTN_ASK_REFACTOR)
    r.outLabel:SetText(L.OUTPUT_LABEL)

    r.prevErrBtn.label:SetText(L.BTN_PREV_ERR)
    r.nextErrBtn.label:SetText(L.BTN_NEXT_ERR)
    r.testErrBtn.label:SetText(L.BTN_TEST_ERR)
    r.askFixBtn.label:SetText(L.BTN_ASK_FIX_ERR)
    r.clearErrBtn.label:SetText(L.BTN_CLEAR_ERR)

    r.toolsTitle:SetText(L.TOOLS_HEADER)
    r.apiBtn.label:SetText(L.BTN_OPEN_API)
    r.fstackBtn.label:SetText(L.BTN_OPEN_FSTACK)
    r.etraceBtn.label:SetText(L.BTN_OPEN_ETRACE)
    r.reloadBtn.label:SetText(L.BTN_RELOAD_UI)
    r.snipTitle:SetText(L.SNIPPETS_HEADER)

    for _, row in ipairs(self.snippetRows or {}) do
        row.loadBtn.label:SetText(L.BTN_LOAD_SNIPPET)
        row.execBtn.label:SetText(L.BTN_EXEC_SNIPPET)
        row.delBtn.label:SetText(L.BTN_DEL_SNIPPET)
    end

    self:RefreshUI()
end

function ns:RefreshChatTab()
    if not self.chatView or not self.db then return end
    self.chatView:Clear()
    self:RefreshModeButton()
    if self.uiRefs and self.uiRefs.langBtn then
        self.uiRefs.langBtn.label:SetText(self:GetLocaleDisplayLabel())
    end

    local pendingCount = 0
    for _, req in ipairs(self.db.outbox) do
        if req.status == "pending" then
            pendingCount = pendingCount + 1
        end
    end

    if self.statusLabel then
        local errCount = #(self.db.errors or {})
        self.statusLabel:SetText(string.format(self.L.STATUS_BAR, pendingCount, errCount))
    end

    local latestAssistantMsg = nil
    for _, msg in ipairs(self.db.history) do
        local ts = msg.timestamp and ("|cff7f8c8d[" .. msg.timestamp .. "]|r ") or ""
        if msg.role == "user" then
            self.chatView:AddMessage(ts .. self.L.ROLE_USER .. tostring(msg.content or ""))
        else
            latestAssistantMsg = msg
            local body = tostring(msg.content or "")
            local firstLine = true
            for line in (body .. "\n"):gmatch("(.-)\n") do
                if firstLine then
                    self.chatView:AddMessage(ts .. line)
                    firstLine = false
                else
                    self.chatView:AddMessage(line)
                end
            end

            if msg.waypoint and type(msg.waypoint) == "table" then
                self.chatView:AddMessage(string.format(
                    "  |cffFFD100📍 %s (%.1f, %.1f) -> [%s]|r",
                    tostring(msg.waypoint.label or "Waypoint"),
                    tonumber(msg.waypoint.x) or 0,
                    tonumber(msg.waypoint.y) or 0,
                    self.L.BTN_WAYPOINT
                ))
            end
            if msg.filesChanged and #msg.filesChanged > 0 then
                self.chatView:AddMessage("  |cff34A853Files:|r " .. table.concat(msg.filesChanged, ", "))
            end
            if msg.code and msg.code ~= "" then
                self.chatView:AddMessage("  |cff4285F4[Lua Snippet Attached -> " .. self.L.BTN_RUN_REPLY .. "]|r")
            end
            if msg.macroBody and msg.macroBody ~= "" then
                self.chatView:AddMessage("  |cffFBBC05[Macro Attached -> " .. self.L.BTN_MAKE_MACRO .. "]|r")
            end
        end
        self.chatView:AddMessage(" ")
    end

    self.latestAssistantMsg = latestAssistantMsg
end

function ns:RefreshErrorTab()
    if not self.errorDetailBox or not self.db then return end
    local errs = self.db.errors or {}
    if #errs == 0 then
        self.errorSummaryLabel:SetText(self.L.ERR_NONE)
        self.errorDetailBox:SetText(self.L.ERR_PLACEHOLDER)
        self.selectedErrorIndex = nil
        return
    end

    if not self.selectedErrorIndex or self.selectedErrorIndex > #errs or self.selectedErrorIndex < 1 then
        self.selectedErrorIndex = #errs
    end

    local cur = errs[self.selectedErrorIndex]
    self.errorSummaryLabel:SetText(string.format(
        self.L.ERR_SUMMARY,
        self.selectedErrorIndex,
        #errs,
        tostring(cur.addon or "Unknown"),
        cur.count or 1,
        tostring(cur.lastSeen or "")
    ))

    local detail = table.concat({
        "=== Error Message ===",
        tostring(cur.message or ""),
        "",
        "=== Stack Trace ===",
        tostring(cur.stack or "(no stack trace)"),
    }, "\n")
    self.errorDetailBox:SetText(detail)
end

function ns:RefreshSnippetTab()
    if not self.snippetRows or not self.db then return end
    local snippets = self.db.snippets or {}
    for idx, row in ipairs(self.snippetRows) do
        local item = snippets[idx]
        if item then
            row.title:SetText(string.format("%d. %s", idx, item.title or "Untitled"))
            row.item = item
            row.index = idx
            row:Show()
        else
            row:Hide()
        end
    end
end

function ns:RefreshUI()
    self:RefreshChatTab()
    self:RefreshErrorTab()
    self:RefreshSnippetTab()
end

function ns:SelectTab(tabIndex)
    if not self.mainFrame then return end
    self.activeTab = tabIndex or 1
    for i, panel in ipairs(self.tabPanels) do
        if i == self.activeTab then
            panel:Show()
            ApplyBackdrop(self.tabButtons[i], COLORS.btnPrimary, COLORS.borderActive)
        else
            panel:Hide()
            ApplyBackdrop(self.tabButtons[i], COLORS.btnNormal, COLORS.border)
        end
    end
    self:RefreshUI()
end

function ns:BuildMainFrame()
    if self.mainFrame then
        return self.mainFrame
    end

    local L = self.L
    local refs = {}
    self.uiRefs = refs

    local f = CreateFrame("Frame", "AntigravityMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(760, 560)
    f:SetPoint("CENTER", 0, 20)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    ApplyBackdrop(f, COLORS.bgMain, COLORS.border)
    f:Hide()

    if UISpecialFrames then
        table.insert(UISpecialFrames, "AntigravityMainFrame")
    end

    local accentColors = {
        { 0.26, 0.52, 0.96 },
        { 0.92, 0.26, 0.21 },
        { 0.98, 0.74, 0.02 },
        { 0.20, 0.66, 0.33 },
    }
    local segWidth = 758 / 4
    for i, col in ipairs(accentColors) do
        local bar = f:CreateTexture(nil, "ARTWORK")
        bar:SetSize(segWidth, 3)
        bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1 + (i - 1) * segWidth, -1)
        bar:SetColorTexture(col[1], col[2], col[3], 1)
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("|cff4285F4Antigravity|r |cff34A853AI Guide & Studio|r  |cff9aa0a6" .. L.APP_SUBTITLE .. "|r")
    refs.headerTitle = title

    local closeBtn = CreateFlatButton(f, "X", 26, 24, COLORS.btnNormal, function()
        f:Hide()
    end)
    closeBtn:SetPoint("TOPRIGHT", -12, -10)

    local langBtn = CreateFlatButton(f, self:GetLocaleDisplayLabel(), 138, 24, COLORS.btnNormal, function()
        ns:CycleLocale()
    end)
    langBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    refs.langBtn = langBtn

    self.statusLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.statusLabel:SetPoint("RIGHT", langBtn, "LEFT", -10, 0)

    local tabNames = { L.TAB_1, L.TAB_2, L.TAB_3, L.TAB_4 }
    self.tabButtons = {}
    self.tabPanels = {}

    for i, name in ipairs(tabNames) do
        local btn = CreateFlatButton(f, name, 176, 28, COLORS.btnNormal, function()
            ns:SelectTab(i)
        end)
        btn:SetPoint("TOPLEFT", 16 + (i - 1) * 182, -44)
        self.tabButtons[i] = btn

        local panel = CreateFrame("Frame", nil, f)
        panel:SetPoint("TOPLEFT", 16, -80)
        panel:SetPoint("BOTTOMRIGHT", -16, 14)
        panel:Hide()
        self.tabPanels[i] = panel
    end

    -- ========================================================================
    -- [Tab 1] Q&A & Coding Terminal
    -- ========================================================================
    local p1 = self.tabPanels[1]

    local chatWrap = CreateFrame("Frame", nil, p1, "BackdropTemplate")
    chatWrap:SetSize(728, 240)
    chatWrap:SetPoint("TOPLEFT", 0, 0)
    ApplyBackdrop(chatWrap, COLORS.bgInput, COLORS.border)

    local chatView = CreateFrame("ScrollingMessageFrame", nil, chatWrap)
    chatView:SetPoint("TOPLEFT", 10, -10)
    chatView:SetPoint("BOTTOMRIGHT", -12, 10)
    chatView:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    chatView:SetJustifyH("LEFT")
    chatView:SetFading(false)
    chatView:SetMaxLines(400)
    chatView:EnableMouseWheel(true)
    chatView:SetHyperlinksEnabled(true)
    chatView:SetScript("OnMouseWheel", function(selfFrame, delta)
        if delta > 0 then
            selfFrame:ScrollUp()
        else
            selfFrame:ScrollDown()
        end
    end)
    chatView:SetScript("OnHyperlinkClick", function(_, link, text, button)
        if SetItemRef then
            SetItemRef(link, text, button)
        end
    end)
    self.chatView = chatView

    local actionRow = CreateFrame("Frame", nil, p1)
    actionRow:SetSize(728, 26)
    actionRow:SetPoint("TOPLEFT", chatWrap, "BOTTOMLEFT", 0, -5)

    refs.pinBtn = CreateFlatButton(actionRow, L.BTN_WAYPOINT, 92, 24, COLORS.btnPurple, function()
        local msg = ns.latestAssistantMsg
        if not msg or not msg.waypoint then
            return
        end
        ns:SetMapWaypoint(msg.waypoint)
    end)
    refs.pinBtn:SetPoint("LEFT", 0, 0)

    refs.quickRunBtn = CreateFlatButton(actionRow, L.BTN_RUN_REPLY, 96, 24, COLORS.btnGreen, function()
        local code = (ns.latestAssistantMsg and ns.latestAssistantMsg.code) or ns.latestInboxCode or ""
        if code == "" then return end
        local ok, out = ns:RunLuaSnippet(code)
        if ok then
            ns:Print("OK:\n" .. out)
        else
            ns:Print("|cffEA4335Error:|r " .. tostring(out))
        end
    end)
    refs.quickRunBtn:SetPoint("LEFT", refs.pinBtn, "RIGHT", 5, 0)

    refs.openInEditorBtn = CreateFlatButton(actionRow, L.BTN_TO_EDITOR, 80, 24, COLORS.btnNormal, function()
        local code = (ns.latestAssistantMsg and ns.latestAssistantMsg.code) or ns.latestInboxCode or ""
        if code == "" then return end
        ns.codeEditorBox:SetText(code)
        ns:SelectTab(2)
    end)
    refs.openInEditorBtn:SetPoint("LEFT", refs.quickRunBtn, "RIGHT", 5, 0)

    refs.makeMacroBtn = CreateFlatButton(actionRow, L.BTN_MAKE_MACRO, 88, 24, COLORS.btnWarn, function()
        local msg = ns.latestAssistantMsg
        if not msg or not msg.macroBody or msg.macroBody == "" then return end
        ns:CreateOrUpdateMacro(msg.macroName or "AGY_Macro", msg.macroBody, true)
    end)
    refs.makeMacroBtn:SetPoint("LEFT", refs.openInEditorBtn, "RIGHT", 5, 0)

    refs.shareAnsBtn = CreateFlatButton(actionRow, L.BTN_SHARE, 104, 24, COLORS.btnNormal, function()
        if ns.ShareLatestAnswerToGroup then
            ns:ShareLatestAnswerToGroup()
        end
    end)
    refs.shareAnsBtn:SetPoint("LEFT", refs.makeMacroBtn, "RIGHT", 5, 0)

    refs.pasteRunBtn = CreateFlatButton(actionRow, L.BTN_PASTE_CLIP, 238, 24, COLORS.btnPrimary, function()
        ns:ShowClipboardModal("paste")
    end)
    refs.pasteRunBtn:SetPoint("RIGHT", 0, 0)

    local presetRow = CreateFrame("Frame", nil, p1)
    presetRow:SetSize(728, 25)
    presetRow:SetPoint("TOPLEFT", actionRow, "BOTTOMLEFT", 0, -5)

    self.modeBtn = CreateFlatButton(presetRow, "", 168, 24, COLORS.btnNormal, function()
        local cur = ns.db.settings.requestMode or "auto"
        local nextMode = "auto"
        for idx, m in ipairs(MODE_CYCLE) do
            if m == cur then
                nextMode = MODE_CYCLE[(idx % #MODE_CYCLE) + 1]
                break
            end
        end
        ns.db.settings.requestMode = nextMode
        ns:RefreshModeButton()
    end)
    self.modeBtn:SetPoint("LEFT", 0, 0)

    refs.targetAskBtn = CreateFlatButton(presetRow, L.PRESET_TARGET, 180, 24, COLORS.btnNormal, function()
        if ns.QuickAskCurrentTarget then
            ns:QuickAskCurrentTarget()
        end
    end)
    refs.targetAskBtn:SetPoint("LEFT", self.modeBtn, "RIGHT", 6, 0)

    refs.questAskBtn = CreateFlatButton(presetRow, L.PRESET_QUEST, 175, 24, COLORS.btnNormal, function()
        ns.db.settings.requestMode = "qa"
        ns:RefreshModeButton()
        ns.promptEditBox:SetText(ns.L.PROMPT_QUEST_ASK)
        ns.promptEditBox:SetFocus()
    end)
    refs.questAskBtn:SetPoint("LEFT", refs.targetAskBtn, "RIGHT", 6, 0)

    refs.buildAskBtn = CreateFlatButton(presetRow, L.PRESET_BUILD, 187, 24, COLORS.btnNormal, function()
        ns.db.settings.requestMode = "qa"
        ns:RefreshModeButton()
        ns.promptEditBox:SetText(ns.L.PROMPT_BUILD_ASK)
        ns.promptEditBox:SetFocus()
    end)
    refs.buildAskBtn:SetPoint("LEFT", refs.questAskBtn, "RIGHT", 6, 0)

    local optRow = CreateFrame("Frame", nil, p1)
    optRow:SetSize(728, 22)
    optRow:SetPoint("TOPLEFT", presetRow, "BOTTOMLEFT", 0, -4)

    refs.cbCtx = CreateCheckToggle(optRow, L.OPT_ATTACH_CTX, self.db.settings.attachPlayerContext, function(v)
        ns.db.settings.attachPlayerContext = v
    end)
    refs.cbCtx:SetPoint("LEFT", 0, 0)

    refs.cbErr = CreateCheckToggle(optRow, L.OPT_ATTACH_ERR, self.db.settings.attachErrors, function(v)
        ns.db.settings.attachErrors = v
    end)
    refs.cbErr:SetPoint("LEFT", 245, 0)

    refs.cbMouse = CreateCheckToggle(optRow, L.OPT_ATTACH_MOUSE, self.db.settings.attachMouseover, function(v)
        ns.db.settings.attachMouseover = v
    end)
    refs.cbMouse:SetPoint("LEFT", 455, 0)

    local promptWrap = CreateScrollEditBox(p1, 728, 76, false)
    promptWrap:SetPoint("TOPLEFT", optRow, "BOTTOMLEFT", 0, -4)
    self.promptEditBox = promptWrap.editBox

    promptWrap:SetScript("OnReceiveDrag", function()
        if ns.InsertCursorItemIntoPrompt then
            ns:InsertCursorItemIntoPrompt()
        end
    end)
    promptWrap:SetScript("OnMouseDown", function()
        if not (ns.InsertCursorItemIntoPrompt and ns:InsertCursorItemIntoPrompt()) then
            promptWrap.editBox:SetFocus()
        end
    end)
    self.promptEditBox:SetScript("OnReceiveDrag", function()
        if ns.InsertCursorItemIntoPrompt then
            ns:InsertCursorItemIntoPrompt()
        end
    end)
    self.promptEditBox:SetScript("OnEnterPressed", function(selfBox)
        if IsControlKeyDown and IsControlKeyDown() then
            local txt = strtrim(selfBox:GetText() or "")
            if txt ~= "" then
                ns:ShowClipboardModal("copy", ns:BuildClipboardPacket(txt))
            end
        elseif IsAltKeyDown and IsAltKeyDown() then
            local txt = strtrim(selfBox:GetText() or "")
            if txt ~= "" then
                ns:EnqueuePrompt(txt)
                selfBox:SetText("")
                ns:SafeReloadUI()
            end
        else
            selfBox:Insert("\n")
        end
    end)

    refs.sendBtn = CreateFlatButton(p1, L.BTN_SEND_RELOAD, 205, 30, COLORS.btnPrimary, function()
        local txt = strtrim(ns.promptEditBox:GetText() or "")
        if txt ~= "" then
            ns:EnqueuePrompt(txt)
            ns.promptEditBox:SetText("")
        end
        ns:SafeReloadUI()
    end)
    refs.sendBtn:SetPoint("BOTTOMLEFT", 0, 0)

    refs.queueOnlyBtn = CreateFlatButton(p1, L.BTN_QUEUE_ONLY, 190, 30, COLORS.btnNormal, function()
        local txt = strtrim(ns.promptEditBox:GetText() or "")
        if txt == "" then
            ns:Print(ns.L.MSG_EMPTY_PROMPT)
            return
        end
        ns:EnqueuePrompt(txt)
        ns.promptEditBox:SetText("")
        ns:Print(ns.L.MSG_QUEUED)
    end)
    refs.queueOnlyBtn:SetPoint("LEFT", refs.sendBtn, "RIGHT", 8, 0)

    refs.clipCopyBtn = CreateFlatButton(p1, L.BTN_COPY_CLIP, 230, 30, COLORS.btnGreen, function()
        local txt = strtrim(ns.promptEditBox:GetText() or "")
        if txt == "" then
            ns:Print(ns.L.MSG_EMPTY_PROMPT)
            return
        end
        local packet = ns:BuildClipboardPacket(txt)
        ns:ShowClipboardModal("copy", packet)
    end)
    refs.clipCopyBtn:SetPoint("LEFT", refs.queueOnlyBtn, "RIGHT", 8, 0)

    refs.clearChatBtn = CreateFlatButton(p1, L.BTN_CLEAR_CHAT, 79, 30, COLORS.btnNormal, function()
        ns.db.history = {}
        ns:RefreshChatTab()
    end)
    refs.clearChatBtn:SetPoint("BOTTOMRIGHT", 0, 0)

    -- ========================================================================
    -- [Tab 2] Live Lua Studio
    -- ========================================================================
    local p2 = self.tabPanels[2]

    refs.editorHeader = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    refs.editorHeader:SetPoint("TOPLEFT", 0, -2)
    refs.editorHeader:SetText(L.EDITOR_HEADER)

    local editorWrap = CreateScrollEditBox(p2, 728, 250, false)
    editorWrap:SetPoint("TOPLEFT", 0, -22)
    self.codeEditorBox = editorWrap.editBox
    if self.InboxPayload and self.InboxPayload.messages and self.InboxPayload.messages[1] then
        self.codeEditorBox:SetText(self.InboxPayload.messages[1].code or "")
    end
    self.codeEditorBox:SetScript("OnEnterPressed", function(selfBox)
        if IsControlKeyDown and IsControlKeyDown() then
            local ok, output = ns:RunLuaSnippet(selfBox:GetText())
            if ok then
                ns.codeOutputBox:SetText("|cff34A853[OK]|r\n" .. output)
            else
                ns.codeOutputBox:SetText("|cffEA4335" .. tostring(output) .. "|r")
            end
        else
            selfBox:Insert("\n")
        end
    end)

    local editorBtnRow = CreateFrame("Frame", nil, p2)
    editorBtnRow:SetSize(728, 28)
    editorBtnRow:SetPoint("TOPLEFT", editorWrap, "BOTTOMLEFT", 0, -6)

    refs.runCodeBtn = CreateFlatButton(editorBtnRow, L.BTN_RUN_LUA, 165, 28, COLORS.btnGreen, function()
        local code = ns.codeEditorBox:GetText()
        local ok, output = ns:RunLuaSnippet(code)
        if ok then
            ns.codeOutputBox:SetText("|cff34A853[OK]|r\n" .. output)
        else
            ns.codeOutputBox:SetText("|cffEA4335" .. tostring(output) .. "|r")
        end
    end)
    refs.runCodeBtn:SetPoint("LEFT", 0, 0)

    refs.saveSnippetBtn = CreateFlatButton(editorBtnRow, L.BTN_SAVE_SNIPPET, 145, 28, COLORS.btnPrimary, function()
        local code = strtrim(ns.codeEditorBox:GetText() or "")
        if code == "" then return end
        local firstLine = code:match("^%-%-%s*(.-)\r?\n") or code:sub(1, 28):gsub("\n", " ")
        table.insert(ns.db.snippets, {
            title = firstLine ~= "" and firstLine or ("Snippet #" .. (#ns.db.snippets + 1)),
            code = code,
        })
        ns:TrimTable(ns.db.snippets, 20)
        ns:RefreshSnippetTab()
    end)
    refs.saveSnippetBtn:SetPoint("LEFT", refs.runCodeBtn, "RIGHT", 8, 0)

    refs.toMacroBtn = CreateFlatButton(editorBtnRow, L.BTN_RUN_MACRO, 145, 28, COLORS.btnWarn, function()
        local code = strtrim(ns.codeEditorBox:GetText() or "")
        if code == "" then return end
        local oneLine = code:gsub("%-%-[^\n]*", ""):gsub("%s+", " ")
        ns:CreateOrUpdateMacro("AGY_Run", "/run " .. oneLine, true)
    end)
    refs.toMacroBtn:SetPoint("LEFT", refs.saveSnippetBtn, "RIGHT", 8, 0)

    refs.askRefactorBtn = CreateFlatButton(editorBtnRow, L.BTN_ASK_REFACTOR, 240, 28, COLORS.btnNormal, function()
        local code = strtrim(ns.codeEditorBox:GetText() or "")
        if code == "" then return end
        ns.db.settings.requestMode = "code"
        ns.promptEditBox:SetText(string.format(ns.L.PROMPT_REFACTOR, code))
        ns:SelectTab(1)
        ns.promptEditBox:SetFocus()
    end)
    refs.askRefactorBtn:SetPoint("RIGHT", 0, 0)

    refs.outLabel = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    refs.outLabel:SetPoint("TOPLEFT", editorBtnRow, "BOTTOMLEFT", 0, -8)
    refs.outLabel:SetText(L.OUTPUT_LABEL)

    local outWrap = CreateScrollEditBox(p2, 728, 130, true)
    outWrap:SetPoint("TOPLEFT", refs.outLabel, "BOTTOMLEFT", 0, -4)
    self.codeOutputBox = outWrap.editBox
    self.codeOutputBox:SetText(L.OUTPUT_PLACEHOLDER)

    -- ========================================================================
    -- [Tab 3] Error Debugger
    -- ========================================================================
    local p3 = self.tabPanels[3]

    self.errorSummaryLabel = p3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.errorSummaryLabel:SetPoint("TOPLEFT", 0, -4)

    refs.prevErrBtn = CreateFlatButton(p3, L.BTN_PREV_ERR, 95, 24, COLORS.btnNormal, function()
        if not ns.db or #ns.db.errors == 0 then return end
        ns.selectedErrorIndex = math.max(1, (ns.selectedErrorIndex or #ns.db.errors) - 1)
        ns:RefreshErrorTab()
    end)
    refs.prevErrBtn:SetPoint("TOPRIGHT", -210, 0)

    refs.nextErrBtn = CreateFlatButton(p3, L.BTN_NEXT_ERR, 95, 24, COLORS.btnNormal, function()
        if not ns.db or #ns.db.errors == 0 then return end
        ns.selectedErrorIndex = math.min(#ns.db.errors, (ns.selectedErrorIndex or 1) + 1)
        ns:RefreshErrorTab()
    end)
    refs.nextErrBtn:SetPoint("LEFT", refs.prevErrBtn, "RIGHT", 6, 0)

    refs.testErrBtn = CreateFlatButton(p3, L.BTN_TEST_ERR, 104, 24, COLORS.btnWarn, function()
        ns:RecordLuaError(
            "Interface/AddOns/SampleLegacyAddon/Core.lua:18: attempt to call global 'GetSpellInfo' (a nil value)",
            "Interface/AddOns/SampleLegacyAddon/Core.lua:18: in function 'UpdateAuraBar'\nInterface/AddOns/SampleLegacyAddon/Core.lua:45: in function <...SampleLegacyAddon/Core.lua:42>"
        )
        ns:RefreshErrorTab()
    end)
    refs.testErrBtn:SetPoint("TOPRIGHT", 0, 0)

    local errDetailWrap = CreateScrollEditBox(p3, 728, 380, true)
    errDetailWrap:SetPoint("TOPLEFT", 0, -34)
    self.errorDetailBox = errDetailWrap.editBox

    refs.askFixBtn = CreateFlatButton(p3, L.BTN_ASK_FIX_ERR, 370, 30, COLORS.btnPrimary, function()
        local errs = ns.db and ns.db.errors or {}
        local cur = errs[ns.selectedErrorIndex or #errs]
        if not cur then return end
        ns.db.settings.requestMode = "code"
        local prompt = string.format(ns.L.PROMPT_FIX_ERR, tostring(cur.addon), tostring(cur.message), tostring(cur.stack or ""))
        ns.promptEditBox:SetText(prompt)
        ns:SelectTab(1)
        ns.promptEditBox:SetFocus()
    end)
    refs.askFixBtn:SetPoint("BOTTOMLEFT", 0, 0)

    refs.clearErrBtn = CreateFlatButton(p3, L.BTN_CLEAR_ERR, 160, 30, COLORS.btnNormal, function()
        ns:ClearErrors()
    end)
    refs.clearErrBtn:SetPoint("BOTTOMRIGHT", 0, 0)

    -- ========================================================================
    -- [Tab 4] Snippets & Official Blizzard Tools
    -- ========================================================================
    local p4 = self.tabPanels[4]

    refs.toolsTitle = p4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    refs.toolsTitle:SetPoint("TOPLEFT", 0, -2)
    refs.toolsTitle:SetText(L.TOOLS_HEADER)

    refs.apiBtn = CreateFlatButton(p4, L.BTN_OPEN_API, 165, 28, COLORS.btnPrimary, function()
        if SlashCmdList["APIDOCUMENTATION"] then
            SlashCmdList["APIDOCUMENTATION"]("")
        elseif UIParentLoadAddOn then
            pcall(UIParentLoadAddOn, "Blizzard_APIDocumentation")
            if APIDocumentation and APIDocumentation.Toggle then
                APIDocumentation:Toggle()
            end
        end
    end)
    refs.apiBtn:SetPoint("TOPLEFT", 0, -26)

    refs.fstackBtn = CreateFlatButton(p4, L.BTN_OPEN_FSTACK, 175, 28, COLORS.btnNormal, function()
        if SlashCmdList["FRAMESTACK"] then
            SlashCmdList["FRAMESTACK"]("")
        end
    end)
    refs.fstackBtn:SetPoint("LEFT", refs.apiBtn, "RIGHT", 8, 0)

    refs.etraceBtn = CreateFlatButton(p4, L.BTN_OPEN_ETRACE, 185, 28, COLORS.btnNormal, function()
        if SlashCmdList["EVENTTRACE"] then
            SlashCmdList["EVENTTRACE"]("")
        end
    end)
    refs.etraceBtn:SetPoint("LEFT", refs.fstackBtn, "RIGHT", 8, 0)

    refs.reloadBtn = CreateFlatButton(p4, L.BTN_RELOAD_UI, 175, 28, COLORS.btnWarn, function()
        ns:SafeReloadUI()
    end)
    refs.reloadBtn:SetPoint("LEFT", refs.etraceBtn, "RIGHT", 8, 0)

    refs.snipTitle = p4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    refs.snipTitle:SetPoint("TOPLEFT", 0, -72)
    refs.snipTitle:SetText(L.SNIPPETS_HEADER)

    self.snippetRows = {}
    for i = 1, 8 do
        local row = CreateFrame("Frame", nil, p4, "BackdropTemplate")
        row:SetSize(728, 36)
        row:SetPoint("TOPLEFT", 0, -96 - (i - 1) * 40)
        ApplyBackdrop(row, COLORS.bgPanel, COLORS.border)

        row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.title:SetPoint("LEFT", 12, 0)
        row.title:SetWidth(430)
        row.title:SetJustifyH("LEFT")

        row.loadBtn = CreateFlatButton(row, L.BTN_LOAD_SNIPPET, 125, 24, COLORS.btnPrimary, function()
            if row.item then
                ns.codeEditorBox:SetText(row.item.code or "")
                ns:SelectTab(2)
            end
        end)
        row.loadBtn:SetPoint("RIGHT", -156, 0)

        row.execBtn = CreateFlatButton(row, L.BTN_EXEC_SNIPPET, 90, 24, COLORS.btnGreen, function()
            if row.item then
                local ok, out = ns:RunLuaSnippet(row.item.code or "")
                if ok then
                    ns:Print(string.format("[%s] OK: %s", tostring(row.item.title), out))
                else
                    ns:Print("|cffEA4335Error:|r " .. tostring(out))
                end
            end
        end)
        row.execBtn:SetPoint("RIGHT", -60, 0)

        row.delBtn = CreateFlatButton(row, L.BTN_DEL_SNIPPET, 46, 24, COLORS.btnNormal, function()
            if row.index and ns.db and ns.db.snippets[row.index] then
                table.remove(ns.db.snippets, row.index)
                ns:RefreshSnippetTab()
            end
        end)
        row.delBtn:SetPoint("RIGHT", -8, 0)

        self.snippetRows[i] = row
    end

    self.mainFrame = f
    self:SelectTab(1)
    return f
end

function ns:ToggleMainFrame(forceShow, tabIndex)
    local f = self:BuildMainFrame()
    if forceShow == true then
        f:Show()
        if tabIndex then
            self:SelectTab(tabIndex)
        else
            self:RefreshUI()
        end
        return
    elseif forceShow == false then
        f:Hide()
        return
    end

    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        if tabIndex then
            self:SelectTab(tabIndex)
        else
            self:RefreshUI()
        end
    end
end
