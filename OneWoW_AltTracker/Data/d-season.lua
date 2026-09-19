local _, ns = ...

local tinsert = tinsert
local C_EncounterJournal = C_EncounterJournal
local C_ChallengeMode = C_ChallengeMode
local C_MythicPlus = C_MythicPlus
local C_SeasonInfo = C_SeasonInfo
local EJ_GetCurrentTier = EJ_GetCurrentTier
local EJ_SelectTier = EJ_SelectTier
local EJ_GetInstanceByIndex = EJ_GetInstanceByIndex
local EJ_GetInstanceInfo = EJ_GetInstanceInfo
local EJ_SelectInstance = EJ_SelectInstance
local EJ_GetEncounterInfoByIndex = EJ_GetEncounterInfoByIndex

ns.SeasonData = ns.SeasonData or {}

-- journalInstanceID / mapID from JournalInstance. Per-raid difficulties from
-- MapDifficulty (Story/Lorewalking omitted). Tidebound has no LFR or 20-man
-- Mythic; weekly outdoor lock is World (250).
ns.SeasonData.raids = {
    {
        key = "venomous",
        label = "The Venomous Abyss",
        short = "Abyss",
        journalInstanceID = 1320,
        mapID = 3004,
        difficulties = {
            {id = 17, key = "LFR", label = "L"},
            {id = 14, key = "NOR", label = "N"},
            {id = 15, key = "HER", label = "H"},
            {id = 16, key = "MYT", label = "M"},
        },
    },
    {
        key = "tidebound",
        label = "The Tidebound Grotto",
        short = "Tide",
        journalInstanceID = 1317,
        mapID = 2987,
        worldBossQuestID = 97128,
        difficulties = {
            {id = 14, key = "NOR", label = "N"},
            {id = 15, key = "HER", label = "H"},
            {id = 233, key = "MYT", label = "M"},
            {id = 250, key = "WORLD", label = "W"},
        },
    },
}

ns.SeasonData.raidDifficulties = {
    {id = 17, key = "LFR", label = "L"},
    {id = 14, key = "NOR", label = "N"},
    {id = 15, key = "HER", label = "H"},
    {id = 16, key = "MYT", label = "M"},
}

-- mapID is MapChallengeMode ID (C_ChallengeMode / C_MythicPlus), not uiMapID.
ns.SeasonData.dungeons = {
    {key = "sd1", name = "Altar of Fangs",          short = "FANG",  mapID = 588},
    {key = "sd2", name = "Murder Row",              short = "MURD",  mapID = 587},
    {key = "sd3", name = "Den of Nalorakk",         short = "NALO",  mapID = 586},
    {key = "sd4", name = "The Blinding Vale",       short = "VALE",  mapID = 584},
    {key = "sd5", name = "Voidscar Arena",          short = "VOID",  mapID = 585},
    {key = "sd6", name = "Ruby Life Pools",         short = "RLP",   mapID = 399},
    {key = "sd7", name = "Kings' Rest",             short = "KR",    mapID = 249},
    {key = "sd8", name = "Temple of Sethraliss",    short = "TOS",   mapID = 250},
}

local raidCache = nil

local function BuildRaidCache()
    local cache = {}
    local currentTier = EJ_GetCurrentTier()
    EJ_SelectTier(currentTier)

    local index = 1
    while true do
        local instanceID, name, _, _, buttonImage = EJ_GetInstanceByIndex(index, true)
        if not instanceID then break end

        local _, _, _, _, _, _, _, _, _, instanceMapID = EJ_GetInstanceInfo(instanceID)
        local mapID = nil
        if type(instanceMapID) == "number" then
            mapID = instanceMapID
        end

        cache[name] = {
            journalInstanceID = instanceID,
            mapID = mapID,
            name = name,
            buttonImage = buttonImage,
        }
        index = index + 1
    end

    return cache
end

local function ChallengeNamesMatch(a, b)
    if a == b then return true end
    if not a or not b then return false end
    return (a:gsub("^The ", "")) == (b:gsub("^The ", ""))
end

--- Fill `dung.mapID` from `C_ChallengeMode.GetMapTable()` when the hardcoded
--- ID is missing or stale. Matches `dung.name` to `GetMapUIInfo`.
---@param dung table
---@return number|nil mapID
function ns.SeasonData:ResolveDungeonMapID(dung)
    if dung.mapID and dung.mapID > 0 then
        local name = C_ChallengeMode.GetMapUIInfo(dung.mapID)
        if name then
            return dung.mapID
        end
    end
    local mapTable = C_ChallengeMode.GetMapTable()
    for _, id in ipairs(mapTable) do
        local name = C_ChallengeMode.GetMapUIInfo(id)
        if ChallengeNamesMatch(name, dung.name) then
            dung.mapID = id
            return id
        end
    end
    return dung.mapID
end

function ns.SeasonData:GetRaidCache()
    if not raidCache then
        raidCache = BuildRaidCache()
    end
    return raidCache
end

function ns.SeasonData:RefreshRaidCache()
    raidCache = BuildRaidCache()
    return raidCache
end

--- Journal instance, game map, and EJ button art. Prefers shipped IDs, then
--- `GetInstanceForGameMap`, then the current-tier name cache.
---@param raidEntry table
---@return number|nil journalInstanceID
---@return number|nil mapID
---@return number|nil buttonImage
function ns.SeasonData:ResolveRaid(raidEntry)
    local journalInstanceID = raidEntry.journalInstanceID
    local mapID = raidEntry.mapID
    local buttonImage

    if not journalInstanceID and type(mapID) == "number" then
        journalInstanceID = C_EncounterJournal.GetInstanceForGameMap(mapID)
    end
    journalInstanceID = tonumber(journalInstanceID)
    if journalInstanceID and journalInstanceID < 1 then
        journalInstanceID = nil
    end

    if journalInstanceID then
        local _, _, _, _, btn, _, _, _, _, instanceMapID = EJ_GetInstanceInfo(journalInstanceID)
        buttonImage = btn
        if type(instanceMapID) == "number" then
            mapID = mapID or instanceMapID
        end
        return journalInstanceID, mapID, buttonImage
    end

    local cache = self:GetRaidCache()
    local info = cache[raidEntry.label]
    if not info then
        for cacheName, cacheInfo in pairs(cache) do
            if ChallengeNamesMatch(cacheName, raidEntry.label) then
                info = cacheInfo
                break
            end
        end
    end
    if info then
        return info.journalInstanceID, mapID or info.mapID, info.buttonImage
    end
    return nil, mapID, nil
end

--- Difficulty columns for this raid, or the shared L/N/H/M list.
---@param raidEntry table|nil
---@return table difficulties
function ns.SeasonData:GetRaidDifficulties(raidEntry)
    if raidEntry and raidEntry.difficulties then
        return raidEntry.difficulties
    end
    return self.raidDifficulties
end

function ns.SeasonData:GetRaidEncounters(raidEntry)
    local journalInstanceID = raidEntry.journalInstanceID
    if not journalInstanceID then
        journalInstanceID = self:ResolveRaid(raidEntry)
    end
    journalInstanceID = tonumber(journalInstanceID)
    if not journalInstanceID or journalInstanceID < 1 then return {} end

    EJ_SelectInstance(journalInstanceID)
    local encounters = {}
    local index = 1
    while true do
        local name, _, journalEncounterID, _, _, _, dungeonEncounterID = EJ_GetEncounterInfoByIndex(index, journalInstanceID)
        if not name then break end
        tinsert(encounters, {
            name = name,
            journalEncounterID = journalEncounterID,
            dungeonEncounterID = dungeonEncounterID,
            index = index,
        })
        index = index + 1
    end
    return encounters
end

-- EXPANSION_SEASON_NAME uses a per-expansion ordinal (1, 2, 3…), not the
-- content season UID from C_SeasonInfo.GetCurrentDisplaySeasonID.
local MAX_EXPANSION_SEASON_ORDINAL = 12

---@return number|nil
local function SeasonOrdinalFromAPI()
    local displayNum = C_MythicPlus.GetCurrentSeasonValues()
    if displayNum and displayNum > 0 and displayNum <= MAX_EXPANSION_SEASON_ORDINAL then
        return displayNum
    end
    local uiSeason = C_MythicPlus.GetCurrentUIDisplaySeason()
    if uiSeason and uiSeason > 0 and uiSeason <= MAX_EXPANSION_SEASON_ORDINAL then
        return uiSeason
    end
    return nil
end

--- Per-expansion season ordinal from live Mythic+ APIs.
---@return number|nil
function ns.SeasonData:GetCurrentSeasonNumber()
    local ordinal = SeasonOrdinalFromAPI()
    if ordinal then
        return ordinal
    end
    if C_MythicPlus.GetCurrentSeason() == -1 then
        C_MythicPlus.RequestMapInfo()
        return SeasonOrdinalFromAPI()
    end
    return nil
end

--- Localized tooltip-style label (`EXPANSION_SEASON_NAME`), e.g. "Midnight Season 2".
---@return string|nil
function ns.SeasonData:GetCurrentSeasonLabel()
    local seasonNum = self:GetCurrentSeasonNumber()
    if not seasonNum then
        return nil
    end
    local expName = OneWoW:GetExpansionName(LE_EXPANSION_LEVEL_CURRENT)
    if not expName then
        local displayExpID = C_SeasonInfo.GetCurrentDisplaySeasonExpansion()
        expName = displayExpID and OneWoW:GetExpansionName(displayExpID)
    end
    if not expName then
        return nil
    end
    return EXPANSION_SEASON_NAME:format(expName, seasonNum)
end

--- Client patch for display, e.g. "12.1" or "12.1.5".
---@return string
function ns.SeasonData:GetClientPatchDisplay()
    local version = GetBuildInfo()
    local major, minor, rev = version:match("^(%d+)%.(%d+)%.(%d+)")
    if not major then
        return version
    end
    if rev ~= "0" then
        return major .. "." .. minor .. "." .. rev
    end
    return major .. "." .. minor
end
