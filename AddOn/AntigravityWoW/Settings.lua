local addonName, ns = ...

-- ============================================================================
-- Settings.lua
-- WoW Forever (Interface: 16001) 공식 ESC -> 설정 -> 애드온 패널 등록
-- (구형 InterfaceOptions_AddCategory 대신 최신 Settings API 사용)
-- ============================================================================

function ns:InitSettingsCategory()
    if self._settingsRegistered then
        return
    end
    if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then
        return
    end
    self._settingsRegistered = true

    local panel = CreateFrame("Frame", "AntigravityWoWSettingsPanel", UIParent)
    panel.name = "Antigravity AI"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff4285F4Antigravity|r |cff34A853AI Guide & Code Studio|r (WoW Forever 16001)")

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    sub:SetWidth(560)
    sub:SetJustifyH("LEFT")
    sub:SetText("인게임에서 와우 퀘스트·공략·아이템 질문(Q&A)과 Antigravity Lua 애드온 코딩·디버깅을 함께 수행합니다.")

    local function MakeCheckbox(yOffset, label, getter, setter)
        local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, yOffset)
        local txt = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        txt:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        txt:SetText(label)
        cb:SetScript("OnShow", function(selfBtn)
            selfBtn:SetChecked(getter() and true or false)
        end)
        cb:SetScript("OnClick", function(selfBtn)
            setter(selfBtn:GetChecked() and true or false)
        end)
        return cb
    end

    MakeCheckbox(-70, "질문/코딩 요청 시 내 캐릭터·장비·타겟·퀘스트 상태 자동 첨부", function()
        return ns.db and ns.db.settings.attachPlayerContext
    end, function(v)
        if ns.db then ns.db.settings.attachPlayerContext = v end
    end)

    MakeCheckbox(-104, "코딩 모드에서 최근 캡처된 Lua 에러 자동 첨부", function()
        return ns.db and ns.db.settings.attachErrors
    end, function(v)
        if ns.db then ns.db.settings.attachErrors = v end
    end)

    MakeCheckbox(-138, "새 AI 응답 수신 후 로그인/리로드 시 자동으로 스튜디오 창 열기", function()
        return ns.db and ns.db.settings.autoOpenOnNewReply
    end, function(v)
        if ns.db then ns.db.settings.autoOpenOnNewReply = v end
    end)

    MakeCheckbox(-172, "미니맵 런처 아이콘 숨기기", function()
        return ns.db and ns.db.settings.hideMinimap
    end, function(v)
        if not ns.db then return end
        ns.db.settings.hideMinimap = v
        if v and ns.minimapBtn then
            ns.minimapBtn:Hide()
        elseif not v then
            if ns.minimapBtn then
                ns.minimapBtn:Show()
            elseif ns.InitMinimapButton then
                ns:InitMinimapButton()
            end
        end
    end)

    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(200, 28)
    openBtn:SetPoint("TOPLEFT", 16, -220)
    openBtn:SetText("Antigravity 스튜디오 열기 (/agy)")
    openBtn:SetScript("OnClick", function()
        if ns.ToggleMainFrame then
            ns:ToggleMainFrame(true, 1)
        end
    end)

    local resetPosBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetPosBtn:SetSize(180, 28)
    resetPosBtn:SetPoint("LEFT", openBtn, "RIGHT", 12, 0)
    resetPosBtn:SetText("창 위치 화면 중앙 초기화")
    resetPosBtn:SetScript("OnClick", function()
        if ns.mainFrame then
            ns.mainFrame:ClearAllPoints()
            ns.mainFrame:SetPoint("CENTER", 0, 20)
        end
        ns:Print("메인 창 위치를 화면 중앙으로 초기화했습니다.")
    end)

    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name)
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
        self.settingsCategory = category
    end
end
