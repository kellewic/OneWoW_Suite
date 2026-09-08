local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local pairs, ipairs, type = pairs, ipairs, type
local tonumber, tostring = tonumber, tostring
local tinsert, sort, wipe = tinsert, sort, wipe
local time = time
local C_AddOns = C_AddOns
local C_Map = C_Map
local C_QuestLog = C_QuestLog
local coroutine_yield = coroutine.yield

local ARCHIVE_HUB = "archive"
local ARCHIVE_EXPANSION_MAX = 9

-- Public, cross-addon read surface for QuestDB Current. ns stays private.
OneWoW_CatDB_QuestDBCurrent_API = {}

local API = OneWoW_CatDB_QuestDBCurrent_API

local EXPANSION_NAMES = {
    [0]  = "Classic",
    [1]  = "Burning Crusade",
    [2]  = "Wrath of the Lich King",
    [3]  = "Cataclysm",
    [4]  = "Mists of Pandaria",
    [5]  = "Warlords of Draenor",
    [6]  = "Legion",
    [7]  = "Battle for Azeroth",
    [8]  = "Shadowlands",
    [9]  = "Dragonflight",
    [10] = "The War Within",
    [11] = "Midnight",
    [12] = "Midnight",
}

ns.itemNameCache = ns.itemNameCache or {}

local sortedQueryJob

---@param expansionID number|nil
---@return boolean
local function ExpansionNeedsArchive(expansionID)
    return type(expansionID) == "number"
        and expansionID >= 0
        and expansionID <= ARCHIVE_EXPANSION_MAX
end

local archiveImported = false

local function ImportArchiveData()
    if archiveImported then
        return
    end
    local archiveAPI = OneWoW_CatDB_QuestDBArchive_API
    if not archiveAPI then
        return
    end
    local quests = archiveAPI.GetAllQuests()
    if quests then
        ns:RegisterQuestData(quests)
        archiveImported = true
        if ns.shippedQuestIDs then
            for questID in pairs(quests) do
                ns.shippedQuestIDs[questID] = true
            end
        end
        if ns.ApplyLearnedQuests then
            ns:ApplyLearnedQuests()
        end
    end
end

--- Load Quest Archive when this expansion is Classic-Dragonflight, or when
--- expansionID is -1 / nil (all-quest search).
---@param expansionID number|nil
---@param shouldYield fun(): boolean|nil
---@return boolean loaded
local function EnsureArchiveLoaded(expansionID, shouldYield)
    if expansionID ~= nil and expansionID ~= -1 and not ExpansionNeedsArchive(expansionID) then
        return true
    end
    OneWoW:EnsureCatalogPack("archive")
    if shouldYield then
        coroutine_yield()
    end
    return true
end

local function CopyQuestIDList(src)
    local out = {}
    if type(src) ~= "table" then
        return out
    end
    for i = 1, #src do
        local id = tonumber(src[i])
        if id then
            tinsert(out, id)
        end
    end
    return out
end

local function HasValue(tbl, value)
    if type(tbl) ~= "table" then
        return false
    end
    for i = 1, #tbl do
        if tbl[i] == value then
            return true
        end
    end
    return false
end

local function HasAnyValue(tbl)
    return type(tbl) == "table" and #tbl > 0
end

local function QuestAssociatedWithNPC(quest, npcID)
    npcID = tonumber(npcID)
    if not quest or not npcID then
        return false
    end
    if tonumber(quest.questGiverID) == npcID or tonumber(quest.questTurnInID) == npcID then
        return true
    end
    local function listHasNPC(list)
        if not list then
            return false
        end
        for i = 1, #list do
            local entry = list[i]
            if type(entry) == "table" and tonumber(entry.npcID) == npcID then
                return true
            end
            if tonumber(entry) == npcID then
                return true
            end
        end
        return false
    end
    return listHasNPC(quest.starts) or listHasNPC(quest.ends)
end

local function QuestZoneName(quest)
    if quest.zoneName and quest.zoneName ~= "" then
        return quest.zoneName
    end
    if quest.mapID then
        local info = C_Map.GetMapInfo(quest.mapID)
        if info and info.name then
            return info.name
        end
    end
    return nil
end

local function HasNormalizedValue(tbl, value)
    if type(tbl) ~= "table" or not value then
        return false
    end
    value = tostring(value):lower()
    for i = 1, #tbl do
        if tostring(tbl[i]):lower() == value then
            return true
        end
    end
    return false
end

---@param npcID number|nil
---@return boolean
local function NPCHasLocation(npcID)
    if not npcID then
        return false
    end
    local npcAPI = OneWoW:GetCatalogPackAPI("vendors")
    if not npcAPI then
        return true
    end
    local npc = npcAPI.GetNPC(npcID)
    if not npc or not npc.locations then
        return false
    end
    for _, loc in pairs(npc.locations) do
        if loc and loc.x and loc.y then
            return true
        end
    end
    return false
end

---@param quest table
---@return boolean
local function QuestNPCHasLocation(quest)
    local startNPC = quest.starts and quest.starts[1] and quest.starts[1].npcID
    if NPCHasLocation(startNPC) then
        return true
    end
    local endNPC = quest.ends and quest.ends[1] and quest.ends[1].npcID
    return NPCHasLocation(endNPC)
end

local function QuestMatches(quest, expansionFilter, zoneFilter, typeFilter, questTypeFilter, searchText, advancedFilters)
    advancedFilters = advancedFilters or {}
    typeFilter = advancedFilters.groupType or typeFilter
    questTypeFilter = advancedFilters.questType or questTypeFilter

    if expansionFilter and expansionFilter ~= -1 and quest.expansion ~= expansionFilter then
        return false
    end
    if zoneFilter and zoneFilter ~= "" and zoneFilter ~= "all" then
        if QuestZoneName(quest) ~= zoneFilter then
            return false
        end
    end
    if typeFilter and typeFilter ~= "all" then
        local sg = quest.suggestedGroup or 0
        if typeFilter == "solo" and sg >= 2 then
            return false
        elseif typeFilter == "group" and (sg < 2 or sg >= 10) then
            return false
        elseif typeFilter == "raid" and sg < 10 then
            return false
        end
    end
    if questTypeFilter and questTypeFilter ~= "all" and quest.questType ~= questTypeFilter then
        return false
    end
    if searchText and searchText ~= "" then
        local needle = searchText:lower():gsub("^\"+", ""):gsub("\"+$", "")
        local name = quest.name and quest.name:lower() or ""
        local idStr = tostring(quest.id or "")
        if needle ~= ""
            and needle ~= idStr
            and not name:find(needle, 1, true)
            and not idStr:find(needle, 1, true)
        then
            local desc = quest.description and quest.description:lower() or ""
            if not desc:find(needle, 1, true) then
                return false
            end
        end
    end
    if advancedFilters.category and advancedFilters.category ~= "all" then
        if not HasValue(quest.categories, advancedFilters.category) then
            return false
        end
    end
    if advancedFilters.flag and advancedFilters.flag ~= "all" then
        if not HasValue(quest.flags, advancedFilters.flag) then
            return false
        end
    end
    if advancedFilters.profession and advancedFilters.profession ~= "all" then
        if not HasNormalizedValue(quest.requiredProfessions, advancedFilters.profession) then
            return false
        end
    end
    if advancedFilters.class and advancedFilters.class ~= "all" then
        if not HasNormalizedValue(quest.requiredClasses, advancedFilters.class) then
            return false
        end
    end
    if advancedFilters.race and advancedFilters.race ~= "all" then
        if not HasNormalizedValue(quest.requiredRaces, advancedFilters.race) then
            return false
        end
    end
    if advancedFilters.faction and advancedFilters.faction ~= "all" then
        if quest.faction and quest.faction ~= "both" and quest.faction ~= advancedFilters.faction then
            return false
        end
    end
    if advancedFilters.story and advancedFilters.story ~= "all" then
        local hasQuestLine = HasAnyValue(quest.questLines)
        local hasStoryline = HasAnyValue(quest.storyline) or hasQuestLine
        local hasSeries = HasAnyValue(quest.series)
        local hasCampaign = HasAnyValue(quest.campaigns)
        if advancedFilters.story == "campaign" and not hasCampaign then
            return false
        elseif advancedFilters.story == "storyline" and not hasStoryline then
            return false
        elseif advancedFilters.story == "chain" and not hasSeries then
            return false
        elseif advancedFilters.story == "standalone" and (hasCampaign or hasStoryline or hasSeries) then
            return false
        end
    end
    if advancedFilters.npcID and not QuestAssociatedWithNPC(quest, advancedFilters.npcID) then
        return false
    end
    if advancedFilters.runtime and advancedFilters.runtime ~= "all" and advancedFilters.runtime ~= "favorite" then
        local hasStarter = (quest.starts and quest.starts[1] and quest.starts[1].npcID)
            or (quest.startObjects and quest.startObjects[1])
        local hasEnder = (quest.ends and quest.ends[1] and quest.ends[1].npcID)
            or (quest.endObjects and quest.endObjects[1])
        local hasLocation =
            (quest.coords and quest.coords.mapID and quest.coords.x and quest.coords.y)
            or (quest.starts and quest.starts[1] and quest.starts[1].mapID and quest.starts[1].x and quest.starts[1].y)
            or (quest.ends and quest.ends[1] and quest.ends[1].mapID and quest.ends[1].x and quest.ends[1].y)
            or (quest.startObjects and quest.startObjects[1] and quest.startObjects[1].mapID and quest.startObjects[1].x and quest.startObjects[1].y)
            or (quest.endObjects and quest.endObjects[1] and quest.endObjects[1].mapID and quest.endObjects[1].x and quest.endObjects[1].y)
            or QuestNPCHasLocation(quest)
        if advancedFilters.runtime == "has_location" then
            if not hasLocation then
                return false
            end
        elseif advancedFilters.runtime == "missing_location" then
            if hasLocation then
                return false
            end
        elseif advancedFilters.runtime == "has_quest_giver" then
            if not hasStarter then
                return false
            end
        elseif advancedFilters.runtime == "has_turnin" then
            if not hasEnder then
                return false
            end
        elseif advancedFilters.runtime == "has_reward_choices" then
            if not (quest.rewardChoices and #quest.rewardChoices > 0) then
                return false
            end
        elseif advancedFilters.runtime == "has_rewards" then
            if not (
                (quest.rewardGold and quest.rewardGold > 0)
                or (quest.rewardXP and quest.rewardXP > 0)
                or (quest.rewardItems and #quest.rewardItems > 0)
                or (quest.rewardChoices and #quest.rewardChoices > 0)
                or (quest.rewardCurrencies and #quest.rewardCurrencies > 0)
            ) then
                return false
            end
        end
    end
    return true
end

local function CompareQuests(a, b)
    local expA, expB = a.expansion or 0, b.expansion or 0
    if expA ~= expB then
        return expA < expB
    end
    local nameA, nameB = a.name or "", b.name or ""
    if nameA ~= nameB then
        return nameA < nameB
    end
    return (a.id or 0) < (b.id or 0)
end

---@param advancedFilters table|nil
local function EnsureNPCDBForLocationFilter(advancedFilters)
    local runtime = advancedFilters and advancedFilters.runtime
    if runtime ~= "has_location" and runtime ~= "missing_location" then
        return
    end
    if not OneWoW:GetCatalogPackAPI("vendors") then
        OneWoW:EnsureCatalogPack("vendors")
    end
end

local function FillSortedQuests(expansionFilter, zoneFilter, typeFilter, questTypeFilter, searchText, advancedFilters, results, shouldYield)
    EnsureNPCDBForLocationFilter(advancedFilters)
    wipe(results)
    local source
    if expansionFilter and expansionFilter ~= -1 then
        source = ns.ExternalQuestDBByExpansion[expansionFilter]
    else
        source = ns.ExternalQuestDB
    end
    if not source then
        return
    end
    local YieldIfNeeded = OneWoW.ChunkedJob.YieldIfNeeded
    for _, quest in pairs(source) do
        if QuestMatches(quest, expansionFilter, zoneFilter, typeFilter, questTypeFilter, searchText, advancedFilters) then
            tinsert(results, quest)
        end
        YieldIfNeeded(shouldYield)
    end
    OneWoW.ChunkedJob.Sort(results, CompareQuests, shouldYield)
end

--- Returns the store settings.
---@return table settings
function API.GetSettings()
    return ns:GetSettings()
end

--- One quest record from shards already in memory.
---@param questID number
---@return table|nil quest
function API.GetQuest(questID)
    return ns.ExternalQuestDB[questID]
end

--- Merge extra quest shards into the hot quest DB.
---@param source table<number, table>
function API.ImportQuestData(source)
    ns:RegisterQuestData(source)
end

--- Load the archive pack, then run callback.
---@param callback function
function API.EnsureArchiveThen(callback)
    OneWoW:EnsureCatalogPack("archive")
    if callback then
        callback()
    end
end

--- All quest records keyed by quest ID.
---@return table quests
function API.GetAllQuests()
    return ns.ExternalQuestDB
end

--- Total shipped quest count.
---@return number count
function API.GetQuestCount()
    local n = 0
    for _ in pairs(ns.ExternalQuestDB) do
        n = n + 1
    end
    return n
end

--- Same as GetQuestCount (old Quests pack aliased the two).
---@return number count
function API.GetCapturedQuestCount()
    return API.GetQuestCount()
end

--- Quests associated with an NPC.
---@param npcID number
---@return table|nil quests
function API.GetQuestsForNPC(npcID)
    return ns.QuestsByNPC[npcID]
end

--- Quests for one expansion. `-1` / nil returns the full DB.
---@param expansionID number|nil
---@return table quests
function API.GetQuestsForExpansion(expansionID)
    if ExpansionNeedsArchive(expansionID) then
        EnsureArchiveLoaded(expansionID)
    end
    if expansionID == nil or expansionID == -1 then
        return ns.ExternalQuestDB
    end
    return ns.ExternalQuestDBByExpansion[expansionID] or {}
end

--- Sorted list for Catalog.
---@return table quests
function API.GetSortedQuests(expansionFilter, zoneFilter, typeFilter, questTypeFilter, searchText, advancedFilters)
    if ExpansionNeedsArchive(expansionFilter) then
        EnsureArchiveLoaded(expansionFilter)
    end
    local results = {}
    FillSortedQuests(expansionFilter, zoneFilter, typeFilter, questTypeFilter, searchText, advancedFilters, results, nil)
    return results
end

function API.CancelSortedQuery()
    if sortedQueryJob then
        sortedQueryJob:Cancel()
        sortedQueryJob = nil
    end
end

--- Time-sliced sorted query into outResults.
---@return table jobHandle
function API.StartSortedQuests(...)
    local expansionFilter, zoneFilter, typeFilter, questTypeFilter, searchText, advancedFilters, outResults, opts = ...
    opts = opts or {}
    if type(outResults) ~= "table" then
        error("StartSortedQuests requires an outResults table", 2)
    end
    API.CancelSortedQuery()
    wipe(outResults)
    local job
    job = OneWoW.ChunkedJob.Start({
        budgetMs = opts.budgetMs,
        run = function(shouldYield)
            local search = searchText and tostring(searchText) or ""
            if search ~= "" and (expansionFilter == -1 or expansionFilter == nil) then
                EnsureArchiveLoaded(-1, shouldYield)
            elseif ExpansionNeedsArchive(expansionFilter) then
                EnsureArchiveLoaded(expansionFilter, shouldYield)
            end
            FillSortedQuests(
                expansionFilter,
                zoneFilter,
                typeFilter,
                questTypeFilter,
                searchText,
                advancedFilters,
                outResults,
                shouldYield
            )
        end,
        onProgress = opts.onProgress,
        onComplete = function()
            if sortedQueryJob == job then
                sortedQueryJob = nil
            end
            if opts.onComplete then
                opts.onComplete(outResults)
            end
        end,
        onCancel = function()
            if sortedQueryJob == job then
                sortedQueryJob = nil
            end
            if opts.onCancel then
                opts.onCancel()
            end
        end,
    })
    sortedQueryJob = job
    return job
end

---@param expansionID number
---@return string|nil name
function API.GetExpansionName(expansionID)
    return EXPANSION_NAMES[expansionID] or OneWoW:GetExpansionName(expansionID)
end

---@return table expansions
function API.GetAvailableExpansions()
    local found = {}
    for expID in pairs(ns.ExternalQuestDBByExpansion) do
        found[expID] = true
    end
    local archiveName = C_AddOns.GetAddOnInfo("OneWoW_Catalog")
    if archiveName and archiveName ~= "" then
        for expID = 0, ARCHIVE_EXPANSION_MAX do
            found[expID] = true
        end
    end
    local result = {}
    for expID in pairs(found) do
        tinsert(result, {
            id = expID,
            name = API.GetExpansionName(expID) or tostring(expID),
        })
    end
    sort(result, function(a, b)
        return a.id < b.id
    end)
    return result
end

---@param expansionID number|nil
---@return table zones
function API.GetAvailableZones(expansionID)
    local source = API.GetQuestsForExpansion(expansionID)
    local found = {}
    for _, quest in pairs(source) do
        local zoneName = QuestZoneName(quest)
        if zoneName and zoneName ~= "" then
            found[zoneName] = true
        end
    end
    local result = {}
    for zoneName in pairs(found) do
        tinsert(result, zoneName)
    end
    sort(result)
    return result
end

local LEARNED_QUEST_KEYS = {
    "name", "starts", "ends", "startObjects", "endObjects",
    "rewardItems", "rewardChoices", "packageItems", "rewardGold", "rewardXP",
    "description", "objectivesText", "objectives", "objectiveDetails",
    "expansion", "mapID", "zoneName",
    "questGiverID", "questTurnInID",
    "flags", "categories", "questType", "classification",
    "rewardSpellIDs", "rewardCurrencies",
    "level", "suggestedGroup", "frequency",
    "isCampaign", "isWorldQuest", "isDaily", "isWeekly",
}

local function NPCIDSet(list)
    local set = {}
    if type(list) ~= "table" then
        return set
    end
    for _, entry in pairs(list) do
        local id
        if type(entry) == "table" then
            id = entry.npcID or entry.objectID
        else
            id = entry
        end
        id = tonumber(id)
        if id then
            set[id] = true
        end
    end
    return set
end

local function RewardIDSet(list)
    local set = {}
    if type(list) ~= "table" then
        return set
    end
    for _, entry in pairs(list) do
        local id
        if type(entry) == "number" then
            id = entry
        elseif type(entry) == "table" then
            id = entry.itemID or entry.currencyID or entry.id
        end
        id = tonumber(id)
        if id then
            set[id] = true
        end
    end
    return set
end

local function SetHasNew(oldSet, newSet)
    for id in pairs(newSet) do
        if not oldSet[id] then
            return true
        end
    end
    return false
end

local function TextIsNew(old, new)
    return type(new) == "string" and new ~= "" and (type(old) ~= "string" or old == "")
end

local function HasNewQuestFacts(existing, data)
    if not existing then
        return true
    end
    if TextIsNew(existing.name, data.name) then
        return true
    end
    if TextIsNew(existing.description, data.description) then
        return true
    end
    if TextIsNew(existing.objectivesText, data.objectivesText) then
        return true
    end
    if data.mapID and not existing.mapID then
        return true
    end
    if SetHasNew(NPCIDSet(existing.starts), NPCIDSet(data.starts)) then
        return true
    end
    if SetHasNew(NPCIDSet(existing.ends), NPCIDSet(data.ends)) then
        return true
    end
    if SetHasNew(NPCIDSet(existing.startObjects), NPCIDSet(data.startObjects)) then
        return true
    end
    if SetHasNew(NPCIDSet(existing.endObjects), NPCIDSet(data.endObjects)) then
        return true
    end
    if SetHasNew(RewardIDSet(existing.rewardItems), RewardIDSet(data.rewardItems)) then
        return true
    end
    if SetHasNew(RewardIDSet(existing.rewardChoices), RewardIDSet(data.rewardChoices)) then
        return true
    end
    if SetHasNew(RewardIDSet(existing.packageItems), RewardIDSet(data.packageItems)) then
        return true
    end
    if SetHasNew(RewardIDSet(existing.rewardCurrencies), RewardIDSet(data.rewardCurrencies)) then
        return true
    end
    if SetHasNew(RewardIDSet(existing.rewardSpellIDs), RewardIDSet(data.rewardSpellIDs)) then
        return true
    end
    return false
end

function ns:SnapshotShippedQuestIDs()
    if ns.shippedQuestIDs then
        return
    end
    ns.shippedQuestIDs = {}
    for questID in pairs(ns.ExternalQuestDB) do
        ns.shippedQuestIDs[questID] = true
    end
end

local function PersistLearnedQuest(questID, data)
    if data.isInternal then
        return
    end
    if not ns.questDb then
        return
    end
    local existing = ns.ExternalQuestDB[questID]
    if existing and not HasNewQuestFacts(existing, data) then
        return
    end
    local db = ns:GetQuestDB()
    db.learned = db.learned or {}
    local rec = db.learned[questID] or { id = questID, learnedAt = time() }
    rec.id = questID
    rec.learnedAt = rec.learnedAt or time()
    rec.sync = true
    if not (ns.shippedQuestIDs and ns.shippedQuestIDs[questID]) then
        rec.unknown = true
    end
    for i = 1, #LEARNED_QUEST_KEYS do
        local key = LEARNED_QUEST_KEYS[i]
        if data[key] ~= nil then
            rec[key] = data[key]
        end
    end
    db.learned[questID] = rec
end

function ns:ApplyLearnedQuests()
    local learned = ns.questDb and ns:GetQuestDB().learned
    if type(learned) ~= "table" then
        return
    end
    for questID, rec in pairs(learned) do
        if type(questID) == "number" and type(rec) == "table" then
            API.StoreQuestInfo(questID, rec, { skipPersist = true })
        end
    end
end

---@return table
function API.GetSyncQueue()
    local out = {}
    local learned = ns.questDb and ns:GetQuestDB().learned
    if type(learned) ~= "table" then
        return out
    end
    for questID, rec in pairs(learned) do
        if type(rec) == "table" and rec.sync then
            out[questID] = rec
        end
    end
    return out
end

---@param questID number
---@param data table
---@param opts table|nil
function API.StoreQuestInfo(questID, data, opts)
    if not questID or type(data) ~= "table" then
        return
    end
    local persist = not (opts and opts.skipPersist)
    if persist then
        PersistLearnedQuest(questID, data)
    end
    local quest = ns.ExternalQuestDB[questID]
    if not quest then
        data.id = data.id or questID
        ns:RegisterQuestData({ [questID] = data })
        return
    end
    for key, value in pairs(data) do
        quest[key] = value
    end
end

---@param questID number
---@param data table
function API.StoreQuestInfoQuiet(questID, data)
    API.StoreQuestInfo(questID, data)
end

---@param itemID number
---@param itemName string
function API.RememberItemName(itemID, itemName)
    if itemID and itemName and itemName ~= "" then
        ns.itemNameCache[itemID] = itemName
    end
end

---@param itemID number
---@return string|nil itemName
function API.GetCachedItemName(itemID)
    return ns.itemNameCache[itemID]
end

---@param shouldYield fun(): boolean|nil
---@return number[] itemIDs
function API.GetRewardItemIDs(shouldYield)
    EnsureArchiveLoaded(-1, shouldYield)
    local out = {}
    local YieldIfNeeded = OneWoW.ChunkedJob.YieldIfNeeded
    for itemID in pairs(ns.QuestsByRewardItem) do
        tinsert(out, itemID)
        YieldIfNeeded(shouldYield)
    end
    return out
end

--- Quest IDs that reward an item.
---@param itemID number
---@param loadArchive boolean|nil
---@return number[]|nil questIDs
function API.GetQuestsRewardingItem(itemID, loadArchive)
    if loadArchive then
        EnsureArchiveLoaded(-1)
    end
    return ns.QuestsByRewardItem[itemID]
end

local function QuestIDListContains(ids, questID)
    for i = 1, #ids do
        if ids[i] == questID then
            return true
        end
    end
    return false
end

local function InsertQuestIDByNumber(ids, questID)
    local out = {}
    local inserted = false
    for i = 1, #ids do
        local id = ids[i]
        if not inserted and questID < id then
            tinsert(out, questID)
            inserted = true
        end
        tinsert(out, id)
    end
    if not inserted then
        tinsert(out, questID)
    end
    return out
end

--- Shipped series omits the viewed quest. Rebuild table order from this list
--- plus each peer's series.
---@param questID number
---@param series number[]
---@return number[]
local function RestoreSeriesChain(questID, series)
    if QuestIDListContains(series, questID) then
        return series
    end

    local nodes = { questID }
    local nodeSet = { [questID] = true }
    for i = 1, #series do
        local id = series[i]
        if not nodeSet[id] then
            nodeSet[id] = true
            tinsert(nodes, id)
        end
    end

    local indegree = {}
    local successors = {}
    local succSet = {}
    for i = 1, #nodes do
        local id = nodes[i]
        indegree[id] = 0
        successors[id] = {}
        succSet[id] = {}
    end

    local function addOrder(list)
        for i = 1, #list - 1 do
            local a = list[i]
            local b = list[i + 1]
            if nodeSet[a] and nodeSet[b] and a ~= b and not succSet[a][b] then
                succSet[a][b] = true
                tinsert(successors[a], b)
                indegree[b] = indegree[b] + 1
            end
        end
    end

    addOrder(series)
    for i = 1, #series do
        local peer = API.GetQuest(series[i])
        if peer then
            addOrder(CopyQuestIDList(peer.series))
        end
    end

    local used = {}
    local ordered = {}
    for _ = 1, #nodes do
        local best
        for i = 1, #nodes do
            local id = nodes[i]
            if not used[id] and indegree[id] == 0 then
                if not best or id < best then
                    best = id
                end
            end
        end
        if not best then
            break
        end
        used[best] = true
        tinsert(ordered, best)
        local succs = successors[best]
        for s = 1, #succs do
            indegree[succs[s]] = indegree[succs[s]] - 1
        end
    end

    if #ordered < #nodes then
        return InsertQuestIDByNumber(series, questID)
    end
    return ordered
end

--- Ordered quest IDs for a QuestLine (all expansions; loaded with Current).
---@param lineID number
---@return number[]|nil
function API.GetQuestLineMembers(lineID)
    local members = ns.QuestLineMembers and ns.QuestLineMembers[lineID]
    if type(members) ~= "table" then
        return nil
    end
    return members
end

---@param quest table|number
---@return number[]|nil
function API.GetQuestGuideChain(quest)
    if type(quest) ~= "table" then
        quest = API.GetQuest(quest)
    end
    if not quest then
        return nil
    end
    for _, line in ipairs(quest.questLines or {}) do
        local members = line.id and API.GetQuestLineMembers(line.id)
        if members and #members >= 2 then
            return CopyQuestIDList(members)
        end
    end
    local storyline = CopyQuestIDList(quest.storyline)
    if #storyline >= 2 then
        return storyline
    end
    local series = CopyQuestIDList(quest.series)
    local questID = tonumber(quest.id)
    if questID then
        local ids = RestoreSeriesChain(questID, series)
        if #ids >= 2 then
            return ids
        end
    elseif #series >= 2 then
        return series
    end
    local chain = CopyQuestIDList(quest.sourceQuests)
    if questID then
        local seen = {}
        for i = 1, #chain do
            seen[chain[i]] = true
        end
        if not seen[questID] then
            tinsert(chain, questID)
            seen[questID] = true
        end
        for _, id in ipairs(CopyQuestIDList(quest.nextQuests)) do
            if not seen[id] then
                seen[id] = true
                tinsert(chain, id)
            end
        end
    end
    if #chain >= 2 then
        return chain
    end
    return nil
end

---@param questID number
---@return table
function API.GetCompletedCharacters(questID)
    return ns.CompletionTracker:GetCompletedCharacters(questID)
end

---@param questID number
---@return table
function API.GetActiveCharacters(questID)
    return ns.CompletionTracker:GetActiveCharacters(questID)
end

---@param questID number
---@return boolean
function API.IsCompletedByCurrentChar(questID)
    return ns.CompletionTracker:IsCompletedByCurrentChar(questID)
end

---@return string[]
function API.GetTrackedCharacterKeys()
    return ns.CompletionTracker:GetTrackedCharacterKeys()
end

---@param charKey string
---@return boolean
function API.PurgeCharacter(charKey)
    return ns.CompletionTracker:PurgeCharacter(charKey)
end

local pendingQuestNames = {}

local questNameFrame = CreateFrame("Frame")
questNameFrame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
questNameFrame:SetScript("OnEvent", function(_, _, questID, success)
    local cbs = pendingQuestNames[questID]
    if not cbs then
        return
    end
    pendingQuestNames[questID] = nil
    local name = success and API.GetQuestName(questID) or nil
    for i = 1, #cbs do
        xpcall(cbs[i], CallErrorHandler, questID, name)
    end
end)

---@param questID number
---@return string|nil name
function API.GetQuestName(questID)
    questID = tonumber(questID)
    if not questID then
        return nil
    end
    local quest = ns.ExternalQuestDB[questID]
    if quest and quest.name and quest.name ~= "" then
        return quest.name
    end
    local name = C_QuestLog.GetTitleForQuestID(questID)
    if name and name ~= "" then
        return name
    end
    name = QuestUtils_GetQuestName(questID)
    if name and name ~= "" then
        return name
    end
    return nil
end

---@param questID number
---@param callback fun(questID: number, name: string|nil)|nil
---@return string|nil name
function API.RequestQuestName(questID, callback)
    questID = tonumber(questID)
    if not questID then
        if callback then
            callback(questID, nil)
        end
        return nil
    end
    local name = API.GetQuestName(questID)
    if name then
        if callback then
            callback(questID, name)
        end
        return name
    end
    if callback then
        local list = pendingQuestNames[questID]
        if not list then
            list = {}
            pendingQuestNames[questID] = list
        end
        tinsert(list, callback)
    end
    C_QuestLog.RequestLoadQuestByID(questID)
    return nil
end

OneWoW_GUI:RegisterEntityResolver("quest", {
    Resolve = function(id)
        return API.GetQuestName(id)
    end,
    RequestAsync = function(id, cb)
        API.RequestQuestName(id, function(questID, name)
            cb(questID, name and { name = name } or nil)
        end)
    end,
})

OneWoW_CatDB_QuestDBArchive_API = OneWoW_CatDB_QuestDBCurrent_API
