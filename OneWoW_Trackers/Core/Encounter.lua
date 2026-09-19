local _, ns = ...

-- ============================================================================
-- TrackerEncounter
-- ============================================================================
-- Dungeon and raid boss tracking cannot read unit GUIDs (secret in instances).
-- Completion uses ENCOUNTER_END's combat encounter ID plus raid lockouts.
-- Fill uses the current or last-ended encounter, not the targeted unit.
-- ============================================================================

ns.TrackerEncounter = {}
local Enc = ns.TrackerEncounter

local tonumber = tonumber
local GetInstanceInfo = GetInstanceInfo
local EJ_GetEncounterInfo = EJ_GetEncounterInfo
local EJ_GetEncounterInfoByIndex = EJ_GetEncounterInfoByIndex
local EJ_SelectInstance = EJ_SelectInstance
local EJ_GetInstanceInfo = EJ_GetInstanceInfo
local C_EncounterJournal = C_EncounterJournal

local active
local lastEnded

local function SafeText(value)
    if value == nil or value == "" then return nil end
    if OneWoW.Restriction.IsSecret(value) then return nil end
    return value
end

-- GetInstanceForGameMap is nilable in the docs but returns 0 when the map has
-- no Adventure Guide instance this session. EJ_SelectInstance(0) errors.
local function JournalInstanceID(id)
    id = tonumber(id)
    if not id or id < 1 then return nil end
    return id
end

local function InstanceMapID()
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType == "none" then return nil end
    return tonumber(instanceID)
end

--- Journal encounter ID and display name for a combat encounter on this map.
---@param dungeonEncounterID number
---@param instanceMapID number|nil
---@return number|nil journalEncounterID
---@return string|nil name
local function JournalForDungeon(dungeonEncounterID, instanceMapID)
    dungeonEncounterID = tonumber(dungeonEncounterID)
    instanceMapID = tonumber(instanceMapID)
    if not dungeonEncounterID or not instanceMapID then return nil end

    local journalInstanceID = JournalInstanceID(C_EncounterJournal.GetInstanceForGameMap(instanceMapID))
    if not journalInstanceID then return nil end

    EJ_SelectInstance(journalInstanceID)
    local i = 1
    while true do
        local name, _, journalID, _, _, _, combatID = EJ_GetEncounterInfoByIndex(i, journalInstanceID)
        if not journalID then break end
        if tonumber(combatID) == dungeonEncounterID then
            return journalID, SafeText(name)
        end
        i = i + 1
    end
end

local function Snapshot(dungeonEncounterID, encounterName, difficultyID)
    local mapID = InstanceMapID()
    local journalID, journalName = JournalForDungeon(dungeonEncounterID, mapID)
    return {
        dungeonEncounterID = tonumber(dungeonEncounterID),
        journalEncounterID = journalID,
        name = journalName or SafeText(encounterName),
        difficultyID = tonumber(difficultyID),
        mapID = mapID,
    }
end

--- Remember the pull that just started (numeric IDs from ENCOUNTER_START).
---@param dungeonEncounterID number
---@param encounterName string|nil
---@param difficultyID number|nil
function Enc.OnEncounterStart(dungeonEncounterID, encounterName, difficultyID)
    if OneWoW.Restriction.IsSecret(dungeonEncounterID) then
        active = nil
        return
    end
    active = Snapshot(dungeonEncounterID, encounterName, difficultyID)
end

--- Remember a successful kill (numeric IDs from ENCOUNTER_END).
---@param dungeonEncounterID number
---@param encounterName string|nil
---@param difficultyID number|nil
---@param success number
function Enc.OnEncounterEnd(dungeonEncounterID, encounterName, difficultyID, success)
    if OneWoW.Restriction.IsSecret(dungeonEncounterID) then
        active = nil
        return
    end
    local snap = Snapshot(dungeonEncounterID, encounterName, difficultyID)
    active = nil
    if tonumber(success) == 1 then
        lastEnded = snap
    end
end

function Enc.OnEnteringWorld()
    active = nil
end

--- Current pull, or the last successful kill this session.
---@return table|nil info
function Enc.GetFillable()
    return active or lastEnded
end

--- Display ID for the editor box (Adventure Guide encounter ID when known).
---@param info table
---@return number|nil
function Enc.DisplayID(info)
    return info.journalEncounterID or info.dungeonEncounterID
end

--- Journal ID, combat ID, and instance map for a typed Adventure Guide encounter.
---@param journalEncounterID number
---@return table|nil
function Enc.ResolveFromJournalID(journalEncounterID)
    journalEncounterID = tonumber(journalEncounterID)
    if not journalEncounterID then return nil end
    if OneWoW.Restriction.IsSecret(journalEncounterID) then return nil end

    local name, _, _, _, _, journalInstanceID = EJ_GetEncounterInfo(journalEncounterID)
    name = SafeText(name)
    if not name and not journalInstanceID then return nil end

    local dungeonEncounterID, mapID
    journalInstanceID = JournalInstanceID(journalInstanceID)
    if journalInstanceID then
        EJ_SelectInstance(journalInstanceID)
        local i = 1
        while true do
            local _, _, journalID, _, _, _, combatID = EJ_GetEncounterInfoByIndex(i, journalInstanceID)
            if not journalID then break end
            if journalID == journalEncounterID then
                dungeonEncounterID = tonumber(combatID)
                break
            end
            i = i + 1
        end
        local _, _, _, _, _, _, _, _, _, instanceMapID = EJ_GetInstanceInfo(journalInstanceID)
        mapID = tonumber(instanceMapID)
    end

    return {
        encounterID = journalEncounterID,
        dungeonEncounterID = dungeonEncounterID,
        mapID = mapID,
        name = name,
    }
end

--- Combat encounter ID used by ENCOUNTER_END / raid locks.
---@param params table
---@return number|nil
function Enc.DungeonIDFromParams(params)
    local dungeonID = tonumber(params.dungeonEncounterID)
    if dungeonID then return dungeonID end
    local journalID = tonumber(params.encounterID)
    if not journalID then return nil end
    local resolved = Enc.ResolveFromJournalID(journalID)
    if resolved and resolved.dungeonEncounterID then
        params.dungeonEncounterID = resolved.dungeonEncounterID
        if resolved.mapID and not params.mapID then
            params.mapID = resolved.mapID
        end
        return resolved.dungeonEncounterID
    end
end

--- Merge fill stash and journal lookup into saved step params.
---@param params table
---@param fill table|nil
---@return table
function Enc.EnrichParams(params, fill)
    local typed = tonumber(params.encounterID)
    if fill then
        params.dungeonEncounterID = fill.dungeonEncounterID or params.dungeonEncounterID
        if fill.mapID then params.mapID = fill.mapID end
        if fill.journalEncounterID then
            params.encounterID = fill.journalEncounterID
        elseif typed then
            params.encounterID = typed
        end
        return params
    end

    if not typed then return params end
    local resolved = Enc.ResolveFromJournalID(typed)
    if resolved then
        params.encounterID = resolved.encounterID
        if resolved.dungeonEncounterID then
            params.dungeonEncounterID = resolved.dungeonEncounterID
        end
        if resolved.mapID and not params.mapID then
            params.mapID = resolved.mapID
        end
    elseif not params.dungeonEncounterID then
        params.dungeonEncounterID = typed
    end
    return params
end

local E = ns.TrackerEvaluators
local C_RaidLocks = C_RaidLocks

-- Live lockout when map + combat ID are known. Returns nil while the lock is
-- still open so a just-killed session latch is not wiped on the next scan.
E.Register("kill_encounter", function(op)
    local dungeonID = tonumber(op.dungeonEncounterID) or Enc.DungeonIDFromParams(op)
    local mapID = tonumber(op.mapID)
    if not dungeonID or not mapID then return end
    local diffID = tonumber(op.difficultyID)
    if C_RaidLocks.IsEncounterComplete(mapID, dungeonID, diffID) then
        return 1, 1
    end
end)
