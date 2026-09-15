local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local Inventory = OneWoW.Inventory
local Location = OneWoW.Location

ns.TrackerEngine = {}
local TE = ns.TrackerEngine
local TD

local pairs, ipairs, tonumber, tostring = pairs, ipairs, tonumber, tostring
local tinsert, wipe = tinsert, wipe
local format, strlower = format, strlower
local time = time
local UnitFactionGroup, CreateVector2D = UnitFactionGroup, CreateVector2D
local C_MapExplorationInfo = C_MapExplorationInfo

local eventFrame = nil
local lootIndex = {}
local npcIndex = {}
local instanceIndex = {}
local killIndex = {}
local encounterIndex = {}
local exploreIndex = {}
local next = next
local lastScanTime = 0
local SCAN_THROTTLE = 1.0
local initialized = false
local callbacks = {}
local scanPending = false
local refreshPending = false

function TE:RegisterCallback(event, fn)
    callbacks[event] = callbacks[event] or {}
    tinsert(callbacks[event], fn)
end

local function FireCallbacks(event, ...)
    if callbacks[event] then
        for _, fn in ipairs(callbacks[event]) do
            fn(...)
        end
    end
end

-- True when a step is flagged rosterMode. Roster steps record the current
-- character into the account-wide roster on trigger completion instead of
-- flipping a single shared checkbox.
local function StepIsRoster(listID, sectionKey, stepKey)
    local step = TD:GetStep(listID, sectionKey, stepKey)
    return step and step.rosterMode
end

local activeEventsCache = {}
local lastEventCheck = 0
local calendarKnown = false
local observedListID = nil

-- Calendar-gated sections stay visible until CALENDAR_UPDATE_EVENT_LIST.
-- After that, a missing eventID is inactive.

local function RefreshActiveEvents()
    local now = time()
    if calendarKnown and (now - lastEventCheck) < 300 then return end
    lastEventCheck = now
    wipe(activeEventsCache)
    local currentDate = C_DateAndTime.GetCurrentCalendarTime()
    if not currentDate then return end
    local numEvents = C_Calendar.GetNumDayEvents(0, currentDate.monthDay)
    for i = 1, numEvents do
        local event = C_Calendar.GetDayEvent(0, currentDate.monthDay, i)
        if event and event.eventID then
            activeEventsCache[event.eventID] = true
        end
    end
end

function TE:IsEventActive(eventID)
    if not eventID then return true end
    RefreshActiveEvents()
    if not calendarKnown then return true end
    return activeEventsCache[tonumber(eventID)] or false
end

function TE:SetObservedList(listID)
    if observedListID == listID then return end
    observedListID = listID
    if initialized then
        self:RebuildIndices()
    end
end

local function IsListObserved(listID, list)
    return list.pinned or listID == observedListID
end

function TE:HasProfession(baseSkillLineID)
    if not baseSkillLineID then return true end
    baseSkillLineID = tonumber(baseSkillLineID)
    if not baseSkillLineID then return true end
    local prof1, prof2 = GetProfessions()
    for _, idx in ipairs({ prof1, prof2 }) do
        if idx then
            local _, _, _, _, _, _, skillLineID = GetProfessionInfo(idx)
            if skillLineID == baseSkillLineID then return true end
        end
    end
    return false
end

local function MatchesFaction(faction)
    if not faction or faction == "both" then return true end
    local playerFaction = UnitFactionGroup("player")
    if not playerFaction then return false end
    return strlower(playerFaction) == strlower(faction)
end

function TE:IsStepVisible(step, section)
    if step and not MatchesFaction(step.faction) then
        return false
    end
    if step and step.professionRequired and not self:HasProfession(step.professionRequired) then
        return false
    end
    if step and step.eventRequired and not self:IsEventActive(step.eventRequired) then
        return false
    end
    if section and not MatchesFaction(section.faction) then
        return false
    end
    if section and section.professionRequired and not self:HasProfession(section.professionRequired) then
        return false
    end
    if section and section.eventRequired and not self:IsEventActive(section.eventRequired) then
        return false
    end
    return true
end

function TE:IsSectionVisible(section)
    if section and not MatchesFaction(section.faction) then
        return false
    end
    if section and section.professionRequired and not self:HasProfession(section.professionRequired) then
        return false
    end
    if section and section.eventRequired and not self:IsEventActive(section.eventRequired) then
        return false
    end
    return true
end

function TE:HasIncompleteStep(listID, section)
    for _, step in ipairs(section.steps or {}) do
        if not TD:IsStepComplete(listID, section.key, step.key) then
            return true
        end
    end
    return false
end

function TE:HasIncompleteVisibleStep(listID, section)
    for _, step in ipairs(section.steps or {}) do
        if self:IsStepVisible(step, section) and not TD:IsStepComplete(listID, section.key, step.key) then
            return true
        end
    end
    return false
end

function TE:HasIncompleteVisibleList(listID)
    local list = TD:GetList(listID)
    if not list then return false end
    for _, sec in ipairs(list.sections or {}) do
        if self:IsSectionVisible(sec) and self:HasIncompleteVisibleStep(listID, sec) then
            return true
        end
    end
    return false
end

--- Pin membership stays even when the overlay is hidden (auto-hide or role
--- scope). DestroyPinnedWindow is the only unpin path.
---@param list table
---@return boolean
function TE:ShouldShowPinnedOverlay(list)
    if not list or not list.pinned then return false end
    local scope = list.pinScope
    if scope and scope.mode == "selected" then
        if not OneWoW.AltScope:IsCharIncluded(OneWoW_GUI:BuildCharKey(), scope) then
            return false
        end
    end
    if list.pinnedAutoHideWhenComplete and list.listType ~= "farmvalue" then
        if not self:HasIncompleteVisibleList(list.id) then
            return false
        end
    end
    return true
end

local overlaySyncing = {}

local function NotifyMapPins()
    ns.TrackerMap:MarkMinimapDirty()
    ns.TrackerMap:RefreshWorldMap()
end

function TE:SyncPinnedOverlay(listID)
    if overlaySyncing[listID] then return end
    local list = TD:GetList(listID)
    if not list then return end
    overlaySyncing[listID] = true
    local should = self:ShouldShowPinnedOverlay(list)
    local win = ns.TrackerPinned:Get(listID)
    if should then
        if win then
            if not win:IsShown() then
                win:Show()
                win:Refresh()
            end
        else
            self:CreatePinnedWindow(listID)
            if not self:ShouldShowPinnedOverlay(list) then
                ns.TrackerPinned:Suppress(listID)
            end
        end
    elseif win then
        ns.TrackerPinned:Suppress(listID)
    end
    overlaySyncing[listID] = nil
    NotifyMapPins()
end

function TE:SyncAllPinnedOverlays()
    local lists = TD:GetListsDB()
    for listID, list in pairs(lists) do
        if list.pinned then
            self:SyncPinnedOverlay(listID)
        end
    end
end

local function BuildIndices()
    wipe(lootIndex)
    wipe(npcIndex)
    wipe(instanceIndex)
    wipe(killIndex)
    wipe(encounterIndex)
    wipe(exploreIndex)

    local lists = TD:GetListsDB()
    for listID, list in pairs(lists) do
        if IsListObserved(listID, list) then
        for _, sec in ipairs(list.sections) do
            for _, step in ipairs(sec.steps or {}) do
                local tt = step.trackType
                local tp = step.trackParams or {}

                if tt == "loot_item" and tp.itemID then
                    local iid = tonumber(tp.itemID)
                    if iid then
                        lootIndex[iid] = lootIndex[iid] or {}
                        tinsert(lootIndex[iid], { listID = listID, sectionKey = sec.key, stepKey = step.key })
                    end
                end

                if tt == "npc_interact" and tp.npcID then
                    local nid = tonumber(tp.npcID)
                    if nid then
                        npcIndex[nid] = npcIndex[nid] or {}
                        tinsert(npcIndex[nid], { listID = listID, sectionKey = sec.key, stepKey = step.key })
                    end
                end

                if tt == "enter_instance" and tp.instanceID then
                    local insID = tonumber(tp.instanceID)
                    if insID then
                        instanceIndex[insID] = instanceIndex[insID] or {}
                        tinsert(instanceIndex[insID], { listID = listID, sectionKey = sec.key, stepKey = step.key })
                    end
                end

                if tt == "kill_creature" and tp.creatureID then
                    local cid = tonumber(tp.creatureID)
                    if cid then
                        killIndex[cid] = killIndex[cid] or {}
                        tinsert(killIndex[cid], { listID = listID, sectionKey = sec.key, stepKey = step.key })
                    end
                end

                if tt == "kill_encounter" then
                    local eid = ns.TrackerEncounter.DungeonIDFromParams(tp)
                    if eid then
                        encounterIndex[eid] = encounterIndex[eid] or {}
                        tinsert(encounterIndex[eid], {
                            listID = listID, sectionKey = sec.key, stepKey = step.key,
                        })
                    end
                end

                if tt == "exploration" and tp.areaID then
                    local aid = tonumber(tp.areaID)
                    if aid then
                        exploreIndex[aid] = exploreIndex[aid] or {}
                        tinsert(exploreIndex[aid], { listID = listID, sectionKey = sec.key, stepKey = step.key })
                    end
                end

                for _, obj in ipairs(step.objectives or {}) do
                    local ot = obj.type
                    local op = obj.params or {}

                    if ot == "npc_interact" and op.npcID then
                        local nid = tonumber(op.npcID)
                        if nid then
                            npcIndex[nid] = npcIndex[nid] or {}
                            tinsert(npcIndex[nid], {
                                listID = listID, sectionKey = sec.key,
                                stepKey = step.key, objKey = obj.key,
                            })
                        end
                    end

                    if ot == "enter_instance" and op.instanceID then
                        local insID = tonumber(op.instanceID)
                        if insID then
                            instanceIndex[insID] = instanceIndex[insID] or {}
                            tinsert(instanceIndex[insID], {
                                listID = listID, sectionKey = sec.key,
                                stepKey = step.key, objKey = obj.key,
                            })
                        end
                    end

                    if ot == "kill_creature" and op.creatureID then
                        local cid = tonumber(op.creatureID)
                        if cid then
                            killIndex[cid] = killIndex[cid] or {}
                            tinsert(killIndex[cid], {
                                listID = listID, sectionKey = sec.key,
                                stepKey = step.key, objKey = obj.key,
                            })
                        end
                    end

                    if ot == "kill_encounter" then
                        local eid = ns.TrackerEncounter.DungeonIDFromParams(op)
                        if eid then
                            encounterIndex[eid] = encounterIndex[eid] or {}
                            tinsert(encounterIndex[eid], {
                                listID = listID, sectionKey = sec.key,
                                stepKey = step.key, objKey = obj.key,
                            })
                        end
                    end

                    if ot == "exploration" and op.areaID then
                        local aid = tonumber(op.areaID)
                        if aid then
                            exploreIndex[aid] = exploreIndex[aid] or {}
                            tinsert(exploreIndex[aid], {
                                listID = listID, sectionKey = sec.key,
                                stepKey = step.key, objKey = obj.key,
                            })
                        end
                    end
                end
            end
        end
        end
    end
end

function TE:EvaluateObjective(obj)
    return ns.TrackerEvaluators.Evaluate(obj)
end

function TE:EvaluateStep(listID, sectionKey, step)
    if not step then return end

    if step.objectives and #step.objectives > 0 then
        local allComplete = true
        for _, obj in ipairs(step.objectives) do
            local current, max = self:EvaluateObjective(obj)
            if current ~= nil then
                local complete = max and max > 0 and current >= max
                TD:SetObjectiveComplete(listID, sectionKey, step.key, obj.key, complete)
                if not complete then allComplete = false end
            else
                if not TD:GetObjectiveProgress(listID, sectionKey, step.key, obj.key) then
                    allComplete = false
                end
            end
        end

        local sp = TD:GetStepProgress(listID, sectionKey, step.key)
        if allComplete and not sp.completed then sp.lastCompleted = time() end
        sp.completed = allComplete
        sp.current = allComplete and 1 or 0
    else
        local current, goal = self:EvaluateObjective({
            type = step.trackType,
            params = step.trackParams or {},
        })

        local effectiveMax = 0
        if not step.noMax then
            if goal ~= nil then
                effectiveMax = goal
            else
                effectiveMax = step.max or 1
            end
        end

        if step.rosterMode then
            if current ~= nil and effectiveMax > 0 and current >= effectiveMax then
                TD:RecordRosterCompletion(listID, step.key)
            end
            return
        end

        if current ~= nil then
            local sp = TD:GetStepProgress(listID, sectionKey, step.key)
            sp.current = current
            if step.noMax then return end
            if effectiveMax > 0 and current >= effectiveMax then
                if not sp.completed then sp.lastCompleted = time() end
                sp.completed = true
            elseif effectiveMax > 0 then
                sp.completed = false
            end
        end
    end
end

function TE:FullScan()
    scanPending = false
    local now = time()
    if (now - lastScanTime) < SCAN_THROTTLE then return end
    lastScanTime = now

    local lists = TD:GetListsDB()
    for listID, list in pairs(lists) do
        if IsListObserved(listID, list) then
            self:EvaluateList(listID)
        end
    end

    FireCallbacks("OnScanComplete")
    self:RefreshAllPinnedWindows()
end

local function DeferScan(delay)
    if scanPending then return end
    scanPending = true
    C_Timer.After(delay or 0.5, function()
        TE:FullScan()
    end)
end

local function DeferRefresh()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.1, function()
        refreshPending = false
        TE:RefreshAllPinnedWindows()
    end)
end

function TE:EvaluateList(listID)
    local list = TD:GetList(listID)
    if not list then return end

    for _, sec in ipairs(list.sections) do
        if self:IsSectionVisible(sec) then
            for _, step in ipairs(sec.steps or {}) do
                if self:IsStepVisible(step, sec) then
                    -- Session types without objectives no-op here (Evaluate
                    -- returns nil); steps with objectives roll up through
                    -- EvaluateStep so a ticked last objective can complete
                    -- the parent instead of sitting in a dead exclusion list.
                    self:EvaluateStep(listID, sec.key, step)
                end
            end
        end
    end
    if list.pinned then
        self:SyncPinnedOverlay(listID)
    end
end

-- Session latch: objectives roll up through EvaluateStep; bare session steps
-- bump (or roster-record) the same way the four original handlers did.
local function LatchSession(ref, max)
    if ref.objKey then
        TD:SetObjectiveComplete(ref.listID, ref.sectionKey, ref.stepKey, ref.objKey, true)
        local step = TD:GetStep(ref.listID, ref.sectionKey, ref.stepKey)
        if step then
            TE:EvaluateStep(ref.listID, ref.sectionKey, step)
        end
        return
    end
    if StepIsRoster(ref.listID, ref.sectionKey, ref.stepKey) then
        TD:RecordRosterCompletion(ref.listID, ref.stepKey)
        return
    end
    local step = TD:GetStep(ref.listID, ref.sectionKey, ref.stepKey)
    TD:BumpStepProgress(ref.listID, ref.sectionKey, ref.stepKey, 1, max or (step and step.max) or 1)
end

local function OnItemLooted(itemID)
    itemID = tonumber(itemID)
    if not itemID or not lootIndex[itemID] then return end

    for _, ref in ipairs(lootIndex[itemID]) do
        LatchSession(ref, 1)
    end

    FireCallbacks("OnProgressChanged")
    DeferRefresh()
end

local function OnNPCInteract(npcID)
    npcID = tonumber(npcID)
    if not npcID or not npcIndex[npcID] then return end

    for _, ref in ipairs(npcIndex[npcID]) do
        LatchSession(ref, 1)
    end

    FireCallbacks("OnProgressChanged")
    DeferRefresh()
end

local function OnEnterInstance()
    if not next(instanceIndex) then return end
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType == "none" then return end
    instanceID = tonumber(instanceID)
    if not instanceID or not instanceIndex[instanceID] then return end

    for _, ref in ipairs(instanceIndex[instanceID]) do
        LatchSession(ref, 1)
    end

    FireCallbacks("OnProgressChanged")
    DeferRefresh()
end

local function OnCreatureKilled(creatureID)
    creatureID = tonumber(creatureID)
    if not creatureID or not killIndex[creatureID] then return end

    for _, ref in ipairs(killIndex[creatureID]) do
        LatchSession(ref)
    end

    FireCallbacks("OnProgressChanged")
    DeferRefresh()
end

local function OnEncounterKilled(dungeonEncounterID)
    dungeonEncounterID = tonumber(dungeonEncounterID)
    if not dungeonEncounterID or not encounterIndex[dungeonEncounterID] then return end

    for _, ref in ipairs(encounterIndex[dungeonEncounterID]) do
        LatchSession(ref)
    end

    FireCallbacks("OnProgressChanged")
    DeferRefresh()
end

-- There is no "has area X ever been explored" query, so exploration latches
-- from the area IDs under the player's feet when fog updates (and once after
-- login, in case the event fired before indices existed).
local function OnAreaExplored()
    if not next(exploreIndex) then return end
    local mapID, x, y = Location.GetPlayerLocation()
    if not mapID or not x then return end

    local areaIDs = C_MapExplorationInfo.GetExploredAreaIDsAtPosition(
        mapID, CreateVector2D(x / 100, y / 100))
    if not areaIDs then return end

    local any = false
    for i = 1, #areaIDs do
        local refs = exploreIndex[areaIDs[i]]
        if refs then
            for _, ref in ipairs(refs) do
                LatchSession(ref, 1)
                any = true
            end
        end
    end
    if any then
        FireCallbacks("OnProgressChanged")
        DeferRefresh()
    end
end

local function OnPlayerEnteringWorld()
    TD:CheckResets()
    TD:CheckCustomTimerResets()
    BuildIndices()
    ns.TrackerEncounter.OnEnteringWorld()
    scanPending = true
    C_Timer.After(2, function()
        TE:FullScan()
        OnEnterInstance()
        OnAreaExplored()
    end)
    C_Timer.After(3, function()
        C_Calendar.OpenCalendar()
    end)
    TE:RestorePinnedWindows()
end

local function OnEvent(_, event, ...)
    if event == "CHAT_MSG_LOOT" then
        local msg = ...
        if msg and not OneWoW.Restriction.IsSecret(msg) then
            local itemID = msg:match("item:(%d+)")
            if itemID then
                OnItemLooted(itemID)
            end
        end

    elseif event == "GOSSIP_SHOW" then
        local npcGUID = UnitGUID("npc")
        if npcGUID and not OneWoW.Restriction.IsSecret(npcGUID) then
            local npcType, _, _, _, _, npcID = strsplit("-", npcGUID)
            if npcType == "Creature" then
                OnNPCInteract(npcID)
            end
        end

    elseif event == "ENCOUNTER_START" then
        local encounterID, encounterName, difficultyID = ...
        ns.TrackerEncounter.OnEncounterStart(encounterID, encounterName, difficultyID)

    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, difficultyID, _, success = ...
        ns.TrackerEncounter.OnEncounterEnd(encounterID, encounterName, difficultyID, success)
        if tonumber(success) == 1 and not OneWoW.Restriction.IsSecret(encounterID) then
            OnEncounterKilled(encounterID)
        end

    elseif event == "PARTY_KILL" then
        -- 12.0 removed COMBAT_LOG_EVENT_UNFILTERED for addons; PARTY_KILL now
        -- delivers (attackerGUID, targetGUID) directly. The target GUID is a
        -- secret value while its unit identity is restricted (inside instances),
        -- so kill tracking only resolves in the open world.
        if next(killIndex) then
            local _, targetGUID = ...
            if targetGUID and not OneWoW.Restriction.IsSecret(targetGUID) then
                local unitType, _, _, _, _, creatureID = strsplit("-", targetGUID)
                if unitType == "Creature" or unitType == "Vehicle" then
                    OnCreatureKilled(creatureID)
                end
            end
        end

    elseif event == "CALENDAR_UPDATE_EVENT_LIST" then
        calendarKnown = true
        lastEventCheck = 0
        DeferScan(1.0)

    elseif event == "MAP_EXPLORATION_UPDATED" then
        OnAreaExplored()

    else
        DeferScan(0.5)
    end
end

local function EnsureEventFrame()
    if not eventFrame then
        eventFrame = CreateFrame("Frame", "OneWoW_Trackers_EngineFrame", UIParent)
        eventFrame:Hide()
    end
    return eventFrame
end

function TE:OnPlayerEnteringWorld()
    OnPlayerEnteringWorld()
end

function TE:Initialize()
    TD = ns.TrackerData
    if not TD then return end
    if initialized then return end
    initialized = true

    local frame = EnsureEventFrame()
    frame:RegisterEvent("QUEST_LOG_UPDATE")
    frame:RegisterEvent("QUEST_TURNED_IN")
    frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    frame:RegisterEvent("CHAT_MSG_LOOT")
    frame:RegisterEvent("GOSSIP_SHOW")
    frame:RegisterEvent("PARTY_KILL")
    frame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    frame:RegisterEvent("ENCOUNTER_START")
    frame:RegisterEvent("ENCOUNTER_END")
    frame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
    frame:RegisterEvent("UPDATE_FACTION")
    frame:RegisterEvent("PLAYER_LEVEL_UP")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("ZONE_CHANGED")
    frame:RegisterEvent("SKILL_LINES_CHANGED")
    frame:RegisterEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED")
    frame:RegisterEvent("NEW_TOY_ADDED")
    frame:RegisterEvent("NEW_MOUNT_ADDED")
    frame:RegisterEvent("NEW_PET_ADDED")
    frame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
    frame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
    frame:RegisterEvent("MAP_EXPLORATION_UPDATED")

    frame:SetScript("OnEvent", OnEvent)

    Inventory.RegisterDelayedCallback("Trackers_Engine", function()
        DeferScan(0.5)
    end)

    -- Trade-skill refresh is funneled through OneWoW.ProfessionRecipe: the open
    -- channel fires once the profession window is loaded/ready (replaces the
    -- former raw TRADE_SKILL_SHOW / TRADE_SKILL_LIST_UPDATE registrations).
    OneWoW.ProfessionRecipe.RegisterOpenCallback("OneWoW_Trackers_Engine", function()
        DeferScan(0.5)
    end)

    BuildIndices()

    OneWoW.AltScope:RegisterChangedCallback("OneWoW_Trackers_Pins", function()
        TE:SyncAllPinnedOverlays()
    end)

    C_Timer.NewTicker(30, function()
        TD:CheckCustomTimerResets()
        TE:RefreshAllPinnedWindows()
    end)
end

function TE:RebuildIndices()
    BuildIndices()
end

function TE:CreatePinnedWindow(listID)
    local win = ns.TrackerPinned:Show(listID)
    if win then
        BuildIndices()
        self:EvaluateList(listID)
    end
    return win
end

function TE:DestroyPinnedWindow(listID)
    ns.TrackerPinned:Destroy(listID)
    BuildIndices()
end

function TE:GetPinnedWindow(listID)
    return ns.TrackerPinned:Get(listID)
end

function TE:RefreshAllPinnedWindows()
    if initialized then
        self:SyncAllPinnedOverlays()
    end
    ns.TrackerPinned:RefreshAll()
    if initialized then
        NotifyMapPins()
    end
end

--- Notify hub UI and all pinned windows that manual progress changed.
function TE:NotifyProgressChanged()
    FireCallbacks("OnProgressChanged")
    self:RefreshAllPinnedWindows()
end

--- True when the player may check the step off. Does not wrap the mutators:
--- engine-observed session bumps stay ungated. Un-completing is always allowed
--- at the click site (do not call this for that path).
---@param listID string
---@param sectionKey string
---@param stepKey string
---@return boolean
function TE:TryUserComplete(listID, sectionKey, stepKey)
    if TD:CanCompleteStep(listID, sectionKey, stepKey) then
        return true
    end
    local L = ns.L
    print(format("%s %s", L["ADDON_CHAT_PREFIX"], L["TRACKER_STEP_REQUIRES"]))
    return false
end

function TE:RestorePinnedWindows()
    ns.TrackerPinned:RestoreAll()
end

function TE:GetTrackTypeDisplayName(trackType)
    local L = ns.L
    local names = {
        manual          = L["TRACKER_TYPE_MANUAL"],
        quest           = L["TRACKER_TYPE_QUEST"],
        quest_account   = L["TRACKER_TYPE_QUEST_ACCOUNT"],
        quest_pool      = L["TRACKER_TYPE_QUEST_POOL"],
        quest_pool_account = L["TRACKER_TYPE_QUEST_POOL_ACCOUNT"],
        quest_progress  = L["TRACKER_TYPE_QUEST_PROGRESS"],
        quest_active    = L["TRACKER_TYPE_QUEST_ACTIVE"],
        quest_world     = L["WORLD_QUEST"],
        level           = LEVEL,
        item            = L["ITEM"],
        currency        = CURRENCY,
        achievement     = L["ACHIEVEMENT"],
        reputation      = REPUTATION,
        renown          = L["TRACKER_TYPE_RENOWN"],
        spell_known     = L["TRACKER_TYPE_SPELL_KNOWN"],
        ilvl            = L["TRACKER_TYPE_ILVL"],
        location        = ZONE,
        coordinates     = L["TRACKER_TYPE_COORDINATES"],
        npc_interact    = L["TRACKER_TYPE_NPC_INTERACT"],
        enter_instance  = L["TRACKER_TYPE_ENTER_INSTANCE"],
        kill_creature   = L["TRACKER_TYPE_KILL_CREATURE"],
        kill_encounter  = L["TRACKER_TYPE_KILL_ENCOUNTER"],
        loot_item       = L["TRACKER_TYPE_LOOT_ITEM"],
        toy             = TOY,
        mount           = MOUNT,
        pet             = L["BATTLE_PET"],
        transmog        = L["TRACKER_TYPE_TRANSMOG"],
        exploration     = L["TRACKER_TYPE_EXPLORATION"],
        vault_raid      = L["TRACKER_TYPE_VAULT_RAID"],
        vault_dungeon   = L["TRACKER_TYPE_VAULT_DUNGEON"],
        vault_world     = L["TRACKER_TYPE_VAULT_WORLD"],
        prof_skill      = L["TRACKER_TYPE_PROF_SKILL"],
        prof_concentration = L["TRACKER_TYPE_PROF_CONC"],
        prof_knowledge  = L["TRACKER_TYPE_PROF_KNOW"],
        prof_firstcraft = L["TRACKER_TYPE_PROF_FIRST"],
        prof_catchup    = L["TRACKER_TYPE_PROF_CATCHUP"],
        rare_quest      = L["TRACKER_TYPE_RARE_QUEST"],
        custom_timer    = L["TRACKER_TYPE_CUSTOM_TIMER"],
        campaign        = L["CAMPAIGN"],
    }
    return names[trackType] or trackType
end

function TE:GetListTypeDisplayName(listType)
    local L = ns.L
    local names = {
        guide     = GUIDE,
        daily     = DAILY,
        weekly    = WEEKLY,
        todo      = L["TRACKER_LIST_TODO"],
        repeating = L["TRACKER_LIST_REPEATING"],
        farmvalue = L["TRACKER_LIST_FARMVALUE"],
    }
    return names[listType] or listType
end

function TE:BuildStepTooltip(tooltip, listID, sectionKey, step)
    if not tooltip or not step then return end

    tooltip:AddLine(step.label or "Step", 1, 1, 1)

    if step.description and step.description ~= "" then
        tooltip:AddLine(step.description, 0.7, 0.7, 0.7, true)
    end

    if step.userNote and step.userNote ~= "" then
        tooltip:AddLine(" ")
        tooltip:AddLine("Notes:", 0.5, 0.7, 1.0)
        tooltip:AddLine(step.userNote, 0.6, 0.8, 1.0, true)
    end

    local tt = step.trackType or "manual"
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("Track Type:", self:GetTrackTypeDisplayName(tt), 0.5, 0.5, 0.5, 1, 0.82, 0)

    if step.rosterMode then
        local completers = TD:GetRosterCompleters(listID, step.key)
        tooltip:AddDoubleLine(ns.L["TRACKER_ROSTER_MODE"],
            tostring(#completers), 0.5, 0.5, 0.5, 1, 1, 1)
    end

    local sp = TD:GetStepProgress(listID, sectionKey, step.key)
    if not step.rosterMode then
        local progressStr = ns.TrackerEvaluators.FormatStepProgress(step, sp)
        if progressStr ~= "" then
            tooltip:AddDoubleLine("Current:", progressStr, 0.5, 0.5, 0.5, 1, 1, 1)
        end
    end
    if sp.completed then
        tooltip:AddLine("Status: Complete", 0.4, 0.8, 0.4)
    else
        tooltip:AddLine("Status: In Progress", 1, 0.82, 0)
    end

    if sp.lastCompleted and sp.lastCompleted > 0 then
        local diff = time() - sp.lastCompleted
        local timeStr
        if diff < 60 then timeStr = "Just now"
        elseif diff < 3600 then timeStr = format("%d min ago", math.floor(diff / 60))
        elseif diff < 86400 then timeStr = format("%d hr ago", math.floor(diff / 3600))
        else timeStr = format("%d days ago", math.floor(diff / 86400))
        end
        tooltip:AddDoubleLine("Last Done:", timeStr, 0.5, 0.5, 0.5, 0.7, 0.7, 0.7)
    end

    local list = TD:GetList(listID)
    local sec = TD:GetSection(listID, sectionKey)
    local resetType = TD:GetEffectiveResetType(list, sec, step)
    if resetType ~= "todo" then
        tooltip:AddDoubleLine("Reset:", self:GetListTypeDisplayName(resetType), 0.5, 0.5, 0.5, 0.7, 0.7, 0.7)
    end

    if step.mapID then
        local mapInfo = C_Map.GetMapInfo(step.mapID)
        if mapInfo then
            tooltip:AddDoubleLine("Location:", mapInfo.name, 0.5, 0.5, 0.5, 0.7, 0.7, 0.7)
        end
        if step.coordX and step.coordY then
            tooltip:AddDoubleLine("Coords:", format("%.1f, %.1f", step.coordX, step.coordY), 0.5, 0.5, 0.5, 0.7, 0.7, 0.7)
        end
    end

    if step.objectives and #step.objectives > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("Objectives:", 1, 0.82, 0)
        for _, obj in ipairs(step.objectives) do
            local complete = TD:GetObjectiveProgress(listID, sectionKey, step.key, obj.key)
            local prefix = complete and "|cFF66CC66Done|r" or "|cFFFF6666Todo|r"
            tooltip:AddDoubleLine("  " .. (obj.description or obj.type), prefix, 0.8, 0.8, 0.8)
        end
    end
end
