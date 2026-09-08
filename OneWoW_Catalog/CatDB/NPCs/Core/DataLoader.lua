local _, ns = ...

-- ============================================================================
-- NPCDB loader
-- ============================================================================
-- Emit agents call ns:RegisterNpcData{ [npcID] = { ... } } from Data/ shards.
--   ns.NPCs            [npcID] = npc record
--   ns.NPCsByItem      [itemID][npcID] = true
--   ns.VendorIDs       [npcID] = true  (listed Catalog NPCs)
-- ============================================================================

local pairs = pairs

ns.NPCs = ns.NPCs or {}
ns.NPCsByItem = ns.NPCsByItem or {}
ns.VendorIDs = ns.VendorIDs or {}

local npcs = ns.NPCs
local byItem = ns.NPCsByItem
local vendorIDs = ns.VendorIDs

--- True for the Catalog NPCs list: interactable roles, encounters, or anyone
--- the player talked to / learned.
---@param npc table|nil
---@return boolean
function ns.IsListVendor(npc)
    if not npc then
        return false
    end
    if npc.learned or npc.sync or npc.lastScanned then
        return true
    end
    local roles = npc.roles
    if roles then
        for i = 1, #roles do
            local role = roles[i]
            if role == "vendor" or role == "trainer" or role == "service"
                or role == "quest_giver" or role == "rare" or role == "boss"
                or role == "vignette" then
                return true
            end
        end
        return false
    end
    local hasItems = false
    if npc.items then
        for _ in pairs(npc.items) do
            hasItems = true
            break
        end
    end
    return hasItems
end

--- Merge NPC rows keyed by npcID.
---@param source table<number, table>
function ns:RegisterNpcData(source)
    if type(source) ~= "table" then return end

    for npcID, record in pairs(source) do
        if type(npcID) == "number" and type(record) == "table" then
            npcs[npcID] = record
            if ns.IsListVendor(record) then
                vendorIDs[npcID] = true
            else
                vendorIDs[npcID] = nil
            end
            if record.items then
                for itemID in pairs(record.items) do
                    if type(itemID) == "number" then
                        byItem[itemID] = byItem[itemID] or {}
                        byItem[itemID][npcID] = true
                    end
                end
            end
        end
    end
end
