local OBJECTIVES = {
    [171] = {treasures = {83253, 83255}, treatise = {83725}, weeklyQuest = {84133}, craftingOrders = {}}, --alchemy
    [164] = {treasures = {83256, 83257}, treatise = {83726}, weeklyQuest = {84127}, craftingOrders = {}}, --blacksmithing
    [202] = {treasures = {83260, 83261}, treatise = {83728}, weeklyQuest = {84128}, craftingOrders = {}}, --engineering
    [773] = {treasures = {83262, 83264}, treatise = {83730}, weeklyQuest = {84129}, craftingOrders = {}}, --inscription
    [755] = {treasures = {83265, 83266}, treatise = {83731}, weeklyQuest = {84130}, craftingOrders = {}}, --jewelcrafting
    [165] = {treasures = {83267, 83268}, treatise = {83732}, weeklyQuest = {84131}, craftingOrders = {}}, --leatherworking
    [197] = {treasures = {83269, 83270}, treatise = {83735}, weeklyQuest = {84132}, craftingOrders = {}}, --tailoring
    [333] = {treasures = {83258, 83259}, treatise = {83727}, weeklyQuest = {84084, 84085, 84086}, disenchanting = {84290, 84291, 84292, 84293, 84294, 84295}}, --enchanting
    [182] = {treasures = {}, treatise = {83729}, weeklyQuest = {82965, 82958, 82916, 82962, 82970}, gathering = {81416, 81417, 81418, 81419, 81420, 81421}}, --herbalism
    [186] = {treasures = {}, treatise = {83733}, weeklyQuest = {83105, 83106, 83104, 83102, 83103}, gathering = {83050, 83051, 83052, 83053, 83054, 83049}}, --mining
    [393] = {treasures = {}, treatise = {83734}, weeklyQuest = {83098, 82993, 82992, 83100, 83097}, gathering = {81459, 81460, 81461, 81462, 81463, 81464}} --skinning
}

local OBJECTIVE_GROUPS = {
    gathering = {isUnique = false, free = true, name = "Gathering"},
    treasures = {isUnique = false, free = true, name = "Treasures/Dirt"},
    treatise = {isUnique = false, free = false, name = "Treatise"},
    weeklyQuest = {isUnique = true, free = false, name = "Weekly Quest"},
    craftingOrders = {isUnique = false, free = false, name = "Crafting Orders"},
    disenchanting = {isUnique = false, free = false, name = "Disenchanting"}
}

local CURRENCIES = {
    [171] = {ID = 2785}, --alchemy
    [164] = {ID = 2786}, --blacksmithing
    [202] = {ID = 2788}, --engineering
    [773] = {ID = 2790}, --inscription
    [755] = {ID = 2791}, --jewelcrafting
    [165] = {ID = 2792}, --leatherworking
    [197] = {ID = 2795}, --tailoring
    [333] = {ID = 2787}, --enchanting
    [182] = {ID = 2789}, --herbalism
    [186] = {ID = 2793}, --mining
    [393] = {ID = 2794}  --skinning
}

local function GetSubSkillLineID(profession)
    local profTradeSkillLines = C_TradeSkillUI.GetAllProfessionTradeSkillLines()
    local subProfessionName = 'Khaz Algar ' .. profession
    local profInfo
    for _,v in ipairs(profTradeSkillLines) do
        profInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(v)
        if profInfo and string.find(profInfo.professionName, subProfessionName) then
            return profInfo.professionID
        end
    end
end

local function IsPathMaxedOut(pathID, configID)
    local pathState = C_ProfSpecs.GetStateForPath(pathID, configID)
    if pathState ~= 2 then return false end
    
    local childIDs = C_ProfSpecs.GetChildrenForPath(pathID)
    if #childIDs > 0 then
        for _,childID in ipairs(childIDs) do
            if not IsPathMaxedOut(childID, configID) then return false end
        end
    end
    return true
end

local function HasMaxKP(skillLineID, configID)
    local tabIDs = C_ProfSpecs.GetSpecTabIDsForSkillLine(skillLineID)
    local tabState
    for _,tabID in ipairs(tabIDs) do
        tabState =  C_ProfSpecs.GetStateForTab(tabID, configID)
        if tabState ~= 1 then return false end
        if not IsPathMaxedOut(C_ProfSpecs.GetRootPathForTab(tabID), configID) then return false end
    end
    return true
end

local function GetNodeKP(profession, nodeID)
    local nodeInfo = C_Traits.GetNodeInfo(profession.configID, nodeID)
    local nodeCurrKP = nodeInfo.ranksPurchased - 1
    local nodeMaxKP = nodeInfo.maxRanks - 1
    local childNodeCurrKP_sum = 0
    local childNodeMaxKP_sum = 0
    local childNodeCurrKP, childNodeMaxKP
    
    if nodeCurrKP < 0 then
        nodeCurrKP = 0
    end
    
    if #nodeInfo.visibleEdges > 0 then
        for _,edge in ipairs(nodeInfo.visibleEdges) do
            childNodeCurrKP, childNodeMaxKP = GetNodeKP(profession, edge.targetNode)
            childNodeCurrKP_sum = childNodeCurrKP_sum + childNodeCurrKP
            childNodeMaxKP_sum = childNodeMaxKP_sum + childNodeMaxKP
        end
    end
    
    return nodeCurrKP + childNodeCurrKP_sum, nodeMaxKP + childNodeMaxKP_sum
end

local function IsKPProfession(profession)
    if not profession then return false end
    if not profession.ID or profession.ID == 0 then return false end
    if not profession.skillLineID or profession.skillLineID == 0 then return false end
    if not profession.configID or profession.configID == 0 then return false end
    if not profession.currencyID or profession.currencyID == 0 then return false end

    return true
end

local function GetKPprogress(profession)
    if not IsKPProfession(profession) then return end

    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(profession.currencyID)
    local currKP = currencyInfo.quantity
    local maxKP = 0
    
    local tabIDs = C_ProfSpecs.GetSpecTabIDsForSkillLine(profession.skillLineID)
    local tabInfo, tabCurrKP, tabMaxKP
    for _,tabID in ipairs(tabIDs) do
        tabInfo = C_ProfSpecs.GetTabInfo(tabID)
        tabCurrKP, tabMaxKP = GetNodeKP(profession, tabInfo.rootNodeID)
        currKP = currKP + tabCurrKP
        maxKP = maxKP + tabMaxKP
    end
    
    if currKP > maxKP then
        currKP = maxKP
    end
    
    return currKP, maxKP
end

local function CheckProfessionObjective(quests, objectiveGroup)
    local maxQuestCount = #quests
    local complQuestCount = 0
    local objectiveComplete = false
    
    if OBJECTIVE_GROUPS[objectiveGroup].isUnique and maxQuestCount > 1 then
        maxQuestCount = 1
    end
    
    for _,questID in ipairs(quests) do
        if C_QuestLog.IsQuestFlaggedCompleted(questID) then
            complQuestCount = complQuestCount +1
        end
    end

    if complQuestCount >= maxQuestCount then
        objectiveComplete = true
    end
    
    return objectiveComplete, (maxQuestCount - complQuestCount)
end

local function CheckProfessionObjectives(profession, callback)
    for objGroup, _ in pairs(OBJECTIVES[profession.ID]) do
        objCompleted, objRemaining = CheckProfessionObjective(OBJECTIVES[profession.ID][objGroup], objGroup)
        callback(objRemaining, objCompleted, objGroup)
    end
end

local function GetKPweeklyRemaining(profession)
    if not IsKPProfession(profession) or HasMaxKP(profession.skillLineID, profession.configID) then return 0 end

    local allObjRemaining = 0
    CheckProfessionObjectives(profession, function(objRemaining, objCompleted, objGroup)
        if OBJECTIVE_GROUPS[objGroup].free then
            allObjRemaining = allObjRemaining + objRemaining
        end
    end)

    return allObjRemaining
end

local function GetProfessionDetails(profession)
    local professionDetails = nil

    if profession then
        professionDetails = {}
        professionDetails.ID = select(7, GetProfessionInfo(profession))
        professionDetails.name = select(1, GetProfessionInfo(profession))
        professionDetails.skillLineID = GetSubSkillLineID(professionDetails.name)
        professionDetails.configID = C_ProfSpecs.GetConfigIDForSkillLine(professionDetails.skillLineID)

        if CURRENCIES[professionDetails.ID] then
            professionDetails.currencyID = CURRENCIES[professionDetails.ID].ID
        end
    end

    return professionDetails
end



local function CreateBadge(point)
    local badge = CreateFrame("Frame", "MyProfessionsBadge", ProfessionMicroButton)
    badge:SetSize(20, 20)
    badge:SetFrameStrata("MEDIUM")
    badge:SetFrameLevel(ProfessionMicroButton:GetFrameLevel() + 10)
    badge:SetPoint(point, ProfessionMicroButton, "TOP", 0, 6)

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

f.badgeProfession1 = CreateBadge("TOPRIGHT")
f.badgeProfession2 = CreateBadge("TOPLEFT")

function f:UpdateProfession1Badge()
    local count = GetKPweeklyRemaining(self.profession1)

    if count and count > 0 then
        self.badgeProfession1.text:SetText(tostring(count))
        self.badgeProfession1:Show()
    else
        self.badgeProfession1:Hide()
    end
end

function f:UpdateProfession2Badge()
    local count = GetKPweeklyRemaining(self.profession2)

    if count and count > 0 then
        self.badgeProfession2.text:SetText(tostring(count))
        self.badgeProfession2:Show()
    else
        self.badgeProfession2:Hide()
    end
end

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("QUEST_TURNED_IN")
f:RegisterEvent("BAG_UPDATE")
f:SetScript("OnEvent", function(self, event, ...)
    local profession1, profession2 = GetProfessions()

    if event == "PLAYER_LOGIN" then
        self.profession1 = GetProfessionDetails(profession1)
        self.profession2 = GetProfessionDetails(profession2)
    end

    self:UpdateProfession1Badge()
    self:UpdateProfession2Badge()
end)

local function CreateTooltipText(profession)
    if not IsKPProfession(profession) then return "" end

    local detailsText = ""
    local allObjRemaining = 0

    if not HasMaxKP(profession.skillLineID, profession.configID) then
        CheckProfessionObjectives(profession, function(objRemaining, objCompleted, objGroup)
            allObjRemaining = allObjRemaining + objRemaining

            if not objCompleted then
                local objectiveText = "  " .. OBJECTIVE_GROUPS[objGroup].name .. ": " .. objRemaining .. "\n"
                detailsText = detailsText .. objectiveText
            end
        end)

        if #detailsText <= 0 then
            detailsText = "  Week done!"
        end
    else
        detailsText = "  All done!"
    end

    local kPprogressText = " [" .. profession.currentKP .. "/" .. profession.maxKP .. "]"
    local headerText = "|cFFFFD100"..profession.name.."|r" .. kPprogressText

    return "\n" .. headerText .. "\n" .. detailsText
end

ProfessionMicroButton:HookScript("OnEnter", function(self)
    if GameTooltip:IsOwned(self) then

        if f.profession1 then
            f.profession1.currentKP, f.profession1.maxKP = GetKPprogress(f.profession1)
            GameTooltip:AddLine(CreateTooltipText(f.profession1), 1, 1, 1, true)
        end

        if f.profession2 then
            f.profession2.currentKP, f.profession2.maxKP = GetKPprogress(f.profession2)
            GameTooltip:AddLine(CreateTooltipText(f.profession2), 1, 1, 1, true)
        end

        GameTooltip:Show()
    end
end)
