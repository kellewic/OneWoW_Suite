local _, ns = ...
local L = ns.L

local pairs = pairs
local tinsert, wipe = tinsert, wipe
local strlower, strfind, strtrim = strlower, strfind, strtrim
local tonumber, sort = tonumber, sort
local GetExpansionLevel = GetExpansionLevel

local C_MountJournal = C_MountJournal
local C_ToyBox = C_ToyBox
local C_PetJournal = C_PetJournal
local C_TransmogCollection = C_TransmogCollection
local C_HousingCatalog = C_HousingCatalog
local C_Item = C_Item
local C_Timer = C_Timer

-- ============================================================================
-- CollectibleBrowse
-- ============================================================================
-- Bounded journal walks for Catalog Collectibles / Housing. Mounts come from
-- GetMountIDs. Pets and toys temporarily show every journal filter, cache the
-- ID list, then restore the player's Collections filters. Appearances walk
-- wardrobe categories until the list cap (or until a search is satisfied).
-- Housing uses an independent C_HousingCatalog searcher. Collected / Not
-- Collected is a visible-list filter via GetCollectionState (housing also
-- drives the searcher's owned flags). Journal APIs do not expose expansion.
--
-- CatDB packs are read per selected itemID only, and only when already
-- loaded. JumpToVendor / JumpToQuest / JumpToPlace load that one pack.
-- Selecting a row does not prefetch packs.
-- ============================================================================

ns.CollectibleBrowse = ns.CollectibleBrowse or {}
local Browse = ns.CollectibleBrowse

local Collectibles = OneWoW.Collectibles

local DECOR_ENTRY_TYPE = Enum.HousingCatalogEntryType.Decor
local ALL_CATEGORY_ID = Constants.HousingCatalogConsts.HOUSING_CATALOG_ALL_CATEGORY_ID

local mountCache
local petCache
local toyCache

local queryJob
local housingSearcher
local housingToken = 0

local function NameMatches(name, term)
    if not term or term == "" then
        return true
    end
    if not name or name == "" then
        return false
    end
    return strfind(strlower(name), term, 1, true) ~= nil
end

local function TypeLabel(kind)
    if kind == "appearance" then
        return L["JOURNAL_FILTER_TMOG"]
    end
    if kind == "mount" then
        return MOUNTS
    end
    if kind == "pet" then
        return PETS
    end
    if kind == "toy" then
        return L["JOURNAL_FILTER_TOY"]
    end
    if kind == "decor" then
        return L["DECOR"]
    end
    return kind
end

--- Localized type name for a collectible kind.
---@param kind string
---@return string
function Browse.TypeLabel(kind)
    return TypeLabel(kind)
end

local function LiveCollected(entry)
    if not entry or not entry.key then
        return false
    end
    local state = Collectibles.GetCollectionState(entry.key)
    if not state then
        return false
    end
    entry.collected = state.collected == true
    entry.numCollected = state.numCollected
    entry.numLimit = state.limit
    entry.numOwned = state.numOwned
    entry.numStored = state.numStored
    entry.numPlaced = state.numPlaced
    return entry.collected
end

--- True when the row's live collected flag matches All / Collected / Not Collected.
---@param entry table
---@param collectedFilter string|nil
---@return boolean
local function CollectedWanted(entry, collectedFilter)
    if not collectedFilter or collectedFilter == "all" then
        return true
    end
    if collectedFilter == "collected" then
        return entry.collected == true
    end
    if collectedFilter == "notcollected" then
        return entry.collected ~= true
    end
    return true
end

--- "all" / "collected" / "notcollected". Missing opts means show both.
---@param opts table|nil
---@return string
local function CollectedFilterFromOpts(opts)
    local filter = opts and opts.collectedFilter
    if filter == "collected" or filter == "notcollected" then
        return filter
    end
    return "all"
end

--- Refresh live collection flags on a browse row.
---@param entry table
---@return boolean collected
function Browse.RefreshCollected(entry)
    return LiveCollected(entry)
end

local function EnsureMountCache(shouldYield)
    if mountCache then
        return mountCache
    end
    mountCache = {}
    local YieldIfNeeded = OneWoW.ChunkedJob.YieldIfNeeded
    local ids = C_MountJournal.GetMountIDs()
    for i = 1, #ids do
        local mountID = ids[i]
        local name, spellID, icon, _, _, _, _, isFactionSpecific, faction, _, _, _, _ =
            C_MountJournal.GetMountInfoByID(mountID)
        if name then
            local _, description, source = C_MountJournal.GetMountInfoExtraByID(mountID)
            local sourceText
            if source and source ~= "" then
                sourceText = strtrim((source:gsub("|n", " ")))
                if sourceText == "" then
                    sourceText = nil
                end
            end
            if description == "" then
                description = nil
            end
            local factionName
            if isFactionSpecific then
                if faction == 0 then
                    factionName = FACTION_HORDE
                elseif faction == 1 then
                    factionName = FACTION_ALLIANCE
                end
            end
            tinsert(mountCache, {
                kind = "mount",
                id = mountID,
                key = Collectibles.BuildKey("mount", mountID),
                name = name,
                icon = icon,
                spellID = spellID,
                sourceText = sourceText,
                description = description,
                factionName = factionName,
            })
        end
        if shouldYield then
            YieldIfNeeded(shouldYield)
        end
    end
    return mountCache
end

local function WithPetJournalAll(fn)
    local collected = C_PetJournal.IsFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED)
    local notCollected = C_PetJournal.IsFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED)
    local types = {}
    for i = 1, C_PetJournal.GetNumPetTypes() do
        types[i] = C_PetJournal.IsPetTypeChecked(i)
    end
    local sources = {}
    for i = 1, C_PetJournal.GetNumPetSources() do
        sources[i] = C_PetJournal.IsPetSourceChecked(i)
    end

    C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED, true)
    C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED, true)
    C_PetJournal.SetAllPetTypesChecked(true)
    C_PetJournal.SetAllPetSourcesChecked(true)
    C_PetJournal.ClearSearchFilter()

    fn()

    C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED, collected)
    C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED, notCollected)
    for i = 1, #types do
        C_PetJournal.SetPetTypeFilter(i, types[i])
    end
    for i = 1, #sources do
        C_PetJournal.SetPetSourceChecked(i, sources[i])
    end
end

local function EnsurePetCache()
    if petCache then
        return petCache
    end
    petCache = {}
    local seen = {}
    WithPetJournalAll(function()
        local n = C_PetJournal.GetNumPets()
        for i = 1, n do
            local _, speciesID, _, _, _, _, _, name, icon, _, _, sourceText, description =
                C_PetJournal.GetPetInfoByIndex(i)
            if speciesID and not seen[speciesID] and name then
                seen[speciesID] = true
                if sourceText and sourceText ~= "" then
                    sourceText = strtrim((sourceText:gsub("|n", " ")))
                    if sourceText == "" then
                        sourceText = nil
                    end
                else
                    sourceText = nil
                end
                if description == "" then
                    description = nil
                end
                tinsert(petCache, {
                    kind = "pet",
                    id = speciesID,
                    key = Collectibles.BuildKey("pet", speciesID),
                    name = name,
                    icon = icon,
                    sourceText = sourceText,
                    description = description,
                })
            end
        end
    end)
    return petCache
end

local function WithToyBoxAll(fn)
    local collected = C_ToyBox.GetCollectedShown()
    local uncollected = C_ToyBox.GetUncollectedShown()
    local unusable = C_ToyBox.GetUnusableShown()
    local sources = {}
    for i = 1, C_PetJournal.GetNumPetSources() do
        sources[i] = C_ToyBox.IsSourceTypeFilterChecked(i)
    end
    local expansions = {}
    local maxExp = GetExpansionLevel()
    for i = 0, maxExp do
        expansions[i] = C_ToyBox.IsExpansionTypeFilterChecked(i)
    end

    C_ToyBox.SetCollectedShown(true)
    C_ToyBox.SetUncollectedShown(true)
    C_ToyBox.SetUnusableShown(true)
    C_ToyBox.SetAllSourceTypeFilters(true)
    C_ToyBox.SetAllExpansionTypeFilters(true)
    C_ToyBox.SetFilterString("")
    C_ToyBox.ForceToyRefilter()

    fn()

    C_ToyBox.SetCollectedShown(collected)
    C_ToyBox.SetUncollectedShown(uncollected)
    C_ToyBox.SetUnusableShown(unusable)
    for i = 1, #sources do
        C_ToyBox.SetSourceTypeFilter(i, sources[i])
    end
    for i = 0, maxExp do
        C_ToyBox.SetExpansionTypeFilter(i, expansions[i])
    end
    C_ToyBox.ForceToyRefilter()
end

local function EnsureToyCache()
    if toyCache then
        return toyCache
    end
    toyCache = {}
    WithToyBoxAll(function()
        local n = C_ToyBox.GetNumFilteredToys()
        for i = 1, n do
            local itemID = C_ToyBox.GetToyFromIndex(i)
            if itemID and itemID > 0 then
                local _, name, icon = C_ToyBox.GetToyInfo(itemID)
                tinsert(toyCache, {
                    kind = "toy",
                    id = itemID,
                    key = Collectibles.BuildKey("toy", itemID),
                    name = name,
                    icon = icon,
                    itemID = itemID,
                })
            end
        end
    end)
    return toyCache
end

local function CopyRow(src)
    return {
        kind = src.kind,
        id = src.id,
        key = src.key,
        name = src.name,
        icon = src.icon,
        iconAtlas = src.iconAtlas,
        itemID = src.itemID,
        quality = src.quality,
        spellID = src.spellID,
        sourceText = src.sourceText,
        description = src.description,
        factionName = src.factionName,
        itemType = src.itemType,
        itemSubType = src.itemSubType,
    }
end

local function AppendFromCache(cache, term, collectedFilter, cap, results, seen, shouldYield)
    if not cache then
        return
    end
    local YieldIfNeeded = OneWoW.ChunkedJob.YieldIfNeeded
    for i = 1, #cache do
        if #results >= cap then
            return
        end
        local row = cache[i]
        if row.key and not seen[row.key] and NameMatches(row.name, term) then
            local copy = CopyRow(row)
            LiveCollected(copy)
            if CollectedWanted(copy, collectedFilter) then
                seen[row.key] = true
                tinsert(results, copy)
            end
        end
        YieldIfNeeded(shouldYield)
    end
end

local function AppearanceCategories()
    local cats = {}
    local seen = {}
    for _, value in pairs(Enum.TransmogCollectionType) do
        if type(value) == "number" and value ~= Enum.TransmogCollectionType.None and not seen[value] then
            seen[value] = true
            tinsert(cats, value)
        end
    end
    sort(cats)
    return cats
end

local function WithAppearanceFiltersAll(fn)
    local collected = C_TransmogCollection.GetCollectedShown()
    local uncollected = C_TransmogCollection.GetUncollectedShown()
    C_TransmogCollection.SetCollectedShown(true)
    C_TransmogCollection.SetUncollectedShown(true)
    C_TransmogCollection.ClearSearch(Enum.TransmogSearchType.Items)
    fn()
    C_TransmogCollection.SetCollectedShown(collected)
    C_TransmogCollection.SetUncollectedShown(uncollected)
end

local function AppendAppearances(term, collectedFilter, cap, results, seen, shouldYield)
    local YieldIfNeeded = OneWoW.ChunkedJob.YieldIfNeeded
    local cats = AppearanceCategories()
    for c = 1, #cats do
        if #results >= cap then
            return
        end
        WithAppearanceFiltersAll(function()
            local appearances = C_TransmogCollection.GetCategoryAppearances(cats[c])
            if not appearances then
                return
            end
            for i = 1, #appearances do
                if #results >= cap then
                    return
                end
                local visual = appearances[i]
                if visual and not visual.isHideVisual then
                    local sources = C_TransmogCollection.GetAllAppearanceSources(visual.visualID)
                    local sourceID = sources and sources[1]
                    if sourceID then
                        local key = Collectibles.BuildKey("appearance", "source", sourceID)
                        if key and not seen[key] then
                            local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
                            local appearanceInfo = C_TransmogCollection.GetAppearanceSourceInfo(sourceID)
                            local name = sourceInfo and sourceInfo.name
                            local icon = appearanceInfo and appearanceInfo.icon
                            local itemID = sourceInfo and sourceInfo.itemID
                                or C_TransmogCollection.GetSourceItemID(sourceID)
                            local quality = sourceInfo and sourceInfo.quality
                            if (not name or not icon) and itemID then
                                local itemName, _, itemQuality, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
                                name = name or itemName
                                icon = icon or itemIcon
                                quality = quality or itemQuality
                            end
                            if NameMatches(name, term) then
                                local copy = {
                                    kind = "appearance",
                                    id = sourceID,
                                    key = key,
                                    name = name,
                                    icon = icon,
                                    itemID = itemID,
                                    quality = quality,
                                }
                                LiveCollected(copy)
                                if CollectedWanted(copy, collectedFilter) then
                                    seen[key] = true
                                    tinsert(results, copy)
                                end
                            end
                        end
                    end
                end
            end
        end)
        YieldIfNeeded(shouldYield)
    end
end

local KIND_CACHE = {
    mount = EnsureMountCache,
    pet = EnsurePetCache,
    toy = EnsureToyCache,
}

local ALL_KINDS = { "mount", "pet", "toy", "appearance" }

local function KindsForFilter(filterKey)
    if filterKey == "all" then
        return ALL_KINDS
    end
    return { filterKey }
end

--- Cancel an in-flight collectibles or housing query.
function Browse.CancelQuery()
    if queryJob then
        queryJob:Cancel()
        queryJob = nil
    end
    housingToken = housingToken + 1
end

--- Time-sliced collectibles query into `outResults`.
---@param filterKey string
---@param searchTerm string|nil
---@param outResults table
---@param opts table|nil `{ collectedFilter? = "all"|"collected"|"notcollected", budgetMs?, onProgress?, onComplete?, onCancel? }`
---@return table jobHandle
function Browse.StartCollectiblesQuery(filterKey, searchTerm, outResults, opts)
    opts = opts or {}
    Browse.CancelQuery()
    wipe(outResults)

    local hasText = ns.CatalogListHasSearchText(searchTerm)
    local term = hasText and strlower(searchTerm) or nil
    local collectedFilter = CollectedFilterFromOpts(opts)
    local isFiltered = hasText or filterKey ~= "all" or collectedFilter ~= "all"
    local cap = ns.GetCatalogListCap(isFiltered)
    local kinds = KindsForFilter(filterKey)

    local job = OneWoW.ChunkedJob.Start({
        budgetMs = opts.budgetMs or 8,
        run = function(shouldYield)
            local seen = {}
            local perKind = cap
            if filterKey == "all" and not hasText then
                perKind = math.ceil(cap / #kinds)
            end
            for k = 1, #kinds do
                if #outResults >= cap then
                    break
                end
                local kind = kinds[k]
                local remain = cap - #outResults
                local take = remain
                if filterKey == "all" and not hasText then
                    take = math.min(remain, perKind)
                end
                if kind == "appearance" then
                    AppendAppearances(term, collectedFilter, #outResults + take, outResults, seen, shouldYield)
                else
                    local cache = KIND_CACHE[kind](shouldYield)
                    OneWoW.ChunkedJob.YieldIfNeeded(shouldYield)
                    AppendFromCache(cache, term, collectedFilter, #outResults + take, outResults, seen, shouldYield)
                end
            end
            OneWoW.ChunkedJob.Sort(outResults, function(a, b)
                if a.collected ~= b.collected then
                    return a.collected
                end
                return (a.name or "") < (b.name or "")
            end, shouldYield)
        end,
        onProgress = opts.onProgress,
        onComplete = function()
            queryJob = nil
            if opts.onComplete then
                opts.onComplete(#outResults >= cap)
            end
        end,
        onCancel = function()
            if queryJob then
                queryJob = nil
            end
            if opts.onCancel then
                opts.onCancel()
            end
        end,
    })
    queryJob = job
    return job
end

local function DecorRowFromInfo(info)
    if not info or info.entryType ~= DECOR_ENTRY_TYPE then
        return nil
    end
    local recordID = info.recordID
    local icon = info.iconTexture
    local iconAtlas = info.iconAtlas
    local itemID = info.itemID
    local quality = info.quality
    local itemType, itemSubType
    if itemID then
        local itemName, _, itemQuality, _, _, className, subName, _, _, itemIcon = C_Item.GetItemInfo(itemID)
        icon = icon or itemIcon or select(5, C_Item.GetItemInfoInstant(itemID))
        quality = quality or itemQuality
        itemType = className
        itemSubType = subName
        if not info.name or info.name == "" then
            info.name = itemName
        end
    end
    local sourceText = info.sourceText
    if sourceText == "" then
        sourceText = nil
    end
    local row = {
        kind = "decor",
        id = recordID,
        key = Collectibles.BuildKey("decor", recordID),
        name = info.name,
        icon = icon,
        iconAtlas = icon and nil or iconAtlas,
        itemID = itemID,
        quality = quality,
        sourceText = sourceText,
        itemType = itemType,
        itemSubType = itemSubType,
    }
    LiveCollected(row)
    return row
end

local function EnsureHousingSearcher()
    if housingSearcher then
        return housingSearcher
    end
    housingSearcher = C_HousingCatalog.CreateCatalogSearcher()
    housingSearcher:SetAutoUpdateOnParamChanges(false)
    housingSearcher:SetStoredOnly(false)
    housingSearcher:SetBaseVariantOnly(true)
    housingSearcher:SetCollected(true)
    housingSearcher:SetUncollected(true)
    housingSearcher:SetSortType(Enum.HousingCatalogSortType.Alphabetical)
    housingSearcher:SetFilteredCategoryID(ALL_CATEGORY_ID)
    return housingSearcher
end

--- Apply owned / not-owned to the housing searcher. Row `collected` still
--- comes from GetCollectionState (numOwned > 0).
---@param searcher table
---@param collectedFilter string
local function ApplyHousingCollectedFilter(searcher, collectedFilter)
    if collectedFilter == "collected" then
        searcher:SetCollected(true)
        searcher:SetUncollected(false)
    elseif collectedFilter == "notcollected" then
        searcher:SetCollected(false)
        searcher:SetUncollected(true)
    else
        searcher:SetCollected(true)
        searcher:SetUncollected(true)
    end
end

--- Async housing decor query into `outResults`.
---@param filterKey string|nil
---@param searchTerm string|nil
---@param outResults table
---@param opts table|nil `{ collectedFilter? = "all"|"collected"|"notcollected", onComplete? }`
function Browse.StartHousingQuery(filterKey, searchTerm, outResults, opts)
    opts = opts or {}
    Browse.CancelQuery()
    wipe(outResults)

    local hasText = ns.CatalogListHasSearchText(searchTerm)
    local collectedFilter = CollectedFilterFromOpts(opts)
    local isFiltered = hasText or (filterKey and filterKey ~= "all") or collectedFilter ~= "all"
    local cap = ns.GetCatalogListCap(isFiltered)
    local token = housingToken
    local searcher = EnsureHousingSearcher()
    ApplyHousingCollectedFilter(searcher, collectedFilter)

    searcher:SetResultsUpdatedCallback(function()
        if token ~= housingToken then
            return
        end
        wipe(outResults)
        local entries = searcher:GetCatalogSearchResults()
        local total = 0
        if type(entries) == "table" then
            total = #entries
            for i = 1, total do
                if #outResults >= cap then
                    break
                end
                local entry = entries[i]
                local info = C_HousingCatalog.GetCatalogEntryInfo(entry)
                if not info and entry and entry.recordID then
                    info = C_HousingCatalog.GetCatalogEntryInfoByRecordID(
                        entry.entryType or DECOR_ENTRY_TYPE,
                        entry.recordID,
                        true
                    )
                end
                local row = DecorRowFromInfo(info)
                if row and CollectedWanted(row, collectedFilter) then
                    tinsert(outResults, row)
                end
            end
        end
        if opts.onComplete then
            opts.onComplete(total > cap)
        end
    end)

    if hasText then
        searcher:SetSearchText(searchTerm)
    else
        searcher:SetSearchText("")
    end
    searcher:RunSearch()
end

--- Per-item CatDB + journal sources. Empty until those packs are already loaded.
---@param entry table
---@return table sources
function Browse.BuildSources(entry)
    local sources = {
        drops = {},
        vendors = {},
        quests = {},
        achievements = {},
        rare = nil,
    }
    if not entry then
        return sources
    end

    if entry.key then
        local lock = Collectibles.GetRareLockByKey(entry.key)
        if lock then
            sources.rare = lock
            sources.rare.name = Collectibles.ResolveNPCName(lock.npcID)
        end
    end

    local itemID = entry.itemID
    if not itemID then
        return sources
    end

    local detail = ns.ItemSearch:GetDetail(itemID)
    sources.drops = detail.drops or sources.drops
    sources.vendors = detail.vendors or sources.vendors
    sources.quests = detail.questRewards or sources.quests

    local journalAPI = ns.GetCatalogPackAPI("journal")
    if journalAPI then
        local ids = journalAPI.GetAchievementsForItem(itemID)
        if ids then
            for i = 1, #ids do
                local achievementID = ids[i]
                local _, name = GetAchievementInfo(achievementID)
                tinsert(sources.achievements, {
                    achievementID = achievementID,
                    name = name,
                })
            end
        end
    end

    return sources
end

local function DropCanJump(drop)
    if drop.placeKey or (drop.instanceID and drop.instanceID > 0) or drop.uiMapID then
        return true
    end
    return false
end

function Browse.JumpToVendor(npcID)
    npcID = tonumber(npcID)
    if not npcID then
        return
    end
    local packName = ns.EnsureCatalogPack("vendors")
    local function open()
        ns.UI.OpenToVendor(npcID)
    end
    if ns.GetCatalogPackAPI("vendors") then
        open()
        return
    end
    if packName then
        OneWoW:WithAddon(packName, open)
    end
end

function Browse.JumpToQuest(questID)
    questID = tonumber(questID)
    if not questID then
        return
    end
    local packName = ns.EnsureCatalogPack("quests")
    local function open()
        ns.UI.OpenQuest(questID)
    end
    if ns.GetCatalogPackAPI("quests") then
        open()
        return
    end
    if packName then
        OneWoW:WithAddon(packName, open)
    end
end

function Browse.JumpToPlace(drop)
    if not drop then
        return
    end
    local packName = ns.EnsureCatalogPack("journal")
    local function open()
        ns.UI.OpenToInstance({
            placeKey = drop.placeKey,
            instanceID = drop.instanceID,
            mapID = drop.uiMapID,
            encounterID = drop.encounterID,
        })
    end
    if ns.GetCatalogPackAPI("journal") then
        open()
        return
    end
    if packName then
        OneWoW:WithAddon(packName, open)
    end
end

function Browse.JumpToRare(lock)
    if not lock or not lock.mapID then
        return
    end
    ns.Navigation:OpenMapPin(lock.mapID, lock.x, lock.y, lock.name or lock.title)
end

function Browse.JumpToAchievement(achievementID)
    achievementID = tonumber(achievementID)
    if not achievementID then
        return
    end
    local ok = OneWoW:EnsureLoaded("Blizzard_AchievementUI")
    if not ok then
        return
    end
    ShowAchievementFrameForAchievement(achievementID)
end

function Browse.DropCanJump(drop)
    return DropCanJump(drop)
end

--- Schedule a 0-delay refresh so tab create does not walk journals this frame.
---@param fn fun()
function Browse.Defer(fn)
    C_Timer.After(0, fn)
end
