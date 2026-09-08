local ADDON_NAME, ns = ...

local ipairs = ipairs

-- Scan callbacks used to live on BootStore. Catalog is a hub, not a store.
local scanCallbacks = {}

function ns:RegisterScanCallback(idOrFn, maybeFn)
    local id, fn
    if type(idOrFn) == "function" then
        fn = idOrFn
        id = nil
    else
        id = idOrFn
        fn = maybeFn
    end
    scanCallbacks[#scanCallbacks + 1] = { id = id, fn = fn }
end

function ns:FireScanCallbacks(data)
    for i, entry in ipairs(scanCallbacks) do
        local label = entry.id or ("CatDB#" .. i)
        OneWoW.Lifecycle.SafeCall(label, entry.fn, data)
    end
end

--- Learned NPC overlay. Deferred until NPCs are actually used so opening
--- Zones does not walk every saved vendor into memory.
function ns:EnsureCatDBVendorRuntime()
    if ns._catdbVendorRuntime then
        return
    end
    ns._catdbVendorRuntime = true
    ns:ApplyLearnedNPCs()
end

--- Quest completion snapshot and log catch-up. Deferred until Quests are used
--- so opening Zones does not copy every completed quest id.
function ns:EnsureCatDBQuestRuntime()
    if ns._catdbQuestRuntime then
        return
    end
    ns._catdbQuestRuntime = true
    if OneWoW.CatDBSync then
        OneWoW.CatDBSync.Flush("quest")
        OneWoW.CatDBSync.Register("quest", OneWoW_CatDB_QuestDBCurrent_API.GetSyncQueue)
    end
    ns:SnapshotShippedQuestIDs()
    ns:ApplyLearnedQuests()
    ns.CompletionTracker:Initialize()
    ns.QuestScanner:Initialize()
end

function ns:StartCatDBRuntime()
    ns.DataLoader = OneWoW:CreateItemDataLoader(ns:GetDB())
    ns.DataLoader:Initialize()
    if OneWoW.CatDBSync then
        OneWoW.CatDBSync.Flush("npc")
        OneWoW.CatDBSync.Register("npc", OneWoW_CatDB_NPCDB_API.GetSyncQueue)
    end
    OneWoW.Merchant.RegisterScanCallback("CatDB_NPCDB", function(scan)
        OneWoW_CatDB_NPCDB_API.MergeMerchantScan(scan)
    end)
    OneWoW:SignalDataReady(ADDON_NAME)
end
