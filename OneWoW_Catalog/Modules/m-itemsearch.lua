local _, ns = ...

local pairs, ipairs = pairs, ipairs
local tinsert, sort, wipe = tinsert, sort, wipe
local C_Item, C_TradeSkillUI = C_Item, C_TradeSkillUI

ns.ItemSearch = {}
local ItemSearch = ns.ItemSearch

local function GetRecipeKnownByFromAltTracker(itemID)
    local profsAPI = OneWoW_AltTracker_Professions_API
    if not profsAPI then return nil end
    local profChars = profsAPI.GetAllCharacters()

    local recipeItemMap = profsAPI.GetRecipeItemMap()
    local recipeSpellID
    if recipeItemMap and recipeItemMap[itemID] then
        recipeSpellID = recipeItemMap[itemID]
    end

    if not recipeSpellID then
        local _, spellID = C_Item.GetItemSpell(itemID)
        if spellID then recipeSpellID = spellID end
    end

    local knownBy = {}
    local seen = {}

    if recipeSpellID then
        for charKey, charData in pairs(profChars) do
            if charData.recipes then
                for _, recipeSet in pairs(charData.recipes) do
                    if recipeSet[recipeSpellID] and not seen[charKey] then
                        seen[charKey] = true
                        tinsert(knownBy, charKey)
                    end
                end
            end
        end
    end

    if #knownBy == 0 then
        local itemName = C_Item.GetItemNameByID(itemID)
        if itemName then
            local craftedName = itemName:match("^%S+:%s*(.+)$") or itemName
            for charKey, charData in pairs(profChars) do
                if charData.recipes and not seen[charKey] then
                    for _, recipeSet in pairs(charData.recipes) do
                        for storedID in pairs(recipeSet) do
                            local info = C_TradeSkillUI.GetRecipeInfo(storedID)
                            if info and info.name == craftedName then
                                profsAPI.SetRecipeItemMapEntry(itemID, storedID)
                                if not seen[charKey] then
                                    seen[charKey] = true
                                    tinsert(knownBy, charKey)
                                end
                                break
                            end
                        end
                        if seen[charKey] then break end
                    end
                end
            end
        end
    end

    sort(knownBy)
    return knownBy
end

-- The localized item name is embedded in every hyperlink's "[Name]" segment, so
-- it can be recovered offline without touching the live item cache.
local function NameFromLink(itemLink)
    if type(itemLink) ~= "string" then return nil end
    return itemLink:match("%[(.-)%]")
end

-- Storage location type -> the locLabel key the item-search UI displays. The
-- Storage Query layer emits "auction"; the UI's label map uses "ah". Types not
-- listed here (bags/bank/mail/guild) pass through unchanged.
local LOC_TYPE_TO_LABEL = {
    auction = "ah",
}

local INDEX_LOC_TO_LABEL = {
    bags = "bags",
    bank = "bank",
    equipped = "bags",
    warband = "warband",
    guild = "guild",
    mail = "mail",
    auction = "ah",
}

--- Per-item owned snapshot. Uses Storage's inverted index; does not Gather.
---@param itemID number
---@return table|nil
local function GetOwnedTooltip(itemID)
    local storageAPI = OneWoW_AltTracker_Storage_API
    if not storageAPI then
        return nil
    end
    return storageAPI.GetItemIndex():GetTooltipData(itemID)
end

---@param loc table
---@return string|nil
---@return string|nil
local function OwnedLocDisplay(loc)
    local locType = loc.locationType or loc.locLabel
    local locLabel = INDEX_LOC_TO_LABEL[locType] or LOC_TYPE_TO_LABEL[locType] or locType
    local charName
    if locType == "warband" then
        charName = "Warband"
    elseif locType == "guild" then
        charName = loc.guildName
    else
        charName = loc.name or loc.charName
    end
    return charName, locLabel
end

-- Full owned rollup. Only the Owned filter's empty browse uses this; search and
-- detail look up one itemID on Storage's index.
local function GetOwnedItems(shouldYield)
    local owned = {}
    local storageAPI = OneWoW_AltTracker_Storage_API
    if not storageAPI or not storageAPI.Gather then return owned end

    local YieldIfNeeded = OneWoW.ChunkedJob.YieldIfNeeded
    local instances = storageAPI.Gather({
        chars = "all",
        containers = { bags = true, personal = true, warband = true, guild = true, mail = true, auction = true },
    })

    for _, inst in ipairs(instances) do
        local itemID = inst.itemID
        if itemID then
            local where = inst.where or {}
            local locType = where.type
            local locLabel = LOC_TYPE_TO_LABEL[locType] or locType

            local charName
            if locType == "warband" then
                charName = "Warband"
            elseif locType == "guild" then
                charName = where.guildName
            else
                charName = where.charName
            end

            local count = inst.count or 1
            local rec = owned[itemID]
            if not rec then
                rec = { total = 0, locations = {} }
                owned[itemID] = rec
            end
            rec.total = rec.total + count

            if not rec.name then
                local name = inst.name or NameFromLink(inst.itemLink)
                if name and name ~= "" then
                    rec.name = name
                end
            end

            tinsert(rec.locations, { charName = charName, locLabel = locLabel, count = count })
        end
        YieldIfNeeded(shouldYield)
    end

    return owned
end

-- Per-filter data availability. Opening the tab loads the active filter's
-- packs (ItemDB for All / Drops). Buttons stay dim until that pack is ready.
-- Shared by Query (source gating) and the UI so the two cannot drift.
local SOURCE_AVAILABILITY = {
    all     = function() return true end,
    drops   = function()
        -- Drop names come from ItemDB; without it the journal name index
        -- is empty and Drops / All look broken.
        return ns.GetCatalogPackAPI("journal") ~= nil
            and ns.GetCatalogPackAPI("items") ~= nil
    end,
    vendors = function() return ns.GetCatalogPackAPI("vendors") ~= nil end,
    crafted = function() return ns.GetCatalogPackAPI("tradeskills") ~= nil end,
    owned   = function() return OneWoW_AltTracker_Storage_API ~= nil end,
    quests  = function() return ns.GetCatalogPackAPI("quests") ~= nil end,
}

function ItemSearch:IsSourceAvailable(sourceKey)
    local fn = SOURCE_AVAILABILITY[sourceKey]
    if not fn then return true end
    return fn() and true or false
end

-- The backing data addons this tab aggregates. Resolved at call time.
local FILTER_PACK_ROLE = {
    drops   = "journal",
    vendors = "vendors",
    crafted = "tradeskills",
    quests  = "quests",
}

--- Deduped addons for data-ready watchers.
---@return string[]
function ItemSearch.GetSourceAddons()
    return ns.GetCatalogItemSearchAddons()
end

--- Addon that backs one Item Search source filter. All maps to ItemDB.
---@param filterKey string
---@return string|nil
function ItemSearch.GetSourceAddon(filterKey)
    if filterKey == "owned" then
        return "OneWoW_AltTracker_Storage"
    end
    if filterKey == "all" then
        return ns.ResolveCatalogPack("items")
    end
    local role = FILTER_PACK_ROLE[filterKey]
    if not role then
        return nil
    end
    return ns.ResolveCatalogPack(role)
end

--- Packs this filter needs loaded. All and Drops include ItemDB.
---@param filterKey string
---@return string[]
function ItemSearch.GetFilterPacks(filterKey)
    local out = {}
    local seen = {}
    local function add(name)
        if name and not seen[name] then
            seen[name] = true
            out[#out + 1] = name
        end
    end
    if filterKey == "all" or filterKey == "drops" then
        add(ns.ResolveCatalogPack("items"))
    end
    local addon = ItemSearch.GetSourceAddon(filterKey)
    if addon then
        add(addon)
    end
    return out
end

--- Load the packs for this filter. Opening the tab or changing filter is the
--- explicit action; do not wait for another tab to have loaded them.
---@param filterKey string
---@param onUpdate function|nil
function ItemSearch.EnsureFilterPacks(filterKey, onUpdate)
    if filterKey == "all" or filterKey == "drops" then
        OneWoW:EnsureCatalogPack("items")
        OneWoW:EnsureCatalogRoleShardsForFilter("items", 0, onUpdate)
    end
    local role = FILTER_PACK_ROLE[filterKey]
    if role == "tradeskills" then
        OneWoW:EnsureCatalogPack("tradeskills")
    elseif role then
        OneWoW:EnsureCatalogPack(role)
        OneWoW:EnsureCatalogRoleShardsForFilter(role, 0, onUpdate)
    end
    if filterKey == "owned" then
        OneWoW:EnsureLoaded("OneWoW_AltTracker_Storage")
    end
end

-- Fill `results` from sources. Empty / 1-char browse never builds ZoneDB drop
-- indexes or walks all vendors / recipes / quest rewards. Name search walks
-- ItemDB (already in memory) and uses per-item lookups. `shouldYield` keeps
-- large walks off the hitch path.
local function BuildQueryResults(self, searchTerm, sourceFilter, results, shouldYield)
    wipe(results)
    local yieldCheck = shouldYield or function() return false end
    local YieldIfNeeded = OneWoW.ChunkedJob.YieldIfNeeded

    local hasFilter = searchTerm ~= nil and #searchTerm >= 2
    local term = hasFilter and searchTerm:lower() or ""
    local exactItemID = hasFilter and tonumber(searchTerm) or nil
    local resultMap = {}
    local count = 0
    local listCap = ns.GetCatalogListCap(hasFilter or sourceFilter ~= "all")

    local doJournal = (sourceFilter == "all" or sourceFilter == "drops")   and self:IsSourceAvailable("drops")
    local doVendors = (sourceFilter == "all" or sourceFilter == "vendors") and self:IsSourceAvailable("vendors")
    local doCrafted = (sourceFilter == "all" or sourceFilter == "crafted") and self:IsSourceAvailable("crafted")
    local doOwned   = (sourceFilter == "all" or sourceFilter == "owned")   and self:IsSourceAvailable("owned")
    local doQuest   = (sourceFilter == "all" or sourceFilter == "quests")  and self:IsSourceAvailable("quests")

    local function addOrAnnotate(itemID, name, icon, quality, sourceKey)
        if resultMap[itemID] then
            results[resultMap[itemID]][sourceKey] = true
            return
        end
        count = count + 1
        local entry = {
            itemID    = itemID,
            name      = name,
            icon      = icon,
            quality   = quality or 1,
            ownedCount = 0,
            isJournal = false,
            isVendor  = false,
            isCrafted = false,
            isOwned   = false,
            isQuestReward = false,
            isExactMatch  = false,
        }
        entry[sourceKey] = true
        results[count] = entry
        resultMap[itemID] = count
    end

    local function AnnotateOwned(entry)
        local data = GetOwnedTooltip(entry.itemID)
        if data then
            entry.ownedCount = data.totalCount or 0
            entry.isOwned = true
        end
    end

    ---@param itemID number
    ---@return boolean
    local function PassesSourceFilter(itemID)
        if sourceFilter == "all" then
            return true
        end
        if sourceFilter == "drops" then
            if not doJournal then
                return false
            end
            local journalAPI = ns.GetCatalogPackAPI("journal")
            local drops = journalAPI.GetItemDropLocations(itemID)
            return drops and drops[1] ~= nil
        end
        if sourceFilter == "vendors" then
            if not doVendors then
                return false
            end
            local vendorsAPI = ns.GetCatalogPackAPI("vendors")
            return vendorsAPI.ItemIsSold(itemID)
        end
        if sourceFilter == "crafted" then
            if not doCrafted then
                return false
            end
            local tsAddon = ns.GetCatalogPackAPI("tradeskills")
            local recipes = tsAddon.GetRecipesByItem(itemID)
            return recipes and recipes[1] ~= nil
        end
        if sourceFilter == "quests" then
            if not doQuest then
                return false
            end
            local questAddon = ns.GetCatalogPackAPI("quests")
            local quests = questAddon.GetQuestsRewardingItem(itemID)
            return quests and quests[1] ~= nil
        end
        if sourceFilter == "owned" then
            return doOwned and GetOwnedTooltip(itemID) ~= nil
        end
        return true
    end

    if exactItemID then
        local sourceKey = "isQuestReward"
        if sourceFilter == "drops" then
            sourceKey = "isJournal"
        elseif sourceFilter == "vendors" then
            sourceKey = "isVendor"
        elseif sourceFilter == "crafted" then
            sourceKey = "isCrafted"
        elseif sourceFilter == "owned" then
            sourceKey = "isOwned"
        elseif sourceFilter == "all" then
            sourceKey = "isExactMatch"
        end

        local exactName = C_Item.GetItemNameByID(exactItemID)
        local _, _, _, _, exactIcon = C_Item.GetItemInfoInstant(exactItemID)
        addOrAnnotate(exactItemID, exactName, exactIcon, nil, sourceKey)
        if resultMap[exactItemID] then
            results[resultMap[exactItemID]].isExactMatch = true
            AnnotateOwned(results[resultMap[exactItemID]])
        end
        return
    end

    -- Empty / 1-char: never EnsureDropIndex / GetAllVendors / all recipes / all
    -- quest rewards. All-sources browse takes 50 already-resident ItemDB names.
    if not hasFilter then
        if sourceFilter == "owned" and doOwned then
            local ownedMap = GetOwnedItems(yieldCheck)
            for itemID, od in pairs(ownedMap) do
                if count >= listCap then
                    break
                end
                addOrAnnotate(itemID, od.name, nil, nil, "isOwned")
                if resultMap[itemID] then
                    results[resultMap[itemID]].ownedCount = od.total or 0
                end
                YieldIfNeeded(yieldCheck)
            end
        elseif sourceFilter == "drops" and doJournal then
            local journalAPI = ns.GetCatalogPackAPI("journal")
            local names = journalAPI and journalAPI.GetItemNameIndexIfReady()
            if names then
                for itemID, name in pairs(names) do
                    if count >= listCap then
                        break
                    end
                    local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
                    addOrAnnotate(itemID, name, icon, nil, "isJournal")
                    YieldIfNeeded(yieldCheck)
                end
            end
        elseif sourceFilter == "all" then
            local itemAPI = ns.GetCatalogPackAPI("items")
            local names = itemAPI and itemAPI.GetItemNameIndex()
            if names then
                for itemID, name in pairs(names) do
                    if count >= listCap then
                        break
                    end
                    if type(name) == "string" and name ~= "" then
                        local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
                        addOrAnnotate(itemID, name, icon, nil, "isExactMatch")
                    end
                    YieldIfNeeded(yieldCheck)
                end
            end
        end

        for i = 1, count do
            AnnotateOwned(results[i])
            YieldIfNeeded(yieldCheck)
        end

        OneWoW.ChunkedJob.Sort(results, function(a, b)
            if a.ownedCount > 0 and b.ownedCount == 0 then return true end
            if a.ownedCount == 0 and b.ownedCount > 0 then return false end
            return (a.name or "") < (b.name or "")
        end, shouldYield)
        return
    end

    -- 2+ char search: ItemDB names (resident). Drops filter may build the
    -- journal drop-name index once; other filters use per-item lookups.
    local nameIndex
    if sourceFilter == "drops" and doJournal then
        local journalAPI = ns.GetCatalogPackAPI("journal")
        nameIndex = journalAPI and journalAPI.GetItemNameIndex()
    else
        local itemAPI = ns.GetCatalogPackAPI("items")
        nameIndex = itemAPI and itemAPI.GetItemNameIndex()
    end

    if nameIndex then
        for itemID, name in pairs(nameIndex) do
            if type(name) == "string" and name:lower():find(term, 1, true) then
                if sourceFilter == "all" or sourceFilter == "drops" or PassesSourceFilter(itemID) then
                    local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
                    local sourceKey = "isExactMatch"
                    if sourceFilter == "drops" then
                        sourceKey = "isJournal"
                    elseif sourceFilter == "vendors" then
                        sourceKey = "isVendor"
                    elseif sourceFilter == "crafted" then
                        sourceKey = "isCrafted"
                    elseif sourceFilter == "owned" then
                        sourceKey = "isOwned"
                    elseif sourceFilter == "quests" then
                        sourceKey = "isQuestReward"
                    end
                    addOrAnnotate(itemID, name, icon, nil, sourceKey)
                end
            end
            YieldIfNeeded(yieldCheck)
        end
    end

    for i = 1, count do
        AnnotateOwned(results[i])
        YieldIfNeeded(yieldCheck)
    end

    OneWoW.ChunkedJob.Sort(results, function(a, b)
        if a.ownedCount > 0 and b.ownedCount == 0 then return true end
        if a.ownedCount == 0 and b.ownedCount > 0 then return false end
        return (a.name or "") < (b.name or "")
    end, shouldYield)
end

--- Synchronous query (small callers / tests). Prefer StartQuery for UI walks.
function ItemSearch:Query(searchTerm, sourceFilter)
    local results = {}
    BuildQueryResults(self, searchTerm, sourceFilter, results, nil)
    return results
end

function ItemSearch:CancelQuery()
    if self._queryJob then
        self._queryJob:Cancel()
        self._queryJob = nil
    end
end

--- Time-sliced query into `outResults` (mutated in place). Cancels any prior job.
---@param searchTerm string|nil
---@param sourceFilter string|nil
---@param outResults table
---@param opts table|nil { onProgress, onComplete, onCancel, finalize, budgetMs }
--- finalize(results, shouldYield) runs inside the job after the walk (e.g. favorites).
---@return table jobHandle
function ItemSearch:StartQuery(searchTerm, sourceFilter, outResults, opts)
    opts = opts or {}
    if type(outResults) ~= "table" then
        error("ItemSearch:StartQuery requires an outResults table", 2)
    end

    self:CancelQuery()
    wipe(outResults)

    local job
    job = OneWoW.ChunkedJob.Start({
        budgetMs = opts.budgetMs,
        run = function(shouldYield)
            BuildQueryResults(self, searchTerm, sourceFilter, outResults, shouldYield)
            if opts.finalize then
                opts.finalize(outResults, shouldYield)
            end
        end,
        onProgress = opts.onProgress,
        onComplete = function()
            if self._queryJob == job then
                self._queryJob = nil
            end
            if opts.onComplete then
                opts.onComplete(outResults)
            end
        end,
        onCancel = function()
            if self._queryJob == job then
                self._queryJob = nil
            end
            if opts.onCancel then
                opts.onCancel()
            end
        end,
    })
    self._queryJob = job
    return job
end

function ItemSearch:GetDetail(itemID)
    local isRecipe = OneWoW.PredicateEngine:IsRecipeItem(itemID)

    local detail = {
        drops        = {},
        vendors      = {},
        crafted      = {},
        owned        = {},
        questRewards = {},
        isRecipe     = isRecipe,
        recipeKnownBy = isRecipe and GetRecipeKnownByFromAltTracker(itemID) or nil,
    }

    local journalAPI = ns.GetCatalogPackAPI("journal")
    if journalAPI then
        for _, drop in ipairs(journalAPI.GetItemDropLocations(itemID)) do
            tinsert(detail.drops, {
                placeKey      = drop.placeKey,
                instanceID    = drop.instanceID,
                instanceType  = drop.instanceType,
                instanceName  = drop.instanceName or "",
                encounterID   = drop.encounterID,
                encounterName = drop.encounterName,
                uiMapID       = drop.uiMapID,
                npcID         = drop.npcID,
                worldRare     = drop.worldRare,
                difficulties  = drop.difficulties,
            })
        end
    end

    local vendorsAPI = ns.GetCatalogPackAPI("vendors")
    local sellingVendors = vendorsAPI and vendorsAPI.GetVendorsByItem(itemID)
    if sellingVendors then
        for _, vendor in ipairs(sellingVendors) do
            local mapID, loc
            if vendor.locations then
                for mID, l in pairs(vendor.locations) do
                    mapID = mID
                    loc = l
                    break
                end
            end
            local itemEntry = vendor.items and vendor.items[itemID]
            tinsert(detail.vendors, {
                name  = vendor.name,
                npcID = vendor.npcID,
                zone  = loc and loc.zone,
                mapID = mapID,
                cost  = itemEntry and itemEntry.cost,
            })
        end
    end

    local tsAddon = ns.GetCatalogPackAPI("tradeskills")
    if tsAddon then
        local craftedRecipes = tsAddon.GetRecipesByItem(itemID)
        for _, recipe in ipairs(craftedRecipes) do
            tinsert(detail.crafted, {
                recipeID  = recipe.id,
                profName  = recipe.prof,
                expansion = recipe.exp,
                knownBy   = tsAddon.GetRecipeKnownBy(recipe.id),
            })
        end
    end

    local ownedData = GetOwnedTooltip(itemID)
    if ownedData then
        local byCharLoc = {}
        for _, loc in ipairs(ownedData.locations) do
            local charName, locLabel = OwnedLocDisplay(loc)
            local key = tostring(charName) .. "|" .. tostring(locLabel)
            if not byCharLoc[key] then
                byCharLoc[key] = { charName = charName, locLabel = locLabel, count = 0 }
                tinsert(detail.owned, byCharLoc[key])
            end
            byCharLoc[key].count = byCharLoc[key].count + (loc.count or 1)
        end
    end

    local questAddon = ns.GetCatalogPackAPI("quests")
    if questAddon then
        local questIDs = questAddon.GetQuestsRewardingItem(itemID, true)
        if questIDs then
            for _, questID in ipairs(questIDs) do
                local questName = questAddon.GetQuestName and questAddon.GetQuestName(questID)
                if not questName then
                    local q = questAddon.GetQuest(questID)
                    questName = q and q.name
                end
                tinsert(detail.questRewards, { questID = questID, questName = questName })
            end
        end
    end

    return detail
end
