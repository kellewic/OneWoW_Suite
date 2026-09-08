local _, ns = ...

-- ============================================================================
-- QuestScanner
-- ============================================================================
-- Live quest-dialog / quest-log capture into QuestDB Current. Ownership:
--   * starts / ends store { npcID } only. NPC map pins live on NPCDB.
--   * GameObject givers / turn-ins stay on the quest as startObjects /
--     endObjects (objects have no NPCDB row), with the player map pin.
--   * Do not write player xy onto the quest row or onto starts/ends.
-- ============================================================================

local ipairs, type, tonumber = ipairs, type, tonumber
local tinsert = tinsert
local strsplit, strtrim = strsplit, strtrim
local Enum = Enum
local C_QuestLog, C_QuestInfoSystem = C_QuestLog, C_QuestInfoSystem
local C_Map, C_Timer, C_CurrencyInfo, C_TaskQuest = C_Map, C_Timer, C_CurrencyInfo, C_TaskQuest
local UnitExists, UnitGUID, UnitName = UnitExists, UnitGUID, UnitName

local GetQuestID, GetTitleText, GetQuestText, GetObjectiveText =
    GetQuestID, GetTitleText, GetQuestText, GetObjectiveText
local GetQuestLogQuestText, GetQuestUiMapID = GetQuestLogQuestText, GetQuestUiMapID
local GetRewardMoney, GetRewardXP = GetRewardMoney, GetRewardXP
local GetNumQuestRewards, GetNumQuestChoices, GetQuestItemInfo =
    GetNumQuestRewards, GetNumQuestChoices, GetQuestItemInfo
local GetQuestLogRewardMoney, GetQuestLogRewardXP = GetQuestLogRewardMoney, GetQuestLogRewardXP
local GetNumQuestLogRewards, GetQuestLogRewardInfo = GetNumQuestLogRewards, GetQuestLogRewardInfo
local GetNumQuestLogChoices, GetQuestLogChoiceInfo = GetNumQuestLogChoices, GetQuestLogChoiceInfo
local GetQuestLogSpecialItemInfo = GetQuestLogSpecialItemInfo

local API = OneWoW_CatDB_QuestDBCurrent_API

ns.QuestScanner = {}
local QuestScanner = ns.QuestScanner

local pendingQuestDetails = {}

local INTERNAL_PATTERNS = {
    "tracking quest",
    "^decor ",
    "^deprecated",
    "^test ",
    "^qa ",
}

local BOARD_QUEST_PATTERNS = {
    "^hero's call:",
    "^warchief's command:",
    "^adventurers wanted:",
}

local BOARD_SOURCE_PATTERNS = {
    "call board",
    "command board",
    "adventure guide",
}

local INTERACT_UNITS = { "npc", "questnpc", "target" }

local function MatchesAnyPattern(value, patterns)
    if not value then return false end
    local lower = tostring(value):lower()
    for _, pattern in ipairs(patterns) do
        if lower:find(pattern) then return true end
    end
    return false
end

local function IsInternalQuest(name, info)
    if not name then return true end
    if info and info.isHidden then return true end
    return MatchesAnyPattern(name, INTERNAL_PATTERNS)
end

local function IsBoardSourcedQuest(name, sourceName)
    return MatchesAnyPattern(name, BOARD_QUEST_PATTERNS)
        or MatchesAnyPattern(sourceName, BOARD_SOURCE_PATTERNS)
end

local function AddUnique(tbl, value)
    if value == nil then return end
    for _, existing in ipairs(tbl) do
        if existing == value then return end
    end
    tinsert(tbl, value)
end

local function EnsureList(data, field)
    data[field] = data[field] or {}
    return data[field]
end

local function AddFlag(data, flag)
    AddUnique(EnsureList(data, "flags"), flag)
end

local function AddCategory(data, category)
    AddUnique(EnsureList(data, "categories"), category)
end

local function GetMapName(mapID)
    if not mapID or mapID == 0 then return nil end
    local mapInfo = C_Map.GetMapInfo(mapID)
    return mapInfo and mapInfo.name or nil
end

local function NormalizeName(name)
    if not name then return nil end
    name = strtrim(tostring(name))
    if name == "" then return nil end
    return name:lower()
end

local function NamesMatch(a, b)
    local na, nb = NormalizeName(a), NormalizeName(b)
    return na ~= nil and na == nb
end

--- Creature / Vehicle / GameObject the player is talking to. GUID parse is
--- skipped while the id is secret (instanced content).
---@return table|nil
local function GetInteractUnit()
    for _, unit in ipairs(INTERACT_UNITS) do
        if UnitExists(unit) then
            local guid = UnitGUID(unit)
            if guid and not OneWoW.Restriction.IsSecret(guid) then
                local unitType, _, _, _, _, unitID = strsplit("-", guid)
                unitID = tonumber(unitID)
                if unitID
                    and (unitType == "Creature"
                        or unitType == "Vehicle"
                        or unitType == "GameObject")
                then
                    return {
                        unitType = unitType,
                        id = unitID,
                        name = UnitName(unit),
                    }
                end
            end
        end
    end
    return nil
end

local function MarkNPCFieldCleared(data, field)
    data[field] = {}
    if field == "starts" then
        data.questGiverID = false
        data.questGiverName = false
        data.questGiverCleared = true
    elseif field == "ends" then
        data.questTurnInID = false
        data.questTurnInName = false
        data.questTurnInCleared = true
    end
end

---@param data table
---@param field string
---@param expectedName string|nil
---@return string
local function CaptureInteractNPC(data, field, expectedName)
    local unit = GetInteractUnit()
    if not unit then
        return "none"
    end

    if expectedName and not NamesMatch(unit.name, expectedName) then
        MarkNPCFieldCleared(data, field)
        return "mismatch"
    end

    if unit.unitType == "GameObject" then
        data[field] = {}
        local objectsField = field == "starts" and "startObjects" or "endObjects"
        local obj = { objectID = unit.id }
        local mapID, x, y = OneWoW.Location.GetPlayerLocation()
        if mapID then
            obj.mapID = mapID
            obj.x = x
            obj.y = y
            data.mapID = data.mapID or mapID
            data.zoneName = data.zoneName or GetMapName(mapID)
        end
        data[objectsField] = { obj }
        return "captured"
    end

    data[field] = { { npcID = unit.id } }
    if field == "starts" then
        data.questGiverID = unit.id
        data.questGiverName = unit.name
    else
        data.questTurnInID = unit.id
        data.questTurnInName = unit.name
    end
    local mapID, x, y = OneWoW.Location.GetPlayerLocation()
    local learn = {
        name = unit.name,
        roles = { "quest_giver" },
        category = "quest_giver",
        mapID = mapID,
        x = x,
        y = y,
        questID = data.id,
    }
    if OneWoW.CatDBSync then
        OneWoW.CatDBSync.LearnNPC(unit.id, learn)
    elseif OneWoW_CatDB_NPCDB_API and OneWoW_CatDB_NPCDB_API.EnsureLearnedNPC then
        OneWoW_CatDB_NPCDB_API.EnsureLearnedNPC(unit.id, learn)
    end
    return "captured"
end

local function CaptureMapData(data, questID)
    local mapID = GetQuestUiMapID(questID)
    if mapID and mapID ~= 0 then
        data.mapID = mapID
        data.zoneName = GetMapName(mapID) or data.zoneName
    end
end

local function CaptureObjectives(data, questID)
    local objectives = C_QuestLog.GetQuestObjectives(questID)
    if not objectives or #objectives == 0 then return end

    local objList, detailList = {}, {}
    for _, obj in ipairs(objectives) do
        if obj.text and obj.text ~= "" then
            tinsert(objList, obj.text)
        end
        tinsert(detailList, {
            text = obj.text,
            objectiveType = obj.type,
            numRequired = obj.numRequired,
        })
    end

    if #objList > 0 then data.objectives = objList end
    if #detailList > 0 then data.objectiveDetails = detailList end
end

local QUEST_LOG_VALUE_FIELDS = {
    "level", "difficultyLevel", "suggestedGroup", "campaignID", "frequency",
}
local QUEST_LOG_BOOL_FIELDS = {
    "isTask", "isBounty", "isStory", "isOnMap", "hasLocalPOI", "isHidden",
    "isScaling", "isAutoComplete", "startEvent",
}

local function CaptureQuestLogFields(data, logInfo)
    if not logInfo then return end

    for _, field in ipairs(QUEST_LOG_VALUE_FIELDS) do
        if logInfo[field] ~= nil then data[field] = logInfo[field] end
    end
    for _, field in ipairs(QUEST_LOG_BOOL_FIELDS) do
        if logInfo[field] ~= nil then data[field] = logInfo[field] and true or false end
    end

    data.suggestedGroup = data.suggestedGroup or 0

    if data.isTask then AddCategory(data, "task") end
    if data.isBounty then AddCategory(data, "bounty") end
    if data.isStory then AddCategory(data, "story") end
    if data.isHidden then AddFlag(data, "hidden") end
    if data.isScaling then AddFlag(data, "scaling") end
    if data.isAutoComplete then AddFlag(data, "auto_complete") end
    if data.hasLocalPOI then AddFlag(data, "local_poi") end
    if data.isOnMap then AddFlag(data, "on_map") end
    if data.startEvent then AddFlag(data, "start_event") end
end

local function CaptureClassification(data, questID, logInfo)
    local classification = C_QuestInfoSystem.GetQuestClassification(questID)
    data.classification = classification

    local QC = Enum.QuestClassification
    if classification == QC.Campaign then
        data.isCampaign = true
        AddCategory(data, "campaign")
    elseif classification == QC.WorldQuest then
        data.isWorldQuest = true
        data.questType = "world"
    elseif classification == QC.Legendary then
        AddCategory(data, "legendary")
    elseif classification == QC.Recurring then
        AddFlag(data, "repeatable")
    elseif classification == QC.Calling then
        AddCategory(data, "calling")
    elseif classification == QC.Meta then
        AddCategory(data, "meta")
    elseif classification == QC.Threat then
        AddCategory(data, "threat")
    elseif classification == QC.Important then
        AddCategory(data, "important")
    end

    local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
    if tagInfo then
        data.tagName = tagInfo.tagName
        data.isElite = tagInfo.isElite or false
        data.tagID = tagInfo.tagID
        if tagInfo.isElite then AddFlag(data, "elite") end

        local tagName = tagInfo.tagName and tagInfo.tagName:lower()
        if tagName then
            if tagName:find("raid", 1, true) then
                data.questType = "raid"
            elseif tagName:find("dungeon", 1, true) then
                data.questType = "dungeon"
            elseif tagName:find("pvp", 1, true) then
                data.questType = "pvp"
            elseif tagName:find("profession", 1, true) then
                data.questType = "profession"
            end
        end
    end

    if logInfo then
        data.frequency = logInfo.frequency
        if logInfo.frequency == Enum.QuestFrequency.Daily then
            data.isDaily = true
            AddFlag(data, "daily")
        elseif logInfo.frequency == Enum.QuestFrequency.Weekly then
            data.isWeekly = true
            AddFlag(data, "weekly")
        end
    end

    data.questType = data.questType or "standard"

    data.sharable = C_QuestLog.IsPushableQuest(questID) and true or false

    local timeLeft = C_TaskQuest.GetQuestTimeLeftSeconds(questID)
    if timeLeft and timeLeft > 0 then
        data.timerSeconds = timeLeft
        AddFlag(data, "timed")
    end
end

local function CaptureRewardSpells(data, questID)
    local spellIDs = C_QuestInfoSystem.GetQuestRewardSpells(questID)
    if spellIDs and #spellIDs > 0 then
        data.rewardSpellIDs = spellIDs
    end
end

local function CaptureRewardCurrencies(data, questID)
    local list = C_QuestInfoSystem.GetQuestRewardCurrencies(questID)
    if not list or #list == 0 then return end

    local currencies = EnsureList(data, "rewardCurrencies")
    for _, c in ipairs(list) do
        local currencyID = c.currencyID
        if currencyID then
            local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
            tinsert(currencies, {
                currencyID = currencyID,
                quantity = c.totalRewardAmount or c.quantity or 1,
                name = info and info.name or c.name,
                icon = info and info.iconFileID or c.texture,
            })
        end
    end

    if #currencies == 0 then data.rewardCurrencies = nil end
end

local function CaptureDialogRewardItems(data)
    local rewardItems = EnsureList(data, "rewardItems")
    local rewardChoices = EnsureList(data, "rewardChoices")

    for i = 1, GetNumQuestRewards() do
        local _, _, _, _, _, itemID = GetQuestItemInfo("reward", i)
        AddUnique(rewardItems, itemID)
    end

    for i = 1, GetNumQuestChoices() do
        local _, _, _, _, _, itemID = GetQuestItemInfo("choice", i)
        if itemID then
            AddUnique(rewardChoices, itemID)
            AddUnique(rewardItems, itemID)
        end
    end

    if #rewardItems == 0 then data.rewardItems = nil end
    if #rewardChoices == 0 then data.rewardChoices = nil end
end

local function CaptureQuestLogRewardItems(data, questID)
    local rewardItems = EnsureList(data, "rewardItems")
    for i = 1, GetNumQuestLogRewards(questID) do
        local _, _, _, _, _, itemID = GetQuestLogRewardInfo(i, questID)
        AddUnique(rewardItems, itemID)
    end

    local rewardChoices = EnsureList(data, "rewardChoices")
    for i = 1, GetNumQuestLogChoices(questID) do
        local _, _, _, _, _, itemID = GetQuestLogChoiceInfo(i, questID)
        if itemID then
            AddUnique(rewardChoices, itemID)
            AddUnique(rewardItems, itemID)
        end
    end

    if #rewardItems == 0 then data.rewardItems = nil end
    if #rewardChoices == 0 then data.rewardChoices = nil end
end

local function CaptureSpecialQuestItem(data, logIndex)
    local itemLink, texture, charges, showWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
    if not itemLink then return end

    data.specialItem = {
        itemID = type(itemLink) == "string" and tonumber(itemLink:match("item:(%d+)")) or nil,
        link = itemLink,
        texture = texture,
        charges = charges,
        showItemWhenComplete = showWhenComplete and true or false,
    }
end

local function CaptureQuestDetailSnapshot()
    local questID = GetQuestID()
    if not questID or questID == 0 then return end

    local unit = GetInteractUnit()
    local sourceName = unit and unit.name

    local data = {
        id = questID,
        name = GetTitleText(),
        description = GetQuestText(),
        objectivesText = GetObjectiveText(),
        sourceName = sourceName,
        capturedFrom = "QUEST_DETAIL",
    }

    local money = GetRewardMoney()
    if money and money > 0 then data.rewardGold = money end
    local xp = GetRewardXP()
    if xp and xp > 0 then data.rewardXP = xp end

    CaptureMapData(data, questID)

    if IsBoardSourcedQuest(data.name, sourceName) then
        MarkNPCFieldCleared(data, "starts")
    elseif CaptureInteractNPC(data, "starts", sourceName) ~= "captured" then
        MarkNPCFieldCleared(data, "starts")
    end

    CaptureDialogRewardItems(data)
    CaptureRewardCurrencies(data, questID)
    CaptureRewardSpells(data, questID)

    pendingQuestDetails[questID] = data
end

local function CaptureQuestTurnInSnapshot(questID, sourceEvent)
    questID = questID or GetQuestID()
    if not questID or questID == 0 then return end

    local unit = GetInteractUnit()
    local sourceName = unit and unit.name

    local data = {
        id = questID,
        name = GetTitleText() or C_QuestLog.GetTitleForQuestID(questID),
        sourceName = sourceName,
        capturedFrom = sourceEvent or "QUEST_COMPLETE",
    }

    local desc = GetQuestText()
    if desc and desc ~= "" then data.description = desc end
    local obj = GetObjectiveText()
    if obj and obj ~= "" then data.objectivesText = obj end

    local money = GetRewardMoney()
    if money and money > 0 then data.rewardGold = money end
    local xp = GetRewardXP()
    if xp and xp > 0 then data.rewardXP = xp end

    CaptureMapData(data, questID)

    if CaptureInteractNPC(data, "ends", sourceName) ~= "captured" and sourceEvent then
        MarkNPCFieldCleared(data, "ends")
    end

    CaptureDialogRewardItems(data)
    CaptureRewardCurrencies(data, questID)
    CaptureRewardSpells(data, questID)

    API.StoreQuestInfo(questID, data)
end

local function CaptureQuestFromLog(questID)
    if not questID then return end

    local data = pendingQuestDetails[questID] or {}
    data.id = questID
    data.name = data.name or C_QuestLog.GetTitleForQuestID(questID)
    data.capturedFrom = data.capturedFrom or "QUEST_LOG"

    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    local logInfo = logIndex and C_QuestLog.GetInfo(logIndex)

    if IsInternalQuest(data.name, logInfo) then
        API.StoreQuestInfo(questID, { id = questID, name = data.name, isInternal = true })
        pendingQuestDetails[questID] = nil
        return
    end

    if IsBoardSourcedQuest(data.name, data.sourceName) then
        MarkNPCFieldCleared(data, "starts")
    end

    CaptureMapData(data, questID)
    CaptureClassification(data, questID, logInfo)
    CaptureQuestLogFields(data, logInfo)

    if logIndex then
        local desc, obj = GetQuestLogQuestText(logIndex)
        if desc and desc ~= "" and not data.description then data.description = desc end
        if obj and obj ~= "" and not data.objectivesText then data.objectivesText = obj end
        CaptureSpecialQuestItem(data, logIndex)
    end

    CaptureObjectives(data, questID)

    local requiredMoney = C_QuestLog.GetRequiredMoney(questID)
    if requiredMoney and requiredMoney > 0 then data.requiredMoney = requiredMoney end

    local rewardMoney = GetQuestLogRewardMoney(questID)
    if rewardMoney and rewardMoney > 0 then data.rewardGold = rewardMoney end
    local rewardXP = GetQuestLogRewardXP(questID)
    if rewardXP and rewardXP > 0 then data.rewardXP = rewardXP end

    CaptureQuestLogRewardItems(data, questID)
    CaptureRewardCurrencies(data, questID)
    CaptureRewardSpells(data, questID)

    API.StoreQuestInfo(questID, data)
    pendingQuestDetails[questID] = nil
end

local function ScanActiveQuestLog()
    local count = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, count do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden and info.questID then
            CaptureQuestFromLog(info.questID)
        end
    end
end

local scanFrame = CreateFrame("Frame")
scanFrame:RegisterEvent("QUEST_DETAIL")
scanFrame:RegisterEvent("QUEST_ACCEPTED")
scanFrame:RegisterEvent("QUEST_PROGRESS")
scanFrame:RegisterEvent("QUEST_COMPLETE")
scanFrame:RegisterEvent("QUEST_TURNED_IN")
scanFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "QUEST_DETAIL" then
        CaptureQuestDetailSnapshot()
    elseif event == "QUEST_ACCEPTED" then
        if type(arg1) == "number" then
            C_Timer.After(0, function() CaptureQuestFromLog(arg1) end)
        end
    elseif event == "QUEST_PROGRESS" then
        CaptureQuestTurnInSnapshot(nil, "QUEST_PROGRESS")
    elseif event == "QUEST_COMPLETE" then
        CaptureQuestTurnInSnapshot(nil, "QUEST_COMPLETE")
    elseif event == "QUEST_TURNED_IN" then
        CaptureQuestTurnInSnapshot(arg1, "QUEST_TURNED_IN")
        if arg1 then
            ns.CompletionTracker:MarkCompleted(arg1)
        end
    end
end)

local function CatchUpOpenQuestDialog()
    local questID = GetQuestID()
    if not questID or questID == 0 then
        return
    end
    if QuestFrameRewardPanel:IsShown() then
        CaptureQuestTurnInSnapshot(questID, "QUEST_COMPLETE")
    elseif QuestFrameProgressPanel:IsShown() then
        CaptureQuestTurnInSnapshot(questID, "QUEST_PROGRESS")
    elseif QuestFrameDetailPanel:IsShown() then
        CaptureQuestDetailSnapshot()
    end
end

function QuestScanner:Initialize()
    CatchUpOpenQuestDialog()
    C_Timer.After(1.5, ScanActiveQuestLog)
end
