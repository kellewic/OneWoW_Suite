local _, ns = ...

local OneWoW = OneWoW
local C_Timer = C_Timer
local C_AddOns = C_AddOns

-- ============================================================================
-- Catalog data-pack loader
-- ============================================================================
-- Catalog packs are lazyStores: login does not parse them. Opening a pack-backed
-- tab is the usual trigger (MainWindow EnsureCatalogPack). Quest capture still needs
-- quest shards when the player talks to an NPC without opening Catalog first.
-- Load on the next frame so the quest / reward UI can paint before the pack
-- parse (QuestScanner.Initialize catch-up stores the dialog that triggered it).
-- ============================================================================

local questPackFrame = CreateFrame("Frame")
local loadQueued = false
questPackFrame:SetScript("OnEvent", function(self)
    if loadQueued then
        return
    end
    loadQueued = true
    C_Timer.After(0, function()
        local addon = OneWoW:EnsureCatalogPack("quests")
        if addon and C_AddOns.IsAddOnLoaded(addon) then
            self:UnregisterAllEvents()
        else
            loadQueued = false
        end
    end)
end)

--- Arm gameplay load triggers for lazy Catalog packs.
--- Registers quest events so the Quests pack loads on first NPC interaction.
function ns.ArmCatalogDataPacks()
    questPackFrame:RegisterEvent("QUEST_DETAIL")
    questPackFrame:RegisterEvent("QUEST_PROGRESS")
    questPackFrame:RegisterEvent("QUEST_ACCEPTED")
    questPackFrame:RegisterEvent("QUEST_TURNED_IN")
    questPackFrame:RegisterEvent("QUEST_COMPLETE")
end
