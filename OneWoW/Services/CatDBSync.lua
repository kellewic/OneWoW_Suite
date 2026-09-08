local _, ns = ...

-- ============================================================================
-- CatDBSync
-- ============================================================================
-- Always-loaded queue for facts the player just saw (NPC talk, quest dialog,
-- merchant, trainer, services, profession window). CatDB packs are
-- LoadOnDemand — gossip must not parse NPC shards. Rows land here, then flush
-- into the pack's learned overlay when that pack loads. New or newly complete
-- facts set sync = true. Companion reads only those flagged rows (plus this
-- pending queue). This file does not upload.
--
-- Contract: OneWoW/Docs/CATDB_CONTRIBUTE.md
-- ============================================================================

local CatDBSync = {}
ns.CatDBSync = CatDBSync

local ipairs, pairs, type = ipairs, pairs, type
local tonumber = tonumber
local time = time
local tinsert, wipe = tinsert, wipe
local strsplit = strsplit
local C_Timer = C_Timer
local C_AddOns = C_AddOns
local C_TradeSkillUI = C_TradeSkillUI
local Enum = Enum
local UnitExists, UnitGUID, UnitName = UnitExists, UnitGUID, UnitName
local UnitCreatureType, UnitClassification = UnitCreatureType, UnitClassification

local INTERACT_UNITS = { "npc", "questnpc", "target" }
local KINDS = { "npc", "quest", "recipe" }

local getters = {}
local session = { npc = {}, quest = {}, recipe = {} }
local questLoadQueued = false
local recipeLoadQueued = false

local function CopyScalarTable(src)
    if type(src) ~= "table" then
        return nil
    end
    local out = {}
    for k, v in pairs(src) do
        out[k] = v
    end
    return out
end

local function RoleList(roles)
    local out, seen = {}, {}
    if type(roles) ~= "table" then
        return out
    end
    for i = 1, #roles do
        local role = roles[i]
        if type(role) == "string" and role ~= "" and not seen[role] then
            seen[role] = true
            tinsert(out, role)
        end
    end
    for role, flag in pairs(roles) do
        if type(role) == "string" and flag and not seen[role] then
            seen[role] = true
            tinsert(out, role)
        end
    end
    return out
end

local function MergeRoleLists(dst, src)
    if type(src) ~= "table" then
        return dst
    end
    dst = dst or {}
    local seen = {}
    for i = 1, #dst do
        seen[dst[i]] = true
    end
    local incoming = RoleList(src)
    for i = 1, #incoming do
        local role = incoming[i]
        if not seen[role] then
            seen[role] = true
            tinsert(dst, role)
        end
    end
    return dst
end

local function MergeIDList(dst, src)
    if src == nil then
        return dst
    end
    dst = dst or {}
    local seen = {}
    for i = 1, #dst do
        seen[dst[i]] = true
    end
    local function add(id)
        id = tonumber(id)
        if id and not seen[id] then
            seen[id] = true
            tinsert(dst, id)
        end
    end
    if type(src) == "number" then
        add(src)
    elseif type(src) == "table" then
        for i = 1, #src do
            add(src[i])
        end
        add(src.questID or src.id)
    end
    return dst
end

local function MergeLearnInfo(dst, src)
    if type(src) ~= "table" then
        return dst
    end
    dst = dst or {}
    if src.name and src.name ~= "" and (not dst.name or dst.name == "") then
        dst.name = src.name
    end
    if src.title and src.title ~= "" and (not dst.title or dst.title == "") then
        dst.title = src.title
    end
    if src.subtitle and src.subtitle ~= "" and (not dst.subtitle or dst.subtitle == "") then
        dst.subtitle = src.subtitle
    end
    if src.category and src.category ~= "" and (not dst.category or dst.category == "") then
        dst.category = src.category
    end
    if src.displayID and (not dst.displayID or dst.displayID == 0) then
        dst.displayID = src.displayID
    end
    if src.creatureType and (not dst.creatureType or dst.creatureType == "") then
        dst.creatureType = src.creatureType
    end
    if src.classification and not dst.classification then
        dst.classification = src.classification
    end
    if src.expansion and not dst.expansion then
        dst.expansion = src.expansion
    end
    dst.roles = MergeRoleLists(dst.roles, src.roles)
    dst.questIDs = MergeIDList(dst.questIDs, src.questIDs)
    dst.questIDs = MergeIDList(dst.questIDs, src.questID)
    if src.mapID and not dst.mapID then
        dst.mapID = src.mapID
        dst.x = src.x
        dst.y = src.y
    elseif src.mapID and src.x and src.y and (not dst.x or not dst.y) then
        dst.mapID = src.mapID
        dst.x = src.x
        dst.y = src.y
    end
    if type(src.locations) == "table" then
        dst.locations = dst.locations or {}
        for mapID, loc in pairs(src.locations) do
            if type(loc) == "table" and not dst.locations[mapID] then
                dst.locations[mapID] = CopyScalarTable(loc)
            end
        end
    end
    if type(src.items) == "table" and not dst.items then
        dst.items = src.items
    end
    if src.lastScanned then
        dst.lastScanned = src.lastScanned
    end
    if src.sync then
        dst.sync = true
    end
    if src.item and not dst.item then
        dst.item = src.item
    end
    if src.prof and not dst.prof then
        dst.prof = src.prof
    end
    if src.pid and not dst.pid then
        dst.pid = src.pid
    end
    if type(src.rg) == "table" and not dst.rg then
        dst.rg = src.rg
    end
    return dst
end

local function PersistRoot()
    local db = ns.db and ns.db.global
    if not db then
        return nil
    end
    db.catdbLearn = db.catdbLearn or { npc = {}, quest = {}, recipe = {} }
    for i = 1, #KINDS do
        local kind = KINDS[i]
        if type(db.catdbLearn[kind]) ~= "table" then
            db.catdbLearn[kind] = {}
        end
    end
    return db.catdbLearn
end

local function Queue(kind, id, info)
    id = tonumber(id)
    if not id or not kind then
        return
    end
    session[kind][id] = MergeLearnInfo(session[kind][id], info)
    session[kind][id].id = session[kind][id].id or id
    session[kind][id].learnedAt = session[kind][id].learnedAt or time()
    session[kind][id].sync = true
    local store = PersistRoot()
    if store then
        store[kind][id] = MergeLearnInfo(store[kind][id], session[kind][id])
        store[kind][id].sync = true
    end
end

local function TakePending(kind)
    local out = {}
    local store = PersistRoot()
    local persisted = store and store[kind]
    if type(persisted) == "table" then
        for id, info in pairs(persisted) do
            out[id] = MergeLearnInfo(out[id], info)
        end
        wipe(persisted)
    end
    for id, info in pairs(session[kind]) do
        out[id] = MergeLearnInfo(out[id], info)
    end
    wipe(session[kind])
    return out
end

local function CopyPending(kind)
    local out = {}
    local store = PersistRoot()
    local persisted = store and store[kind]
    if type(persisted) == "table" then
        for id, info in pairs(persisted) do
            out[id] = info
        end
    end
    for id, info in pairs(session[kind]) do
        out[id] = MergeLearnInfo(CopyScalarTable(out[id]), info)
    end
    return out
end

---@param pack string
---@param getter fun(): table
function CatDBSync.Register(pack, getter)
    if type(pack) == "string" and type(getter) == "function" then
        getters[pack] = getter
    end
end

---@param kind string|nil
function CatDBSync.Flush(kind)
    if kind == "npc" or not kind then
        local api = OneWoW_CatDB_NPCDB_API
        if api and api.EnsureLearnedNPC then
            for id, info in pairs(TakePending("npc")) do
                api.EnsureLearnedNPC(id, info)
            end
        end
    end
    if kind == "quest" or not kind then
        local api = OneWoW_CatDB_QuestDBCurrent_API
        if api and api.StoreQuestInfo then
            for id, info in pairs(TakePending("quest")) do
                api.StoreQuestInfo(id, info)
            end
        end
    end
    if kind == "recipe" or not kind then
        local api = OneWoW_CatDB_TradeSkillDB_API
        if api and api.EnsureLearnedRecipe then
            for id, info in pairs(TakePending("recipe")) do
                api.EnsureLearnedRecipe(id, info)
            end
        end
    end
end

---@return table
function CatDBSync.GetQueue()
    local out = {
        npc = CopyPending("npc"),
        quest = CopyPending("quest"),
        recipe = CopyPending("recipe"),
    }
    for pack, getter in pairs(getters) do
        local ok, rows = pcall(getter)
        if ok and type(rows) == "table" then
            local dest = out[pack]
            if type(dest) ~= "table" then
                dest = {}
                out[pack] = dest
            end
            for id, rec in pairs(rows) do
                dest[id] = rec
            end
        end
    end
    return out
end

---@param npcID number
---@param info table|nil
function CatDBSync.LearnNPC(npcID, info)
    npcID = tonumber(npcID)
    if not npcID or npcID == 0 then
        return
    end
    local api = OneWoW_CatDB_NPCDB_API
    if api and api.EnsureLearnedNPC then
        api.EnsureLearnedNPC(npcID, info)
        return
    end
    Queue("npc", npcID, info)
end

---@param questID number
---@param info table|nil
function CatDBSync.LearnQuest(questID, info)
    questID = tonumber(questID)
    if not questID or questID == 0 then
        return
    end
    local api = OneWoW_CatDB_QuestDBCurrent_API
    if api and api.StoreQuestInfo then
        api.StoreQuestInfo(questID, info or { id = questID })
        return
    end
    Queue("quest", questID, info)
end

---@param recipeID number
---@param info table|nil
function CatDBSync.LearnRecipe(recipeID, info)
    recipeID = tonumber(recipeID)
    if not recipeID or recipeID == 0 then
        return
    end
    local api = OneWoW_CatDB_TradeSkillDB_API
    if api and api.EnsureLearnedRecipe then
        api.EnsureLearnedRecipe(recipeID, info)
        return
    end
    Queue("recipe", recipeID, info)
end

local function GetInteractUnit()
    for _, unit in ipairs(INTERACT_UNITS) do
        if UnitExists(unit) then
            local guid = UnitGUID(unit)
            if guid and not ns.Restriction.IsSecret(guid) then
                local unitType, _, _, _, _, unitID = strsplit("-", guid)
                unitID = tonumber(unitID)
                if unitID
                    and (unitType == "Creature" or unitType == "Vehicle")
                then
                    return {
                        unit = unit,
                        id = unitID,
                        name = UnitName(unit),
                        creatureType = UnitCreatureType(unit),
                        classification = UnitClassification(unit),
                    }
                end
            end
        end
    end
    return nil
end

local function RoleFromInteraction(interactionType)
    if not interactionType then
        return nil
    end
    local pit = Enum.PlayerInteractionType
    if interactionType == pit.Merchant then
        return "vendor"
    end
    if interactionType == pit.Trainer then
        return "trainer"
    end
    if interactionType == pit.QuestGiver then
        return "quest_giver"
    end
    local serviceKeys = {
        "Banker", "GuildBanker", "TaxiNode", "BarberShop", "Transmogrifier",
        "Auctioneer", "Binder", "TabardVendor", "VoidStorageBanker",
        "ItemUpgrade", "GuildRegistrar", "Registrar", "PetitionVendor",
        "MailInfo", "SpiritHealer", "AdventureMap",
    }
    for i = 1, #serviceKeys do
        if interactionType == pit[serviceKeys[i]] then
            return "service"
        end
    end
    return nil
end

local function CaptureInteract(role)
    local unit = GetInteractUnit()
    if not unit then
        return
    end
    local mapID, x, y = ns.Location.GetPlayerLocation()
    local info = {
        name = unit.name,
        creatureType = unit.creatureType,
        classification = unit.classification,
        mapID = mapID,
        x = x,
        y = y,
        lastScanned = time(),
    }
    if role then
        info.roles = { role }
        if role == "quest_giver" then
            info.category = "quest_giver"
        elseif role == "trainer" then
            info.category = "profession_trainer"
        end
    end
    CatDBSync.LearnNPC(unit.id, info)
end

local function ArmQuestPack()
    if questLoadQueued then
        return
    end
    questLoadQueued = true
    C_Timer.After(0, function()
        questLoadQueued = false
        ns:EnsureCatalogPack("quests")
    end)
end

local function ArmTradeSkillPack()
    if recipeLoadQueued then
        return
    end
    local addon = ns.ResolveCatalogPack and ns:ResolveCatalogPack("tradeskills")
    if not addon then
        return
    end
    if C_AddOns.IsAddOnLoaded(addon) then
        return
    end
    recipeLoadQueued = true
    C_Timer.After(0, function()
        recipeLoadQueued = false
        if ns.EnsureLoaded then
            ns:EnsureLoaded(addon)
        end
        if ns.ProfessionRecipe.IsTradeskillOpen() then
            ScanVisibleRecipes(ns.ProfessionRecipe.GetLastScan())
        end
    end)
end

local function CaptureRecipeInfo(recipeID, scan)
    local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
    local out = { id = recipeID }
    if info then
        out.name = info.name
    end
    if scan and scan.baseInfo then
        out.prof = scan.baseInfo.parentProfessionName or scan.baseInfo.professionName
        out.pid = scan.baseInfo.parentProfessionID or scan.baseInfo.professionID
    end
    local link = C_TradeSkillUI.GetRecipeItemLink(recipeID)
    if link then
        out.item = tonumber(link:match("item:(%d+)"))
    end
    local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
    if schematic and schematic.reagentSlotSchematics then
        local rg = {}
        local basic = Enum.CraftingReagentType.Basic
        for i = 1, #schematic.reagentSlotSchematics do
            local slot = schematic.reagentSlotSchematics[i]
            if slot.reagentType == basic and slot.reagents then
                local qty = slot.quantityRequired or 1
                for j = 1, #slot.reagents do
                    local reagent = slot.reagents[j]
                    if reagent and reagent.itemID then
                        tinsert(rg, { reagent.itemID, qty })
                    end
                end
            end
        end
        if rg[1] then
            out.rg = rg
        end
    end
    return out
end

local function RecipeNeedsContribute(recipeID)
    local api = OneWoW_CatDB_TradeSkillDB_API
    if not api then
        return false
    end
    local shipped = api.GetRecipe(recipeID)
    if not shipped then
        return true
    end
    return type(shipped.rg) ~= "table" or shipped.rg[1] == nil
end

local function ScanVisibleRecipes(scan)
    local ids = C_TradeSkillUI.GetAllRecipeIDs()
    if not ids then
        return
    end
    for i = 1, #ids do
        local recipeID = ids[i]
        if RecipeNeedsContribute(recipeID) then
            CatDBSync.LearnRecipe(recipeID, CaptureRecipeInfo(recipeID, scan))
        end
    end
end

local EVENT_ROLES = {
    GOSSIP_SHOW = nil,
    QUEST_GREETING = "quest_giver",
    QUEST_DETAIL = "quest_giver",
    QUEST_PROGRESS = "quest_giver",
    QUEST_COMPLETE = "quest_giver",
    QUEST_ACCEPTED = "quest_giver",
    QUEST_TURNED_IN = "quest_giver",
    TRAINER_SHOW = "trainer",
    TAXIMAP_OPENED = "service",
}

local QUEST_EVENTS = {
    QUEST_DETAIL = true,
    QUEST_PROGRESS = true,
    QUEST_COMPLETE = true,
    QUEST_ACCEPTED = true,
    QUEST_TURNED_IN = true,
}

local function OnEvent(event, arg1)
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        CaptureInteract(RoleFromInteraction(arg1))
        return
    end
    if QUEST_EVENTS[event] then
        ArmQuestPack()
    end
    if EVENT_ROLES[event] ~= nil or event == "GOSSIP_SHOW" then
        CaptureInteract(EVENT_ROLES[event])
    end
end

ns.RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "CatDBSync", OnEvent)
for event in pairs(EVENT_ROLES) do
    ns.RegisterEvent(event, "CatDBSync", OnEvent)
end

if ns.Merchant and ns.Merchant.RegisterScanCallback then
    ns.Merchant.RegisterScanCallback("CatDBSync", function(scan)
        if not scan or not scan.npcID or scan.npcID == 0 then
            return
        end
        local loc = scan.location
        CatDBSync.LearnNPC(scan.npcID, {
            name = scan.name,
            title = scan.subtitle,
            subtitle = scan.subtitle,
            displayID = scan.displayID,
            creatureType = scan.creatureType,
            classification = scan.classification,
            roles = { "vendor" },
            mapID = loc and loc.mapID,
            x = loc and loc.x,
            y = loc and loc.y,
            items = scan.items,
            lastScanned = scan.scannedAt,
        })
    end)
end

ns.ProfessionRecipe.RegisterShowCallback("CatDBSync", function()
    ArmTradeSkillPack()
end)

ns.ProfessionRecipe.RegisterScanCallback("CatDBSync", function(scan)
    ScanVisibleRecipes(scan)
end)

ns.ProfessionRecipe.RegisterLearnedCallback("CatDBSync", function(recipeID)
    recipeID = tonumber(recipeID)
    if not recipeID then
        return
    end
    CatDBSync.LearnRecipe(recipeID, CaptureRecipeInfo(recipeID))
end)

ns:RegisterCoreLoginHandler("CatDBSync", function()
    local store = PersistRoot()
    if store then
        for i = 1, #KINDS do
            local kind = KINDS[i]
            for id, info in pairs(session[kind]) do
                store[kind][id] = MergeLearnInfo(store[kind][id], info)
            end
        end
    end
    CatDBSync.Flush()
end)
