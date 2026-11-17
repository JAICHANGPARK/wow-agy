local addonName, ns = ...

-- ============================================================================
-- MinimapButton.lua
-- Draggable minimap launcher button + Blizzard Official Addon Compartment hooks
-- ============================================================================

local function UpdateButtonPosition(btn, angleDeg)
    local rad = math.rad(angleDeg or 215)
    local radius = 80
    local x = math.cos(rad) * radius
    local y = math.sin(rad) * radius
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function PopulateTooltip(ownerFrame)
    if not GameTooltip then return end
    GameTooltip:SetOwner(ownerFrame, "ANCHOR_LEFT")
    local ver = ns.GetAddonMeta and ns:GetAddonMeta("Version", ns.VERSION) or "2026.11.17"
    local author = ns.GetAddonMeta and ns:GetAddonMeta("Author", ns.DEFAULT_AUTHOR) or "JAICHANGPARK (Dreamwalker)"
    GameTooltip:AddLine(string.format("|cff4285F4wow-agy|r |cff34A853v%s|r", ver))
    GameTooltip:AddLine("By " .. author, 1.0, 0.82, 0.0)
    GameTooltip:AddLine(ns.L.MINIMAP_TIP_LCLICK, 0.85, 0.85, 0.85)
    GameTooltip:AddLine(ns.L.MINIMAP_TIP_RCLICK, 0.85, 0.85, 0.85)
    GameTooltip:AddLine(ns.L.MINIMAP_TIP_SCLICK, 0.85, 0.85, 0.85)
    GameTooltip:AddLine(ns.L.MINIMAP_TIP_DRAG, 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

-- Official Blizzard Addon Compartment callbacks (declared in WoWAGY.toc)
function WoWAGY_OnAddonCompartmentClick(_, mouseButton)
    if IsShiftKeyDown and IsShiftKeyDown() then
        ns:SafeReloadUI()
    elseif mouseButton == "RightButton" then
        ns:ToggleMainFrame(true, 2)
    else
        ns:ToggleMainFrame()
    end
end

function WoWAGY_OnAddonCompartmentEnter(_, menuButtonFrame)
    if menuButtonFrame then
        PopulateTooltip(menuButtonFrame)
    end
end

function WoWAGY_OnAddonCompartmentLeave()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

function ns:UpdateMinimapBadge()
    if not self.minimapBtn or not self.db then return end
    local errCount = #(self.db.errors or {})
    local pendingCount = 0
    for _, req in ipairs(self.db.outbox or {}) do
        if req.status == "pending" then
            pendingCount = pendingCount + 1
        end
    end

    if errCount > 0 then
        self.minimapBtn.badge:SetText("|cffEA4335" .. tostring(errCount) .. "|r")
        self.minimapBtn.badgeBg:Show()
    elseif pendingCount > 0 then
        self.minimapBtn.badge:SetText("|cffFBBC05" .. tostring(pendingCount) .. "|r")
        self.minimapBtn.badgeBg:Show()
    else
        self.minimapBtn.badge:SetText("")
        self.minimapBtn.badgeBg:Hide()
    end
end

function ns:InitMinimapButton()
    if self.minimapBtn or not Minimap then
        return
    end
    if self.db and self.db.settings.hideMinimap then
        return
    end

    local btn = CreateFrame("Button", "WoWAGYMinimapButton", Minimap, "BackdropTemplate")
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(0.08, 0.12, 0.20, 0.95)
    btn:SetBackdropBorderColor(0.26, 0.52, 0.96, 1)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", 0, 0)
    label:SetText("|cff4285F4AGY|r")

    local badgeBg = btn:CreateTexture(nil, "OVERLAY")
    badgeBg:SetSize(14, 14)
    badgeBg:SetPoint("TOPRIGHT", 3, 3)
    badgeBg:SetColorTexture(0.05, 0.05, 0.08, 0.95)
    badgeBg:Hide()
    btn.badgeBg = badgeBg

    local badge = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badge:SetPoint("CENTER", badgeBg, "CENTER", 0, 0)
    btn.badge = badge

    btn:SetScript("OnDragStart", function(selfBtn)
        selfBtn:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            ns.db.settings.minimapAngle = angle
            UpdateButtonPosition(selfBtn, angle)
        end)
    end)

    btn:SetScript("OnDragStop", function(selfBtn)
        selfBtn:SetScript("OnUpdate", nil)
    end)

    btn:SetScript("OnClick", function(_, mouseBtn)
        WoWAGY_OnAddonCompartmentClick(nil, mouseBtn)
    end)

    btn:SetScript("OnEnter", function(selfBtn)
        PopulateTooltip(selfBtn)
    end)
    btn:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    UpdateButtonPosition(btn, (self.db and self.db.settings.minimapAngle) or 215)
    self.minimapBtn = btn
    self:UpdateMinimapBadge()
end
