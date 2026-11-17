local addonName, ns = ...

-- ============================================================================
-- Context.lua
-- WoW Forever (Interface: 16001) 호환 플레이어/장착장비/전문기술/타겟/퀘스트/프레임 수집기
-- 및 아이템/주문/퀘스트 Shift+클릭 + 드래그 앤 드롭 프롬프트 입력 연동
-- ============================================================================

local EQUIP_SLOT_NAMES = {
    [1] = "머리", [2] = "목", [3] = "어깨", [5] = "가슴",
    [6] = "허리", [7] = "다리", [8] = "발", [9] = "손목",
    [10] = "손", [11] = "반지1", [12] = "반지2", [13] = "장신구1",
    [14] = "장신구2", [15] = "망토", [16] = "주장비", [17] = "보조장비", [18] = "원거리",
}

local function SafeGetMapCoords()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then
        return nil, nil, nil
    end
    local okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not okMap or not mapID then
        return nil, nil, nil
    end
    local okPos, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not okPos or not pos or not pos.GetXY then
        return mapID, nil, nil
    end
    local x, y = pos:GetXY()
    if x and y then
        return mapID, math.floor(x * 10000) / 100, math.floor(y * 10000) / 100
    end
    return mapID, nil, nil
end

-- 장착 중인 장비 목록 수집 (아이템 추천·비교 질문 시 활용)
local function SafeGetEquippedItems()
    local items = {}
    if not GetInventoryItemLink then
        return items
    end
    for slotId = 1, 18 do
        local slotLabel = EQUIP_SLOT_NAMES[slotId]
        if slotLabel then
            local ok, link = pcall(GetInventoryItemLink, "player", slotId)
            if ok and type(link) == "string" and link ~= "" then
                local itemId = tonumber(link:match("item:(%d+)")) or 0
                local itemName = link:match("%[(.-)%]") or link
                table.insert(items, {
                    slot = slotLabel,
                    itemID = itemId,
                    name = itemName,
                })
            end
        end
    end
    return items
end

-- 배운 전문기술 및 현재 숙련도 수집
local function SafeGetProfessions()
    local profs = {}
    if GetProfessions and GetProfessionInfo then
        local ok, p1, p2, arch, fish, cook = pcall(GetProfessions)
        if ok then
            local indices = { p1, p2, cook, fish, arch }
            for _, idx in ipairs(indices) do
                if idx then
                    local okInfo, name, _, skillLevel, maxSkillLevel = pcall(GetProfessionInfo, idx)
                    if okInfo and name then
                        table.insert(profs, {
                            name = tostring(name),
                            rank = tonumber(skillLevel) or 0,
                            maxRank = tonumber(maxSkillLevel) or 0,
                        })
                    end
                end
            end
        end
    end
    return profs
end

-- 현재 선택 중인 타겟(NPC/몬스터/플레이어) 정보 안전 수집
local function SafeGetTargetInfo()
    if not UnitExists then
        return nil
    end
    local okExists, exists = pcall(UnitExists, "target")
    if not okExists or not exists then
        return nil
    end

    local info = {
        name = "Unknown",
        level = 0,
        classification = "normal",
        creatureType = "",
        npcID = 0,
    }

    pcall(function()
        info.name = tostring(UnitName("target") or "Unknown")
    end)
    pcall(function()
        info.level = tonumber(UnitLevel("target")) or -1
    end)
    if UnitClassification then
        pcall(function()
            info.classification = tostring(UnitClassification("target") or "normal")
        end)
    end
    if UnitCreatureType then
        pcall(function()
            info.creatureType = tostring(UnitCreatureType("target") or "")
        end)
    end
    if UnitGUID then
        pcall(function()
            local guid = UnitGUID("target")
            if type(guid) == "string" then
                local unitType, _, _, _, _, npcIdStr = strsplit("-", guid)
                if (unitType == "Creature" or unitType == "Vehicle") and npcIdStr then
                    info.npcID = tonumber(npcIdStr) or 0
                end
            end
        end)
    end

    return info
end

local function SafeGetTrackedQuests()
    local quests = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local ok, numEntries = pcall(C_QuestLog.GetNumQuestLogEntries)
        if ok and type(numEntries) == "number" then
            for i = 1, math.min(numEntries, 40) do
                local okInfo, info = pcall(C_QuestLog.GetInfo, i)
                if okInfo and info and not info.isHeader and info.questID then
                    local objectivesText = {}
                    if C_QuestLog.GetQuestObjectives then
                        local okObj, objs = pcall(C_QuestLog.GetQuestObjectives, info.questID)
                        if okObj and type(objs) == "table" then
                            for _, obj in ipairs(objs) do
                                if obj and obj.text then
                                    table.insert(objectivesText, tostring(obj.text))
                                end
                            end
                        end
                    end

                    table.insert(quests, {
                        questID = info.questID,
                        title = info.title or "",
                        level = info.difficultyLevel or info.level or 0,
                        isComplete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID) or false,
                        objectives = objectivesText,
                    })
                    if #quests >= 10 then
                        break
                    end
                end
            end
        end
    end
    return quests
end

function ns:InspectMouseoverFrame()
    local frame = nil
    if GetMouseFoci then
        local ok, foci = pcall(GetMouseFoci)
        if ok and type(foci) == "table" and foci[1] then
            frame = foci[1]
        end
    elseif GetMouseFocus then
        local ok, f = pcall(GetMouseFocus)
        if ok then
            frame = f
        end
    end

    if not frame or frame == WorldFrame then
        return nil
    end

    local info = {
        name = (frame.GetName and frame:GetName()) or "(익명 프레임)",
        objectType = (frame.GetObjectType and frame:GetObjectType()) or "Unknown",
        parent = (frame.GetParent and frame:GetParent() and frame:GetParent().GetName and frame:GetParent():GetName()) or "nil",
    }

    local okSize, w, h = pcall(function()
        return frame:GetWidth(), frame:GetHeight()
    end)
    if okSize and w and h then
        info.width = math.floor(w + 0.5)
        info.height = math.floor(h + 0.5)
    end

    return info
end

function ns:CollectContext(includeMouseover)
    local version, build, buildDate, tocVersion = "unknown", "0", "", 0
    if GetBuildInfo then
        version, build, buildDate, tocVersion = GetBuildInfo()
    end

    local localizedClass, englishClass = "", ""
    if UnitClass then
        localizedClass, englishClass = UnitClass("player")
    end

    local localizedRace, englishRace = "", ""
    if UnitRace then
        localizedRace, englishRace = UnitRace("player")
    end

    local mapID, coordX, coordY = SafeGetMapCoords()

    local ctx = {
        capturedAt = self:FormatTimestamp(),
        client = {
            version = tostring(version or ""),
            build = tostring(build or ""),
            buildDate = tostring(buildDate or ""),
            tocVersion = tonumber(tocVersion) or 0,
            gameLocale = (GetLocale and GetLocale()) or "enUS",
            uiLocale = (self.GetEffectiveLocale and self:GetEffectiveLocale()) or "enUS",
            hasCSpell = (C_Spell and C_Spell.GetSpellInfo ~= nil) or false,
            hasCUnitAuras = (C_UnitAuras ~= nil) or false,
        },
        player = {
            name = (UnitName and UnitName("player")) or "Unknown",
            realm = (GetRealmName and GetRealmName()) or "",
            level = (UnitLevel and UnitLevel("player")) or 0,
            className = localizedClass or "",
            classTag = englishClass or "",
            race = localizedRace or englishRace or "",
            moneyCopper = (GetMoney and GetMoney()) or 0,
            inCombat = (InCombatLockdown and InCombatLockdown()) or false,
        },
        location = {
            zone = (GetRealZoneText and GetRealZoneText()) or "",
            subZone = (GetSubZoneText and GetSubZoneText()) or "",
            mapID = mapID or 0,
            x = coordX or 0,
            y = coordY or 0,
        },
        equippedItems = SafeGetEquippedItems(),
        professions = SafeGetProfessions(),
        target = SafeGetTargetInfo(),
        quests = SafeGetTrackedQuests(),
    }

    if includeMouseover then
        ctx.mouseoverFrame = self:InspectMouseoverFrame()
    end

    return ctx
end

function ns:AppendLinkToPrompt(link)
    if not link or link == "" then return false end
    local box = self.promptEditBox
    if box and box:IsVisible() and box:HasFocus() then
        if self._lastInsertedLink == link and self._lastInsertedAt == (GetTime and GetTime() or -1) then
            return true
        end
        self._lastInsertedLink = link
        self._lastInsertedAt = GetTime and GetTime() or 0
        local itemOrSpellId = link:match("(%a+:%d+)") or ""
        if itemOrSpellId ~= "" then
            box:Insert(" " .. link .. " [" .. itemOrSpellId .. "] ")
        else
            box:Insert(" " .. link .. " ")
        end
        return true
    end
    return false
end

-- 커서에 집은 아이템/주문을 프롬프트 입력창에 드래그 앤 드롭으로 첨부
function ns:InsertCursorItemIntoPrompt()
    if not GetCursorInfo or not self.promptEditBox then
        return false
    end
    local infoType, idOrIndex, subType, extraId = GetCursorInfo()
    if not infoType then
        return false
    end

    if infoType == "item" then
        local link = subType -- item인 경우 3번째 반환값이 itemLink
        if type(link) == "string" and link ~= "" then
            self.promptEditBox:SetFocus()
            self:AppendLinkToPrompt(link)
        else
            self.promptEditBox:Insert(string.format(" [item:%s] ", tostring(idOrIndex)))
        end
        if ClearCursor then ClearCursor() end
        return true
    elseif infoType == "spell" then
        local spellID = extraId or idOrIndex
        local spellName = ""
        if C_Spell and C_Spell.GetSpellInfo and spellID then
            local sInfo = C_Spell.GetSpellInfo(spellID)
            spellName = (sInfo and sInfo.name) or ""
        end
        self.promptEditBox:SetFocus()
        self.promptEditBox:Insert(string.format(" %s[spell:%s] ", spellName ~= "" and (spellName .. " ") or "", tostring(spellID)))
        if ClearCursor then ClearCursor() end
        return true
    end
    return false
end

-- Shift+클릭(가방·장비창·상점·전리품·주문서·퀘스트 링크) 시 프롬프트 창 자동 삽입
function ns:InitHyperlinkHook()
    if self._hyperlinkHooked then
        return
    end
    self._hyperlinkHooked = true

    if ChatEdit_InsertLink then
        hooksecurefunc("ChatEdit_InsertLink", function(link)
            ns:AppendLinkToPrompt(link)
        end)
    end
    if HandleModifiedItemClick then
        hooksecurefunc("HandleModifiedItemClick", function(link)
            if IsShiftKeyDown and IsShiftKeyDown() then
                ns:AppendLinkToPrompt(link)
                if StackSplitFrame and StackSplitFrame:IsShown() and ns.promptEditBox and ns.promptEditBox:HasFocus() then
                    StackSplitFrame:Hide()
                end
            end
        end)
    end
end
