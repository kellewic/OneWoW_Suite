local _, ns = ...

-- Public, cross-addon read surface for the Notes hub. ns stays private.
OneWoW_Notes_API = {}

--- Returns an NPC note.
---@param npcID number
---@return table|nil npcData
function OneWoW_Notes_API.GetNPC(npcID)
    return ns.NPCs:GetNPC(npcID)
end

--- Adds or updates an NPC note.
---@param npcID number
---@param npcData table
---@return boolean saved
function OneWoW_Notes_API.AddOrUpdateNPC(npcID, npcData)
    npcID = tonumber(npcID)
    if not npcID then
        return false
    end

    local existing = ns.NPCs:GetNPC(npcID)
    if existing then
        for key, value in pairs(npcData) do
            if value ~= nil then
                existing[key] = value
            end
        end
        ns.NPCs:SaveNPC(npcID, existing)
    else
        ns.NPCs:AddNPC(npcID, npcData)
    end

    return true
end

--- Adds a new NPC note (fails if the NPC already exists).
---@param npcID number
---@param npcData table
---@return boolean saved
function OneWoW_Notes_API.AddNPC(npcID, npcData)
    npcID = tonumber(npcID)
    if not npcID or not ns.NPCs then
        return false
    end
    ns.NPCs:AddNPC(npcID, npcData)
    return true
end

--- Saves an existing NPC note.
---@param npcID number
---@param npcData table
---@return boolean saved
function OneWoW_Notes_API.SaveNPC(npcID, npcData)
    npcID = tonumber(npcID)
    if not npcID or not ns.NPCs then
        return false
    end
    ns.NPCs:SaveNPC(npcID, npcData)
    return true
end

--- Opens an NPC note, selecting it when the NPCs tab is ready.
---@param npcID number
---@return boolean opened
function OneWoW_Notes_API.OpenNPC(npcID)
    npcID = tonumber(npcID)
    if not npcID then
        return false
    end

    ns.pendingNPCSelect = npcID
    OneWoW.UI:Show("notes")
    OneWoW.UI:SelectSubTab("notes", "npcs")
    OneWoW.UI:CommitNavEntity("npc", npcID)

    local tabFrame = OneWoW.UI:GetContentFrame("notes", "npcs")
    if tabFrame and tabFrame.SelectNPC then
        tabFrame.SelectNPC(npcID)
        ns.pendingNPCSelect = nil
    end

    return true
end

--- Snapshot of a player unit for new note creation.
---@param unit string?
---@return table|nil playerInfo
function OneWoW_Notes_API.GetPlayerInfoFromUnit(unit)
    if not ns.Players then return nil end
    return ns.Players:GetPlayerInfoFromUnit(unit or "target")
end

--- Returns a player note.
---@param fullName string
---@return table|nil playerData
function OneWoW_Notes_API.GetPlayer(fullName)
    if not fullName or fullName == "" or not ns.Players then
        return nil
    end
    return ns.Players:GetPlayer(fullName)
end

--- Adds a new player note.
---@param fullName string
---@param playerData table
---@return boolean saved
function OneWoW_Notes_API.AddPlayer(fullName, playerData)
    if not fullName or fullName == "" or not ns.Players then
        return false
    end
    ns.Players:AddPlayer(fullName, playerData)
    return true
end

--- Saves an existing player note.
---@param fullName string
---@param playerData table
---@return boolean saved
function OneWoW_Notes_API.SavePlayer(fullName, playerData)
    if not fullName or fullName == "" or not ns.Players then
        return false
    end
    ns.Players:SavePlayer(fullName, playerData)
    return true
end

--- Records a collectible reference ("sighting") on a player note. Idempotent per
--- key; the optional spellID is stored for context (dropped if it is a secret).
---@param fullName string
---@param key string canonical collectible key
---@param spellID number|nil
---@return boolean added
function OneWoW_Notes_API.AddPlayerCollectibleRef(fullName, key, spellID)
    if not fullName or fullName == "" or not ns.Players then
        return false
    end
    return ns.Players:AddCollectibleRef(fullName, key, spellID)
end

--- True if a player note already references a collectible (structured ref, or a
--- legacy content-embedded link). Lets callers dedup without knowing the note
--- storage or link grammar.
---@param fullName string
---@param key string canonical collectible key
---@return boolean
function OneWoW_Notes_API.PlayerHasCollectibleRef(fullName, key)
    if not fullName or fullName == "" or not ns.Players then
        return false
    end
    return ns.Players:HasCollectibleRef(fullName, key)
end

--- Opens a player note, selecting it when the Players tab is ready.
---@param fullName string
---@return boolean opened
function OneWoW_Notes_API.OpenPlayer(fullName)
    if not fullName or fullName == "" then
        return false
    end

    ns.pendingPlayerSelect = fullName
    OneWoW.UI:Show("notes")
    OneWoW.UI:SelectSubTab("notes", "players")
    OneWoW.UI:CommitNavEntity("player", fullName)

    local tabFrame = OneWoW.UI:GetContentFrame("notes", "players")
    if tabFrame and tabFrame.SelectPlayer then
        tabFrame.SelectPlayer(fullName)
        ns.pendingPlayerSelect = nil
    end

    return true
end

--- Refreshes the Players tab in place if it is already built, without opening
--- the window. Reselects fullName when provided so external edits show live.
---@param fullName string|nil
---@return boolean refreshed
function OneWoW_Notes_API.RefreshPlayersTab(fullName)
    local tabFrame = OneWoW.UI:GetContentFrame("notes", "players")
    if not tabFrame then
        return false
    end

    if fullName and fullName ~= "" and tabFrame.SelectPlayer then
        tabFrame.SelectPlayer(fullName)
    elseif tabFrame.RefreshPlayersList then
        tabFrame.RefreshPlayersList()
    end

    return true
end

--- Returns an item note.
---@param itemID number
---@return table|nil itemData
function OneWoW_Notes_API.GetItem(itemID)
    return ns.Items:GetItem(itemID)
end

--- Adds or updates an item note.
---@param itemID number
---@param itemData table
---@return boolean saved
function OneWoW_Notes_API.AddOrUpdateItem(itemID, itemData)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    local existing = ns.Items:GetItem(itemID)
    if existing then
        for key, value in pairs(itemData) do
            if value ~= nil then
                existing[key] = value
            end
        end
        ns.Items:SaveItem(itemID, existing)
    else
        ns.Items:AddItem(itemID, itemData)
    end

    return true
end

--- Returns the resolved current zone display title (zone + subzone when present).
---@return string|nil
function OneWoW_Notes_API.GetCurrentZoneName()
    if not ns.Zones then return nil end
    return ns.Zones:GetCurrentZoneName()
end

--- Returns live zone / subzone / map info for the player.
---@return string zone
---@return string subzone
---@return table|nil mapInfo
function OneWoW_Notes_API.GetCurrentZoneParts()
    if not ns.Zones then return "", "", nil end
    return ns.Zones:GetCurrentZoneParts()
end

--- Returns a zone note by opaque id.
---@param noteId string
---@return table|nil zoneData
function OneWoW_Notes_API.GetZone(noteId)
    if not noteId or noteId == "" or not ns.Zones then
        return nil
    end
    return ns.Zones:GetZone(noteId)
end

--- Map context for the current player location.
---@return table|nil mapInfo
function OneWoW_Notes_API.GetCurrentMapInfo()
    if not ns.Zones then return nil end
    return ns.Zones:GetCurrentMapInfo()
end

--- Adds a new zone note. zoneData.zone is required. Returns the opaque note id.
---@param zoneData table
---@return string|nil noteId
function OneWoW_Notes_API.AddZone(zoneData)
    if type(zoneData) ~= "table" or not zoneData.zone or zoneData.zone == "" or not ns.Zones then
        return nil
    end
    return ns.Zones:AddZone(zoneData)
end

--- Opens a zone note by opaque id (or by exact zone+subzone when given a legacy title string that FindIdByParts can resolve after migration).
---@param noteIdOrTitle string
---@return boolean opened
function OneWoW_Notes_API.OpenZone(noteIdOrTitle)
    if not noteIdOrTitle or noteIdOrTitle == "" or not ns.Zones then
        return false
    end

    local noteId = noteIdOrTitle
    if not ns.Zones:GetZone(noteId) then
        local zone, subzone = ns.Zones:ParseLegacyKey(noteIdOrTitle)
        noteId = ns.Zones:FindIdByParts(zone, subzone)
        if not noteId then
            return false
        end
    end

    ns.pendingZoneSelect = noteId
    OneWoW.UI:Show("notes")
    OneWoW.UI:SelectSubTab("notes", "zones")
    OneWoW.UI:CommitNavEntity("zone", noteId)

    local tabFrame = OneWoW.UI:GetContentFrame("notes", "zones")
    if tabFrame and tabFrame.SelectZone then
        tabFrame.SelectZone(noteId)
        ns.pendingZoneSelect = nil
    end

    return true
end

--- Opens an item note, selecting it when the Items tab is ready.
---@param itemID number
---@return boolean opened
function OneWoW_Notes_API.OpenItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    ns.pendingItemSelect = itemID
    OneWoW.UI:Show("notes")
    OneWoW.UI:SelectSubTab("notes", "items")
    OneWoW.UI:CommitNavEntity("item", itemID)

    if ns.UI.OpenNotesItem and ns.UI.OpenNotesItem(itemID) then
        ns.pendingItemSelect = nil
    end

    return true
end

-- ---------------------------------------------------------------------------
-- Collectibles (keyed by canonical collectible key, e.g. "mount:2240")
-- ---------------------------------------------------------------------------

--- Returns a collectible record by key.
---@param key string
---@return table|nil record
function OneWoW_Notes_API.GetCollectible(key)
    if not ns.Collectibles then return nil end
    return ns.Collectibles:GetCollectible(key)
end

--- Create-or-update a collectible record (only non-nil fields overwrite).
---@param key string
---@param fields table|nil
---@return boolean ok, table|nil record
function OneWoW_Notes_API.UpsertCollectible(key, fields)
    if not ns.Collectibles then return false end
    return ns.Collectibles:UpsertCollectible(key, fields)
end

--- Saves an existing collectible record.
---@param key string
---@param data table
---@return boolean saved
function OneWoW_Notes_API.SaveCollectible(key, data)
    if not ns.Collectibles or not data then return false end
    ns.Collectibles:SaveCollectible(key, data)
    return true
end

--- Opens a collectible record, selecting it when the Collectibles tab is ready.
---@param key string
---@return boolean opened
function OneWoW_Notes_API.OpenCollectible(key)
    key = OneWoW.Collectibles.CanonicalizeKey(key)
    if not key then
        return false
    end

    ns.pendingCollectibleSelect = key
    OneWoW.UI:Show("notes")
    OneWoW.UI:SelectSubTab("notes", "collectibles")
    OneWoW.UI:CommitNavEntity("collectible", key)

    local tabFrame = OneWoW.UI:GetContentFrame("notes", "collectibles")
    if tabFrame and tabFrame.SelectCollectible then
        tabFrame.SelectCollectible(key)
        ns.pendingCollectibleSelect = nil
    end

    return true
end

--- Builds a canonical mount collectible key, or nil.
---@param mountID number
---@return string|nil key
function OneWoW_Notes_API.BuildMountKey(mountID)
    return OneWoW.Collectibles.BuildKey("mount", mountID)
end

--- Builds a canonical appearance-source collectible key, or nil.
---@param sourceID number
---@return string|nil key
function OneWoW_Notes_API.BuildAppearanceSourceKey(sourceID)
    return OneWoW.Collectibles.BuildKey("appearance", "source", sourceID)
end

--- Builds a clickable collectible hyperlink for a key (opens the Collectibles tab
--- when clicked), or nil if the key is invalid. Lets other units embed a thin
--- collectible reference in note content without knowing the link grammar.
---@param key string
---@return string|nil link
function OneWoW_Notes_API.BuildCollectibleLink(key)
    if not ns.NotesHyperlinks then return nil end
    return ns.NotesHyperlinks:BuildCollectibleLink(key)
end

--- Show or toggle the Notes module in the suite hub.
function OneWoW_Notes_API.OpenNotes()
    if ns.SlashCommandHandler then
        ns:SlashCommandHandler()
    end
end

--- Hide the notes help panel when hub navigation changes.
function OneWoW_Notes_API.CloseHelpPanel()
    if ns.CloseHelpPanel then
        ns:CloseHelpPanel()
    end
end

--- Keybinding entry: opens Notes (no dedicated quick-note UI yet).
function OneWoW_Notes_API.QuickNote()
    OneWoW_Notes_API.OpenNotes()
end

-- ---------------------------------------------------------------------------
-- OneWay Pins
-- ---------------------------------------------------------------------------

function OneWoW_Notes_API.IsWayPinsEnabled()
    return ns.WayPinsVisual.Enabled()
end

--- Turns OneWay Pins on or off. Saved pins stay.
---@param enabled boolean
function OneWoW_Notes_API.SetWayPinsEnabled(enabled)
    ns.db.global.waypinEnabled = enabled and true or false
    if ns.WayPinsMap then
        ns.WayPinsMap:ApplyEnabled()
    end
    if ns.UI.SyncWayPinSettings then
        ns.UI.SyncWayPinSettings()
    end
end

--- Adds a OneWay Pin. Returns the opaque pin id.
--- Same source + sourceKey + mapID returns the existing pin (no duplicate).
---@param fields table
---@return string|nil pinID
function OneWoW_Notes_API.AddWayPin(fields)
    if not ns.WayPinsVisual.Enabled() then return nil end
    if not ns.WayPins then return nil end
    return ns.WayPins:Add(fields)
end

--- First pin for this source, sourceKey, and map.
---@param source string
---@param sourceKey any
---@param mapID number
---@return table|nil pin
function OneWoW_Notes_API.FindWayPin(source, sourceKey, mapID)
    if not ns.WayPinsVisual.Enabled() then return nil end
    if not ns.WayPins then return nil end
    return ns.WayPins:FindBySource(source, sourceKey, mapID)
end

--- Open Notes on the OneWay Pins tab, selecting this pin (Zone filter All).
---@param pinID string|nil
function OneWoW_Notes_API.OpenWayPin(pinID)
    if not ns.WayPinsVisual.Enabled() then return end
    if ns.WayPinsMap then
        ns.WayPinsMap:OpenPinTab(pinID)
    end
end

--- Pins for a uiMapID, title-sorted.
---@param mapID number
---@return table[]
function OneWoW_Notes_API.GetWayPinsForMap(mapID)
    if not ns.WayPinsVisual.Enabled() then return {} end
    if not ns.WayPins then return {} end
    return ns.WayPins:GetForMap(mapID)
end

--- Super-tracks a saved OneWay Pin (live waypoint only).
---@param pinID string
---@return boolean
function OneWoW_Notes_API.TrackWayPin(pinID)
    if not ns.WayPinsVisual.Enabled() then return false end
    if not ns.WayPins then return false end
    return ns.WayPins:Track(pinID)
end

--- Matching zone notes for the player's zone/subzone (opaque ids).
---@param zone string
---@param subzone string
---@return table[]
function OneWoW_Notes_API.FindMatchingZoneNotes(zone, subzone)
    if not ns.Zones then return {} end
    return ns.Zones:FindMatchingNotes(zone, subzone)
end

--- Farming journal notes whose place text matches any of `placeNames`.
---@param placeNames string[]
---@return table[]
function OneWoW_Notes_API.FindFarmingNotesForPlace(placeNames)
    local hits = {}
    if type(placeNames) ~= "table" or not ns.NotesData then
        return hits
    end

    local needles = {}
    for i = 1, #placeNames do
        local name = placeNames[i]
        if type(name) == "string" and name ~= "" then
            needles[#needles + 1] = name:lower()
        end
    end
    if #needles == 0 then
        return hits
    end

    local function PlaceMatches(place)
        if type(place) ~= "string" or place == "" then
            return false
        end
        local hay = place:lower()
        for i = 1, #needles do
            local needle = needles[i]
            if hay == needle or hay:find(needle, 1, true) or needle:find(hay, 1, true) then
                return true
            end
        end
        return false
    end

    for id, data in pairs(ns.NotesData:GetAllNotes()) do
        if type(data) == "table" and data.noteType == "farming" and PlaceMatches(data.instance_name) then
            hits[#hits + 1] = {
                id = id,
                title = data.title or "",
                itemID = data.itemID,
                itemName = data.itemName or "",
                content = data.content or "",
            }
        end
    end
    return hits
end

--- Journal notes of `noteType` that still have unchecked tasks.
---@param noteType string
---@return table[]
function OneWoW_Notes_API.GetIncompleteJournalNotes(noteType)
    local hits = {}
    if not noteType or not ns.NotesData then
        return hits
    end
    for id, data in pairs(ns.NotesData:GetAllNotes()) do
        if type(data) == "table" and data.noteType == noteType then
            local tasks = {}
            for _, todo in ipairs(data.todos or {}) do
                if not todo.completed and todo.text and todo.text ~= "" then
                    tasks[#tasks + 1] = todo.text
                end
            end
            if #tasks > 0 then
                hits[#hits + 1] = {
                    id = id,
                    title = data.title or "",
                    tasks = tasks,
                }
            end
        end
    end
    return hits
end

--- Opens a journal note on the Notes tab.
---@param noteID string
---@return boolean
function OneWoW_Notes_API.OpenJournalNote(noteID)
    if not noteID or noteID == "" then
        return false
    end
    ns.pendingJournalSelect = noteID
    OneWoW.UI:Show("notes")
    OneWoW.UI:SelectSubTab("notes", "notes")
    local tabFrame = OneWoW.UI:GetContentFrame("notes", "notes")
    if tabFrame and tabFrame.setSelectedNote then
        tabFrame.setSelectedNote(noteID)
        ns.pendingJournalSelect = nil
    end
    return true
end

--- Open the OneWay Pin editor. `seed` is an existing pin or a coord draft.
---@param seed table|nil
function OneWoW_Notes_API.OpenWayPinEditor(seed)
    if not ns.WayPinsVisual.Enabled() then return end
    if ns.UI and ns.UI.OpenWayPinDialog then
        ns.UI.OpenWayPinDialog(seed)
    end
end
