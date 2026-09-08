local _, ns = ...

local C_AddOns = C_AddOns
local GetExpansionLevel = GetExpansionLevel
local pairs, type, tonumber = pairs, type, tonumber
local tinsert, sort = tinsert, sort

-- ============================================================================
-- CatalogData
-- ============================================================================
-- Discovers installed OneWoW_CatDB_<Era> addons (plus Other), owns per-era
-- topic toggles, and loads only the shards a Catalog role needs. Era Data/
-- and DataExtra/ files register factories via Defer; tables are built when
-- the topic is enabled.
--
-- Role APIs live on Catalog (OneWoW_Catalog): journal/zones, vendors,
-- quests/archive, items. Tradeskills stay OneWoW_CatDB_TradeSkillDB.
-- ============================================================================

local CatalogData = {}
ns.CatalogData = CatalogData

local RUNTIME_ADDON = "OneWoW_Catalog"
local TRADESKILL_ADDON = "OneWoW_CatDB_TradeSkillDB"
local OTHER_ADDON = "OneWoW_CatDB_Other"
local OTHER_EXPANSION_ID = 99

local TOPICS = {
    "hubs",
    "zone",
    "zone_extra",
    "npc",
    "quest",
    "item",
    "achievement",
    "mappin",
}

local TOPIC_SET = {}
for i = 1, #TOPICS do
    TOPIC_SET[TOPICS[i]] = true
end

-- Suite expansion 1-12 -> LE expansion 0-11 (GetExpansionName).
local SUITE_TO_LE = {
    [1] = 0, [2] = 1, [3] = 2, [4] = 3, [5] = 4, [6] = 5,
    [7] = 6, [8] = 7, [9] = 8, [10] = 9, [11] = 10, [12] = 11,
}

local LE_TO_SUITE = {}
for suite, le in pairs(SUITE_TO_LE) do
    LE_TO_SUITE[le] = suite
end

local journalShardJob
local journalShardOnUpdate

local ROLE_API = {
    journal = "OneWoW_CatDB_ZoneDB_API",
    zones = "OneWoW_CatDB_ZoneDB_API",
    vendors = "OneWoW_CatDB_NPCDB_API",
    npcs = "OneWoW_CatDB_NPCDB_API",
    quests = "OneWoW_CatDB_QuestDBCurrent_API",
    archive = "OneWoW_CatDB_QuestDBCurrent_API",
    items = "OneWoW_CatDB_ItemDB_API",
    tradeskills = "OneWoW_CatDB_TradeSkillDB_API",
}

local ROLE_TOPICS = {
    journal = { hubs = true, zone = true, zone_extra = true },
    zones = { hubs = true, zone = true, zone_extra = true },
    vendors = { npc = true },
    npcs = { npc = true },
    quests = { quest = true },
    archive = { quest = true },
    items = { item = true, achievement = true },
}

local ROLE_RUNTIME = {
    journal = RUNTIME_ADDON,
    zones = RUNTIME_ADDON,
    vendors = RUNTIME_ADDON,
    npcs = RUNTIME_ADDON,
    quests = RUNTIME_ADDON,
    archive = RUNTIME_ADDON,
    items = RUNTIME_ADDON,
    tradeskills = TRADESKILL_ADDON,
}

-- LE expansion 0-9 (Classic-Dragonflight) used to live in Quest Archive.
local ARCHIVE_LE_MAX = 9

local factories = {} -- [addon][topic] = { fn, ... }
local activated = {} -- [addon][topic] = true
local sinks = {} -- [topic] = fn
local scanned
local eras -- sorted list of { addon, expansionID, title }

local function TopicsStore()
    return ns.db.global.catalogTopics
end

local function DefaultTopicOn(expansionID, topic)
    if topic == "zone_extra" then
        return false
    end
    if expansionID == OTHER_EXPANSION_ID then
        return topic == "item" or topic == "achievement"
    end
    -- Journal places for every expansion that is turned on. NPC / quest / item
    -- topics stay on The War Within and Midnight unless the player enables them.
    if topic == "zone" or topic == "hubs" then
        return true
    end
    return expansionID >= 11
end

local function ScanInstalled()
    if scanned then
        return
    end
    scanned = true
    eras = {}
    local n = C_AddOns.GetNumAddOns()
    for i = 1, n do
        local name = C_AddOns.GetAddOnInfo(i)
        local exp = C_AddOns.GetAddOnMetadata(name, "X-OneWoW-CatDB")
        if exp and exp ~= "" then
            local expansionID = tonumber(exp)
            local title
            if expansionID == OTHER_EXPANSION_ID then
                title = ns.L["CAT_MOD_ERA_OTHER"]
            else
                local le = SUITE_TO_LE[expansionID]
                title = le and ns:GetExpansionName(le) or name
            end
            tinsert(eras, {
                addon = name,
                expansionID = expansionID,
                title = title,
            })
        end
    end
    sort(eras, function(a, b)
        if a.expansionID == b.expansionID then
            return a.addon < b.addon
        end
        return a.expansionID < b.expansionID
    end)
end

function CatalogData:GetTopics()
    return TOPICS
end

function CatalogData:IsRuntimeAddon(name)
    return name == RUNTIME_ADDON
end

function CatalogData:IsEraAddon(name)
    ScanInstalled()
    for i = 1, #eras do
        if eras[i].addon == name then
            return true
        end
    end
    return false
end

function CatalogData:GetEras()
    ScanInstalled()
    return eras
end

function CatalogData:GetEra(addon)
    ScanInstalled()
    for i = 1, #eras do
        if eras[i].addon == addon then
            return eras[i]
        end
    end
    return nil
end

function CatalogData:GetStoreTitle(store)
    if store == TRADESKILL_ADDON then
        return ns.L["CAT_MOD_TRADESKILLDB"]
    end
    local era = self:GetEra(store)
    if era then
        if era.expansionID == OTHER_EXPANSION_ID then
            return ns.L["CAT_MOD_ERA_OTHER"]
        end
        return era.title
    end
    return nil
end

function CatalogData:IsTopic(topic)
    return TOPIC_SET[topic] == true
end

function CatalogData:IsTopicEnabled(addon, topic)
    if not TOPIC_SET[topic] then
        return false
    end
    local store = TopicsStore()
    local row = store[addon]
    if row and row[topic] ~= nil then
        return row[topic] and true or false
    end
    local era = self:GetEra(addon)
    if not era then
        return false
    end
    return DefaultTopicOn(era.expansionID, topic)
end

function CatalogData:SetTopicEnabled(addon, topic, enabled)
    if not TOPIC_SET[topic] then
        return
    end
    local store = TopicsStore()
    store[addon] = store[addon] or {}
    store[addon][topic] = enabled and true or false
    if enabled and C_AddOns.IsAddOnLoaded(addon) then
        self:ActivateTopic(addon, topic)
    end
end

function CatalogData:GetDefaultTopicEnabled(addon, topic)
    local era = self:GetEra(addon)
    if not era then
        return false
    end
    return DefaultTopicOn(era.expansionID, topic)
end

--- Era Data/ and DataExtra/ files call this at parse time. `factory` is not run until Activate.
--- Multiple Defer calls for the same topic merge (base then extra).
---@param addon string
---@param topic string
---@param factory function
function CatalogData:Defer(addon, topic, factory)
    if type(factory) ~= "function" or not TOPIC_SET[topic] then
        return
    end
    factories[addon] = factories[addon] or {}
    local list = factories[addon][topic]
    if not list then
        list = {}
        factories[addon][topic] = list
    end
    tinsert(list, factory)
end

---@param topic string
---@param fn function
function CatalogData:SetSink(topic, fn)
    sinks[topic] = fn
end

function CatalogData:ActivateTopic(addon, topic)
    if not TOPIC_SET[topic] then
        return
    end
    activated[addon] = activated[addon] or {}
    if activated[addon][topic] then
        return
    end
    local bag = factories[addon]
    local list = bag and bag[topic]
    if type(list) ~= "table" then
        return
    end
    local sink = sinks[topic]
    for i = 1, #list do
        local payload = list[i]()
        if sink and payload ~= nil then
            sink(payload, addon, topic)
        end
    end
    activated[addon][topic] = true
end

function CatalogData:ActivateEnabled(addon)
    for i = 1, #TOPICS do
        local topic = TOPICS[i]
        if self:IsTopicEnabled(addon, topic) then
            self:ActivateTopic(addon, topic)
        end
    end
end

local function RoleNeedsEra(self, role, era)
    local topics = ROLE_TOPICS[role]
    if not topics then
        return false
    end
    if role == "archive" then
        local le = SUITE_TO_LE[era.expansionID]
        if not le or le > ARCHIVE_LE_MAX then
            return false
        end
    end
    for topic in pairs(topics) do
        if self:IsTopicEnabled(era.addon, topic) then
            return true
        end
    end
    return false
end

function CatalogData:ResolveRoleAddon(roleOrName)
    if ROLE_RUNTIME[roleOrName] then
        return ROLE_RUNTIME[roleOrName]
    end
    if self:IsEraAddon(roleOrName) then
        return roleOrName
    end
    if roleOrName == RUNTIME_ADDON or roleOrName == TRADESKILL_ADDON then
        return roleOrName
    end
    return nil
end

function CatalogData:GetRoleAPIName(roleOrName)
    if ROLE_API[roleOrName] then
        return ROLE_API[roleOrName]
    end
    return nil
end

function CatalogData:GetRoleAPI(roleOrName)
    local apiName = ROLE_API[roleOrName]
    if not apiName then
        return nil
    end
    return _G[apiName]
end

function CatalogData:IsRoleAvailable(roleOrName)
    if roleOrName == "tradeskills" or roleOrName == TRADESKILL_ADDON then
        if not C_AddOns.DoesAddOnExist(TRADESKILL_ADDON) then
            return false
        end
        if not ns:IsFeatureWanted(RUNTIME_ADDON) then
            return false
        end
        return ns:IsFeatureWanted(TRADESKILL_ADDON)
    end
    if not C_AddOns.DoesAddOnExist(RUNTIME_ADDON) then
        return false
    end
    if not ns:IsFeatureWanted(RUNTIME_ADDON) then
        return false
    end
    ScanInstalled()
    if roleOrName == RUNTIME_ADDON then
        return true
    end
    local role = ROLE_TOPICS[roleOrName] and roleOrName or nil
    if not role then
        return self:IsEraAddon(roleOrName) and ns:IsAddonEnabled(roleOrName)
    end
    for i = 1, #eras do
        local era = eras[i]
        if ns:IsFeatureWanted(era.addon) and RoleNeedsEra(self, role, era) then
            return true
        end
    end
    -- Runtime can still answer empty queries when no era topic is on.
    return true
end

--- Load runtime + present era addons whose topics feed this role, then activate.
---@param roleOrName string
---@return string|nil runtimeAddon
function CatalogData:EnsureRole(roleOrName)
    if roleOrName == "tradeskills" or roleOrName == TRADESKILL_ADDON then
        ns:EnsureLoaded(RUNTIME_ADDON)
        ns:EnsureLoaded(TRADESKILL_ADDON)
        return TRADESKILL_ADDON
    end
    if self:IsEraAddon(roleOrName) then
        ns:EnsureLoaded(RUNTIME_ADDON)
        ns:EnsureLoaded(roleOrName)
        self:ActivateEnabled(roleOrName)
        return RUNTIME_ADDON
    end
    local role = ROLE_TOPICS[roleOrName] and roleOrName or nil
    ns:EnsureLoaded(RUNTIME_ADDON)
    -- Journal/zones place tables load per expansion via EnsureJournalShards.
    -- Activating every wanted era here hitch-opens Catalog on one frame.
    if role and role ~= "journal" and role ~= "zones" then
        ScanInstalled()
        local topics = ROLE_TOPICS[role]
        for i = 1, #eras do
            local era = eras[i]
            if ns:IsFeatureWanted(era.addon) and RoleNeedsEra(self, role, era) then
                ns:EnsureLoaded(era.addon)
                for topic in pairs(topics) do
                    if self:IsTopicEnabled(era.addon, topic) then
                        self:ActivateTopic(era.addon, topic)
                    end
                end
                if self:IsTopicEnabled(era.addon, "mappin") then
                    self:ActivateTopic(era.addon, "mappin")
                end
            end
        end
        if role == "quests" or role == "archive" then
            OneWoW_Catalog.EnsureCatDBQuestRuntime()
        elseif role == "vendors" or role == "npcs" then
            OneWoW_Catalog.EnsureCatDBVendorRuntime()
        end
    end
    return RUNTIME_ADDON
end

function CatalogData:IsTopicActivated(addon, topic)
    return activated[addon] and activated[addon][topic] == true
end

local function EraRoleTopicsReady(self, era, topics)
    if not C_AddOns.IsAddOnLoaded(era.addon) then
        return false
    end
    for topic in pairs(topics) do
        if self:IsTopicEnabled(era.addon, topic) and not self:IsTopicActivated(era.addon, topic) then
            return false
        end
    end
    return true
end

local function TradeskillRoleReady(self)
    if not ns:IsFeatureWanted(RUNTIME_ADDON) then
        return false
    end
    if not ns:IsFeatureWanted(TRADESKILL_ADDON) then
        return false
    end
    if not C_AddOns.DoesAddOnExist(TRADESKILL_ADDON) then
        return false
    end
    return C_AddOns.IsAddOnLoaded(TRADESKILL_ADDON) and self:GetRoleAPI("tradeskills") ~= nil
end

--- wanted eras for this role, and how many of those have their topics activated.
---@return number wanted
---@return number ready
local function CountRoleEraReadiness(self, role)
    ScanInstalled()
    local topics = ROLE_TOPICS[role]
    local wanted, ready = 0, 0
    for i = 1, #eras do
        local era = eras[i]
        if (role == "journal" or role == "zones") and era.expansionID == OTHER_EXPANSION_ID then
            -- Other has no Journal places.
        elseif ns:IsFeatureWanted(era.addon) and RoleNeedsEra(self, role, era) then
            wanted = wanted + 1
            if EraRoleTopicsReady(self, era, topics) then
                ready = ready + 1
            end
        end
    end
    return wanted, ready
end

--- True when this role can answer a query from already-loaded expansion data.
--- Journal is ready when any wanted expansion is activated (not every era).
---@param roleOrName string
---@return boolean
function CatalogData:IsRoleQueryReady(roleOrName)
    if roleOrName == "tradeskills" or roleOrName == TRADESKILL_ADDON then
        return TradeskillRoleReady(self)
    end
    if not ns:IsFeatureWanted(RUNTIME_ADDON) then
        return false
    end
    if not C_AddOns.IsAddOnLoaded(RUNTIME_ADDON) then
        return false
    end
    if not self:GetRoleAPI(roleOrName) then
        return false
    end
    local role = ROLE_TOPICS[roleOrName] and roleOrName or nil
    if not role then
        return self:IsEraAddon(roleOrName) and C_AddOns.IsAddOnLoaded(roleOrName)
    end
    local _, ready = CountRoleEraReadiness(self, role)
    return ready > 0
end

--- True when every wanted expansion for this role is loaded and activated.
---@param roleOrName string
---@return boolean
function CatalogData:IsRoleFullyLoaded(roleOrName)
    if roleOrName == "tradeskills" or roleOrName == TRADESKILL_ADDON then
        return TradeskillRoleReady(self)
    end
    if not ns:IsFeatureWanted(RUNTIME_ADDON) then
        return false
    end
    if not C_AddOns.IsAddOnLoaded(RUNTIME_ADDON) then
        return false
    end
    if not self:GetRoleAPI(roleOrName) then
        return false
    end
    local role = ROLE_TOPICS[roleOrName] and roleOrName or nil
    if not role then
        return self:IsEraAddon(roleOrName) and C_AddOns.IsAddOnLoaded(roleOrName)
    end
    local wanted, ready = CountRoleEraReadiness(self, role)
    return wanted > 0 and ready == wanted
end

local function RoleUnavailable(self, role)
    return not self:IsRoleQueryReady(role) or not self:IsRoleFullyLoaded(role)
end

--- Player-facing reason a Catalog-backed line is empty. Nil when the role can query.
--- Empty sources while an expansion is still unloaded must not look like "no sources."
---@param roleOrRoles string|string[]
---@return string|nil
function CatalogData:GetUnavailableNotice(roleOrRoles)
    if type(roleOrRoles) == "table" then
        for i = 1, #roleOrRoles do
            if RoleUnavailable(self, roleOrRoles[i]) then
                return ns.L["CATALOG_NOT_ENABLED"]
            end
        end
        return nil
    end
    if not roleOrRoles or not RoleUnavailable(self, roleOrRoles) then
        return nil
    end
    return ns.L["CATALOG_NOT_ENABLED"]
end

--- True when Catalog is up and every wanted expansion's Journal place
--- topics (hubs + zone) are loaded and activated. Missing a shard means this
--- place's card/toast should say Zones Catalog is not loaded.
function CatalogData:AreWantedJournalPlacesLoaded()
    if not C_AddOns.IsAddOnLoaded(RUNTIME_ADDON) then
        return false
    end
    if not self:GetRoleAPI("journal") then
        return false
    end
    ScanInstalled()
    for i = 1, #eras do
        local era = eras[i]
        if era.expansionID ~= OTHER_EXPANSION_ID and ns:IsFeatureWanted(era.addon) then
            if not C_AddOns.IsAddOnLoaded(era.addon) then
                return false
            end
            if not self:IsTopicActivated(era.addon, "hubs") or not self:IsTopicActivated(era.addon, "zone") then
                return false
            end
        end
    end
    return true
end

local function ActivateJournalEra(self, era)
    ns:EnsureLoaded(era.addon)
    self:ActivateTopic(era.addon, "hubs")
    self:ActivateTopic(era.addon, "zone")
    if self:IsTopicEnabled(era.addon, "zone_extra") then
        self:ActivateTopic(era.addon, "zone_extra")
    end
    if self:IsTopicEnabled(era.addon, "mappin") then
        self:ActivateTopic(era.addon, "mappin")
    end
end

function CatalogData:CancelJournalShardJob()
    if journalShardJob then
        local job = journalShardJob
        journalShardJob = nil
        journalShardOnUpdate = nil
        job:Cancel()
    end
end

--- Suite expansion for the client's current expansion, or the newest wanted pack.
---@return number expansionID 0 when no journal pack is wanted
function CatalogData:GetCurrentSuiteExpansionID()
    ScanInstalled()
    local current = LE_TO_SUITE[GetExpansionLevel()] or 12
    for i = 1, #eras do
        local era = eras[i]
        if era.expansionID == current and ns:IsFeatureWanted(era.addon) then
            return current
        end
    end
    for i = #eras, 1, -1 do
        local era = eras[i]
        if era.expansionID ~= OTHER_EXPANSION_ID and ns:IsFeatureWanted(era.addon) then
            return era.expansionID
        end
    end
    return 0
end

--- Wanted Journal expansions for the Zones dropdown (even before those shards load).
---@return { expansionID: number, displayName: string }[]
function CatalogData:GetWantedJournalExpansions()
    ScanInstalled()
    local out = {}
    for i = 1, #eras do
        local era = eras[i]
        if era.expansionID ~= OTHER_EXPANSION_ID and ns:IsFeatureWanted(era.addon) then
            tinsert(out, { expansionID = era.expansionID, displayName = era.title })
        end
    end
    return out
end

--- Load hubs + zone for one suite expansion (no-op for 0 / All).
---@param expansionID number
function CatalogData:EnsureJournalShards(expansionID)
    if not expansionID or expansionID == 0 then
        return
    end
    ns:EnsureLoaded(RUNTIME_ADDON)
    ScanInstalled()
    for i = 1, #eras do
        local era = eras[i]
        if era.expansionID == expansionID and ns:IsFeatureWanted(era.addon) then
            ActivateJournalEra(self, era)
            return
        end
    end
end

--- Load the selected expansion now. All loads this expansion first, then the rest
--- across frames so opening Zones does not hitch every pack on one paint.
---@param expansionID number
---@param onUpdate function|nil
function CatalogData:EnsureJournalShardsForFilter(expansionID, onUpdate)
    ns:EnsureLoaded(RUNTIME_ADDON)
    ScanInstalled()
    if expansionID and expansionID ~= 0 then
        self:CancelJournalShardJob()
        self:EnsureJournalShards(expansionID)
        return
    end
    local current = self:GetCurrentSuiteExpansionID()
    if current ~= 0 then
        self:EnsureJournalShards(current)
    end
    journalShardOnUpdate = onUpdate
    if journalShardJob then
        return
    end
    local pending = {}
    for i = 1, #eras do
        local era = eras[i]
        if era.expansionID ~= OTHER_EXPANSION_ID
            and era.expansionID ~= current
            and ns:IsFeatureWanted(era.addon)
        then
            if not (self:IsTopicActivated(era.addon, "hubs") and self:IsTopicActivated(era.addon, "zone")) then
                tinsert(pending, era)
            end
        end
    end
    if #pending == 0 then
        return
    end
    journalShardJob = ns.ChunkedJob.Start({
        budgetMs = 8,
        run = function(shouldYield)
            for i = 1, #pending do
                ActivateJournalEra(self, pending[i])
                ns.ChunkedJob.YieldIfNeeded(shouldYield)
            end
        end,
        onProgress = function()
            if journalShardOnUpdate then
                journalShardOnUpdate()
            end
        end,
        onComplete = function()
            journalShardJob = nil
            local cb = journalShardOnUpdate
            journalShardOnUpdate = nil
            if cb then
                cb()
            end
        end,
        onCancel = function()
            journalShardJob = nil
        end,
    })
end

--- Load zone + hubs for every wanted expansion pack (not Other).
--- Used when standing in a place whose expansion topic was off or never loaded.
function CatalogData:EnsureWantedJournalPlaces()
    self:CancelJournalShardJob()
    ns:EnsureLoaded(RUNTIME_ADDON)
    ScanInstalled()
    for i = 1, #eras do
        local era = eras[i]
        if era.expansionID ~= OTHER_EXPANSION_ID and ns:IsFeatureWanted(era.addon) then
            ActivateJournalEra(self, era)
        end
    end
end

--- Load every present era that has this topic enabled.
---@param topic string
function CatalogData:EnsureTopic(topic)
    if not TOPIC_SET[topic] then
        return
    end
    ns:EnsureLoaded(RUNTIME_ADDON)
    ScanInstalled()
    for i = 1, #eras do
        local era = eras[i]
        if ns:IsFeatureWanted(era.addon) and self:IsTopicEnabled(era.addon, topic) then
            ns:EnsureLoaded(era.addon)
            self:ActivateTopic(era.addon, topic)
        end
    end
end

function CatalogData:GetMapPinPacks()
    ScanInstalled()
    local out = {}
    for i = 1, #eras do
        local era = eras[i]
        if C_AddOns.IsAddOnLoaded(era.addon) and self:IsTopicEnabled(era.addon, "mappin") then
            self:ActivateTopic(era.addon, "mappin")
        end
        local pins = self.shippedPins[era.addon]
        if type(pins) == "table" then
            tinsert(out, {
                id = "catdb:" .. era.addon,
                name = era.title,
                expansion = SUITE_TO_LE[era.expansionID],
                pins = pins,
                shipped = true,
                addon = era.addon,
            })
        end
    end
    return out
end

CatalogData.shippedPins = CatalogData.shippedPins or {}
CatalogData.RUNTIME_ADDON = RUNTIME_ADDON
CatalogData.TRADESKILL_ADDON = TRADESKILL_ADDON
CatalogData.OTHER_ADDON = OTHER_ADDON
CatalogData.OTHER_EXPANSION_ID = OTHER_EXPANSION_ID
CatalogData.SUITE_TO_LE = SUITE_TO_LE
CatalogData.ARCHIVE_LE_MAX = ARCHIVE_LE_MAX
