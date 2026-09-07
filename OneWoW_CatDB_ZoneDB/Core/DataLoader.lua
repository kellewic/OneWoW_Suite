local _, ns = ...

-- ============================================================================
-- ZoneDB loader
-- ============================================================================
-- Emit agents call these registrars from Data/ shards:
--   ns:RegisterPlaceData{ ["instance:63"] = { ... } }
--   ns:RegisterEncounterData{ [89] = { ... } }
--   ns:RegisterDifficultyData{ [1] = { ... } }
--   ns:RegisterTierMembership{ ... }
--   ns:RegisterListingOverrides{ ... }
-- ============================================================================

local pairs = pairs

ns.Places = ns.Places or {}
ns.Encounters = ns.Encounters or {}
ns.Difficulties = ns.Difficulties or {}
ns.TierMembership = ns.TierMembership or {}
ns.ListingOverrides = ns.ListingOverrides or {}

local function MergeByKey(dest, source)
    if type(source) ~= "table" then return end
    for key, row in pairs(source) do
        dest[key] = row
    end
end

--- Merge place rows (zone / instance / delve / hub / world).
---@param source table<string, table>
function ns:RegisterPlaceData(source)
    MergeByKey(ns.Places, source)
end

--- Merge encounter rows keyed by encounterID.
---@param source table<number, table>
function ns:RegisterEncounterData(source)
    MergeByKey(ns.Encounters, source)
end

--- Merge Difficulty rows keyed by difficultyID.
---@param source table<number, table>
function ns:RegisterDifficultyData(source)
    MergeByKey(ns.Difficulties, source)
end

--- Merge journal-tier membership.
---@param source table
function ns:RegisterTierMembership(source)
    MergeByKey(ns.TierMembership, source)
end

--- Merge listing overrides.
---@param source table
function ns:RegisterListingOverrides(source)
    MergeByKey(ns.ListingOverrides, source)
end
