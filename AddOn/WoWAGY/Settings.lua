local addonName, ns = ...

-- ============================================================================
-- Settings.lua
-- WoW Forever (Interface: 16001) ESC -> Options -> AddOns -> wow-agy Panel
-- Displays options + TOC Metadata (Version, Author, License, GitHub URL)
-- ============================================================================

function ns:InitSettingsCategory()
    if self._settingsRegistered then
        return
    end
    if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then
        return
    end
    self._settingsRegistered = true

    local panel = CreateFrame("Frame", "WoWAGYSettingsPanel", UIParent)
    panel.name = "wow-agy"

    local ver = self:GetAddonMeta("Version", self.VERSION)
    local author = self:GetAddonMeta("Author", self.DEFAULT_AUTHOR)
    local githubUrl = self:GetAddonMeta("X-Website", self.DEFAULT_GITHUB)
    local licenseName = self:GetAddonMeta("X-License", self.DEFAULT_LICENSE)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(string.format("|cff4285F4wow-agy|r |cff34A853AI Guide & Studio|r  |cff9aa0a6v%s|r", ver))

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

    MakeCheckbox(-68, "OPT_ATTACH_CTX", function()
        return ns.db and ns.db.settings.attachPlayerContext
    end, function(v)
        if ns.db then ns.db.settings.attachPlayerContext = v end
    end)

    MakeCheckbox(-102, "OPT_ATTACH_ERR", function()
        return ns.db and ns.db.settings.attachErrors
    end, function(v)
        if ns.db then ns.db.settings.attachErrors = v end
    end)

    MakeCheckbox(-136, "SETTINGS_AUTO_OPEN", function()
        return ns.db and ns.db.settings.autoOpenOnNewReply
    end, function(v)
        if ns.db then ns.db.settings.autoOpenOnNewReply = v end
    end)

    MakeCheckbox(-170, "SETTINGS_HIDE_MINI", function()
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
    langBtn:SetPoint("TOPLEFT", 16, -216)
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
    openBtn:SetPoint("TOPLEFT", 16, -254)
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

    -- Addon Information / Credits Section (Read dynamically from WoWAGY.toc)
    local infoTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    infoTitle:SetPoint("TOPLEFT", 16, -308)
    infoTitle:SetText("Addon Info & Credits")

    local infoBody = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    infoBody:SetPoint("TOPLEFT", infoTitle, "BOTTOMLEFT", 0, -8)
    infoBody:SetJustifyH("LEFT")
    infoBody:SetText(table.concat({
        string.format("• Addon: |cff4285F4wow-agy|r (Folder: %s)  |  Version: |cff34A853%s|r  |  Interface: 16001", self.ADDON_NAME, ver),
        string.format("• Author: |cffFFD100%s|r  |  License: %s", author, licenseName),
        string.format("• GitHub: |cff67D8EF%s|r", githubUrl),
    }, "\n"))

    local copyUrlBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    copyUrlBtn:SetSize(200, 26)
    copyUrlBtn:SetPoint("TOPLEFT", infoBody, "BOTTOMLEFT", 0, -10)
    copyUrlBtn:SetText("Copy GitHub URL")
    copyUrlBtn:SetScript("OnClick", function()
        if ns.ShowClipboardModal then
            ns:ShowClipboardModal("copy", githubUrl)
        else
            ns:Print(githubUrl)
        end
    end)

    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name)
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
        self.settingsCategory = category
    end
end
