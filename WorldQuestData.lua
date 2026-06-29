local _, _A = ...


-- Use /dump C_Map.GetBestMapForUnit("player") in-game to find map IDs
_A.WorldQuestsZones = {
    [2424] = "Silvermoon - Isle of Quel'Danas",
    [2393] = "Silvermoon",
    [2395] = "Eversong Woods",
    [2437] = "Zul'Aman",
    [2413] = "Harandar",
    [2576] = "Harandar - The Den",
    [2405] = "Voidstorm",
    [2444] = "Voidstorm - Bloodplains",
    [2600] = "Naigtal",
}
local WorldQuestsZones = _A.WorldQuestsZones


_A.FoundWorldQuests = { quests = {}, count = 0 }
local FoundWorldQuests = _A.FoundWorldQuests

function FoundWorldQuests:GetQuests()
    return self.quests
end

function FoundWorldQuests:GetQuest(questID)
    return self.quests[questID]
end

function FoundWorldQuests:GetCount()
    return self.count
end

function FoundWorldQuests:AddQuest(questID, data)
    local quests = self.quests
    if not quests[questID] then
        self.count = self.count + 1
    end
    quests[questID] = data
end

function FoundWorldQuests:RemoveQuest(questID)
    local quests = self.quests
    if quests[questID] then
        quests[questID] = nil
        self.count = self.count - 1
    end
end

function FoundWorldQuests:Clear()
    self.quests = {}
    self.count = 0
end


function _A.ProcessWorldQuest(questID, savedVars)
    local mapID = C_TaskQuest.GetQuestZoneID(questID)
    local existingQuest = FoundWorldQuests:GetQuests(questID)

    if existingQuest and (C_QuestLog.IsComplete(questID) or not C_TaskQuest.IsActive(questID)) then
        FoundWorldQuests:RemoveQuest(questID)
        return true
    end

    if not WorldQuestsZones[mapID] then return false end

    if not C_QuestLog.IsWorldQuest(questID) then return false end

    local mapInfo = C_Map.GetMapInfo(mapID)
    local rewards = _A:GetRewardsForQuest(questID)

    if rewards.gold > savedVars.MinGoldReward then -- or rewards.faction then
        local quest = {
            ID = questID,
            name = C_QuestLog.GetTitleForQuestID(questID) or "Unknown Quest",
            amount = rewards.gold,
            faction = rewards.faction,
            tagInfo = C_QuestLog.GetQuestTagInfo(questID),
            minutesLeft = C_TaskQuest.GetQuestTimeLeftMinutes(questID) or 0,
            zone = mapInfo and mapInfo.name or "Unknown Zone",
        }
        FoundWorldQuests:AddQuest(questID, quest)

        return true
    end

    return false
end

function _A:GetRewardsForQuest(questID)
    local rewards = { gold = 0, reputation = false }

    rewards.gold = GetQuestLogRewardMoney(questID) or 0

    local factionID = nil
    local currencies = C_QuestLog.GetQuestRewardCurrencies(questID) or {}
    for _, currency in ipairs(currencies) do
        if currency.currencyID == 0 or currency.name == "Gold" then
            rewards.gold = rewards.gold + (currency.totalRewardAmount or 0)
        end

        factionID = C_CurrencyInfo.GetFactionGrantedByCurrency(currency.currencyID)
    end

    rewards.gold = math.floor(rewards.gold / 10000) * 10000

    if C_QuestLog.QuestContainsFirstTimeRepBonusForPlayer(questID) then
        factionID = select(2, C_TaskQuest.GetQuestInfoByQuestID(questID))
    end

    if factionID and not _A:IsFactionMaxed(factionID) then
        rewards.faction = _A.ParagonFactions[factionID]
    end

    return rewards
end

function _A:IsFactionMaxed(factionID)
    -- 1. Check Major Factions
    if C_MajorFactions.HasMaximumRenown(factionID) then
        return true
    end

    -- -- 2. Check Standard Reputations (Exalted / Paragon)
    -- local data = C_GossipInfo.GetFriendshipReputation(factionID)
    -- if data and data.friendshipFactionID > 0 then
    --     -- Handle Friendship/Crony systems (like The Severed Threads)
    --     return data.nextThreshold == nil
    -- else
    --     -- Standard Rep (Exalted is Rank 8)
    --     local _, _, standingID = GetFactionInfoByID(factionID)
    --     return standingID and standingID >= 8
    -- end

    return false
end