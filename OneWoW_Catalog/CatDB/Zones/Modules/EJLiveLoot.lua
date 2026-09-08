-- ============================================================================
-- EJLiveLoot
-- ============================================================================
-- Live Encounter Journal overlay for one Catalog card: scaled loot links and
-- names. Per-instance only. Does not scrape the encyclopedia at login.
-- Live Encounter Journal loot overlay.
-- ============================================================================
local _, ns = ...

local Card = ns.JournalCard
local EJLive = {}
ns.EJLiveLoot = EJLive

local pairs, ipairs, type = pairs, ipairs, type
local tinsert, wipe, sort = tinsert, wipe, sort
local C_EncounterJournal = C_EncounterJournal
local C_Item = C_Item
local C_SpecializationInfo = C_SpecializationInfo
local C_Timer = C_Timer

local EJ_SLOT_FILTER_NO_FILTER = Enum.ItemSlotFilterType.NoFilter

local DUNGEON_DIFFS = { 1, 2, 23, 8, 24 }
local RAID_DIFFS = { 3, 4, 5, 6, 17, 14, 15, 16 }
local WB_TRY_DIFFS = { 0, 14, 15 }

---@param inst table
---@return boolean
local function IsWorldHub(inst)
    return inst.instanceType == "world" and inst.instanceID and inst.instanceID > 0
end

---@param diffID number
---@return string
local function DifficultyLabel(diffID)
    local meta = ns.Difficulties and ns.Difficulties[diffID]
    local name = GetDifficultyInfo(diffID)
    if name and name ~= "" then
        return name
    end
    if meta and meta.name then
        return meta.name
    end
    if diffID == 0 then
        return "World"
    end
    return "Difficulty " .. tostring(diffID)
end

---@param inst table
---@return number[]
local function ResolveScanDifficulties(inst)
    local ids = {}
    local seen = {}
    local function add(diffID)
        if not diffID or seen[diffID] then
            return
        end
        seen[diffID] = true
        ids[#ids + 1] = diffID
    end

    if inst.validDifficulties then
        for i = 1, #inst.validDifficulties do
            add(inst.validDifficulties[i])
        end
    else
        local list = (inst.instanceType == "party") and DUNGEON_DIFFS or RAID_DIFFS
        for i = 1, #list do
            add(list[i])
        end
    end

    local filtered = {}
    for i = 1, #ids do
        local diffID = ids[i]
        if EJ_IsValidInstanceDifficulty(diffID) then
            filtered[#filtered + 1] = diffID
        end
    end
    if #filtered > 0 then
        return filtered
    end
    return ids
end

local ejOriginalOnEvent = nil
local ejSuppressCount = 0
local ejSavedDifficulty = nil
local ejSavedSlotFilter = nil
local ejSavedLootClassID = nil
local ejSavedLootSpecID = nil

local function SuppressEJ()
    ejSuppressCount = ejSuppressCount + 1
    if ejSuppressCount > 1 then
        return
    end
    if not EncounterJournal then
        return
    end
    ejSavedDifficulty = EJ_GetDifficulty()
    ejSavedSlotFilter = C_EncounterJournal.GetSlotFilter()
    ejSavedLootClassID, ejSavedLootSpecID = EJ_GetLootFilter()
    ejOriginalOnEvent = EncounterJournal:GetScript("OnEvent")
    EncounterJournal:SetScript("OnEvent", nil)
    EncounterJournal:UnregisterEvent("EJ_LOOT_DATA_RECIEVED")
    EncounterJournal:UnregisterEvent("EJ_DIFFICULTY_UPDATE")
    EncounterJournal:UnregisterEvent("UNIT_LEVEL")
end

local function UnsuppressEJ()
    ejSuppressCount = ejSuppressCount - 1
    if ejSuppressCount > 0 then
        return
    end
    ejSuppressCount = 0
    if not EncounterJournal then
        return
    end
    if ejSavedDifficulty ~= nil then
        EJ_SetDifficulty(ejSavedDifficulty)
        ejSavedDifficulty = nil
    end
    if ejSavedSlotFilter ~= nil then
        C_EncounterJournal.SetSlotFilter(ejSavedSlotFilter)
        ejSavedSlotFilter = nil
    end
    if ejSavedLootClassID and ejSavedLootSpecID then
        EJ_SetLootFilter(ejSavedLootClassID, ejSavedLootSpecID)
        ejSavedLootClassID = nil
        ejSavedLootSpecID = nil
    end
    if ejOriginalOnEvent then
        EncounterJournal:SetScript("OnEvent", ejOriginalOnEvent)
        ejOriginalOnEvent = nil
    end
    EncounterJournal:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
    EncounterJournal:RegisterEvent("EJ_DIFFICULTY_UPDATE")
    EncounterJournal:RegisterEvent("UNIT_LEVEL")
end

local function ApplyLootFilterForScan()
    local ok = pcall(EJ_SetLootFilter, 0, 0)
    if ok then
        return
    end
    local classID = select(3, UnitClass("player")) or 0
    local spec = C_SpecializationInfo.GetSpecialization() or 1
    local specID = select(1, C_SpecializationInfo.GetSpecializationInfo(spec)) or 0
    EJ_SetLootFilter(classID, specID)
end

---@param info table|nil
---@return string|nil
local function NameFromLootInfo(info)
    if not info then
        return nil
    end
    if info.name and info.name ~= "" then
        return info.name
    end
    local link = info.link
    if type(link) == "string" then
        local fromLink = link:match("%[(.-)%]")
        if fromLink and fromLink ~= "" then
            return fromLink
        end
    end
    if info.itemID then
        return C_Item.GetItemNameByID(info.itemID)
    end
    return nil
end

---@return table
local function ScanLootIndices()
    local items = {}
    local n = EJ_GetNumLoot()
    for index = 1, n do
        local info = C_EncounterJournal.GetLootInfoByIndex(index)
        if info then
            local itemID = info.itemID
            if itemID and itemID > 0 then
                local row = items[itemID]
                if not row then
                    row = { itemID = itemID, name = NameFromLootInfo(info), icon = info.icon, link = info.link }
                    items[itemID] = row
                else
                    if not row.name or row.name == "" then
                        row.name = NameFromLootInfo(info)
                    end
                    if info.icon then
                        row.icon = info.icon
                    end
                    if info.link then
                        row.link = info.link
                    end
                end
            end
        end
    end
    return items
end

---@param instanceID number
---@param firstEncounterID number
---@return boolean
local function DungeonHasNormalLoot(instanceID, firstEncounterID)
    EJ_SelectInstance(instanceID)
    EJ_SelectEncounter(firstEncounterID)
    EJ_SetDifficulty(1)
    C_EncounterJournal.SetSlotFilter(EJ_SLOT_FILTER_NO_FILTER)
    ApplyLootFilterForScan()
    local n = EJ_GetNumLoot()
    if not n or n < 1 then
        return false
    end
    local info = C_EncounterJournal.GetLootInfoByIndex(1)
    if not info or not info.link then
        return false
    end
    local itemLevel = select(4, C_Item.GetItemInfo(info.link))
    if not itemLevel then
        return false
    end
    return itemLevel >= 200
end

---@param instanceID number
---@param encounterID number
---@param inst table
---@param iidWorldBoss boolean
---@param skipNormalDungeon boolean
---@return table
function EJLive:ScanEncounterDifficulties(instanceID, encounterID, inst, iidWorldBoss, skipNormalDungeon)
    local results = {}
    local function addDiff(diffID)
        EJ_SelectInstance(instanceID)
        EJ_SelectEncounter(encounterID)
        EJ_SetDifficulty(diffID)
        C_EncounterJournal.SetSlotFilter(EJ_SLOT_FILTER_NO_FILTER)
        ApplyLootFilterForScan()
        local byID = ScanLootIndices()
        for itemID, data in pairs(byID) do
            local row = results[itemID]
            if not row then
                row = { itemID = itemID, name = data.name, icon = data.icon, difficulties = {}, linkByDiff = {} }
                results[itemID] = row
            end
            if data.link then
                row.linkByDiff[diffID] = data.link
            end
            local seen = false
            for i = 1, #row.difficulties do
                if row.difficulties[i].id == diffID then
                    seen = true
                    break
                end
            end
            if not seen then
                tinsert(row.difficulties, { id = diffID, name = DifficultyLabel(diffID) })
            end
        end
    end

    if iidWorldBoss then
        for i = 1, #WB_TRY_DIFFS do
            addDiff(WB_TRY_DIFFS[i])
        end
        return results
    end

    local diffs = ResolveScanDifficulties(inst)
    for i = 1, #diffs do
        local diffID = diffs[i]
        if not (skipNormalDungeon and diffID == 1) then
            addDiff(diffID)
        end
    end
    return results
end

local scaledLinkCache = {}
EJLive.scanningOnDemand = false

--- Difficulty-scaled Adventure Guide loot link, or nil until EJ has the row.
---@param instanceID number
---@param encounterID number
---@param diffID number
---@param itemID number
---@return string|nil
function EJLive:GetScaledLootLink(instanceID, encounterID, diffID, itemID)
    if not (instanceID and encounterID and diffID and itemID) then
        return nil
    end
    if encounterID == 0 then
        return nil
    end

    local key = instanceID .. ":" .. encounterID .. ":" .. diffID .. ":" .. itemID
    if scaledLinkCache[key] then
        return scaledLinkCache[key]
    end

    OneWoW:EnsureLoaded("Blizzard_EncounterJournal")

    local result
    SuppressEJ()
    EJLive.scanningOnDemand = true
    pcall(function()
        EJ_SelectInstance(instanceID)
        EJ_SelectEncounter(encounterID)
        EJ_SetDifficulty(diffID)
        C_EncounterJournal.SetSlotFilter(EJ_SLOT_FILTER_NO_FILTER)
        ApplyLootFilterForScan()
        local n = EJ_GetNumLoot()
        for i = 1, n do
            local info = C_EncounterJournal.GetLootInfoByIndex(i)
            if info and info.itemID == itemID and info.link then
                result = info.link
                break
            end
        end
    end)
    EJLive.scanningOnDemand = false
    UnsuppressEJ()

    if result then
        scaledLinkCache[key] = result
    end
    return result
end

local dungeonNormalCache = {}
local mergeBusy = false
local mergeTarget = nil
local MAX_MERGE_RETRIES = 3
local mergeRetries = 0
EJLive.mergeAbort = false

---@param inst table
---@param encounterID number
---@return table|nil
local function FindEncounter(inst, encounterID)
    for i = 1, #inst.encounters do
        local enc = inst.encounters[i]
        if enc.encounterID == encounterID then
            return enc
        end
    end
end

---@param enc table
---@param ejMap table
local function MergeEJRowsIntoEncounter(enc, ejMap)
    local byItemID = {}
    for i = 1, #enc.items do
        byItemID[enc.items[i].itemID] = enc.items[i]
    end
    for itemID, ejRow in pairs(ejMap) do
        local row = byItemID[itemID]
        if row then
            for _, d in ipairs(ejRow.difficulties or {}) do
                local seen = false
                for _, ed in ipairs(row.difficulties or {}) do
                    if ed.id == d.id then
                        seen = true
                        break
                    end
                end
                if not seen then
                    row.difficulties = row.difficulties or {}
                    tinsert(row.difficulties, d)
                end
            end
            if ejRow.linkByDiff then
                row.linkByDiff = row.linkByDiff or {}
                for diffID, link in pairs(ejRow.linkByDiff) do
                    row.linkByDiff[diffID] = link
                end
            end
            if ejRow.name and not row.nameResolved then
                row.name = ejRow.name
                row.nameResolved = true
                if row.itemData then
                    row.itemData.name = ejRow.name
                end
            end
            row.fromLiveEJ = true
        end
    end
    sort(enc.items, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
end

---@param inst table
local function ProcessOneInstance(inst)
    if EJLive.mergeAbort then
        return
    end
    local instanceID = inst.instanceID
    local expansionID = inst.expansionID
    local iidWorld = IsWorldHub(inst)
    local skipNormal = false
    if inst.instanceType == "party" then
        if dungeonNormalCache[instanceID] == nil then
            SuppressEJ()
            local ok, hasN = pcall(function()
                if expansionID then
                    EJ_SelectTier(expansionID)
                end
                EJ_SelectInstance(instanceID)
                local bn, _, bid = EJ_GetEncounterInfoByIndex(1)
                if not bn or not bid then
                    return false
                end
                return DungeonHasNormalLoot(instanceID, bid)
            end)
            UnsuppressEJ()
            dungeonNormalCache[instanceID] = ok and hasN or false
        end
        skipNormal = not dungeonNormalCache[instanceID]
    end

    SuppressEJ()
    local ok, err = pcall(function()
        if expansionID then
            EJ_SelectTier(expansionID)
        end
        EJ_SelectInstance(instanceID)
        local bi = 1
        while true do
            local bossName, _, bossID = EJ_GetEncounterInfoByIndex(bi)
            if not bossName or not bossID then
                break
            end
            local enc = FindEncounter(inst, bossID)
            if not enc then
                enc = {
                    encounterID = bossID,
                    name = bossName,
                    nameResolved = bossName ~= nil,
                    bossIndex = bi,
                    items = {},
                    source = "ej",
                }
                tinsert(inst.encounters, enc)
                Card.EnsureWorldSectionHeaders(inst)
            else
                enc.source = "ej"
            end
            if bossName then
                enc.name = bossName
                enc.nameResolved = true
            end
            if not enc.bossIndex or enc.bossIndex == 0 then
                enc.bossIndex = bi
            end
            local ejMap = EJLive:ScanEncounterDifficulties(instanceID, bossID, inst, iidWorld, skipNormal)
            MergeEJRowsIntoEncounter(enc, ejMap)
            bi = bi + 1
        end
        Card.SortEncountersInPlace(inst)
        Card.RecalculateInstanceTotals(inst)
    end)
    UnsuppressEJ()
    if not ok then
        print("|cffff6060OneWoW Catalog:|r Live EJ merge error: " .. tostring(err))
    end
end

---@param inst table|nil
function EJLive:SetMergeTarget(inst)
    mergeTarget = inst
    mergeRetries = 0
end

--- Scan one card against live EJ. Names and scaled links on loot already
--- on the card. Creates missing boss rows from EJ (not pins).
---@param inst table
function EJLive:MergeInstance(inst)
    if mergeBusy then
        return
    end
    if not inst or inst.instanceType == "delve" then
        return
    end
    if not inst.instanceID or inst.instanceID <= 0 then
        return
    end
    if not inst.encounters then
        return
    end

    OneWoW:EnsureLoaded("Blizzard_EncounterJournal")

    mergeBusy = true
    EJLive.mergeAbort = false
    ProcessOneInstance(inst)
    mergeBusy = false
    if not EJLive.mergeAbort then
        ns:FireScanCallbacks("ej_merge")
    end
end

function EJLive:OnJournalCacheCleared()
    self.mergeAbort = true
    mergeBusy = false
    mergeTarget = nil
    mergeRetries = 0
    if self.debounceTimer and self.debounceTimer.Cancel then
        self.debounceTimer:Cancel()
    end
    self.debounceTimer = nil
    wipe(dungeonNormalCache)
    wipe(scaledLinkCache)
end

---@param inst table|nil
---@return boolean
local function HasUnresolvedBossNames(inst)
    if not inst or not inst.encounters then
        return false
    end
    for i = 1, #inst.encounters do
        local enc = inst.encounters[i]
        if enc.encounterID and enc.encounterID > 0 then
            local items = enc.items
            if items then
                for j = 1, #items do
                    if not items[j].nameResolved then
                        return true
                    end
                end
            end
        end
    end
    return false
end

---@return boolean
local function ShouldRetryMerge()
    if mergeBusy or EJLive.scanningOnDemand then
        return false
    end
    if mergeRetries >= MAX_MERGE_RETRIES then
        return false
    end
    return HasUnresolvedBossNames(mergeTarget)
end

EventRegistry:RegisterFrameEventAndCallback("EJ_LOOT_DATA_RECIEVED", function()
    if not ShouldRetryMerge() then
        return
    end
    if EJLive.debounceTimer and EJLive.debounceTimer.Cancel then
        EJLive.debounceTimer:Cancel()
    end
    EJLive.debounceTimer = C_Timer.NewTimer(0.25, function()
        EJLive.debounceTimer = nil
        if not ShouldRetryMerge() then
            return
        end
        mergeRetries = mergeRetries + 1
        EJLive:MergeInstance(mergeTarget)
    end)
end)
