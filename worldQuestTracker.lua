-- /dump C_Map.GetBestMapForUnit("player")
local WORLD_QUEST_ZONES = {
    [2214] = "The Ringing Deeps",
    [2215] = "Hallowfall",
    [2248] = "Isle of Dorn",
    [2339] = "Dornogal",
    [2255] = "Azj-Kahet",
    [2346] = "Undermine",
    [2369] = "Siren Isle",
    [2371] = "K'aresh"
}

local function createBadge(point)
    local badge = CreateFrame("Frame", "MyWorldQuestBadge", QuestLogMicroButton)
    badge:SetSize(20, 20)
    badge:SetFrameStrata("MEDIUM")
    badge:SetFrameLevel(QuestLogMicroButton:GetFrameLevel() + 10)
    badge:SetPoint(point, QuestLogMicroButton, "TOP", 0, 6)

    badge.bg = badge:CreateTexture(nil, "BACKGROUND")
    badge.bg:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask") 
    badge.bg:SetAllPoints(badge)
    badge.bg:SetVertexColor(0, 0, 0)

    badge.border = badge:CreateTexture(nil, "OVERLAY")
    badge.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    badge.border:SetSize(42, 42)
    badge.border:SetPoint("CENTER", badge, "CENTER", 8, -8)
    badge.border:SetVertexColor(1, 0.8, 0, 0.6)

    badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)
    badge.text:SetText("*")

    return badge
end

local f = CreateFrame("Frame")

f.worldQuestBadge = createBadge("TOP")

local function UpdateWorldQuestBadge(count)
    if count and count > 0 then
        f.worldQuestBadge.text:SetText(tostring(count))
        f.worldQuestBadge:Show()
    else
        f.worldQuestBadge:Hide()
    end
end

local function RefreshWorldQuestsPanel()
    if QuestMapFrame.WorldQuestsPanel and QuestMapFrame.WorldQuestsPanel:IsShown() then
        QuestMapFrame.WorldQuestsPanel:RefreshList()
    end
end

local function GetTotalGoldFromQuest(questID)
    local totalMoney = 0

    C_TaskQuest.RequestPreloadRewardData(questID)

    local moneyReward = GetQuestLogRewardMoney(questID)
    if moneyReward and moneyReward > 0 then
        --print("  moneyReward: "..moneyReward)
        totalMoney = totalMoney + moneyReward
    end

    local currencies = C_QuestLog.GetQuestRewardCurrencies(questID)
    if currencies then
        for _, currency in ipairs(currencies) do
            --print("  currency ID: "..currency.currencyID.." name: "..currency.name.." amount: "..currency.totalRewardAmount)
            if currency.currencyID == 0 or currency.name == "Gold" then
                totalMoney = totalMoney + (currency.totalRewardAmount or 0)
            end
        end
    end

    return math.floor((tonumber(totalMoney) / 10000)) * 10000
end

local QUEST_SCAN_RATE = 5 * 60
local FOUND_WORLD_QUESTS = {}
local MAPS_TO_SCAN = {}

local function ProcessQuests()
    local count = 0

    for mapID, zoneName in pairs(MAPS_TO_SCAN) do
        local quests = C_TaskQuest.GetQuestsOnMap(mapID)

        if quests then
            for _, qInfo in ipairs(quests) do
                local questID = qInfo.questID or qInfo.questId or nil

                if questID and not FOUND_WORLD_QUESTS[questID] then
                    local questTagInfo = C_QuestLog.GetQuestTagInfo(questID)

                    if questTagInfo and not C_QuestLog.IsComplete(questID) then
                        --print("Evaluating quest "..id.."/"..qInfo.mapID.."/"..C_QuestLog.GetTitleForQuestID(questID))
                        local goldAmount = GetTotalGoldFromQuest(questID) or 0
                        
                        -- only quests that reward more than 500 gold
                        if goldAmount > (500 * 10000) then
                            local quest = {
                                ID = questID,
                                name = C_QuestLog.GetTitleForQuestID(questID) or "Unknown Quest",
                                amount = goldAmount,
                                tagInfo = questTagInfo,
                                mapID = qInfo.mapID,
                                zoneID = id,
                                zoneName = zoneName
                            }
                            FOUND_WORLD_QUESTS[quest.ID] = quest
                            --print("Found quest "..quest.zoneID.."/"..quest.mapID.."/"..quest.name.." = "..GetMoneyString(quest.amount, true))
                            count = count + 1
                        end
                    end
                end
            end
        end
    end

    --print("|cFFADD8E6Finished scanning found "..tostring(count).." gold world quests")

    UpdateWorldQuestBadge(count)

    RefreshWorldQuestsPanel()

    C_Timer.After(QUEST_SCAN_RATE, ScanForGoldQuests)
end

local function RefreshQuestRewards()
    for mapID, zoneName in pairs(MAPS_TO_SCAN) do
        local quests = C_TaskQuest.GetQuestsOnMap(mapID)

        if quests then
            for _, qInfo in ipairs(quests) do
                local questID = qInfo.questID or qInfo.questId or nil
                if questID then
                    C_TaskQuest.RequestPreloadRewardData(questID)
                end
            end
        end
    end

    C_Timer.After(1, ProcessQuests)
end

local function DrillThroughMaps(mapInfo)
    if mapInfo and mapInfo.parentMapID and mapInfo.parentMapID > 0 then
        MAPS_TO_SCAN[mapInfo.parentMapID] = mapInfo.name

        local parentMapInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
        -- This is the "secret sauce" - requesting the ArtID often forces a data sync
        local _ = C_Map.GetMapArtID(mapInfo.parentMapID)

        DrillThroughMaps(parentMapInfo)
    end
end

local function RefreshMaps()
    for mapID, zoneName in pairs(WORLD_QUEST_ZONES) do
        MAPS_TO_SCAN[mapID] = zoneName

        local mapInfo = C_Map.GetMapInfo(mapID)
        -- This is the "secret sauce" - requesting the ArtID often forces a data sync
        local _ = C_Map.GetMapArtID(mapID)

        DrillThroughMaps(mapInfo)
    end

    C_Timer.After(1, RefreshQuestRewards)
end

function ScanForGoldQuests()
    if UnitAffectingCombat("player") or IsInInstance() then
        C_Timer.After(QUEST_SCAN_RATE, ScanForGoldQuests)
        return
    end

    FOUND_WORLD_QUESTS = {}

    -- RefreshMaps() -> 1s -> RefreshQuestRewards() -> 1s -> ProcessQuests
    RefreshMaps()
end

f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("QUEST_TURNED_IN")
f:RegisterEvent("QUEST_REMOVED")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(10, ScanForGoldQuests)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    elseif event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED" then
        local questID = ...

        if FOUND_WORLD_QUESTS and FOUND_WORLD_QUESTS[questID] then
            FOUND_WORLD_QUESTS[questID] = nil

            -- print("|cFF00FF00[GoldScanner]:|r Quest " .. questID .. " completed. Removing from list.")

            RefreshWorldQuestsPanel()

            local newCount = 0
            for _ in pairs(FOUND_WORLD_QUESTS) do newCount = newCount + 1 end
            UpdateWorldQuestBadge(newCount)
        end
    end
end)

QuestLogMicroButton:HookScript("OnEnter", function(self)
    if GameTooltip:IsOwned(self) then
        local totalGold = 0
        for qID, data in pairs(FOUND_WORLD_QUESTS) do
            totalGold = totalGold + data.amount
        end
        GameTooltip:AddLine("\nTotal Gold available: " .. GetMoneyString(totalGold, true), 1, 1, 1, true)

        GameTooltip:Show()
    end
end)



WorldQuestTabMixin = {}

function WorldQuestTabMixin:OnLoad()
    self.SelectedTexture:Hide()
    self.Icon:SetAtlas(self.activeAtlas)
    self.Icon:SetSize(24, 24)
    self.Icon:Show()
    self.tooltipText = "Gold Quests"
end

function WorldQuestTabMixin:OnClick()
    QuestMapFrame.WorldQuestsPanel:RefreshList()

    QuestMapFrame:SetDisplayMode(self.displayMode)
end



local function FormatQuestTime(totalMinutes)
    if not totalMinutes or totalMinutes <= 0 then 
        return "|cffff0000Expired|r" 
    end

    local days = math.floor(totalMinutes / 1440)
    local remainingMinutes = totalMinutes % 1440
    local hours = math.floor(remainingMinutes / 60)
    local minutes = remainingMinutes % 60

    if days > 0 then
        return string.format("|cFFFFD100%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("|cffff0000%dh %dm", hours, minutes)
    else
        return string.format("|cffff0000%dm", minutes)
    end
end

WorldQuestsPanelMixin = {}

function WorldQuestsPanelMixin:RefreshList()
    if IsShiftKeyDown() then
        ScanForGoldQuests()
    end

    if not FOUND_WORLD_QUESTS then
        return
    end

    local sortedQuests = {}
    for _, data in pairs(FOUND_WORLD_QUESTS) do
        data.minutesLeft = C_TaskQuest.GetQuestTimeLeftMinutes(data.ID) or 0
        table.insert(sortedQuests, data)
    end
    table.sort(sortedQuests, function(a, b) return a.minutesLeft < b.minutesLeft end)

    local container = self.ScrollFrame.ScrollChild

    if not self.pool then
        self.pool = CreateFramePool("Button", container, "WorldQuestEntryTemplate")
    end
    self.pool:ReleaseAll()

    for i, quest in ipairs(sortedQuests) do
        local entry = self.pool:Acquire()
    
        entry.layoutIndex = i

        local atlas, width, height = QuestUtil.GetWorldQuestAtlasInfo(quest.ID, quest.tagInfo, false);
        if atlas then
            entry.Icon:SetAtlas(atlas, true)
            local scale = 18 / math.max(width, height)
            entry.Icon:SetSize(width * scale, height * scale)
        else
            entry.Icon:SetAtlas("worldquest-icon-adventure")
            entry.Icon:SetSize(18, 18)
        end

        entry.Title:SetText(quest.name)
        if quest.minutesLeft < (24 * 60) then
            entry.Title:SetTextColor(RED_FONT_COLOR:GetRGB())
        else
            entry.Title:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        end

        entry.Reward:SetText(GetMoneyString(quest.amount, true))

        entry:SetScript("OnClick", function()
            C_QuestLog.AddWorldQuestWatch(quest.ID, Enum.QuestWatchType.Manual)
        end)

        entry:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

            if GameTooltip:IsOwned(self) then
                GameTooltip:SetText("Quest Details")
                GameTooltip:AddLine("\n|rTime remaining: "..FormatQuestTime(quest.minutesLeft))
                GameTooltip:Show()
            end
        end)

        entry:SetScript("OnLeave", function(self)
            if GameTooltip:IsOwned(self) then
                GameTooltip:Hide()
            end
        end)

        entry:Show()
    end

    container:Layout()
    self.ScrollFrame:UpdateScrollChildRect();
end
