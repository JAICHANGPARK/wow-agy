local addonName, ns = ...

-- ============================================================================
-- MinimapButton.lua
-- 드래그 가능한 미니맵 런처 버튼 + 대기 요청 / 캡처 에러 배지 표시
-- ============================================================================

local function UpdateButtonPosition(btn, angleDeg)
    local rad = math.rad(angleDeg or 215)
    local radius = 80
    local x = math.cos(rad) * radius
    local y = math.sin(rad) * radius
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
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

    local btn = CreateFrame("Button", "AntigravityMinimapButton", Minimap, "BackdropTemplate")
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
        if IsShiftKeyDown and IsShiftKeyDown() then
            ns:SafeReloadUI()
        elseif mouseBtn == "RightButton" then
            ns:ToggleMainFrame(true, 2)
        else
            ns:ToggleMainFrame()
        end
    end)

    btn:SetScript("OnEnter", function(selfBtn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(selfBtn, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff4285F4Antigravity Code Studio|r (Forever 16001)")
        GameTooltip:AddLine("|cffFFFFFF좌클릭:|r 터미널 창 열기/닫기", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffFFFFFF우클릭:|r Live Lua 에디터 열기", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffFFFFFFShift+클릭:|r 동기화 (/reload)", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffFFFFFF드래그:|r 미니맵 아이콘 위치 이동", 0.8, 0.8, 0.8)
        GameTooltip:Show()
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
