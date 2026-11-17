local addonName, ns = ...

-- ============================================================================
-- UI.lua
-- Antigravity AI Guide & Code Studio (WoW Forever 16001 호환)
-- 4개 탭: [1] 질문(Q&A) & 코딩  [2] Live Lua 에디터  [3] 에러 디버거  [4] 스니펫 & 공식 툴
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
local MODE_LABELS = {
    auto = "모드: |cffFBBC05자동 (질문+코딩)|r",
    qa   = "모드: |cff34A853와우 Q&A 공략|r",
    code = "모드: |cff4285F4Lua 코딩|r",
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

-- 클립보드 브릿지 팝업 창 (무-리로드 질문 복사 / 답변 대화창 표시 / 코드 즉시 실행)
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

        m.showChatBtn = CreateFlatButton(m, "대화창에 답변 표시 (무-리로드)", 200, 28, COLORS.btnPrimary, function()
            local raw = m.boxWrap.editBox:GetText()
            if ns:IngestClipboardReply(raw) then
                m:Hide()
                ns:ToggleMainFrame(true, 1)
                ns:Print("클립보드 답변을 대화창에 표시했습니다!")
            else
                ns:Print("붙여넣을 답변 내용이 비어 있습니다.")
            end
        end)
        m.showChatBtn:SetPoint("BOTTOMLEFT", 14, 14)

        m.runBtn = CreateFlatButton(m, "▶ Lua 코드 즉시 실행", 155, 28, COLORS.btnGreen, function()
            local raw = m.boxWrap.editBox:GetText()
            local luaCode = ns:ExtractLuaFromClipboard(raw)
            if luaCode == "" then
                ns:Print("실행할 Lua 코드가 없습니다.")
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
            if ok then
                ns:Print("클립보드 Lua 코드 실행 완료!")
            else
                ns:Print("|cffEA4335실행 오류:|r " .. tostring(out))
            end
        end)
        m.runBtn:SetPoint("LEFT", m.showChatBtn, "RIGHT", 8, 0)

        m.toEditorBtn = CreateFlatButton(m, "에디터로 열기", 105, 28, COLORS.btnNormal, function()
            local raw = m.boxWrap.editBox:GetText()
            local luaCode = ns:ExtractLuaFromClipboard(raw)
            if ns.codeEditorBox then
                ns.codeEditorBox:SetText(luaCode)
            end
            m:Hide()
            ns:ToggleMainFrame(true, 2)
        end)
        m.toEditorBtn:SetPoint("LEFT", m.runBtn, "RIGHT", 8, 0)

        m.closeBtn = CreateFlatButton(m, "닫기", 70, 28, COLORS.btnNormal, function()
            m:Hide()
        end)
        m.closeBtn:SetPoint("BOTTOMRIGHT", -14, 14)

        self.clipModal = m
    end

    local m = self.clipModal
    if mode == "copy" then
        m.title:SetText("|cff4285F4클립보드 브릿지 — 질문/코딩 패킷 복사 (무-리로드)|r")
        m.hint:SetText("아래 패킷이 전체 선택되었습니다. |cffFBBC05Ctrl+C (Mac은 Cmd+C)|r 를 누르면 백그라운드 데몬이 답변을 클립보드로 즉시 돌려줍니다!")
        m.boxWrap.editBox:SetText(initialText or "")
        m:Show()
        m.boxWrap.editBox:SetFocus()
        m.boxWrap.editBox:HighlightText()
    else
        m.title:SetText("|cff34A853클립보드 브릿지 — Antigravity 답변/코드 붙여넣기 (무-리로드)|r")
        m.hint:SetText("|cffFBBC05Ctrl+V (Cmd+V)|r 로 붙여넣은 뒤, 와우 질문 답변은 [대화창에 답변 표시]를, Lua 코드는 [▶ Lua 코드 즉시 실행]을 누르세요.")
        m.boxWrap.editBox:SetText("")
        m:Show()
        m.boxWrap.editBox:SetFocus()
    end
end

function ns:RefreshModeButton()
    if not self.modeBtn or not self.db then return end
    local cur = self.db.settings.requestMode or "auto"
    self.modeBtn.label:SetText(MODE_LABELS[cur] or MODE_LABELS.auto)
end

-- 터미널 대화창 새로고침
function ns:RefreshChatTab()
    if not self.chatView or not self.db then return end
    self.chatView:Clear()
    self:RefreshModeButton()

    local pendingCount = 0
    for _, req in ipairs(self.db.outbox) do
        if req.status == "pending" then
            pendingCount = pendingCount + 1
        end
    end

    if self.statusLabel then
        local errCount = #(self.db.errors or {})
        self.statusLabel:SetText(string.format(
            "TOC: |cff34A85316001|r  |  대기 질문: |cffFBBC05%d건|r  |  에러: |cffEA4335%d건|r",
            pendingCount,
            errCount
        ))
    end

    local latestAssistantMsg = nil
    for _, msg in ipairs(self.db.history) do
        local ts = msg.timestamp and ("|cff7f8c8d[" .. msg.timestamp .. "]|r ") or ""
        if msg.role == "user" then
            self.chatView:AddMessage(ts .. "|cffFBBC05[나]|r " .. tostring(msg.content or ""))
        else
            latestAssistantMsg = msg
            -- 여러 줄 응답을 줄 단위로 추가해 가독성과 스크롤이 자연스럽게 동작하도록 처리
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
                    "  |cffFFD100📍 안내 좌표: %s (%.1f, %.1f) — 아래 [📍 답변 좌표 핀 찍기] 클릭!|r",
                    tostring(msg.waypoint.label or "추천 위치"),
                    tonumber(msg.waypoint.x) or 0,
                    tonumber(msg.waypoint.y) or 0
                ))
            end
            if msg.filesChanged and #msg.filesChanged > 0 then
                self.chatView:AddMessage("  |cff34A853수정된 파일:|r " .. table.concat(msg.filesChanged, ", "))
            end
            if msg.code and msg.code ~= "" then
                self.chatView:AddMessage("  |cff4285F4[첨부된 Lua 스니펫 있음 — 아래 버튼으로 즉시 실행 가능]|r")
            end
            if msg.macroBody and msg.macroBody ~= "" then
                self.chatView:AddMessage("  |cffFBBC05[첨부된 매크로 있음 — 아래 '매크로 생성' 클릭 시 액션바 배치 가능]|r")
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
        self.errorSummaryLabel:SetText("|cff34A853현재 캡처된 런타임 Lua 에러가 없습니다.|r")
        self.errorDetailBox:SetText("-- 다른 애드온이나 스크립트에서 Lua 에러가 발생하면 이곳에 스택 트레이스가 자동 기록됩니다.\n-- 우측 상단 [테스트 에러 발생] 버튼으로 동작을 확인해 볼 수 있습니다.")
        self.selectedErrorIndex = nil
        return
    end

    if not self.selectedErrorIndex or self.selectedErrorIndex > #errs or self.selectedErrorIndex < 1 then
        self.selectedErrorIndex = #errs
    end

    local cur = errs[self.selectedErrorIndex]
    self.errorSummaryLabel:SetText(string.format(
        "에러 |cffFBBC05%d / %d|r  |  추정 애드온: |cffEA4335%s|r  |  발생 횟수: %d회  (%s)",
        self.selectedErrorIndex,
        #errs,
        tostring(cur.addon or "Unknown"),
        cur.count or 1,
        tostring(cur.lastSeen or "")
    ))

    local detail = table.concat({
        "=== 에러 메시지 ===",
        tostring(cur.message or ""),
        "",
        "=== 스택 트레이스 (Stack Trace) ===",
        tostring(cur.stack or "(스택 정보 없음)"),
    }, "\n")
    self.errorDetailBox:SetText(detail)
end

function ns:RefreshSnippetTab()
    if not self.snippetRows or not self.db then return end
    local snippets = self.db.snippets or {}
    for idx, row in ipairs(self.snippetRows) do
        local item = snippets[idx]
        if item then
            row.title:SetText(string.format("%d. %s", idx, item.title or "제목 없음"))
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
    title:SetText("|cff4285F4Antigravity|r |cff34A853AI Guide & Studio|r  |cff9aa0a6(WoW Forever)|r")

    self.statusLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.statusLabel:SetPoint("TOPRIGHT", -48, -17)

    local closeBtn = CreateFlatButton(f, "X", 26, 24, COLORS.btnNormal, function()
        f:Hide()
    end)
    closeBtn:SetPoint("TOPRIGHT", -12, -10)

    local tabNames = {
        "1. 질문(Q&A) & 코딩",
        "2. Live Lua 에디터",
        "3. 에러 디버거",
        "4. 스니펫 & 공식 툴",
    }
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
    -- [탭 1] 와우 질문(Q&A) & Antigravity 코딩 터미널
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

    -- 응답 액션 바 (좌표 핀 / 스니펫 실행 / 에디터 / 매크로 / 파티·복사 공유 / 클립보드 붙여넣기)
    local actionRow = CreateFrame("Frame", nil, p1)
    actionRow:SetSize(728, 26)
    actionRow:SetPoint("TOPLEFT", chatWrap, "BOTTOMLEFT", 0, -5)

    local pinBtn = CreateFlatButton(actionRow, "📍 좌표 핀", 92, 24, COLORS.btnPurple, function()
        local msg = ns.latestAssistantMsg
        if not msg or not msg.waypoint then
            ns:Print("최근 답변에 포함된 지도 좌표가 없습니다.")
            return
        end
        ns:SetMapWaypoint(msg.waypoint)
    end)
    pinBtn:SetPoint("LEFT", 0, 0)

    local quickRunBtn = CreateFlatButton(actionRow, "▶ 코드 실행", 96, 24, COLORS.btnGreen, function()
        local code = (ns.latestAssistantMsg and ns.latestAssistantMsg.code) or ns.latestInboxCode or ""
        if code == "" then
            ns:Print("실행할 응답 코드가 없습니다.")
            return
        end
        local ok, out = ns:RunLuaSnippet(code)
        if ok then
            ns:Print("응답 스니펫 실행 성공!\n" .. out)
        else
            ns:Print("|cffEA4335실행 실패:|r " .. tostring(out))
        end
    end)
    quickRunBtn:SetPoint("LEFT", pinBtn, "RIGHT", 5, 0)

    local openInEditorBtn = CreateFlatButton(actionRow, "에디터로", 80, 24, COLORS.btnNormal, function()
        local code = (ns.latestAssistantMsg and ns.latestAssistantMsg.code) or ns.latestInboxCode or ""
        if code == "" then
            ns:Print("최근 응답에 첨부된 Lua 스니펫이 없습니다.")
            return
        end
        ns.codeEditorBox:SetText(code)
        ns:SelectTab(2)
    end)
    openInEditorBtn:SetPoint("LEFT", quickRunBtn, "RIGHT", 5, 0)

    local makeMacroBtn = CreateFlatButton(actionRow, "매크로 생성", 88, 24, COLORS.btnWarn, function()
        local msg = ns.latestAssistantMsg
        if not msg or not msg.macroBody or msg.macroBody == "" then
            ns:Print("최근 응답에 첨부된 매크로가 없습니다.")
            return
        end
        ns:CreateOrUpdateMacro(msg.macroName or "AGY_Macro", msg.macroBody, true)
    end)
    makeMacroBtn:SetPoint("LEFT", openInEditorBtn, "RIGHT", 5, 0)

    local shareAnsBtn = CreateFlatButton(actionRow, "답변 공유/복사", 104, 24, COLORS.btnNormal, function()
        if ns.ShareLatestAnswerToGroup then
            ns:ShareLatestAnswerToGroup()
        end
    end)
    shareAnsBtn:SetPoint("LEFT", makeMacroBtn, "RIGHT", 5, 0)

    local pasteRunBtn = CreateFlatButton(actionRow, "클립보드 답변/코드 붙여넣기", 238, 24, COLORS.btnPrimary, function()
        ns:ShowClipboardModal("paste")
    end)
    pasteRunBtn:SetPoint("RIGHT", 0, 0)

    -- 빠른 와우 질문 프리셋 & 모드 토글 행
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

    local targetAskBtn = CreateFlatButton(presetRow, "🎯 현재 타겟 공략·드랍 질문", 180, 24, COLORS.btnNormal, function()
        if ns.QuickAskCurrentTarget then
            ns:QuickAskCurrentTarget()
        end
    end)
    targetAskBtn:SetPoint("LEFT", self.modeBtn, "RIGHT", 6, 0)

    local questAskBtn = CreateFlatButton(presetRow, "📜 진행 중 퀘스트 길찾기", 175, 24, COLORS.btnNormal, function()
        ns.db.settings.requestMode = "qa"
        ns:RefreshModeButton()
        ns.promptEditBox:SetText("내 현재 진행 중인 퀘스트 목록과 목표를 보고, 가장 효율적인 동선과 목표 위치(좌표)를 알려줘!")
        ns.promptEditBox:SetFocus()
    end)
    questAskBtn:SetPoint("LEFT", targetAskBtn, "RIGHT", 6, 0)

    local buildAskBtn = CreateFlatButton(presetRow, "⚔️ 내 직업·레벨 육성 팁", 187, 24, COLORS.btnNormal, function()
        ns.db.settings.requestMode = "qa"
        ns:RefreshModeButton()
        ns.promptEditBox:SetText("와우 포에버 기준으로 내 현재 직업과 레벨 구간에서 추천하는 특성/스킬 운영법과 꼭 챙겨야 할 핵심 장비(던전/퀘스트 보상)를 추천해줘!")
        ns.promptEditBox:SetFocus()
    end)
    buildAskBtn:SetPoint("LEFT", questAskBtn, "RIGHT", 6, 0)

    -- 컨텍스트 체크박스 행
    local optRow = CreateFrame("Frame", nil, p1)
    optRow:SetSize(728, 22)
    optRow:SetPoint("TOPLEFT", presetRow, "BOTTOMLEFT", 0, -4)

    local cbCtx = CreateCheckToggle(optRow, "캐릭터·타겟·퀘스트 상태 첨부", self.db.settings.attachPlayerContext, function(v)
        ns.db.settings.attachPlayerContext = v
    end)
    cbCtx:SetPoint("LEFT", 0, 0)

    local cbErr = CreateCheckToggle(optRow, "Lua 에러 첨부(코딩 시)", self.db.settings.attachErrors, function(v)
        ns.db.settings.attachErrors = v
    end)
    cbErr:SetPoint("LEFT", 230, 0)

    local cbMouse = CreateCheckToggle(optRow, "마우스오버 UI 프레임 첨부", self.db.settings.attachMouseover, function(v)
        ns.db.settings.attachMouseover = v
    end)
    cbMouse:SetPoint("LEFT", 415, 0)

    -- 프롬프트 멀티라인 입력창 (Shift+클릭, 아이템/스킬 드래그 앤 드롭, Ctrl+Enter 빠른 전송 지원)
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

    -- 바닥 전송 버튼 행
    local sendBtn = CreateFlatButton(p1, "전송 / 답변 동기화 (/reload)", 205, 30, COLORS.btnPrimary, function()
        local txt = strtrim(ns.promptEditBox:GetText() or "")
        if txt ~= "" then
            ns:EnqueuePrompt(txt)
            ns.promptEditBox:SetText("")
        end
        ns:SafeReloadUI()
    end)
    sendBtn:SetPoint("BOTTOMLEFT", 0, 0)

    local queueOnlyBtn = CreateFlatButton(p1, "큐에만 추가 (나중에 리로드)", 190, 30, COLORS.btnNormal, function()
        local txt = strtrim(ns.promptEditBox:GetText() or "")
        if txt == "" then
            ns:Print("질문 또는 코딩 내용을 먼저 입력해 주세요.")
            return
        end
        ns:EnqueuePrompt(txt)
        ns.promptEditBox:SetText("")
        ns:Print("요청이 큐에 저장되었습니다. 원할 때 /reload 하면 로컬 Antigravity 데몬이 답변을 가져옵니다.")
    end)
    queueOnlyBtn:SetPoint("LEFT", sendBtn, "RIGHT", 8, 0)

    local clipCopyBtn = CreateFlatButton(p1, "클립보드 질문/요청 복사 (무-리로드)", 230, 30, COLORS.btnGreen, function()
        local txt = strtrim(ns.promptEditBox:GetText() or "")
        if txt == "" then
            ns:Print("클립보드로 물어볼 질문이나 요청을 입력해 주세요.")
            return
        end
        local packet = ns:BuildClipboardPacket(txt)
        ns:ShowClipboardModal("copy", packet)
    end)
    clipCopyBtn:SetPoint("LEFT", queueOnlyBtn, "RIGHT", 8, 0)

    local clearChatBtn = CreateFlatButton(p1, "기록 비우기", 84, 30, COLORS.btnNormal, function()
        ns.db.history = {}
        ns:RefreshChatTab()
    end)
    clearChatBtn:SetPoint("BOTTOMRIGHT", 0, 0)

    -- ========================================================================
    -- [탭 2] Live Lua 에디터
    -- ========================================================================
    local p2 = self.tabPanels[2]

    local editorHeader = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    editorHeader:SetPoint("TOPLEFT", 0, -2)
    editorHeader:SetText("|cff4285F4Live Lua Studio|r — WoW Forever (16001) API를 리로드 없이 실시간 테스트하세요. (print 출력 자동 캡처)")

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
                ns.codeOutputBox:SetText("|cff34A853[실행 성공]|r\n" .. output)
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

    local runCodeBtn = CreateFlatButton(editorBtnRow, "▶ 즉시 실행 (Run Lua)", 165, 28, COLORS.btnGreen, function()
        local code = ns.codeEditorBox:GetText()
        local ok, output = ns:RunLuaSnippet(code)
        if ok then
            ns.codeOutputBox:SetText("|cff34A853[실행 성공]|r\n" .. output)
        else
            ns.codeOutputBox:SetText("|cffEA4335" .. tostring(output) .. "|r")
        end
    end)
    runCodeBtn:SetPoint("LEFT", 0, 0)

    local saveSnippetBtn = CreateFlatButton(editorBtnRow, "스니펫 목록에 저장", 145, 28, COLORS.btnPrimary, function()
        local code = strtrim(ns.codeEditorBox:GetText() or "")
        if code == "" then
            ns:Print("저장할 코드가 비어 있습니다.")
            return
        end
        local firstLine = code:match("^%-%-%s*(.-)\r?\n") or code:sub(1, 28):gsub("\n", " ")
        table.insert(ns.db.snippets, {
            title = firstLine ~= "" and firstLine or ("스니펫 #" .. (#ns.db.snippets + 1)),
            code = code,
        })
        ns:TrimTable(ns.db.snippets, 20)
        ns:RefreshSnippetTab()
        ns:Print("스니펫이 저장되었습니다!")
    end)
    saveSnippetBtn:SetPoint("LEFT", runCodeBtn, "RIGHT", 8, 0)

    local toMacroBtn = CreateFlatButton(editorBtnRow, "/run 매크로로 생성", 145, 28, COLORS.btnWarn, function()
        local code = strtrim(ns.codeEditorBox:GetText() or "")
        if code == "" then return end
        local oneLine = code:gsub("%-%-[^\n]*", ""):gsub("%s+", " ")
        ns:CreateOrUpdateMacro("AGY_Run", "/run " .. oneLine, true)
    end)
    toMacroBtn:SetPoint("LEFT", saveSnippetBtn, "RIGHT", 8, 0)

    local askRefactorBtn = CreateFlatButton(editorBtnRow, "이 코드 AGY에게 개선/애드온화 요청", 240, 28, COLORS.btnNormal, function()
        local code = strtrim(ns.codeEditorBox:GetText() or "")
        if code == "" then return end
        ns.db.settings.requestMode = "code"
        local reqPrompt = "아래 WoW Forever (16001) Lua 코드를 검토해서 개선하거나 독립 애드온 파일로 만들어줘:\n```lua\n" .. code .. "\n```"
        ns.promptEditBox:SetText(reqPrompt)
        ns:SelectTab(1)
        ns.promptEditBox:SetFocus()
    end)
    askRefactorBtn:SetPoint("RIGHT", 0, 0)

    local outLabel = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    outLabel:SetPoint("TOPLEFT", editorBtnRow, "BOTTOMLEFT", 0, -8)
    outLabel:SetText("실행 결과 콘솔:")

    local outWrap = CreateScrollEditBox(p2, 728, 130, true)
    outWrap:SetPoint("TOPLEFT", outLabel, "BOTTOMLEFT", 0, -4)
    self.codeOutputBox = outWrap.editBox
    self.codeOutputBox:SetText("-- [▶ 즉시 실행] 버튼을 누르면 print() 출력과 실행 시간이 이곳에 표시됩니다.")

    -- ========================================================================
    -- [탭 3] 에러 디버거
    -- ========================================================================
    local p3 = self.tabPanels[3]

    self.errorSummaryLabel = p3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.errorSummaryLabel:SetPoint("TOPLEFT", 0, -4)

    local prevErrBtn = CreateFlatButton(p3, "◀ 이전 에러", 95, 24, COLORS.btnNormal, function()
        if not ns.db or #ns.db.errors == 0 then return end
        ns.selectedErrorIndex = math.max(1, (ns.selectedErrorIndex or #ns.db.errors) - 1)
        ns:RefreshErrorTab()
    end)
    prevErrBtn:SetPoint("TOPRIGHT", -210, 0)

    local nextErrBtn = CreateFlatButton(p3, "다음 에러 ▶", 95, 24, COLORS.btnNormal, function()
        if not ns.db or #ns.db.errors == 0 then return end
        ns.selectedErrorIndex = math.min(#ns.db.errors, (ns.selectedErrorIndex or 1) + 1)
        ns:RefreshErrorTab()
    end)
    nextErrBtn:SetPoint("LEFT", prevErrBtn, "RIGHT", 6, 0)

    local testErrBtn = CreateFlatButton(p3, "테스트 에러 발생", 104, 24, COLORS.btnWarn, function()
        ns:RecordLuaError(
            "Interface/AddOns/SampleLegacyAddon/Core.lua:18: attempt to call global 'GetSpellInfo' (a nil value)",
            "Interface/AddOns/SampleLegacyAddon/Core.lua:18: in function 'UpdateAuraBar'\nInterface/AddOns/SampleLegacyAddon/Core.lua:45: in function <...SampleLegacyAddon/Core.lua:42>"
        )
        ns:RefreshErrorTab()
        ns:Print("샘플 Forever 16001 호환성 에러(GetSpellInfo nil)를 캡처 목록에 추가했습니다.")
    end)
    testErrBtn:SetPoint("TOPRIGHT", 0, 0)

    local errDetailWrap = CreateScrollEditBox(p3, 728, 380, true)
    errDetailWrap:SetPoint("TOPLEFT", 0, -34)
    self.errorDetailBox = errDetailWrap.editBox

    local askFixBtn = CreateFlatButton(p3, "선택한 에러 Antigravity에게 원인 분석 & 자동 수정 요청", 360, 30, COLORS.btnPrimary, function()
        local errs = ns.db and ns.db.errors or {}
        local cur = errs[ns.selectedErrorIndex or #errs]
        if not cur then
            ns:Print("선택된 Lua 에러가 없습니다.")
            return
        end
        ns.db.settings.requestMode = "code"
        local prompt = table.concat({
            string.format("인게임에서 [%s] 애드온 관련 Lua 에러가 발생했어. WoW Forever (Interface: 16001) API 규격에 맞게 원인을 찾고 해당 파일을 수정해줘:", tostring(cur.addon)),
            "에러: " .. tostring(cur.message),
            "스택:\n" .. tostring(cur.stack or ""),
        }, "\n")
        ns.promptEditBox:SetText(prompt)
        ns:SelectTab(1)
        ns.promptEditBox:SetFocus()
    end)
    askFixBtn:SetPoint("BOTTOMLEFT", 0, 0)

    local clearErrBtn = CreateFlatButton(p3, "에러 기록 모두 지우기", 160, 30, COLORS.btnNormal, function()
        ns:ClearErrors()
    end)
    clearErrBtn:SetPoint("BOTTOMRIGHT", 0, 0)

    -- ========================================================================
    -- [탭 4] 스니펫 & 공식 개발 툴
    -- ========================================================================
    local p4 = self.tabPanels[4]

    local toolsTitle = p4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toolsTitle:SetPoint("TOPLEFT", 0, -2)
    toolsTitle:SetText("블리자드 공식 인게임 개발자 도구 바로가기 (WoW Forever 16001)")

    local apiBtn = CreateFlatButton(p4, "/api 공식 문서 열기", 165, 28, COLORS.btnPrimary, function()
        if SlashCmdList["APIDOCUMENTATION"] then
            SlashCmdList["APIDOCUMENTATION"]("")
        elseif UIParentLoadAddOn then
            pcall(UIParentLoadAddOn, "Blizzard_APIDocumentation")
            if APIDocumentation and APIDocumentation.Toggle then
                APIDocumentation:Toggle()
            else
                ns:Print("채팅창에 |cffFBBC05/api|r 를 입력해 공식 API 브라우저를 여세요.")
            end
        end
    end)
    apiBtn:SetPoint("TOPLEFT", 0, -26)

    local fstackBtn = CreateFlatButton(p4, "/fstack 프레임 인스펙터", 175, 28, COLORS.btnNormal, function()
        if SlashCmdList["FRAMESTACK"] then
            SlashCmdList["FRAMESTACK"]("")
        else
            ns:Print("채팅창에 |cffFBBC05/fstack|r 을 입력해 프레임 인스펙터를 토글하세요.")
        end
    end)
    fstackBtn:SetPoint("LEFT", apiBtn, "RIGHT", 8, 0)

    local etraceBtn = CreateFlatButton(p4, "/etrace 실시간 이벤트 추적", 185, 28, COLORS.btnNormal, function()
        if SlashCmdList["EVENTTRACE"] then
            SlashCmdList["EVENTTRACE"]("")
        else
            ns:Print("채팅창에 |cffFBBC05/etrace|r 를 입력해 이벤트 트레이서를 여세요.")
        end
    end)
    etraceBtn:SetPoint("LEFT", fstackBtn, "RIGHT", 8, 0)

    local reloadBtn = CreateFlatButton(p4, "UI 새로고침 (/reload)", 175, 28, COLORS.btnWarn, function()
        ns:SafeReloadUI()
    end)
    reloadBtn:SetPoint("LEFT", etraceBtn, "RIGHT", 8, 0)

    local snipTitle = p4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    snipTitle:SetPoint("TOPLEFT", 0, -72)
    snipTitle:SetText("저장된 Lua 스니펫 라이브러리 (최대 8개 표시)")

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

        local loadBtn = CreateFlatButton(row, "에디터로 불러오기", 125, 24, COLORS.btnPrimary, function()
            if row.item then
                ns.codeEditorBox:SetText(row.item.code or "")
                ns:SelectTab(2)
            end
        end)
        loadBtn:SetPoint("RIGHT", -156, 0)

        local execBtn = CreateFlatButton(row, "▶ 바로 실행", 90, 24, COLORS.btnGreen, function()
            if row.item then
                local ok, out = ns:RunLuaSnippet(row.item.code or "")
                if ok then
                    ns:Print(string.format("[%s] 실행 완료: %s", tostring(row.item.title), out))
                else
                    ns:Print("|cffEA4335실행 오류:|r " .. tostring(out))
                end
            end
        end)
        execBtn:SetPoint("RIGHT", -60, 0)

        local delBtn = CreateFlatButton(row, "삭제", 46, 24, COLORS.btnNormal, function()
            if row.index and ns.db and ns.db.snippets[row.index] then
                table.remove(ns.db.snippets, row.index)
                ns:RefreshSnippetTab()
            end
        end)
        delBtn:SetPoint("RIGHT", -8, 0)

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
