local objectives = {
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

local objectiveGroups = {
    gathering = {isUnique = false, free = true, name = "Gathering"},
    treasures = {isUnique = false, free = true, name = "Treasures/Dirt"},
    treatise = {isUnique = false, free = false, name = "Treatise"},
    weeklyQuest = {isUnique = true, free = false, name = "Weekly Quest"},
    craftingOrders = {isUnique = false, free = false, name = "Crafting Orders"},
    disenchanting = {isUnique = false, free = false, name = "Disenchanting"}
}

local currencies = {
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

local function getSubSkillLineID(profession)
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

local function pathIsMaxedOut(pathID, configID)
    local pathState = C_ProfSpecs.GetStateForPath(pathID, configID)
    if pathState ~= 2 then return false end
    
    local childIDs = C_ProfSpecs.GetChildrenForPath(pathID)
    if #childIDs > 0 then
        for _,childID in ipairs(childIDs) do
            if not pathIsMaxedOut(childID, configID) then return false end
        end
    end
    return true
end

local function profHasMaxKP(skillLineID, configID)
    local tabIDs = C_ProfSpecs.GetSpecTabIDsForSkillLine(skillLineID)
    local tabState
    for _,tabID in ipairs(tabIDs) do
        tabState =  C_ProfSpecs.GetStateForTab(tabID, configID)
        if tabState ~= 1 then return false end
        if not pathIsMaxedOut(C_ProfSpecs.GetRootPathForTab(tabID), configID) then return false end
    end
    return true
end

local function getNodeKP(profession, nodeID)
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
            childNodeCurrKP, childNodeMaxKP = getNodeKP(profession, edge.targetNode)
            childNodeCurrKP_sum = childNodeCurrKP_sum + childNodeCurrKP
            childNodeMaxKP_sum = childNodeMaxKP_sum + childNodeMaxKP
        end
    end
    
    return nodeCurrKP + childNodeCurrKP_sum, nodeMaxKP + childNodeMaxKP_sum
end

local function isKPProfession(profession)
    if not profession then return false end
    if not profession.ID or profession.ID == 0 then return false end
    if not profession.skillLineID or profession.skillLineID == 0 then return false end
    if not profession.configID or profession.configID == 0 then return false end
    if not profession.currencyID or profession.currencyID == 0 then return false end

    return true
end

local function checkProfObjective(quests, objectiveGroup)
    local maxQuestCount = #quests
    local complQuestCount = 0
    local objectiveComplete = false
    
    if objectiveGroups[objectiveGroup].isUnique and maxQuestCount > 1 then
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

local function checkProfObjectives(profession, callback)
    for objGroup, _ in pairs(objectives[profession.ID]) do
        objCompleted, objRemaining = checkProfObjective(objectives[profession.ID][objGroup], objGroup)
        callback(objRemaining, objCompleted, objGroup)
    end
end

local function getKPweeklyRemaining(profession)
    if not isKPProfession(profession) or profHasMaxKP(profession.skillLineID, profession.configID) then return "" end

    local allObjRemaining = 0
    checkProfObjectives(profession, function(objRemaining, objCompleted, objGroup)
        if objectiveGroups[objGroup].free then
            allObjRemaining = allObjRemaining + objRemaining
        end
    end)

    return (allObjRemaining > 0) and tostring(allObjRemaining) or ""
end

local function getKPprogress(profession)
    if not isKPProfession(profession) then return end

    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(profession.currencyID)
    local currKP = currencyInfo.quantity
    local maxKP = 0
    
    local tabIDs = C_ProfSpecs.GetSpecTabIDsForSkillLine(profession.skillLineID)
    local tabInfo, tabCurrKP, tabMaxKP
    for _,tabID in ipairs(tabIDs) do
        tabInfo = C_ProfSpecs.GetTabInfo(tabID)
        tabCurrKP, tabMaxKP = getNodeKP(profession, tabInfo.rootNodeID)
        currKP = currKP + tabCurrKP
        maxKP = maxKP + tabMaxKP
    end
    
    if currKP > maxKP then
        currKP = maxKP
    end
    
    return currKP, maxKP
end

local function getProfessionDetails(profession)
    local professionDetails = nil

    if profession then
        professionDetails = {}
        professionDetails.ID = select(7, GetProfessionInfo(profession))
        professionDetails.name = select(1, GetProfessionInfo(profession))
        professionDetails.skillLineID = getSubSkillLineID(professionDetails.name)
        professionDetails.configID = C_ProfSpecs.GetConfigIDForSkillLine(professionDetails.skillLineID)

        if currencies[professionDetails.ID] then
            professionDetails.currencyID = currencies[professionDetails.ID].ID
        end
    end

    return professionDetails
end


local function createBadge(point)
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

    return badge
end

local f = CreateFrame("Frame")

function f:UpdateProf1Badge()
    local text = getKPweeklyRemaining(self.prof1)

    if text and #text > 0 then
        self.badgeProf1.text:SetText(text)
        self.badgeProf1:Show()
    else
        self.badgeProf1:Hide()
    end
end

function f:UpdateProf2Badge()
    local text = getKPweeklyRemaining(self.prof2)

    if text and #text > 0 then
        self.badgeProf2.text:SetText(text)
        self.badgeProf2:Show()
    else
        self.badgeProf2:Hide()
    end
end

f.badgeProf1 = createBadge("TOPRIGHT")
f.badgeProf2 = createBadge("TOPLEFT")

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("QUEST_TURNED_IN")
f:RegisterEvent("BAG_UPDATE")
f:SetScript("OnEvent", function(self, event, ...)
    local prof1, prof2 = GetProfessions()

    if event == "PLAYER_LOGIN" then
        self.prof1 = getProfessionDetails(prof1)
        self.prof2 = getProfessionDetails(prof2)
    end

    self:UpdateProf1Badge()
    self:UpdateProf2Badge()
end)


local function addKPprogressText(profession)
    return " [" .. profession.currentKP .. "/" .. profession.maxKP .. "]"
end

local function addProfHeader(profession, objRemaining)
    return "|cFFFFD100"..profession.name.."|r" .. addKPprogressText(profession)
end

local function addObjectiveText(objGroup, objRemaining)
    return "  " .. objectiveGroups[objGroup].name .. ": " .. objRemaining .. "\n"
end

local function composeProfText(profession)
    if not isKPProfession(profession) then return "" end

    local detailedText = ""
    local allObjRemaining = 0

    if not profHasMaxKP(profession.skillLineID, profession.configID) then
        checkProfObjectives(profession, function(objRemaining, objCompleted, objGroup)
            allObjRemaining = allObjRemaining + objRemaining

            if not objCompleted then
                detailedText = detailedText .. addObjectiveText(objGroup, objRemaining)
            end
        end)

        if #detailedText <= 0 then
            detailedText = "  Week done!"
        end
    else
        detailedText = "  All done!"
    end

    local profText = "\n" .. addProfHeader(profession, allObjRemaining) .. "\n"
    profText = profText .. detailedText

    return profText
end

ProfessionMicroButton:HookScript("OnEnter", function(self)
    if GameTooltip:IsOwned(self) then

        if f.prof1 then
            f.prof1.currentKP, f.prof1.maxKP = getKPprogress(f.prof1)
            GameTooltip:AddLine(composeProfText(f.prof1), 1, 1, 1, true)
        end

        if f.prof2 then
            f.prof2.currentKP, f.prof2.maxKP = getKPprogress(f.prof2)
            GameTooltip:AddLine(composeProfText(f.prof2), 1, 1, 1, true)
        end

        GameTooltip:Show()
    end
end)


