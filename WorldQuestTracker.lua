local ADDON_NAME, _A = ...

local TAB_DISPLAY_MODE = 4
local SCAN_RATE = 5 * 60


BT_SavedVars = BT_SavedVars or { WorldQuestTracker = { MinGoldReward = 500 * 10000 } }
local SavedVars = nil


local function QuestSortKey(minutes)
    if minutes > 24 * 60 then
        minutes = 24 * 60
    elseif minutes > 60 then
        return math.floor(minutes / 60) * 60
    end
    return minutes
end


local WorldQuestTrackerMixin = {}

function WorldQuestTrackerMixin:Setup()
    self.worldQuestsToScan = {}
    self.updatingUI = false
    self.pendingZoneScan = false

    self.worldQuestBadge = self:CreateBadge("TOP")

    self:RegisterEvent("VARIABLES_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("QUEST_DATA_LOAD_RESULT")
    self:RegisterEvent("QUEST_TURNED_IN")
    self:RegisterEvent("QUEST_REMOVED")
    self:RegisterEvent("QUEST_POI_UPDATE")

    self:SetScript("OnEvent", self.OnEvent)
end

function WorldQuestTrackerMixin:CreateBadge(point)
    local badge = CreateFrame("Frame", nil, QuestLogMicroButton)
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

    badge:Hide()

    return badge
end

function WorldQuestTrackerMixin:UpdateUI()
    local count = _A.FoundWorldQuests:GetCount()
    if count > 0 then
        self.worldQuestBadge.text:SetText(count)
        self.worldQuestBadge:Show()
    else
        self.worldQuestBadge:Hide()
    end

    if QuestMapFrame and QuestMapFrame.WorldQuestsPanel and QuestMapFrame.WorldQuestsPanel:IsShown() then
        QuestMapFrame.WorldQuestsPanel:RefreshList()
    end

    self.updatingUI = false
end

function WorldQuestTrackerMixin:ProcessQuest(questID)
    if not questID then return end

    if _A.ProcessWorldQuest(questID, SavedVars) then
        if not self.updatingUI then
            self.updatingUI = true
            C_Timer.After(1, function() self:UpdateUI() end)
        end
    end
end

function WorldQuestTrackerMixin:RefreshQuestRewards()
    local mapList = {}
    for mapID in pairs(_A.WorldQuestsZones) do
        table.insert(mapList, mapID)
    end

    self.worldQuestsToScan = {}
    self.pendingZoneScan = true

    -- Phase 1: staggered requests to warm the server-side quest cache per zone.
    for i, mapID in ipairs(mapList) do
        C_Timer.After(i * 0.05, function()
            C_TaskQuest.GetQuestsOnMap(mapID)
        end)
    end

    -- Phase 2: fallback timer in case QUEST_POI_UPDATE already fired or never comes
    C_Timer.After(#mapList * 0.05 + 1.5, function()
        if self.pendingZoneScan then
            self.pendingZoneScan = false
            self:ScanAllZones(mapList)
        end
    end)
end

function WorldQuestTrackerMixin:ScanAllZones(mapList)
    if not mapList then
        mapList = {}
        for mapID in pairs(_A.WorldQuestsZones) do
            table.insert(mapList, mapID)
        end
    end

    local function ScanMapBatch(index)
        local mapID = mapList[index]
        local quests = C_TaskQuest.GetQuestsOnMap(mapID)

        if quests then
            for _, qInfo in ipairs(quests) do
                local questID = qInfo.questId or qInfo.questID
                if questID and C_QuestLog.IsWorldQuest(questID) and not self.worldQuestsToScan[questID] then
                    C_TaskQuest.RequestPreloadRewardData(questID)
                    C_QuestLog.RequestLoadQuestByID(questID)

                    self.worldQuestsToScan[questID] = mapID
                end
            end
        end

        if index < #mapList then
            C_Timer.After(0.1, function() ScanMapBatch(index + 1) end)
        else
            C_Timer.After(2, function() self:RefreshQuests() end)
        end
    end

    if #mapList > 0 then
        ScanMapBatch(1)
    end
end

function WorldQuestTrackerMixin:RefreshQuests()
    for questID in pairs(self.worldQuestsToScan) do
        if not _A.FoundWorldQuests:GetQuest(questID) then
            self:ProcessQuest(questID)
        end
    end

    -- queue the next quest refresh cycle
    C_Timer.After(SCAN_RATE, function() self:RefreshQuestRewards() end)
end

function WorldQuestTrackerMixin:ResetQuests()
    self.worldQuestsToScan = {}

    _A.FoundWorldQuests:Clear()

    self:RefreshQuestRewards()
end

function WorldQuestTrackerMixin:OnEvent(event, ...)
    if event == "VARIABLES_LOADED" then
        SavedVars = BT_SavedVars["WorldQuestTracker"]
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function() self:RefreshQuestRewards() end)
    elseif event == "QUEST_POI_UPDATE" then
        -- Server has returned fresh zone quest data; scan immediately
        -- if we were waiting on it, cancelling the fallback timer via the flag
        if self.pendingZoneScan then
            self.pendingZoneScan = false
            self:ScanAllZones()
        end
    elseif event == "QUEST_DATA_LOAD_RESULT" then
        local questID, success = ...
        if success and questID then
            self:ProcessQuest(questID)
        end
    elseif event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED" then
        local questID = ...

        if _A.FoundWorldQuests:GetQuest(questID) then
            _A.FoundWorldQuests:RemoveQuest(questID)

            if not self.updatingUI then
                self.updatingUI = true
                C_Timer.After(0.1, function() self:UpdateUI() end)
            end
        end
    end
end

local WorldQuestTracker = CreateFrame("Frame")
Mixin(WorldQuestTracker, WorldQuestTrackerMixin)
WorldQuestTracker:Setup()


QuestLogMicroButton:HookScript("OnEnter", function(self)
    if GameTooltip:IsOwned(self) then
        local totalGold = 0
        for _, data in pairs(_A.FoundWorldQuests:GetQuests()) do
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
    self.Icon:SetDesaturated(true)
    self.Icon:SetVertexColor(0.70, 0.60, 0.20)
    self.Icon:SetSize(20, 20)
    self.Icon:Show()
end

function WorldQuestTabMixin:OnClick()
    if IsShiftKeyDown() then
        WorldQuestTracker:ResetQuests()
    else
        QuestMapFrame.WorldQuestsPanel:RefreshList()

        QuestMapFrame:SetDisplayMode(TAB_DISPLAY_MODE)
    end
end


WorldQuestsPanelMixin = {}

function WorldQuestsPanelMixin:RefreshList()
    local sortedQuests = {}
    for _, quest in pairs(_A.FoundWorldQuests:GetQuests()) do
        quest.minutesLeft = C_TaskQuest.GetQuestTimeLeftMinutes(quest.ID) or quest.minutesLeft or 0
        table.insert(sortedQuests, quest)
    end
    table.sort(sortedQuests, function(a, b)
        local aKey = QuestSortKey(a.minutesLeft)
        local bKey = QuestSortKey(b.minutesLeft)
        if aKey ~= bKey then
            return aKey < bKey
        end
        return a.zone < b.zone
    end)

    local container = self.ScrollFrame.Content

    if not self.pool then
        self.pool = CreateFramePool("Button", container, "WorldQuestEntryTemplate")
    end
    self.pool:ReleaseAll()

    local panel = self

    for i, quest in ipairs(sortedQuests) do
        local entry = self.pool:Acquire()

        entry.layoutIndex = i
        entry.questID = quest.ID
        entry.questName = quest.name
        entry.minutesLeft = quest.minutesLeft
        entry.zone = quest.zone
        entry.amount = quest.amount
        entry.faction = quest.faction

        local atlas, width, height = QuestUtil.GetWorldQuestAtlasInfo(quest.ID, quest.tagInfo, false)
        if atlas then
            entry.Icon:SetAtlas(atlas, true)
            local scale = 18 / math.max(width, height)
            entry.Icon:SetSize(width * scale, height * scale)
        else
            entry.Icon:SetAtlas("worldquest-icon-adventure")
            entry.Icon:SetSize(18, 18)
        end

        entry.Title:SetText(entry.questName)
        if entry.minutesLeft <= 0 then
            entry.Title:SetTextColor(DISABLED_FONT_COLOR:GetRGB())
        elseif entry.minutesLeft < (8 * 60) then
            entry.Title:SetTextColor(RED_FONT_COLOR:GetRGB())
        elseif entry.minutesLeft < (24 * 60) then
            entry.Title:SetTextColor(0.8, 0.4, 0)
        else
            entry.Title:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        end

        if entry.amount > 0 then
            entry.Reward:SetText(GetMoneyString(entry.amount, true))
        elseif entry.faction then
            entry.Reward:SetText("Reputation")
        else
            entry.Reward:SetText("n/a")
        end

        entry:SetScript("OnClick", function(self)
            C_QuestLog.AddWorldQuestWatch(self.questID, Enum.QuestWatchType.Manual)
        end)

        if not entry.hooksAttached then
            entry:HookScript("OnEnter", function(self)
                GameTooltip:ClearLines()
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Time left: "..panel:FormatQuestTime(self.minutesLeft), NORMAL_FONT_COLOR:GetRGB())
                GameTooltip:AddLine("|cFFFFD100Zone:|r "..self.zone, 1, 1, 1, true)
                if self.faction then
                    GameTooltip:AddLine("|cFFFFD100Faction:|r "..self.faction, 1, 1, 1, true)
                end
                -- GameTooltip_AddQuestRewardsToTooltip(GameTooltip, self.questID)
                if self.amount > 0 then
                    GameTooltip:AddLine("|cFFFFD100Gold:|r "..GetMoneyString(self.amount, true), 1, 1, 1, true)
                end
                GameTooltip:Show()
            end)

            entry:HookScript("OnLeave", function(self)
                if GameTooltip:IsOwned(self) then
                    GameTooltip:Hide()
                    GameTooltip.questID = nil
                end
            end)

            entry.hooksAttached = true
        end

        entry:Show()
    end

    container:Layout()
    container:Show()

    self.ScrollFrame:UpdateScrollChildRect()
end

function WorldQuestsPanelMixin:FormatQuestTime(totalMinutes)
    if not totalMinutes or totalMinutes <= 0 then return "|cffff0000Expired|r" end

    local days = math.floor(totalMinutes / 1440)
    local remainingMinutes = totalMinutes % 1440
    local hours = math.floor(remainingMinutes / 60)
    local minutes = remainingMinutes % 60

    if days > 0 then
        return string.format("|cFFFFD100%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("|cFFFFD100%dh", hours)
    else
        return string.format("|cffff0000%dm", minutes)
    end
end


SLASH_WorldQuestTracker1 = "/bwq"

SlashCmdList["WorldQuestTracker"] = function(arg)
    local msg = string.lower(arg or "")

    if msg:match("^set%s+%d+$") then
        local value = tonumber(msg:match("^set%s+(%d+)$"))
        if value and value >= 1 then
            SavedVars.MinGoldReward = value * 10000
            print("|cffB0C4DE["..ADDON_NAME.."]|r Minimum gold reward set to "..GetMoneyString(SavedVars.MinGoldReward, true))

            WorldQuestTracker:ResetQuests()
        end
    elseif msg == "show" then
        print("|cffB0C4DE["..ADDON_NAME.."]|r Minimum gold reward is "..GetMoneyString(SavedVars.MinGoldReward, true))
    else
        print("|cffB0C4DE["..ADDON_NAME.."]|r Commands:")
        print("  /bwq set <value> - Set the minimum gold reward amount")
        print("  /bwq show - Prints the minimum gold reward amount")
    end
end