local PARAGON_FACTIONS ={
    -- The War Within
    [2590] = "Council of Dornogal",
    [2688] = "Flame's Radiance",
    [2570] = "Hallowfall Arathi",
    [2594] = "The Assembly of the Deeps",
    [2658] = "The K'aresh Trust",
    [2653] = "The Cartels of Undermine",
        [2685] = "Gallagio Loyalty Rewards Club",
        [2673] = "Bilgewater Cartel",
        [2675] = "Blackwater Cartel",
        [2669] = "Darkfuse Solutions",
        [2677] = "Steamwheedle Cartel",
        [2671] = "Venture Company",
    [2600] = "The Severed Threads",
        [2605] = "The General",
        [2607] = "The Vizier",
        [2601] = "The Weaver",

    -- Dragonflight
    [2574] = "Dream Wardens",
    [2511] = "Iskaara Tuskarr",
    [2564] = "Loamm Niffen",
    [2503] = "Maruuk Centaur",
    [2507] = "Dragonscale Expedition",
    [2510] = "Valdrakken Accord",

    -- Shadowlands
    [2413] = "Court of Harvesters",
    [2470] = "Deaths Advance",
    [2472] = "The Archivists Codex",
    [2407] = "The Ascended",
    [2478] = "The Enlightened",
    [2410] = "The Undying Army",
    [2465] = "The Wild Hunt",
    [2432] = "Ve,nari",

    -- Battle for Azeroth
    [2164] = "Champions of Azeroth",
    [2415] = "Rajani",
    [2391] = "Rustbolt Resistance",
    [2156] = "Talanji's Expedition",
    [2157] = "The Honorbound",
    [2373] = "The Unshackled",
    [2163] = "Tortollan Seekers",
    [2417] = "Uldum Accord",
    [2158] = "Voldunai",
    [2103] = "Zandalari Empire",
    [2160] = "Proudmoore Admiralty",
    [2161] = "Order of Embers",
    [2162] = "Storm's Wake",
    [2159] = "7th Legion",

    -- Legion
    [2170] = "Argussian Reach",
    [2045] = "Armies of Legionfall",
    [2165] = "Army of the Light",
    [1900] = "Court of Farondis",
    [1883] = "Dreamweavers",
    [1828] = "Highmountain Tribe",
    [1859] = "The Nightfallen",
    [1894] = "The Wardens",
    [1948] = "Valarjar",
}


local SCAN_PENDING = false
local AVAILABLE_PARAGON_CACHES = {}


local function CreateBadge(point)
    local badge = CreateFrame("Frame", "MyParagonsBadge", AchievementMicroButton)
    badge:SetSize(20, 20)
    badge:SetFrameStrata("MEDIUM")
    badge:SetFrameLevel(AchievementMicroButton:GetFrameLevel() + 10)
    badge:SetPoint(point, AchievementMicroButton, "TOP", 0, 6)

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
    badge.text:SetText("-")

    return badge
end

local f = CreateFrame("Frame")

f.badgeParagon = CreateBadge("TOP")

local function UpdateParagonBadge()
    local count = 0
    for _, _ in pairs(AVAILABLE_PARAGON_CACHES) do
        count = count + 1
    end

    if count and count > 0 then
        f.badgeParagon.text:SetText(tostring(count))
        f.badgeParagon:Show()
    else
        f.badgeParagon:Hide()
    end
end

local function GetAvailableParagonCaches()
    AVAILABLE_PARAGON_CACHES = {}

    local factionQueue = {}

    for factionID, name in pairs(PARAGON_FACTIONS) do
        table.insert(factionQueue, { id = factionID, name = name })
    end

    local function ScanParagonBatch(startIndex)
        local batchSize = 6 -- Number of factions per frame
        local endIndex = math.min(startIndex + batchSize - 1, #factionQueue)

        for i = startIndex, endIndex do
            local item = factionQueue[i]
            local factionID = item.id
            local factionName = item.name

            if C_Reputation.IsFactionParagonForCurrentPlayer(factionID) then
                local _, _, rewardQuestID, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID)

                if hasRewardPending then
                    print("    Faction has reward pending: "..factionName)

                    AVAILABLE_PARAGON_CACHES[factionID] = {
                        name = factionName,
                        questID = rewardQuestID
                    }
                end
            end
        end

        if endIndex < #factionQueue then
            C_Timer.After(0.1, function() ScanParagonBatch(endIndex + 1) end)
        else
            UpdateParagonBadge()

            SCAN_PENDING = false
        end
    end

    if #factionQueue > 0 then
        ScanParagonBatch(1)
    end
end

local function CreateTooltipText()
    local detailsText = ""

    for _, cache in pairs(AVAILABLE_PARAGON_CACHES) do
        detailsText = detailsText .. "  " .. cache.name .. "\n"
    end

    if #detailsText <= 0 then
         detailsText = "  None!"
    end

    local headerText = "|cFFFFD100Paragon caches:|r"
    return  "\n" .. headerText .. "\n" .. detailsText
end



f:RegisterEvent("QUEST_TURNED_IN")
f:RegisterEvent("UPDATE_FACTION")
f:RegisterEvent("FACTION_STANDING_CHANGED")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "UPDATE_FACTION" or "FACTION_STANDING_CHANGED" then
        if not SCAN_PENDING then
            SCAN_PENDING = true

            C_Timer.After(0.1, GetAvailableParagonCaches)
        end
    elseif event == "QUEST_TURNED_IN" then
        local questID = ...

        for factionID, cache in pairs(AVAILABLE_PARAGON_CACHES) do
            if questID == cache.questID then
                AVAILABLE_PARAGON_CACHES[factionID] = nil

                UpdateParagonBadge()
                break
            end
        end
    end
end)

AchievementMicroButton:HookScript("OnEnter", function(self)
    if GameTooltip:IsOwned(self) then
        GameTooltip:AddLine(CreateTooltipText(), 1, 1, 1, true)
        GameTooltip:Show()
    end
end)
