local addonName, ns = ...

-- ============================================================================
-- Settings.lua
-- WoW Forever (Interface: 16001) ESC -> Options -> AddOns Panel (Multilingual)
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
    sub:SetText(self.L.SETTINGS_DESC)

    local function MakeCheckbox(yOffset, labelKey, getter, setter)
        local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, yOffset)
        local txt = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        txt:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cb:SetScript("OnShow", function(selfBtn)
            txt:SetText(ns.L[labelKey])
            selfBtn:SetChecked(getter() and true or false)
        end)
        txt:SetText(ns.L[labelKey])
        cb:SetScript("OnClick", function(selfBtn)
            setter(selfBtn:GetChecked() and true or false)
        end)
        return cb
    end

    MakeCheckbox(-70, "OPT_ATTACH_CTX", function()
        return ns.db and ns.db.settings.attachPlayerContext
    end, function(v)
        if ns.db then ns.db.settings.attachPlayerContext = v end
    end)

    MakeCheckbox(-104, "OPT_ATTACH_ERR", function()
        return ns.db and ns.db.settings.attachErrors
    end, function(v)
        if ns.db then ns.db.settings.attachErrors = v end
    end)

    MakeCheckbox(-138, "SETTINGS_AUTO_OPEN", function()
        return ns.db and ns.db.settings.autoOpenOnNewReply
    end, function(v)
        if ns.db then ns.db.settings.autoOpenOnNewReply = v end
    end)

    MakeCheckbox(-172, "SETTINGS_HIDE_MINI", function()
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

    local langBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    langBtn:SetSize(220, 28)
    langBtn:SetPoint("TOPLEFT", 16, -220)
    langBtn:SetText(self:GetLocaleDisplayLabel())
    langBtn:SetScript("OnShow", function(selfBtn)
        selfBtn:SetText(ns:GetLocaleDisplayLabel())
    end)
    langBtn:SetScript("OnClick", function(selfBtn)
        ns:CycleLocale()
        selfBtn:SetText(ns:GetLocaleDisplayLabel())
        sub:SetText(ns.L.SETTINGS_DESC)
    end)

    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(220, 28)
    openBtn:SetPoint("TOPLEFT", 16, -260)
    openBtn:SetText(self.L.SETTINGS_OPEN_BTN)
    openBtn:SetScript("OnClick", function()
        if ns.ToggleMainFrame then
            ns:ToggleMainFrame(true, 1)
        end
    end)

    local resetPosBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetPosBtn:SetSize(190, 28)
    resetPosBtn:SetPoint("LEFT", openBtn, "RIGHT", 12, 0)
    resetPosBtn:SetText(self.L.SETTINGS_RESET_POS)
    resetPosBtn:SetScript("OnClick", function()
        if ns.mainFrame then
            ns.mainFrame:ClearAllPoints()
            ns.mainFrame:SetPoint("CENTER", 0, 20)
        end
    end)

    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name)
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
        self.settingsCategory = category
    end
end
