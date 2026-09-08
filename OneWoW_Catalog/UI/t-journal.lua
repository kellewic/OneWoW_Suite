local _, ns = ...
local L = ns.L

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI
local C_Item = C_Item
local RETRIEVING_DATA = RETRIEVING_DATA
local RETRIEVING_ITEM_INFO = RETRIEVING_ITEM_INFO
local UNKNOWNOBJECT = UNKNOWNOBJECT
local BATTLE_PET_SOURCE_1 = BATTLE_PET_SOURCE_1
local COLLECTED = COLLECTED
local NOT_COLLECTED = NOT_COLLECTED
local SetPortraitTextureFromCreatureDisplayID = SetPortraitTextureFromCreatureDisplayID
local EJ_GetCreatureInfo = EJ_GetCreatureInfo
local C_EncounterJournal = C_EncounterJournal
local OVERVIEW = OVERVIEW
local ABILITIES = ABILITIES

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_EDGE = OneWoW_GUI.Constants.BACKDROP_EDGE

ns.UI = ns.UI or {}

local selectedInstance = nil
local journalListAPI = nil
local listResults = {}
local detailElements = {}
local searchText = ""
local expansionFilter = 0
local instanceTypeFilter = "all"
---@type string|number # "all" sentinel, or a numeric EJ difficulty id
local selectedDifficulty = "all"
local expandedEncounters = {}
local achievementsExpanded = true
local panels_ref = nil
local RefreshJournalList
local RefreshDetailView
local ShowInstanceDetail
local nameFillRefreshPending = false

local function ScheduleNameFillRefresh()
    if nameFillRefreshPending then
        return
    end
    nameFillRefreshPending = true
    C_Timer.After(0, function()
        nameFillRefreshPending = false
        if selectedInstance then
            RefreshDetailView(true)
        end
    end)
end

-- Multi-select Item Type filter: keys from ITEM_TYPE_DEFS map to item.special values.
-- Empty table = "Show All" (no filter applied).
local filterItemTypes = {}
local filterCollection = "all"
local hideNonCollectable = false
local hasUncollectedOnly = false
local showBountifulOnly = false

-- Ordered definition for the Item Type filter menu (taxonomy order; Show All is
-- the empty-selection sentinel). Keys drive filterItemTypes; `special` matches
-- item.special in ItemMatchesFilters.
local ITEM_TYPE_DEFS = {
    { key = "tmog",    special = "TMog",    labelKey = "JOURNAL_FILTER_TMOG"    },
    { key = "mounts",  special = "Mount",   labelKey = "JOURNAL_FILTER_MOUNT"   },
    { key = "pets",    special = "Pet",     labelKey = "JOURNAL_FILTER_PET"     },
    { key = "toys",    special = "Toy",     labelKey = "JOURNAL_FILTER_TOY"     },
    { key = "housing", special = "Housing", labelKey = "JOURNAL_FILTER_HOUSING" },
    { key = "recipes", special = "Recipe",  labelKey = "JOURNAL_FILTER_RECIPE"  },
    { key = "quest",   special = "Quest",   labelKey = "JOURNAL_FILTER_QUEST"   },
}

-- Card / Collections taxonomy: Transmog → Mount → Pet → Toy → Housing → Recipe → Quest.
local TAXONOMY_DEFS = {
    { special = "TMog",    flag = "hasTMog",    labelKey = "JOURNAL_CARD_TMOG",    colFmt = "JOURNAL_COL_TMOG",    colorKey = "TMog" },
    { special = "Mount",   flag = "hasMounts",  labelKey = "JOURNAL_CARD_MOUNT",   colFmt = "JOURNAL_COL_MOUNT",   colorKey = "Mount" },
    { special = "Pet",     flag = "hasPets",    labelKey = "JOURNAL_CARD_PET",     colFmt = "JOURNAL_COL_PET",     colorKey = "Pet" },
    { special = "Toy",     flag = "hasToys",    labelKey = "JOURNAL_CARD_TOY",     colFmt = "JOURNAL_COL_TOY",     colorKey = "Toy" },
    { special = "Housing", flag = "hasHousing", labelKey = "JOURNAL_CARD_HOUSING", colFmt = "JOURNAL_COL_HOUSING", colorKey = "Housing" },
    { special = "Recipe",  flag = "hasRecipes", labelKey = "JOURNAL_CARD_RECIPE",  colFmt = "JOURNAL_COL_RECIPE",  colorKey = "Recipe" },
    { special = "Quest",   flag = "hasQuest",   labelKey = "JOURNAL_CARD_QUEST",   colFmt = "JOURNAL_COL_QUEST",   colorKey = "Quest" },
}

local function CountSelectedItemTypes()
    local n = 0
    for _ in pairs(filterItemTypes) do n = n + 1 end
    return n
end

local function GetItemTypeFilterLabel()
    local count = CountSelectedItemTypes()
    if count == 0 then
        return L["JOURNAL_FILTER_SHOW_ALL"]
    end
    if count == 1 then
        for _, def in ipairs(ITEM_TYPE_DEFS) do
            if filterItemTypes[def.key] then
                return L[def.labelKey]
            end
        end
    end
    return string.format(L["JOURNAL_FILTER_N_SELECTED"], count)
end

local function ResetItemTypeFilter()
    wipe(filterItemTypes)
end

local function CountBossEncounters(instData)
    local encounters = instData.encounters
    if encounters and #encounters > 0 then
        local n = 0
        for _, enc in ipairs(encounters) do
            -- Real bosses only; skip section headers, World Rares, and leftover buckets.
            if not enc.sectionHeader and not enc.worldRare and not enc.extrasCategory
                and enc.encounterID and enc.encounterID > 0 then
                n = n + 1
            end
        end
        return n
    end
    return instData.bossCount or 0
end

local function FormatBossCount(n)
    if n == 1 then
        return string.format(L["JOURNAL_CARD_ENCOUNTER_ONE"], n)
    end
    return string.format(L["JOURNAL_CARD_ENCOUNTERS"], n)
end

local function CountRareEncounters(instData)
    local encounters = instData.encounters
    if instData.encountersHydrated and encounters then
        local n = 0
        for _, enc in ipairs(encounters) do
            if enc.worldRare then
                n = n + 1
            end
        end
        return n
    end
    return instData.rareCount or 0
end

local function FormatRareCount(n)
    if n == 1 then
        return string.format(L["JOURNAL_CARD_RARE_ONE"], n)
    end
    return string.format(L["JOURNAL_CARD_RARES"], n)
end

local function FormatAchievementCount(n)
    return string.format("%d %s", n or 0, ACHIEVEMENTS)
end

---@param instData table
---@return number|nil
local function StoriesAchievementID(instData)
    local rows = instData and instData.achievements
    if not rows then
        return nil
    end
    for i = 1, #rows do
        if rows[i].kind == "stories" then
            return rows[i].id
        end
    end
    return nil
end

---@param achID number|nil
---@return table
local function CollectStoryCriteria(achID)
    local out = {}
    if not achID then
        return out
    end
    local n = GetAchievementNumCriteria(achID)
    for i = 1, n do
        local name, _, completed = GetAchievementCriteriaInfo(achID, i)
        if name and name ~= "" then
            tinsert(out, { name = name, completed = completed and true or false })
        end
    end
    return out
end

---@param s string
---@return string
local function StripColorCodes(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn.-:", ""):gsub("|r", ""))
end

--- Criterion name if it appears in the widget text; else text after the last colon.
---@param raw string|nil
---@param criteria table
---@return string|nil displayName
---@return number|nil matchedIndex
local function MatchStoryDisplayName(raw, criteria)
    if not raw or raw == "" then
        return nil, nil
    end
    local plain = StripColorCodes(raw)
    local lower = plain:lower()
    for i = 1, #criteria do
        local name = criteria[i].name
        if name ~= "" and lower:find(name:lower(), 1, true) then
            return name, i
        end
    end
    local after = plain:match("^.*:%s*(.-)%s*$")
    if after and after ~= "" then
        return after, nil
    end
    if plain ~= "" then
        return plain, nil
    end
    return nil, nil
end

---@param instData table
---@return number remaining
---@return number total
local function CountIncompleteStories(instData)
    local achID = StoriesAchievementID(instData)
    if not achID then
        return 0, 0
    end
    local criteria = CollectStoryCriteria(achID)
    local remaining = 0
    for i = 1, #criteria do
        if not criteria[i].completed then
            remaining = remaining + 1
        end
    end
    return remaining, #criteria
end

---@param instData table
---@return boolean
local function StoriesAchievementIncomplete(instData)
    local achID = StoriesAchievementID(instData)
    if not achID then
        return false
    end
    local id, _, _, completed = GetAchievementInfo(achID)
    return id ~= nil and not completed
end

local function FormatCardCountParts(instData)
    local countParts = {}
    if instData.instanceType == "delve" then
        if StoriesAchievementIncomplete(instData) then
            local remaining, total = CountIncompleteStories(instData)
            if total > 0 and remaining > 0 then
                tinsert(countParts, string.format(L["JOURNAL_DELVE_STORIES_LEFT"], remaining, total))
            end
        end
    elseif instData.instanceType == "zone" then
        tinsert(countParts, FormatRareCount(CountRareEncounters(instData)))
        local encCount = CountBossEncounters(instData)
        if encCount > 0 then
            tinsert(countParts, FormatBossCount(encCount))
        end
        tinsert(countParts, string.format(L["JOURNAL_CARD_ITEMS"], instData.totalItems or 0))
    else
        tinsert(countParts, FormatBossCount(CountBossEncounters(instData)))
        if instData.instanceType == "world" then
            tinsert(countParts, FormatRareCount(CountRareEncounters(instData)))
        end
        tinsert(countParts, string.format(L["JOURNAL_CARD_ITEMS"], instData.totalItems or 0))
    end
    tinsert(countParts, FormatAchievementCount(#(instData.achievements or {})))
    return countParts
end

local function FormatDetailStatusLine(instData)
    local statusBits = { instData.name }
    local counts = FormatCardCountParts(instData)
    for i = 1, #counts do
        tinsert(statusBits, counts[i])
    end
    return table.concat(statusBits, " - ")
end

local CARD_HEIGHT = 85
local CARD_STRIDE = CARD_HEIGHT + 2
local CARD_PAD_X = OneWoW_GUI:GetSpacing("SM")
local CARD_PAD_Y = OneWoW_GUI:GetSpacing("SM")
local CARD_LINE_GAP = OneWoW_GUI:GetSpacing("XS")
local CARD_NAME_SIZE = 16
local CARD_META_SIZE = 12
local CARD_TAG_SIZE = 10
local CARD_NAME_MAX_LINES = 2
local CARD_ACTION_RESERVE = ns.Constants.GUI.ICON_BUTTON_SIZE + 6
local CARD_TAG_GAP = 10
-- collections-background-corner is 90x67 (AtlasInfo). Card is 85 tall, so
-- scale down and inset on the existing 1px edge as an ornament, not a frame.
local BOUNTIFUL_CORNER_ATLAS = "collections-background-corner"
local BOUNTIFUL_CORNER_W = 32
local BOUNTIFUL_CORNER_H = 24
local BOUNTIFUL_CORNER_INSET = 1
-- Same four flips as Blizzard_SharedXML SharedCollectionTemplates.xml BGCorner*.
local BOUNTIFUL_CORNER_DEFS = {
    { point = "TOPLEFT",     x =  BOUNTIFUL_CORNER_INSET, y = -BOUNTIFUL_CORNER_INSET, left = 0, right = 1, top = 0, bottom = 1 },
    { point = "TOPRIGHT",    x = -BOUNTIFUL_CORNER_INSET, y = -BOUNTIFUL_CORNER_INSET, left = 1, right = 0, top = 0, bottom = 1 },
    { point = "BOTTOMLEFT",  x =  BOUNTIFUL_CORNER_INSET, y =  BOUNTIFUL_CORNER_INSET, left = 0, right = 1, top = 1, bottom = 0 },
    { point = "BOTTOMRIGHT", x = -BOUNTIFUL_CORNER_INSET, y =  BOUNTIFUL_CORNER_INSET, left = 1, right = 0, top = 1, bottom = 0 },
}
local ITEM_ROW_HEIGHT = 32
local ENC_ROW_HEIGHT = 28
local ENC_ROW_HEIGHT_PORTRAIT = 52
local ENC_PORTRAIT_SIZE = 40
local CATDB_RARE_BASE = 10000000
local LOOT_PAD = 6
local LOOT_ICON = 26
local LOOT_GAP = 8
local LOOT_NAME_MIN = 80
local LOOT_TYPE_MIN = 56
local LOOT_TYPE_MAX = 96
local LOOT_STATUS_MIN = 72
local LOOT_STATUS_MAX = 110
local LOOT_DIFF_MIN = 48
local LOOT_DIFF_MAX = 80
local LOOT_SOURCE_MIN = 56

local SPECIAL_COLORS = ns.Constants.SPECIAL_COLORS

local SPECIAL_LABELS = {
    TMog    = "JOURNAL_SPECIAL_TMOG",
    Recipe  = "JOURNAL_SPECIAL_RECIPE",
    Mount   = "JOURNAL_SPECIAL_MOUNT",
    Pet     = "JOURNAL_SPECIAL_PET",
    Quest   = "JOURNAL_SPECIAL_QUEST",
    Toy     = "JOURNAL_SPECIAL_TOY",
    Housing = "JOURNAL_SPECIAL_HOUSING",
}

local diffAbbrev = {
    ["Normal"]              = "JOURNAL_DIFF_N",
    ["Heroic"]              = "JOURNAL_DIFF_H",
    ["Mythic"]              = "JOURNAL_DIFF_M",
    ["LFR"]                 = "JOURNAL_DIFF_LFR",
    ["Looking For Raid"]    = "JOURNAL_DIFF_LFR",
    ["Timewalking"]         = "JOURNAL_DIFF_TW",
    ["Mythic+"]             = "JOURNAL_DIFF_M+",
    ["10 Player"]           = "JOURNAL_DIFF_10N",
    ["25 Player"]           = "JOURNAL_DIFF_25N",
    ["10 Player (Heroic)"]  = "JOURNAL_DIFF_10H",
    ["25 Player (Heroic)"]  = "JOURNAL_DIFF_25H",
}

-- CatDB diffs often have localized GetDifficultyInfo names, so abbreviate by id.
local DIFF_ID_ABBREV = {
    [1]  = "JOURNAL_DIFF_N",
    [2]  = "JOURNAL_DIFF_H",
    [3]  = "JOURNAL_DIFF_10N",
    [4]  = "JOURNAL_DIFF_25N",
    [5]  = "JOURNAL_DIFF_10H",
    [6]  = "JOURNAL_DIFF_25H",
    [8]  = "JOURNAL_DIFF_M+",
    [14] = "JOURNAL_DIFF_N",
    [15] = "JOURNAL_DIFF_H",
    [16] = "JOURNAL_DIFF_M",
    [17] = "JOURNAL_DIFF_LFR",
    [23] = "JOURNAL_DIFF_M",
    [24] = "JOURNAL_DIFF_TW",
    [33] = "JOURNAL_DIFF_TW",
}

---@param name string|nil
---@return boolean
local function IsBlankDisplayName(name)
    return not name or name == "" or name == "?" or name == "???"
        or name == RETRIEVING_DATA or name == RETRIEVING_ITEM_INFO
        or name == UNKNOWNOBJECT
end

local function GetDataAddon()
    return ns.GetCatalogPackAPI("journal")
end

---@param instData table
---@return string|nil displayName
---@return number|nil matchedIndex
---@return table|nil criteria
local function ResolveDelveStoryDisplayName(instData)
    if not instData or instData.instanceType ~= "delve" then
        return nil, nil, nil
    end
    local addon = GetDataAddon()
    local raw = addon and addon.GetDelveStoryText(instData.mapID)
    local criteria = CollectStoryCriteria(StoriesAchievementID(instData))
    local name, idx = MatchStoryDisplayName(raw, criteria)
    return name, idx, criteria
end

--- Type-line warning color tracks this variant, not the parent Stories achievement.
---@param idx number|nil
---@param criteria table|nil
---@return boolean
local function ActiveStoryIncomplete(idx, criteria)
    if idx and criteria and criteria[idx] then
        return not criteria[idx].completed
    end
    if not criteria then
        return false
    end
    for i = 1, #criteria do
        if not criteria[i].completed then
            return true
        end
    end
    return false
end

local COL_SOURCE_RIGHT = -248
local SOURCE_ICON_SIZE = 14
local ATT_SOURCE_TEXTURE = "Interface\\AddOns\\AllTheThings\\assets\\logo_32x32"

---@param row table
---@return string kind "ej"|"att"|"onewow"
local function SourceKind(row)
    if row.source == "att-live" then
        return "att"
    end
    if row.source == "ej" then
        return "ej"
    end
    return "onewow"
end

---@param kind string
---@return string
local function SourceTooltipText(kind)
    if kind == "att" then
        return L["JOURNAL_SOURCE_ATT_LIVE_TT"]
    end
    if kind == "ej" then
        return ADVENTURE_JOURNAL
    end
    return L["JOURNAL_SOURCE_ONEWOW_TT"]
end

---@param parent Frame
---@param row table
---@param anchor Frame|nil
---@param skipAnchor boolean|nil
---@return Frame
local function AddSourceIcon(parent, row, anchor, skipAnchor)
    local kind = SourceKind(row)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(SOURCE_ICON_SIZE, SOURCE_ICON_SIZE)
    if not skipAnchor then
        if anchor then
            icon:SetPoint("RIGHT", anchor, "LEFT", -10, 0)
        else
            icon:SetPoint("RIGHT", parent, "RIGHT", COL_SOURCE_RIGHT, 0)
        end
    end
    local tex = icon:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    if kind == "ej" then
        tex:SetAtlas("token-choice-wow")
    elseif kind == "att" then
        tex:SetTexture(ATT_SOURCE_TEXTURE)
    else
        tex:SetTexture(OneWoW_GUI.Constants.ICON_TEXTURES.neutral)
    end
    icon:EnableMouse(true)
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(SourceTooltipText(kind))
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    table.insert(detailElements, icon)
    return icon
end

---@param encounter table
---@return number|nil
local function ResolveEncounterDisplayID(encounter)
    local id = encounter.displayID
    if type(id) == "number" and id > 0 then
        return id
    end
    local ids = encounter.displayIDs
    if type(ids) == "table" then
        local first = ids[1]
        if type(first) == "number" and first > 0 then
            encounter.displayID = first
            return first
        end
    end
    local encID = encounter.encounterID
    local addon = GetDataAddon()
    if addon and addon.GetEncounter and type(encID) == "number" then
        local src = addon.GetEncounter(encID)
        local srcIDs = src and src.displayIDs
        local first = srcIDs and srcIDs[1]
        if type(first) == "number" and first > 0 then
            encounter.displayID = first
            return first
        end
    end
    if type(encID) == "number" and encID > 0 and encID < CATDB_RARE_BASE then
        local _, _, _, displayInfo = EJ_GetCreatureInfo(1, encID)
        if type(displayInfo) == "number" and displayInfo > 0 then
            encounter.displayID = displayInfo
            return displayInfo
        end
    end
    local npcID = encounter.npcID
    local vendorAPI = ns.GetCatalogPackAPI("vendors")
    if vendorAPI and npcID then
        local npc = vendorAPI.GetVendor(npcID)
        local did = npc and npc.displayID
        if type(did) == "number" and did > 0 then
            encounter.displayID = did
            return did
        end
    end
    return nil
end

---@param rowW number
---@param leadW number
---@return number nameW
---@return number typeW
---@return number statusW
---@return number diffW
local function LootColumnWidths(rowW, leadW)
    local sourceW = LOOT_SOURCE_MIN
    local minUsed = leadW + LOOT_NAME_MIN + LOOT_GAP
        + LOOT_TYPE_MIN + LOOT_GAP
        + LOOT_STATUS_MIN + LOOT_GAP
        + LOOT_DIFF_MIN + LOOT_GAP
        + sourceW + LOOT_PAD
    local extra = math.max(0, rowW - minUsed)
    local nameShare = extra * 0.7
    local midShare = extra * 0.1
    local typeW = math.min(LOOT_TYPE_MAX, LOOT_TYPE_MIN + midShare)
    local statusW = math.min(LOOT_STATUS_MAX, LOOT_STATUS_MIN + midShare)
    local diffW = math.min(LOOT_DIFF_MAX, LOOT_DIFF_MIN + midShare)
    local nameW = LOOT_NAME_MIN + nameShare
    local used = leadW + nameW + LOOT_GAP + typeW + LOOT_GAP + statusW + LOOT_GAP
        + diffW + LOOT_GAP + sourceW + LOOT_PAD
    if used < rowW then
        nameW = nameW + (rowW - used)
    end
    return nameW, typeW, statusW, diffW
end

---@param row Frame
local function LayoutLootTableRow(row)
    local cols = row._lootCols
    if not cols then
        return
    end
    local rowW = row:GetWidth()
    if rowW < 1 then
        return
    end
    local leadW = cols.leadW or (LOOT_PAD + LOOT_ICON + LOOT_GAP)
    local nameW, typeW, statusW, diffW = LootColumnWidths(rowW, leadW)
    local x = leadW
    cols.name:ClearAllPoints()
    cols.name:SetPoint("LEFT", row, "LEFT", x, 0)
    cols.name:SetWidth(nameW)
    cols.name:SetJustifyH("LEFT")
    x = x + nameW + LOOT_GAP
    cols.type:ClearAllPoints()
    cols.type:SetPoint("LEFT", row, "LEFT", x, 0)
    cols.type:SetWidth(typeW)
    cols.type:SetJustifyH("LEFT")
    x = x + typeW + LOOT_GAP
    cols.status:ClearAllPoints()
    cols.status:SetPoint("LEFT", row, "LEFT", x, 0)
    cols.status:SetWidth(statusW)
    cols.status:SetJustifyH("LEFT")
    x = x + statusW + LOOT_GAP
    cols.diff:ClearAllPoints()
    cols.diff:SetPoint("LEFT", row, "LEFT", x, 0)
    cols.diff:SetWidth(diffW)
    cols.diff:SetJustifyH("LEFT")
    x = x + diffW + LOOT_GAP
    cols.source:ClearAllPoints()
    cols.source:SetPoint("LEFT", row, "LEFT", x, 0)
    if cols.source.GetObjectType and cols.source:GetObjectType() == "FontString" then
        cols.source:SetWidth(LOOT_SOURCE_MIN)
    end
    if cols.list then
        cols.list:ClearAllPoints()
        cols.list:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    end
end

---@param encBtn Frame
local function LayoutEncounterHeaderRow(encBtn)
    local nameFS = encBtn.encName
    if not nameFS then
        return
    end
    local rowW = encBtn:GetWidth()
    if rowW < 1 then
        return
    end
    local trail = (encBtn.encCount:GetStringWidth() or 0) + 10
    if encBtn.jumpBtn then
        trail = trail + 16 + 8
    end
    if encBtn.encSource then
        trail = trail + SOURCE_ICON_SIZE + 8
    end
    if encBtn.seeNpc then
        trail = trail + (encBtn.seeNpc:GetWidth() or 0) + 8
    end
    if encBtn.seeMap then
        trail = trail + (encBtn.seeMap:GetWidth() or 0) + 8
    end
    local nameLeft = encBtn._nameLeft or 28
    local nameMax = math.max(40, rowW - nameLeft - trail - LOOT_PAD)
    local textW = math.min(nameFS:GetStringWidth() or 0, nameMax)
    nameFS:SetWidth(math.max(textW, 1))
    encBtn.encCount:ClearAllPoints()
    encBtn.encCount:SetPoint("LEFT", nameFS, "RIGHT", 10, 0)
    local after = encBtn.encCount
    if encBtn.jumpBtn then
        encBtn.jumpBtn:ClearAllPoints()
        encBtn.jumpBtn:SetPoint("LEFT", after, "RIGHT", 8, 0)
        after = encBtn.jumpBtn
    end
    if encBtn.encSource then
        encBtn.encSource:ClearAllPoints()
        encBtn.encSource:SetPoint("LEFT", after, "RIGHT", 8, 0)
        after = encBtn.encSource
    end
    if encBtn.seeNpc then
        encBtn.seeNpc:ClearAllPoints()
        encBtn.seeNpc:SetPoint("LEFT", after, "RIGHT", 8, 0)
        after = encBtn.seeNpc
    end
    if encBtn.seeMap then
        encBtn.seeMap:ClearAllPoints()
        encBtn.seeMap:SetPoint("LEFT", after, "RIGHT", 8, 0)
    end
end

local rareNameRefreshPending = {}

---@param encounter table
local function ScheduleRareNameRefresh(encounter)
    local npcID = encounter.npcID
    if not npcID or encounter.nameResolved or rareNameRefreshPending[npcID] then
        return
    end
    -- CatDB ships a label (name or "NPC #id"). Do not tooltip-scan every
    -- world rare when the card opens — that rebuilt the pane once per rare.
    if encounter.name and encounter.name ~= "" then
        return
    end
    local addon = GetDataAddon()
    if not addon then
        return
    end
    rareNameRefreshPending[npcID] = true
    C_Timer.After(0.4, function()
        rareNameRefreshPending[npcID] = nil
        local name = addon.ResolveNPCName(npcID)
        if name then
            encounter.name = name
            encounter.nameResolved = true
            if selectedInstance then
                ScheduleNameFillRefresh()
            end
        end
    end)
end

--- Fill name / icon / quality for a visible loot row. Hydrate stays Instant-only,
--- so a row can arrive with the placeholder name *and* the fallback quality (both
--- come from the same uncached-item condition). The store item cache is the source
--- of truth for "resolved"; RequestLoadItemDataByID runs in FillVisibleItem.
---@param item table
---@param row Frame
---@param nameFS FontString
---@param iconTex Texture
---@param iconFrame Frame
local function FillVisibleItemRow(item, row, nameFS, iconTex, iconFrame)
    local addon = GetDataAddon()
    if not addon or not item or not item.itemID then
        return
    end

    ns.FillVisibleItem(row, item.itemID, {
        getCached = addon.GetCachedItem,
        load = addon.LoadItemData,
        apply = function(result, paintWidgets)
            if result.name then
                item.name = result.name
                -- Keep the store's flag in step: the live EJ merge reads it to decide
                -- whether a row still needs an EJ name.
                item.nameResolved = true
                if item.itemData then
                    item.itemData.name = result.name
                end
            end
            if result.icon then
                item.icon = result.icon
            end
            if result.quality ~= nil then
                item.quality = result.quality
                if item.itemData then
                    item.itemData.quality = result.quality
                end
            end
            if result.link and item.itemData then
                item.itemData.link = result.link
            end
            if not paintWidgets then
                return
            end
            nameFS:SetText(item.name)
            iconTex:SetTexture(item.icon)
            local qr, qg, qb = OneWoW_GUI:GetItemQualityColor(item.quality)
            iconFrame:SetBackdropBorderColor(qr, qg, qb)
            nameFS:SetTextColor(qr, qg, qb)
        end,
        onStale = function(result)
            if result.name then
                ScheduleNameFillRefresh()
            end
        end,
    })
end

--- Visible-row item type (Armor / Weapon / Mount / ...). Instant only — CatDB
--- loot rows often omit class/subclass, and walking the store here hitches.
---@param item table
---@return string|nil label
---@return string|nil specialColorKey
local function LootRowTypeLabel(item)
    local itemID = item and item.itemID
    if not itemID then
        return nil, nil
    end
    local _, itemType, itemSubType, _, _, classID = C_Item.GetItemInfoInstant(itemID)
    if IsBlankDisplayName(itemType) then
        itemType = nil
    end
    if IsBlankDisplayName(itemSubType) then
        itemSubType = nil
    end
    if (classID == Enum.ItemClass.Miscellaneous or classID == Enum.ItemClass.Consumable)
        and itemSubType and itemSubType ~= itemType then
        return itemSubType, nil
    end
    if itemType then
        return itemType, nil
    end
    local special = item.special
    if special then
        local labelKey = SPECIAL_LABELS[special]
        return labelKey and L[labelKey] or special, special
    end
    return nil, nil
end

---@param item table
---@return number|nil questID
local function LootRowQuestID(item)
    local sources = item.questSources or (item.itemData and item.itemData.questSources)
    if type(sources) == "table" then
        local faction = UnitFactionGroup("player")
        local fallback
        for i = 1, #sources do
            local qs = sources[i]
            if qs and qs.id then
                if not fallback then
                    fallback = qs.id
                end
                if qs.faction == faction then
                    return qs.id
                end
            end
        end
        if fallback then
            return fallback
        end
    end
    local questAPI = ns.GetCatalogPackAPI("quests")
    local ids = questAPI and questAPI.GetQuestsRewardingItem(item.itemID, false)
    if ids and ids[1] then
        return ids[1]
    end
    return nil
end

--- Collected / not collected for a visible loot row. Pack DetermineItemStatus
--- when special is already known; otherwise Collectibles + quest-item, same
--- path as vendor stock / collection tooltips.
---@param item table
---@param addon table|nil
---@return string|nil status
---@return boolean|nil collected
local function LootRowStatus(item, addon)
    local special = item.special
    if addon and special then
        local status = addon.DetermineItemStatus(item.itemID, item.itemData, special)
        if status then
            return status, addon.IsItemCollected(item.itemID, item.itemData, special)
        end
    end

    local col = OneWoW.Collectibles.GetItemCollectionStatus(item.itemID, nil, { light = true })
    if col and col.applicable then
        return col.collected and COLLECTED or NOT_COLLECTED, col.collected == true
    end

    local classID = item.itemData and item.itemData.classID
    if not classID then
        classID = select(6, C_Item.GetItemInfoInstant(item.itemID))
    end
    if special == "Quest" or classID == Enum.ItemClass.Questitem then
        if addon then
            local status = addon.DetermineItemStatus(item.itemID, item.itemData, "Quest")
            if status then
                return status, addon.IsItemCollected(item.itemID, item.itemData, "Quest")
            end
        end
        local questID = LootRowQuestID(item)
        if questID then
            local questAPI = ns.GetCatalogPackAPI("quests")
            local completed
            if questAPI then
                completed = questAPI.IsCompletedByCurrentChar(questID) == true
            else
                completed = C_QuestLog.IsQuestFlaggedCompleted(questID) == true
            end
            return completed and COLLECTED or NOT_COLLECTED, completed
        end
    end
    return nil, nil
end

-- Tooltips use the difficulty-scaled Encounter Journal link (captured per
-- difficulty by EJLiveLoot) so the displayed item level matches the Adventure
-- Guide. Rank maps a difficulty id to its relative ilvl tier; used to pick the
-- highest available link when no specific difficulty is selected.
local DIFF_ILVL_RANK = {
    [17] = 1,  -- Raid: Looking For Raid
    [1]  = 1,  -- Dungeon: Normal
    [3]  = 1,  -- Raid: 10 Player
    [14] = 2,  -- Raid: Normal
    [2]  = 2,  -- Dungeon: Heroic
    [4]  = 2,  -- Raid: 25 Player
    [24] = 2,  -- Dungeon: Timewalking
    [15] = 3,  -- Raid: Heroic
    [5]  = 3,  -- Raid: 10 Player (Heroic)
    [23] = 3,  -- Dungeon: Mythic
    [16] = 4,  -- Raid: Mythic
    [6]  = 4,  -- Raid: 25 Player (Heroic)
    [8]  = 4,  -- Mythic+
}

local function JournalCacheKey(inst)
    if not inst then return "" end
    if inst.cacheKey then return inst.cacheKey end
    if inst.expansionID and inst.instanceID then
        return tostring(inst.expansionID) .. ":" .. tostring(inst.instanceID)
    end
    return tostring(inst.instanceID or "")
end

local function IsJournalFavorite(inst)
    if not ns.Favorites or not inst then return false end
    local key = JournalCacheKey(inst)
    if ns.Favorites:IsFavorite("journal", key) then
        return true
    end
    -- Legacy favorites keyed by bare instanceID.
    return inst.instanceID ~= nil and ns.Favorites:IsFavorite("journal", inst.instanceID)
end

local function FormatDifficultyMenuLabel(diff)
    local name = diff.name
    local maxPlayers = diff.maxPlayers
    if (not name or name == "") and GetDifficultyInfo then
        local infoName, _, _, _, _, _, _, _, _, infoMax = GetDifficultyInfo(diff.id)
        name = infoName
        maxPlayers = maxPlayers or infoMax
    end
    name = name or tostring(diff.id)
    if ENCOUNTER_JOURNAL_DIFF_TEXT and maxPlayers and maxPlayers > 0 then
        return format(ENCOUNTER_JOURNAL_DIFF_TEXT, maxPlayers, name)
    end
    return name
end

--- Pick the difficulty id whose scaled item level should drive the tooltip.
--- Honors the active difficulty filter; with "all" selected, returns the highest
--- ilvl tier available for the item (mirrors how the Adventure Guide defaults).
---@param item table
---@return number|nil diffID
local function ResolveTooltipDifficulty(item)
    if selectedDifficulty ~= "all" then
        return selectedDifficulty --[[@as number]]
    end
    local bestID, bestRank
    for _, diff in ipairs(item.difficulties or {}) do
        local rank = DIFF_ILVL_RANK[diff.id] or 0
        if not bestRank or rank > bestRank then
            bestRank = rank
            bestID = diff.id
        end
    end
    return bestID
end

--- Resolve the difficulty-scaled Encounter Journal link for an item's tooltip.
--- Uses any link already captured by the background merge, otherwise resolves it
--- live (and caches it back onto the item). Returns nil to fall back to itemID.
---@param item table
---@param encounterID number|nil
---@return string|nil scaledLink
local function GetScaledItemLink(item, encounterID)
    local diffID = ResolveTooltipDifficulty(item)
    if not diffID then return nil end

    if item.linkByDiff and item.linkByDiff[diffID] then
        return item.linkByDiff[diffID]
    end

    local addon = GetDataAddon()
    if addon and selectedInstance and encounterID then
        local link = addon.GetScaledLootLink(selectedInstance.instanceID, encounterID, diffID, item.itemID)
        if link then
            item.linkByDiff = item.linkByDiff or {}
            item.linkByDiff[diffID] = link
            return link
        end
    end
    return nil
end

local function FormatDifficulties(difficulties)
    if not difficulties or #difficulties == 0 then return "" end
    local parts = {}
    local seen = {}
    for _, diff in ipairs(difficulties) do
        local key = (diff.id and DIFF_ID_ABBREV[diff.id]) or diffAbbrev[diff.name]
        local label
        if key then
            label = L[key]
        else
            label = diff.name
            if IsBlankDisplayName(label) and diff.id then
                label = GetDifficultyInfo(diff.id)
            end
        end
        if not IsBlankDisplayName(label) and not seen[label] then
            seen[label] = true
            tinsert(parts, label)
        end
    end
    return table.concat(parts, ", ")
end

local function ItemMatchesFilters(item, addon)
    if next(filterItemTypes) ~= nil then
        -- When at least one Item Type is selected, an item must match one of the chosen
        -- specials; items with no special (e.g. regular gear) are excluded.
        local special = item.special
        if not special then return false end
        local matched = false
        for _, def in ipairs(ITEM_TYPE_DEFS) do
            if filterItemTypes[def.key] and special == def.special then
                matched = true
                break
            end
        end
        if not matched then return false end
    end

    if filterCollection ~= "all" and item.special then
        if addon then
            local isCollected = addon.IsItemCollected(item.itemID, item.itemData, item.special)
            if isCollected ~= nil then
                if filterCollection == "collected" and not isCollected then return false end
                if filterCollection == "notcollected" and isCollected then return false end
            end
        end
    end

    if selectedDifficulty ~= "all" then
        if item.difficulties and #item.difficulties > 0 then
            local found = false
            for _, diff in ipairs(item.difficulties) do
                if tostring(diff.id) == tostring(selectedDifficulty) then found = true; break end
            end
            if not found then return false end
        end
    end

    if hideNonCollectable and not item.special then
        return false
    end

    return true
end

local function ClearDetailElements()
    for _, element in ipairs(detailElements) do
        if element.Hide then element:Hide() end
        if element.SetParent then element:SetParent(nil) end
    end
    wipe(detailElements)
end

local function ApplyInstanceRowChrome(card, selected, hover)
    ns.CardChrome.ApplyRowChrome(card, {
        selected = selected,
        hover = hover,
        borderKey = card._borderKey,
        fillTheme = card._chromeFill,
    })
end

local function ApplyJournalPinSource(btn, entranceSource)
    if not btn.pinTex then
        return
    end
    if entranceSource == "wowhead" then
        btn.pinTex:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    else
        btn.pinTex:SetVertexColor(1, 1, 1, 1)
    end
end

local function WireJournalPinButton(btn, getInstData)
    local pinRegions = { btn:GetRegions() }
    for i = 1, #pinRegions do
        local region = pinRegions[i]
        if region:GetObjectType() == "Texture" then
            btn.pinTex = region
            break
        end
    end
    btn:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(MAP_PIN, 1, 1, 1)
        local inst = getInstData()
        if inst and inst.entranceSource == "wowhead" then
            GameTooltip:AddLine(L["JOURNAL_MAP_PIN_WOWHEAD_TT"], 0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine(L["JOURNAL_MAP_PIN_TT"], 0.8, 0.8, 0.8, true)
        end
        if ns.Navigation:IsWayPinsEnabled() then
            GameTooltip:AddLine(L["JOURNAL_MAP_PIN_SAVE_TT"], 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
end

local function BindJournalPinButton(btn, instData)
    if instData and instData.instanceID and instData.entrances and instData.entrances[1] then
        btn:Show()
        btn:SetFavorite(false)
        ApplyJournalPinSource(btn, instData.entranceSource)
    else
        btn:Hide()
    end
end

-- Map POI atlases inline via |A: so Expansion | Type stays one FontString.
local function FormatInstanceInfoLine(instData, iconSize)
    local typeStr = ""
    if instData.instanceType == "raid" then
        typeStr = string.format("|A:Raid:%d:%d|a %s", iconSize, iconSize, RAID)
    elseif instData.instanceType == "party" then
        typeStr = string.format("|A:Dungeon:%d:%d|a %s", iconSize, iconSize, L["JOURNAL_CARD_DUNGEON"])
    elseif instData.instanceType == "world" then
        typeStr = string.format("|A:worldquest-icon:%d:%d|a %s", iconSize, iconSize, WORLD)
    elseif instData.instanceType == "zone" then
        if instData.isCity then
            typeStr = string.format("|A:poi-town:%d:%d|a %s", iconSize, iconSize, L["JOURNAL_CARD_CITY"])
        else
            typeStr = string.format("|A:Waypoint-MapPin-Untracked:%d:%d|a %s", iconSize, iconSize, ZONE)
        end
    elseif instData.instanceType == "delve" then
        local addon = GetDataAddon()
        local atlas = (addon and addon.IsDelveBountiful(instData.mapID))
            and "delves-bountiful"
            or "delves-regular"
        typeStr = string.format("|A:%s:%d:%d|a %s", atlas, iconSize, iconSize, DELVE_LABEL)
        local storyName, idx, criteria = ResolveDelveStoryDisplayName(instData)
        if storyName then
            if ActiveStoryIncomplete(idx, criteria) then
                storyName = OneWoW_GUI:WrapThemeColor(storyName, "TEXT_WARNING")
            end
            typeStr = typeStr .. "  |  " .. storyName
        end
    end
    if instData.isTimewalker then
        typeStr = typeStr ~= "" and (typeStr .. "  |  " .. PLAYER_DIFFICULTY_TIMEWALKER)
            or PLAYER_DIFFICULTY_TIMEWALKER
    end
    local expName = instData.expansionName or ""
    if typeStr ~= "" then
        return expName .. "  |  " .. typeStr
    end
    return expName
end

--- Action cluster (pin + favorite) keeps the top-right; name stops before it.
---@param row Frame
---@return number
local function InstanceCardActionRight(row)
    local right = CARD_PAD_X
    if row.favBtn and row.favBtn:IsShown() then
        right = right + CARD_ACTION_RESERVE
    end
    if row.pinBtn and row.pinBtn:IsShown() then
        right = right + CARD_ACTION_RESERVE
    end
    return right
end

--- Shown taxonomy tags: wrap into at most two rows and return the band height.
---@param row Frame
---@param cardW number
---@param bottomPad number
---@return number tagH
local function LayoutInstanceCardTags(row, cardW, bottomPad)
    local catTexts = row.catTexts
    local availW = cardW - CARD_PAD_X * 2
    local rowH = CARD_TAG_SIZE
    local shown = {}
    for i = 1, #catTexts do
        local catText = catTexts[i]
        if catText:IsShown() then
            local h = catText:GetStringHeight() or CARD_TAG_SIZE
            if h > rowH then
                rowH = h
            end
            shown[#shown + 1] = catText
        end
    end
    if #shown == 0 then
        return 0
    end

    local rows = 1
    local xPos = 0
    for i = 1, #shown do
        local w = shown[i]:GetStringWidth() or 0
        if xPos > 0 and (xPos + CARD_TAG_GAP + w) > availW then
            rows = 2
            break
        end
        xPos = xPos + w + CARD_TAG_GAP
    end

    local secondY = bottomPad
    local firstY = rows == 1 and bottomPad or (bottomPad + rowH + 2)
    xPos = CARD_PAD_X
    local yPos = firstY
    for i = 1, #shown do
        local catText = shown[i]
        local w = catText:GetStringWidth() or 0
        if xPos > CARD_PAD_X and (xPos + w) > (CARD_PAD_X + availW) then
            xPos = CARD_PAD_X
            yPos = secondY
        end
        catText:ClearAllPoints()
        catText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", xPos, yPos)
        xPos = xPos + w + CARD_TAG_GAP
    end
    return rows * rowH + (rows > 1 and 2 or 0)
end

-- Name stretches to the action cluster and may wrap two lines. Type stays left;
-- counts sit on the right of the same row when they fit, else on the next row
-- right-aligned so the card is not a top-left stack. Tags stay a bottom band.
-- The name+meta block is vertically centered in the space above the tags.
---@param row Frame
local function LayoutInstanceListRow(row)
    local nameFS = row.nameText
    local infoFS = row.infoText
    local countFS = row.countText
    if not nameFS then
        return
    end

    local cardW = row:GetWidth()
    if cardW < 1 then
        cardW = 260
    end
    local cardH = row:GetHeight()
    if cardH < 1 then
        cardH = CARD_HEIGHT
    end

    local actionRight = InstanceCardActionRight(row)
    local nameW = math.max(40, cardW - CARD_PAD_X - actionRight)
    local nameFontSize = select(2, nameFS:GetFont())
    local nameLineH = nameFontSize or CARD_NAME_SIZE
    local nameMaxH = nameLineH * CARD_NAME_MAX_LINES

    nameFS:SetWordWrap(true)
    nameFS:SetMaxLines(CARD_NAME_MAX_LINES)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetJustifyV("TOP")
    nameFS:SetWidth(nameW)
    local nameH = nameFS:GetStringHeight() or nameLineH
    if nameH < 1 then
        nameH = nameLineH
    elseif nameH > nameMaxH then
        nameH = nameMaxH
    end

    local infoW = infoFS:GetStringWidth() or 0
    local countW = countFS:GetStringWidth() or 0
    local infoH = infoFS:GetStringHeight() or CARD_META_SIZE
    local countH = countFS:GetStringHeight() or CARD_META_SIZE
    if infoH < 1 then
        infoH = CARD_META_SIZE
    end
    if countH < 1 then
        countH = CARD_META_SIZE
    end

    local metaInner = math.max(40, cardW - CARD_PAD_X * 2)
    local twoCol = infoW > 0 and countW > 0
        and (infoW + CARD_LINE_GAP + countW) <= metaInner
    local metaH = 0
    if twoCol then
        metaH = math.max(infoH, countH)
    elseif infoW > 0 and countW > 0 then
        metaH = infoH + CARD_LINE_GAP + countH
    elseif countW > 0 then
        metaH = countH
    elseif infoW > 0 then
        metaH = infoH
    end

    local tagH = LayoutInstanceCardTags(row, cardW, CARD_PAD_Y)
    local footer = CARD_PAD_Y + tagH
    if tagH > 0 then
        footer = footer + CARD_LINE_GAP
    end
    local contentH = nameH
    if metaH > 0 then
        contentH = contentH + CARD_LINE_GAP + metaH
    end
    local avail = cardH - CARD_PAD_Y - footer
    if contentH > avail then
        nameFS:SetWordWrap(false)
        nameFS:SetMaxLines(1)
        nameH = nameLineH
        contentH = nameH
        if metaH > 0 then
            contentH = contentH + CARD_LINE_GAP + metaH
        end
    end
    local topY = CARD_PAD_Y + math.max(0, math.floor((avail - contentH) / 2))

    nameFS:ClearAllPoints()
    nameFS:SetPoint("TOPLEFT", row, "TOPLEFT", CARD_PAD_X, -topY)
    nameFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -actionRight, -topY)
    nameFS:SetHeight(nameH)

    local metaY = topY + nameH + CARD_LINE_GAP
    infoFS:ClearAllPoints()
    countFS:ClearAllPoints()
    infoFS:SetWordWrap(false)
    countFS:SetWordWrap(false)

    if twoCol then
        countFS:SetJustifyH("RIGHT")
        countFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -CARD_PAD_X, -metaY)
        countFS:SetWidth(math.max(countW, 1))
        infoFS:SetJustifyH("LEFT")
        infoFS:SetPoint("TOPLEFT", row, "TOPLEFT", CARD_PAD_X, -metaY)
        infoFS:SetPoint("RIGHT", countFS, "LEFT", -CARD_LINE_GAP, 0)
    elseif infoW > 0 and countW > 0 then
        infoFS:SetJustifyH("LEFT")
        infoFS:SetPoint("TOPLEFT", row, "TOPLEFT", CARD_PAD_X, -metaY)
        infoFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -CARD_PAD_X, -metaY)
        countFS:SetJustifyH("RIGHT")
        countFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -CARD_PAD_X, -(metaY + infoH + CARD_LINE_GAP))
        countFS:SetWidth(math.max(countW, 1))
    elseif countW > 0 then
        countFS:SetJustifyH("RIGHT")
        countFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -CARD_PAD_X, -metaY)
        countFS:SetWidth(math.max(countW, 1))
        infoFS:SetWidth(1)
    else
        infoFS:SetJustifyH("LEFT")
        infoFS:SetPoint("TOPLEFT", row, "TOPLEFT", CARD_PAD_X, -metaY)
        infoFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -CARD_PAD_X, -metaY)
        countFS:SetWidth(1)
    end
end

local function AttachBountifulCorners(card)
    local corners = {}
    for i = 1, #BOUNTIFUL_CORNER_DEFS do
        local def = BOUNTIFUL_CORNER_DEFS[i]
        local tex = card:CreateTexture(nil, "OVERLAY", nil, 2)
        tex:SetAtlas(BOUNTIFUL_CORNER_ATLAS, false)
        tex:SetTexCoord(def.left, def.right, def.top, def.bottom)
        tex:SetSize(BOUNTIFUL_CORNER_W, BOUNTIFUL_CORNER_H)
        tex:SetPoint(def.point, card, def.point, def.x, def.y)
        tex:Hide()
        corners[i] = tex
    end
    card.bountifulCorners = corners
end

local function SetBountifulCornersShown(card, shown)
    local corners = card.bountifulCorners
    for i = 1, #corners do
        corners[i]:SetShown(shown)
    end
end

local function CreateInstanceListRow(parent, _)
    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetHeight(CARD_HEIGHT)
    card:SetClipsChildren(true)
    card:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    ns.CardChrome.Attach(card)
    AttachBountifulCorners(card)
    ApplyInstanceRowChrome(card, false, false)
    -- SetPropagateMouseClicks became a protected function; calling it while the
    -- list refreshes in combat throws ADDON_ACTION_BLOCKED. false is the default
    -- state anyway, so skipping it under restriction is harmless. Gated on the
    -- protected-action tier (not Map) so the list still builds inside a Delve.
    if not OneWoW.Restriction.IsProtectedActionBlocked() then
        card:SetPropagateMouseClicks(false)
    end

    local nameText = OneWoW_GUI:CreateFS(card, CARD_NAME_SIZE)
    nameText:SetJustifyH("LEFT")
    nameText:SetJustifyV("TOP")
    nameText:SetWordWrap(true)
    nameText:SetMaxLines(CARD_NAME_MAX_LINES)
    nameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    card.nameText = nameText

    local favBtn = OneWoW_GUI:CreateFavoriteToggleButton(card, {
        size = 20,
        favorite = false,
        tooltipTitle = L["CATALOG_FAVORITE"],
        tooltipText = L["CATALOG_FAVORITE_TT"],
        onClick = function(_, on)
            local instData = card.instData
            if not instData or not instData.instanceID then
                return
            end
            if ns.Favorites then
                ns.Favorites:SetFavorite("journal", JournalCacheKey(instData), on)
            end
            local p = panels_ref or ns.UI.journalPanels
            if p then
                RefreshJournalList(p)
                C_Timer.After(0, function()
                    if (panels_ref or ns.UI.journalPanels) == p then
                        RefreshJournalList(p)
                    end
                end)
            end
        end,
    })
    favBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -4)
    favBtn:SetFrameLevel((card:GetFrameLevel() or 0) + 10)
    card.favBtn = favBtn

    -- Frameless atlas chrome matches the favorite star. Same on/off atlas so the
    -- helper's toggle does not change the pin art; click opens the world map.
    local pinBtn = OneWoW_GUI:CreateFavoriteToggleButton(card, {
        size = 20,
        favorite = false,
        atlasOn = "Waypoint-MapPin-Untracked",
        atlasOff = "Waypoint-MapPin-Untracked",
        tooltipTitle = MAP_PIN,
        tooltipText = L["JOURNAL_MAP_PIN_TT"],
        onClick = function(myself)
            myself:SetFavorite(false)
            local instData = card.instData
            if not instData or not instData.instanceID then
                return
            end
            ns.Navigation:OpenInstanceEntrance(instData.instanceID, instData.entrances)
        end,
    })
    pinBtn:SetPoint("TOPRIGHT", favBtn, "TOPLEFT", -4, 0)
    pinBtn:SetFrameLevel((card:GetFrameLevel() or 0) + 10)
    WireJournalPinButton(pinBtn, function()
        return card.instData
    end)
    pinBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pinBtn:SetScript("OnClick", function(myself, button)
        myself:SetFavorite(false)
        local instData = card.instData
        if not instData or not instData.instanceID then
            return
        end
        if button == "RightButton" then
            if ns.Navigation:IsWayPinsEnabled() then
                ns.Navigation:SaveInstanceEntranceWayPin(instData)
            end
            return
        end
        ns.Navigation:OpenInstanceEntrance(instData.instanceID, instData.entrances)
    end)
    card.pinBtn = pinBtn

    local infoText = OneWoW_GUI:CreateFS(card, CARD_META_SIZE)
    infoText:SetJustifyH("LEFT")
    infoText:SetWordWrap(false)
    infoText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    card.infoText = infoText

    local countText = OneWoW_GUI:CreateFS(card, CARD_META_SIZE)
    countText:SetJustifyH("RIGHT")
    countText:SetWordWrap(false)
    countText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
    card.countText = countText

    -- Pool of taxonomy tag FontStrings; BindInstanceListRow shows only present ones.
    card.catTexts = {}
    for i = 1, #TAXONOMY_DEFS do
        local catText = OneWoW_GUI:CreateFS(card, CARD_TAG_SIZE)
        catText:Hide()
        card.catTexts[i] = catText
    end

    card:SetScript("OnEnter", function(myself)
        ApplyInstanceRowChrome(myself, myself._rowSelected, true)
    end)
    card:SetScript("OnLeave", function(myself)
        ApplyInstanceRowChrome(myself, myself._rowSelected, false)
    end)
    card:SetScript("OnSizeChanged", function(myself)
        LayoutInstanceListRow(myself)
    end)

    return card
end

local function BindInstanceListRow(row, index, instData, state)
    if ns.BindCatalogListCapRow(row, instData) then
        return
    end
    row._zebraIndex = index
    row.instData = instData
    row._rowSelected = state.selected and true or false
    local addon = GetDataAddon()
    row._bountiful = instData.instanceType == "delve"
        and addon
        and addon.IsDelveBountiful(instData.mapID)
        or false
    row._borderKey = ns.CardChrome.JournalBorderKey(instData, row._bountiful)
    ns.CardChrome.ApplyBackground(row.bgTex, ns.CardChrome.ResolveJournalBackground(instData))
    ApplyInstanceRowChrome(row, row._rowSelected, false)
    SetBountifulCornersShown(row, row._bountiful)

    row.nameText:SetText(instData.name or "")

    row.infoText:SetText(FormatInstanceInfoLine(instData, 14))

    -- Skeleton cards already carry the hydrated totals (Generated loot plus
    -- static extras), so there is never a "still loading" count to show.
    row.countText:SetText(table.concat(FormatCardCountParts(instData), "  |  "))

    local tagIndex = 0
    for _, def in ipairs(TAXONOMY_DEFS) do
        if instData[def.flag] then
            tagIndex = tagIndex + 1
            local catText = row.catTexts[tagIndex]
            catText:SetText(L[def.labelKey])
            local c = SPECIAL_COLORS[def.colorKey]
            catText:SetTextColor(c[1], c[2], c[3], 1.0)
            catText:Show()
        end
    end
    for i = tagIndex + 1, #row.catTexts do
        row.catTexts[i]:Hide()
    end

    if row.favBtn and ns.Favorites then
        if instData.instanceID then
            row.favBtn:Show()
            row.favBtn:SetFavorite(IsJournalFavorite(instData))
        else
            row.favBtn:Hide()
        end
    end

    if row.pinBtn then
        BindJournalPinButton(row.pinBtn, instData)
    end

    LayoutInstanceListRow(row)
end

local function FormatAbsentCategories(names)
    if #names == 0 then
        return nil
    end
    local joined
    if #names == 1 then
        joined = names[1]
    elseif #names == 2 then
        joined = names[1] .. " " .. L["JOURNAL_COL_OR"] .. " " .. names[2]
    else
        local parts = {}
        for i = 1, #names - 1 do
            parts[i] = names[i]
        end
        joined = table.concat(parts, ", ")
            .. ", " .. L["JOURNAL_COL_OR"] .. " " .. names[#names]
    end
    return string.format(L["JOURNAL_COL_ABSENT"], joined)
end

local function BuildCollectionsSummary(parent, instData, yOffset, addon)
    local counts = {}
    for _, def in ipairs(TAXONOMY_DEFS) do
        counts[def.special] = { total = 0, collected = 0 }
    end

    for _, enc in ipairs(instData.encounters) do
        for _, item in ipairs(enc.items) do
            if item.special and counts[item.special] then
                counts[item.special].total = counts[item.special].total + 1
                if addon then
                    local isCollected = addon.IsItemCollected(item.itemID, item.itemData, item.special)
                    if isCollected then
                        counts[item.special].collected = counts[item.special].collected + 1
                    end
                end
            end
        end
    end

    local anyPresent = false
    local absentNames = {}
    for _, def in ipairs(TAXONOMY_DEFS) do
        if counts[def.special].total > 0 then
            anyPresent = true
        else
            tinsert(absentNames, L[def.labelKey])
        end
    end

    if not anyPresent then
        local headerText = OneWoW_GUI:CreateFS(parent, 12)
        headerText:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
        headerText:SetText(L["JOURNAL_NO_COLLECTIONS"])
        headerText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        table.insert(detailElements, headerText)
        return yOffset - 22
    end

    local headerText = OneWoW_GUI:CreateFS(parent, 12)
    headerText:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    headerText:SetText(L["JOURNAL_COLLECTIONS"])
    headerText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    table.insert(detailElements, headerText)
    yOffset = yOffset - 18

    local parentWidth = parent:GetWidth()
    if parentWidth <= 0 then
        parentWidth = 400
    end
    local maxX = parentWidth - 10
    local xPos = 10
    local rowY = yOffset

    for _, def in ipairs(TAXONOMY_DEFS) do
        local c = counts[def.special]
        if c.total > 0 then
            local catLabel = OneWoW_GUI:CreateFS(parent, 10)
            catLabel:SetJustifyH("LEFT")
            catLabel:SetText(string.format(L[def.colFmt], c.collected, c.total))

            if c.collected >= c.total then
                catLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                local sc = SPECIAL_COLORS[def.colorKey]
                catLabel:SetTextColor(sc[1], sc[2], sc[3], 1.0)
            end

            local w = catLabel:GetStringWidth()
            if xPos > 10 and (xPos + w) > maxX then
                xPos = 10
                rowY = rowY - 14
            end
            catLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", xPos, rowY)
            table.insert(detailElements, catLabel)
            xPos = xPos + w + 12
        end
    end

    yOffset = rowY - 16

    local absentLine = FormatAbsentCategories(absentNames)
    if absentLine then
        local absentText = OneWoW_GUI:CreateFS(parent, 10)
        absentText:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
        absentText:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
        absentText:SetJustifyH("LEFT")
        absentText:SetText(absentLine)
        absentText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        table.insert(detailElements, absentText)
        yOffset = yOffset - 14
    end

    return yOffset - 4
end

local function GetUniqueDifficulties(instData)
    local seen = {}
    local result = {}
    local function addDiff(diff)
        local id = diff.id
        if not id or seen[id] then return end
        seen[id] = true
        tinsert(result, {
            id = id,
            name = diff.name,
            maxPlayers = diff.maxPlayers,
        })
    end

    for _, enc in ipairs(instData.encounters or {}) do
        for _, item in ipairs(enc.items or {}) do
            if item.difficulties then
                for _, diff in ipairs(item.difficulties) do
                    addDiff(diff)
                end
            end
        end
    end

    -- Include MapDifficulty-valid diffs even before live loot arrives.
    if instData.validDifficulties then
        for _, diffID in ipairs(instData.validDifficulties) do
            if not seen[diffID] then
                local name, maxPlayers
                if GetDifficultyInfo then
                    name, _, _, _, _, _, _, _, _, maxPlayers = GetDifficultyInfo(diffID)
                end
                addDiff({ id = diffID, name = name, maxPlayers = maxPlayers })
            end
        end
    end

    sort(result, function(a, b) return a.id < b.id end)
    return result
end

-- Base list from data (expensive); only refetch when filters change. Favorite sort uses a shallow copy.
local journalBaseListKey  = nil
local journalBaseList     = nil

local function JournalInstanceOrderKey(inst)
    return JournalCacheKey(inst)
end

local function InvalidateJournalFilterCache()
    journalBaseListKey = nil
    journalBaseList = nil
end

-- Opens the WoWHead / Open Quest popup for a quest-reward item. Each source
-- quest gets a copyable WoWHead URL plus an "Open Quest" button when that quest
-- exists in the Quests catalog.
local function ShowQuestLinks(item)
    local links = {}
    local questAddon = ns.GetCatalogPackAPI("quests")
    for _, qs in ipairs(item.questSources or (item.itemData and item.itemData.questSources) or {}) do
        local action
        if questAddon and questAddon.GetQuest(qs.id) then
            local qid = qs.id
            action = {
                text = L["JOURNAL_OPEN_QUEST"],
                onClick = function()
                    if ns.UI and ns.UI.OpenToQuest then ns.UI.OpenToQuest(qid) end
                end,
            }
        end
        table.insert(links, {
            label = qs.faction or L["JOURNAL_QUEST_PREFIX"],
            url = "https://www.wowhead.com/quest=" .. qs.id,
            action = action,
        })
    end
    OneWoW_GUI:ShowCopyLinksDialog(item.name .. "  (" .. item.itemID .. ")", L["JOURNAL_QUEST_LINK_INSTRUCT"], links)
end

-- Which source quest the row's [Open] button jumps to: prefer the player's
-- faction, otherwise the first source quest. Returns a questID or nil.
local function ResolveOpenQuestID(item)
    local faction = UnitFactionGroup("player")
    local fallback
    for _, qs in ipairs(item.questSources or (item.itemData and item.itemData.questSources) or {}) do
        if not fallback then fallback = qs.id end
        if qs.faction == faction then return qs.id end
    end
    return fallback or LootRowQuestID(item)
end

local function PaintDetailItemRow(row, hover)
    if hover then
        OneWoW_GUI:ApplyListRowFill(row, { hover = true })
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    else
        OneWoW_GUI:ApplyListRowFill(row, { zebraIndex = row._zebraIndex })
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end
end

-- Renders one row in the "Quest Related / Quest Drop" encounter:
-- {icon} {name}   {itemID}  Quest: (faction: id ...)   [Click For Link]
local function BuildQuestItemRow(parent, item, yOffset, zebraIndex)
    local itemRow = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    itemRow:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    itemRow:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
    itemRow:SetHeight(ITEM_ROW_HEIGHT)
    itemRow:SetBackdrop(BACKDROP_SIMPLE)
    itemRow._zebraIndex = zebraIndex or 1
    PaintDetailItemRow(itemRow, false)
    table.insert(detailElements, itemRow)

    local iconFrame = CreateFrame("Frame", nil, itemRow, "BackdropTemplate")
    iconFrame:SetSize(26, 26)
    iconFrame:SetPoint("LEFT", itemRow, "LEFT", 6, 0)
    iconFrame:SetBackdrop(BACKDROP_EDGE)
    iconFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetItemQualityColor(item.quality))
    table.insert(detailElements, iconFrame)

    local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
    iconTex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    iconTex:SetTexture(item.icon or 134400)

    -- View Quest / Wowhead are text links (fit-width); View Quest only when the
    -- quest exists in the Quests catalog. Status comes from CompletionTracker.
    local relevantQuestID = ResolveOpenQuestID(item)
    local questAddon = ns.GetCatalogPackAPI("quests")
    local openInDB =
        relevantQuestID
        and questAddon
        and questAddon.GetQuest(relevantQuestID)

    local openLink
    if openInDB then
        openLink = OneWoW_GUI:CreateTextLink(itemRow, {
            text = L["JOURNAL_OPEN"],
            fontSize = 11,
            onClick = function()
                if ns.UI and ns.UI.OpenToQuest then ns.UI.OpenToQuest(relevantQuestID) end
            end,
        })
        openLink:SetPoint("RIGHT", itemRow, "RIGHT", -6, 0)
        table.insert(detailElements, openLink)
    end

    local wowheadLink = OneWoW_GUI:CreateTextLink(itemRow, {
        text = L["JOURNAL_CLICK_FOR_LINK"],
        fontSize = 11,
        onClick = function() ShowQuestLinks(item) end,
    })
    if openLink then
        wowheadLink:SetPoint("RIGHT", openLink, "LEFT", -12, 0)
    else
        wowheadLink:SetPoint("RIGHT", itemRow, "RIGHT", -6, 0)
    end
    table.insert(detailElements, wowheadLink)

    -- Status only (no ItemID / Quest ID — tooltip + View Quest cover that).
    local nameRightAnchor = wowheadLink
    if relevantQuestID then
        local completed
        if questAddon then
            completed = questAddon.IsCompletedByCurrentChar(relevantQuestID)
        else
            completed = C_QuestLog.IsQuestFlaggedCompleted(relevantQuestID) == true
        end
        local statusStr = completed and L["JOURNAL_QUEST_COMPLETED"] or L["JOURNAL_QUEST_NOT_COMPLETED"]
        local infoText = OneWoW_GUI:CreateFS(itemRow, 10)
        infoText:SetPoint("RIGHT", wowheadLink, "LEFT", -10, 0)
        infoText:SetJustifyH("RIGHT")
        infoText:SetText(statusStr)
        if completed then
            infoText:SetTextColor(0.25, 1, 0.25, 1)
        else
            infoText:SetTextColor(1, 0.5, 0.25, 1)
        end
        nameRightAnchor = infoText
    end

    local sourceIcon = AddSourceIcon(itemRow, item, nameRightAnchor)

    local itemName = OneWoW_GUI:CreateFS(itemRow, 12)
    itemName:SetPoint("LEFT", iconFrame, "RIGHT", 8, 0)
    itemName:SetPoint("RIGHT", sourceIcon, "LEFT", -10, 0)
    itemName:SetJustifyH("LEFT")
    itemName:SetWordWrap(false)
    itemName:SetText(item.name)
    itemName:SetTextColor(OneWoW_GUI:GetItemQualityColor(item.quality))

    FillVisibleItemRow(item, itemRow, itemName, iconTex, iconFrame)

    itemRow:EnableMouse(true)
    itemRow:SetScript("OnEnter", function(myself)
        PaintDetailItemRow(myself, true)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(item.itemID)
        GameTooltip:Show()
    end)
    itemRow:SetScript("OnLeave", function(myself)
        PaintDetailItemRow(myself, false)
        GameTooltip:Hide()
    end)

    return yOffset - (ITEM_ROW_HEIGHT + 2)
end

-- GetAchievementInfo.completed is Warband-wide. wasEarnedByMe is this character.
-- There is no separate account flag; Warband is the account progress.
---@param completed boolean
---@param wasEarnedByMe boolean
---@return boolean earnedByMe
---@return boolean earnedByWarband
---@return string label
---@return string colorKey
---@return string tooltip
local function AchievementStatus(completed, wasEarnedByMe)
    local earnedByMe = wasEarnedByMe and true or false
    local earnedByWarband = completed and true or false
    if earnedByMe then
        return earnedByMe, earnedByWarband, CRITERIA_COMPLETED, "TEXT_FEATURES_ENABLED", CRITERIA_COMPLETED
    end
    if earnedByWarband then
        return earnedByMe, earnedByWarband, L["JOURNAL_ACH_WARBAND"], "TEXT_FEATURES_ENABLED", ACCOUNT_WIDE_ACHIEVEMENT_COMPLETED
    end
    return false, false, INCOMPLETE, "TEXT_WARNING", INCOMPLETE
end

local function TintStatusIcon(tex, active, activeKey)
    if active then
        tex:SetDesaturated(false)
        tex:SetVertexColor(OneWoW_GUI:GetThemeColor(activeKey))
    else
        tex:SetDesaturated(true)
        tex:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
end

-- Grey: questlog-questtypeicon-account (18x18). Done: warband-completed-icon (36x42).
-- Scale both to the same row height so neither is squashed.
local ACH_WARBAND_ICON_H = 18

local function SetWarbandStatusIcon(tex, earnedByWarband)
    local atlas = earnedByWarband and "warband-completed-icon" or "questlog-questtypeicon-account"
    local info = C_Texture.GetAtlasInfo(atlas)
    local w = ACH_WARBAND_ICON_H
    if info and info.height and info.height > 0 then
        w = info.width * (ACH_WARBAND_ICON_H / info.height)
    end
    tex:SetAtlas(atlas)
    tex:SetSize(w, ACH_WARBAND_ICON_H)
    if earnedByWarband then
        tex:SetDesaturated(false)
        tex:SetVertexColor(1, 1, 1, 1)
    else
        tex:SetDesaturated(true)
        tex:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
end

---@param panels table
local function LayoutJournalDetailHeader(panels)
    panels.LayoutDetailHeader({ height = 38 })
end

---@param encounter table
---@return string
local function EncounterDisplayName(encounter)
    if not IsBlankDisplayName(encounter.name) then
        return encounter.name
    end
    if encounter.questCategory then
        return L["JOURNAL_CARD_QUEST"]
    end
    return BATTLE_PET_SOURCE_1
end

local function SetDifficultyDropdownInteractive(dropdown, textFS, enabled)
    if enabled then
        dropdown:Enable()
        textFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    else
        OneWoW_GUI:CloseAttachFilterMenu()
        dropdown:SetScript("OnClick", nil)
        dropdown:Disable()
        textFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
end

---@param parent Frame
---@param instData table
---@param zoneMapID number|nil
---@return Button|nil
local function AddZoneJumpButton(parent, instData, zoneMapID)
    local addon = GetDataAddon()
    if not addon or instData.instanceType == "zone" or not zoneMapID then
        return nil
    end
    local dest = addon.GetZoneInstance(instData.expansionID, zoneMapID)
    if not dest then
        return nil
    end
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(16, 16)
    btn:SetFrameLevel((parent:GetFrameLevel() or 0) + 2)
    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetAtlas("Waypoint-MapPin-Tracked")
    btn:SetScript("OnClick", function()
        local p = panels_ref
        if not p then
            return
        end
        ShowInstanceDetail(p, dest)
        if journalListAPI then
            journalListAPI.Refresh()
        end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["JOURNAL_OPEN_ZONE_TT"])
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return btn
end

---@param encounter table
---@return number|nil
local function EncounterNPCID(encounter)
    if encounter.questCategory then
        return nil
    end
    local ids = encounter.npcIDs
    if ids then
        local vendorAPI = ns.GetCatalogPackAPI("vendors")
        if vendorAPI then
            for i = 1, #ids do
                local id = tonumber(ids[i])
                if id and vendorAPI.GetVendor(id) then
                    return id
                end
            end
        end
        return tonumber(ids[1])
    end
    return tonumber(encounter.npcID)
end

---@param encounter table
---@return number|nil mapID
---@return number|nil x
---@return number|nil y
local function EncounterMapPoint(encounter)
    if encounter.questCategory then
        return nil
    end
    local pin = encounter.pin
    local mapID = encounter.zoneMapID
    if (not pin or not mapID) and encounter.encounterID then
        local addon = GetDataAddon()
        local src = addon and addon.GetEncounter(encounter.encounterID)
        if src then
            pin = pin or src.pin
            mapID = mapID or src.uiMapID
        end
    end
    if mapID and pin and pin.x and pin.y then
        return mapID, pin.x, pin.y
    end
    return nil
end

---@param encBtn Button
---@param encounter table
local function AddEncounterNavLinks(encBtn, encounter)
    local npcID = EncounterNPCID(encounter)
    if npcID then
        local seeNpc = OneWoW_GUI:CreateTextLink(encBtn, {
            text = L["JOURNAL_SEE_NPC"],
            fontSize = 11,
            tooltipTitle = L["JOURNAL_SEE_NPC"],
            tooltipText = L["JOURNAL_SEE_NPC_TT"],
            onClick = function()
                ns.UI.OpenToVendor(npcID)
            end,
        })
        seeNpc:SetFrameLevel((encBtn:GetFrameLevel() or 0) + 2)
        encBtn.seeNpc = seeNpc
    end
    local mapID, x, y = EncounterMapPoint(encounter)
    if mapID then
        local seeMap = OneWoW_GUI:CreateTextLink(encBtn, {
            text = L["JOURNAL_SEE_MAP"],
            fontSize = 11,
            tooltipTitle = L["JOURNAL_SEE_MAP"],
            tooltipText = L["JOURNAL_SEE_MAP_TT"],
            onClick = function()
                ns.Navigation:OpenMapPin(mapID, x, y)
            end,
        })
        seeMap:SetFrameLevel((encBtn:GetFrameLevel() or 0) + 2)
        encBtn.seeMap = seeMap
    end
end

---@param encBtn Frame
---@return boolean
local function EncounterHeaderClickOnLink(encBtn)
    return (encBtn.seeNpc and encBtn.seeNpc:IsMouseOver())
        or (encBtn.seeMap and encBtn.seeMap:IsMouseOver())
        or (encBtn.jumpBtn and encBtn.jumpBtn:IsMouseOver())
end

local function OpenAchievementUI(achievementID)
    local ok = OneWoW:EnsureLoaded("Blizzard_AchievementUI")
    if not ok then
        return
    end
    ShowAchievementFrameForAchievement(achievementID)
end

---@param parent Frame
---@param instData table
---@param yOffset number
---@return number yOffset
local function BuildAchievementsTable(parent, instData, yOffset)
    local rows = instData.achievements
    if not rows or #rows == 0 then
        return yOffset
    end

    -- Same chrome as the Items column header: plus on the left, labels on one row.
    local COL_POINTS_RIGHT = -170
    local COL_STATUS_RIGHT = -8
    local ACH_STATUS_ICON  = 14
    local ACH_STATUS_GAP   = 3

    local colHdrFrame = CreateFrame("Button", nil, parent, "BackdropTemplate")
    colHdrFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    colHdrFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
    colHdrFrame:SetHeight(20)
    colHdrFrame:SetBackdrop(BACKDROP_SIMPLE)
    colHdrFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    colHdrFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    table.insert(detailElements, colHdrFrame)

    local expandIcon = colHdrFrame:CreateTexture(nil, "ARTWORK")
    expandIcon:SetSize(14, 14)
    expandIcon:SetPoint("LEFT", colHdrFrame, "LEFT", 6, 0)
    expandIcon:SetAtlas(achievementsExpanded and "Gamepad_Rev_Minus_64" or "Gamepad_Rev_Plus_64")

    local hdrPoints = OneWoW_GUI:CreateFS(colHdrFrame, 10)
    hdrPoints:SetPoint("RIGHT", colHdrFrame, "RIGHT", COL_POINTS_RIGHT, 0)
    hdrPoints:SetText(L["JOURNAL_COL_HDR_POINTS"])
    hdrPoints:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    hdrPoints:SetJustifyH("RIGHT")

    local hdrName = OneWoW_GUI:CreateFS(colHdrFrame, 10)
    hdrName:SetPoint("LEFT", expandIcon, "RIGHT", 4, 0)
    hdrName:SetPoint("RIGHT", hdrPoints, "LEFT", -8, 0)
    hdrName:SetJustifyH("LEFT")
    hdrName:SetWordWrap(false)
    hdrName:SetText(L["ACHIEVEMENT"])
    hdrName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local hdrStatus = OneWoW_GUI:CreateFS(colHdrFrame, 10)
    hdrStatus:SetPoint("RIGHT", colHdrFrame, "RIGHT", COL_STATUS_RIGHT, 0)
    hdrStatus:SetText(STATUS)
    hdrStatus:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    hdrStatus:SetJustifyH("RIGHT")

    colHdrFrame:SetScript("OnClick", function()
        achievementsExpanded = not achievementsExpanded
        RefreshDetailView(true)
    end)
    colHdrFrame:SetScript("OnEnter", function(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    end)
    colHdrFrame:SetScript("OnLeave", function(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)

    yOffset = yOffset - 24
    if not achievementsExpanded then
        return yOffset - 8
    end

    local zebra = 0

    --- Nested Stories criteria: same row height, name indented, no icon column.
    local function AppendStoryCriterionRow(achID, critName, critDone, isActive)
        zebra = zebra + 1
        local critRow = CreateFrame("Button", nil, parent, "BackdropTemplate")
        critRow:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
        critRow:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
        critRow:SetHeight(ITEM_ROW_HEIGHT)
        critRow:SetBackdrop(BACKDROP_SIMPLE)
        critRow._zebraIndex = zebra
        PaintDetailItemRow(critRow, false)
        table.insert(detailElements, critRow)

        local statusLabel = critDone and CRITERIA_COMPLETED or INCOMPLETE
        local colorKey = critDone and "TEXT_FEATURES_ENABLED" or "TEXT_WARNING"
        local statusFS = OneWoW_GUI:CreateFS(critRow, 10)
        statusFS:SetPoint("RIGHT", critRow, "RIGHT", COL_STATUS_RIGHT, 0)
        statusFS:SetJustifyH("RIGHT")
        statusFS:SetWordWrap(false)
        statusFS:SetText(statusLabel)
        local statusTextW = statusFS:GetStringWidth()
        if statusTextW > 72 then
            statusFS:SetWidth(72)
        end
        statusFS:SetTextColor(OneWoW_GUI:GetThemeColor(colorKey))

        local xIcon = critRow:CreateTexture(nil, "ARTWORK")
        xIcon:SetSize(ACH_STATUS_ICON, ACH_STATUS_ICON)
        xIcon:SetPoint("RIGHT", statusFS, "LEFT", -4, 0)
        xIcon:SetAtlas("common-icon-redx")
        TintStatusIcon(xIcon, not critDone, "TEXT_WARNING")

        local checkIcon = critRow:CreateTexture(nil, "ARTWORK")
        checkIcon:SetSize(ACH_STATUS_ICON, ACH_STATUS_ICON)
        checkIcon:SetPoint("RIGHT", xIcon, "LEFT", -ACH_STATUS_GAP, 0)
        checkIcon:SetAtlas("common-icon-checkmark")
        TintStatusIcon(checkIcon, critDone, "TEXT_FEATURES_ENABLED")

        local nameFS = OneWoW_GUI:CreateFS(critRow, 12)
        nameFS:SetPoint("LEFT", critRow, "LEFT", 40, 0)
        nameFS:SetPoint("RIGHT", checkIcon, "LEFT", -8, 0)
        nameFS:SetJustifyH("LEFT")
        nameFS:SetWordWrap(false)
        nameFS:SetText(critName)
        nameFS:SetTextColor(OneWoW_GUI:GetThemeColor(isActive and "TEXT_ACCENT" or "TEXT_PRIMARY"))

        local capturedID = achID
        local capturedName = critName
        critRow:SetScript("OnClick", function()
            OpenAchievementUI(capturedID)
        end)
        critRow:SetScript("OnEnter", function(myself)
            PaintDetailItemRow(myself, true)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(capturedName, 1, 1, 1)
            local tr, tg, tb = OneWoW_GUI:GetThemeColor(colorKey)
            GameTooltip:AddLine(statusLabel, tr, tg, tb, true)
            GameTooltip:Show()
        end)
        critRow:SetScript("OnLeave", function(myself)
            PaintDetailItemRow(myself, false)
            GameTooltip:Hide()
        end)

        yOffset = yOffset - (ITEM_ROW_HEIGHT + 2)
    end

    for _, row in ipairs(rows) do
        local achID = row.id
        local id, name, points, completed, _, _, _, description, _, icon, rewardText, _, wasEarnedByMe =
            GetAchievementInfo(achID)
        if id then
            zebra = zebra + 1
            local itemRow = CreateFrame("Button", nil, parent, "BackdropTemplate")
            itemRow:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
            itemRow:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
            itemRow:SetHeight(ITEM_ROW_HEIGHT)
            itemRow:SetBackdrop(BACKDROP_SIMPLE)
            itemRow._zebraIndex = zebra
            PaintDetailItemRow(itemRow, false)
            table.insert(detailElements, itemRow)

            local iconFrame = CreateFrame("Frame", nil, itemRow, "BackdropTemplate")
            iconFrame:SetSize(26, 26)
            iconFrame:SetPoint("LEFT", itemRow, "LEFT", 6, 0)
            iconFrame:SetBackdrop(BACKDROP_EDGE)
            iconFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
            iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            table.insert(detailElements, iconFrame)

            local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
            iconTex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
            iconTex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
            iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            iconTex:SetTexture(icon)

            local earnedByMe, earnedByWarband, statusLabel, colorKey, statusTooltip =
                AchievementStatus(completed, wasEarnedByMe)
            local statusFS = OneWoW_GUI:CreateFS(itemRow, 10)
            statusFS:SetPoint("RIGHT", itemRow, "RIGHT", COL_STATUS_RIGHT, 0)
            statusFS:SetJustifyH("RIGHT")
            statusFS:SetWordWrap(false)
            statusFS:SetText(statusLabel)
            local statusTextW = statusFS:GetStringWidth()
            if statusTextW > 72 then
                statusFS:SetWidth(72)
            end
            statusFS:SetTextColor(OneWoW_GUI:GetThemeColor(colorKey))

            -- Check | Warband | X | Status. Grey until that flag is a yes.
            local xIcon = itemRow:CreateTexture(nil, "ARTWORK")
            xIcon:SetSize(ACH_STATUS_ICON, ACH_STATUS_ICON)
            xIcon:SetPoint("RIGHT", statusFS, "LEFT", -4, 0)
            xIcon:SetAtlas("common-icon-redx")
            TintStatusIcon(xIcon, not earnedByMe and not earnedByWarband, "TEXT_WARNING")

            local warbandIcon = itemRow:CreateTexture(nil, "ARTWORK")
            warbandIcon:SetPoint("RIGHT", xIcon, "LEFT", -ACH_STATUS_GAP, 0)
            SetWarbandStatusIcon(warbandIcon, earnedByWarband)

            local checkIcon = itemRow:CreateTexture(nil, "ARTWORK")
            checkIcon:SetSize(ACH_STATUS_ICON, ACH_STATUS_ICON)
            checkIcon:SetPoint("RIGHT", warbandIcon, "LEFT", -ACH_STATUS_GAP, 0)
            checkIcon:SetAtlas("common-icon-checkmark")
            TintStatusIcon(checkIcon, earnedByMe, "TEXT_FEATURES_ENABLED")

            local pointsFS = OneWoW_GUI:CreateFS(itemRow, 10)
            pointsFS:SetPoint("RIGHT", itemRow, "RIGHT", COL_POINTS_RIGHT, 0)
            pointsFS:SetJustifyH("RIGHT")
            pointsFS:SetText(tostring(points or 0))
            pointsFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

            local nameFS = OneWoW_GUI:CreateFS(itemRow, 12)
            local jumpBtn = AddZoneJumpButton(itemRow, instData, row.zoneMapID)
            if jumpBtn then
                jumpBtn:SetPoint("LEFT", iconFrame, "RIGHT", 4, 0)
                nameFS:SetPoint("LEFT", jumpBtn, "RIGHT", 6, 0)
            else
                nameFS:SetPoint("LEFT", iconFrame, "RIGHT", 8, 0)
            end
            nameFS:SetPoint("RIGHT", pointsFS, "LEFT", -8, 0)
            nameFS:SetJustifyH("LEFT")
            nameFS:SetWordWrap(false)
            nameFS:SetText(name)
            nameFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            local capturedID = achID
            itemRow:SetScript("OnClick", function()
                OpenAchievementUI(capturedID)
            end)
            itemRow:SetScript("OnEnter", function(myself)
                PaintDetailItemRow(myself, true)
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetText(name, 1, 1, 1)
                local tr, tg, tb = OneWoW_GUI:GetThemeColor(colorKey)
                GameTooltip:AddLine(statusTooltip, tr, tg, tb, true)
                if description and description ~= "" then
                    GameTooltip:AddLine(description, 0.8, 0.8, 0.8, true)
                end
                if rewardText and rewardText ~= "" then
                    local rr, gg, bb = OneWoW_GUI:GetThemeColor("TEXT_ACCENT")
                    GameTooltip:AddLine(rewardText, rr, gg, bb, true)
                end
                GameTooltip:Show()
            end)
            itemRow:SetScript("OnLeave", function(myself)
                PaintDetailItemRow(myself, false)
                GameTooltip:Hide()
            end)

            yOffset = yOffset - (ITEM_ROW_HEIGHT + 2)

            if row.kind == "stories" and not completed then
                local criteria = CollectStoryCriteria(achID)
                local addon = GetDataAddon()
                local raw = addon and addon.GetDelveStoryText(instData.mapID)
                local _, activeIdx = MatchStoryDisplayName(raw, criteria)
                for j = 1, #criteria do
                    AppendStoryCriterionRow(achID, criteria[j].name, criteria[j].completed, j == activeIdx)
                end
            end
        end
    end

    return yOffset - 8
end

-- Guide overview headerType is local in FrameXML (EJ_HTYPE_OVERVIEW = 3).
local EJ_SECTION_HEADER_OVERVIEW = 3
local JOURNAL_ENCOUNTER_ID_MAX = 9999999

local function IsGuideEncounterID(encounterID)
    return type(encounterID) == "number"
        and encounterID >= 1
        and encounterID <= JOURNAL_ENCOUNTER_ID_MAX
end

local function InstanceHasGuidePage(instData)
    if not instData or not instData.instanceID or instData.instanceID <= 0 then
        return false
    end
    local instanceType = instData.instanceType
    if instanceType == "zone" or instanceType == "delve" or instData.isCity then
        return false
    end
    return true
end

local LORE_PAD = 10
local LORE_BODY_GAP = 4
local LORE_TITLE_GAP = 8
local LORE_LABEL_GAP = 12

local function LorePlain(text)
    if not text or text == "" then
        return nil
    end
    local plain = StripColorCodes(text)
    if not plain or plain == "" then
        return nil
    end
    return plain
end

local function LoreGapBefore(kind, isFirst)
    if isFirst then
        return 0
    end
    if kind == "label" then
        return LORE_LABEL_GAP
    end
    if kind == "title" then
        return LORE_TITLE_GAP
    end
    return LORE_BODY_GAP
end

---@param blocks { kind: string, text: string, depth?: number }[]
---@return number yOffset
local function AppendLorePanel(parent, yOffset, blocks)
    if not blocks or #blocks == 0 then
        return yOffset
    end
    local parentW = parent:GetWidth() or 0
    if parentW < 40 then
        parentW = 400
    end
    local insetW = parentW - 16
    local inset = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    inset:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    inset:SetWidth(insetW)
    inset:SetBackdrop(BACKDROP_SIMPLE)
    inset:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    inset:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    table.insert(detailElements, inset)

    local prev
    local prevIndent = LORE_PAD
    local height = LORE_PAD
    for i = 1, #blocks do
        local block = blocks[i]
        local kind = block.kind
        local colorKey = "TEXT_SECONDARY"
        if kind == "label" or kind == "title" then
            colorKey = "TEXT_ACCENT"
        end
        local indent = LORE_PAD + ((block.depth or 0) * 12)
        local textW = math.max(20, insetW - indent - LORE_PAD)
        local fs = OneWoW_GUI:CreateFS(inset, 11)
        fs:SetWidth(textW)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetWordWrap(true)
        fs:SetText(block.text)
        fs:SetTextColor(OneWoW_GUI:GetThemeColor(colorKey))
        local lineH = fs:GetStringHeight() or 12
        fs:SetHeight(lineH)
        local gap = LoreGapBefore(kind, i == 1)
        if prev then
            fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", indent - prevIndent, -gap)
        else
            fs:SetPoint("TOPLEFT", inset, "TOPLEFT", indent, -LORE_PAD)
        end
        height = height + gap + lineH
        prev = fs
        prevIndent = indent
    end
    inset:SetHeight(height + LORE_PAD)
    return yOffset - (height + LORE_PAD) - 8
end

local function CollectGuideSections(rootSectionID)
    local sections = {}
    local function skipOverviews(sectionID)
        while sectionID and sectionID > 0 do
            local info = C_EncounterJournal.GetSectionInfo(sectionID)
            if not info then
                return nil
            end
            if info.headerType == EJ_SECTION_HEADER_OVERVIEW then
                sectionID = info.siblingSectionID
            else
                return sectionID
            end
        end
        return nil
    end

    local function walk(sectionID, depth)
        while sectionID and sectionID > 0 do
            local info = C_EncounterJournal.GetSectionInfo(sectionID)
            if not info then
                break
            end
            local hasTitle = info.title and info.title ~= ""
            local hasDesc = info.description and info.description ~= ""
            if hasTitle or hasDesc then
                tinsert(sections, {
                    title = info.title,
                    description = info.description,
                    depth = depth,
                })
            end
            if info.firstChildSectionID and info.firstChildSectionID > 0 then
                walk(info.firstChildSectionID, depth + 1)
            end
            sectionID = info.siblingSectionID
        end
    end

    local startID = skipOverviews(rootSectionID)
    if startID then
        walk(startID, 0)
    end
    return sections
end

local function LiveInstanceDescription(instanceID)
    if not OneWoW:EnsureLoaded("Blizzard_EncounterJournal") then
        return nil
    end
    local _, description = EJ_GetInstanceInfo(instanceID)
    if description and description ~= "" then
        return description
    end
    return nil
end

local function AppendLiveEncounterGuide(parent, encounter, yOffset)
    if encounter.worldRare or encounter.extrasCategory or encounter.questCategory then
        return yOffset
    end
    local encID = encounter.encounterID
    if not IsGuideEncounterID(encID) then
        return yOffset
    end
    if not OneWoW:EnsureLoaded("Blizzard_EncounterJournal") then
        return yOffset
    end
    local _, description, _, rootSectionID = EJ_GetEncounterInfo(encID)
    local blocks = {}
    local lore = LorePlain(description)
    if lore then
        tinsert(blocks, { kind = "body", text = lore })
    end
    if rootSectionID and rootSectionID > 0 then
        local sections = CollectGuideSections(rootSectionID)
        if #sections > 0 then
            tinsert(blocks, { kind = "label", text = ABILITIES })
            for i = 1, #sections do
                local sec = sections[i]
                local title = LorePlain(sec.title)
                local body = LorePlain(sec.description)
                if title then
                    tinsert(blocks, { kind = "title", text = title, depth = sec.depth })
                end
                if body then
                    tinsert(blocks, { kind = "body", text = body, depth = sec.depth })
                end
            end
        end
    end
    if #blocks == 0 then
        return yOffset
    end
    return AppendLorePanel(parent, yOffset, blocks)
end

RefreshDetailView = function(isSecondRefresh)
    if not panels_ref or not selectedInstance then return end

    local panels = panels_ref
    local instData = selectedInstance
    local addon = GetDataAddon()

    if panels.emptyDetail then panels.emptyDetail:Hide() end
    ClearDetailElements()

    local parent = panels.detailScrollChild
    local yOffset = -8

    LayoutJournalDetailHeader(panels)

    local nameHeader = OneWoW_GUI:CreateFS(parent, 16)
    nameHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    nameHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    nameHeader:SetJustifyH("LEFT")
    nameHeader:SetText(instData.name)
    nameHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    table.insert(detailElements, nameHeader)
    yOffset = yOffset - 22

    local typeLine = OneWoW_GUI:CreateFS(parent, 12)
    typeLine:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    typeLine:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    typeLine:SetJustifyH("LEFT")
    typeLine:SetText(FormatInstanceInfoLine(instData, 14))
    typeLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    table.insert(detailElements, typeLine)
    yOffset = yOffset - 18

    local infoLine = OneWoW_GUI:CreateFS(parent, 12)
    infoLine:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    infoLine:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    infoLine:SetJustifyH("LEFT")
    local infoParts = {}
    if instData.instanceType ~= "delve" and instData.instanceType ~= "zone" then
        tinsert(infoParts, L["JOURNAL_DETAIL_INST_ID"] .. ": " .. instData.instanceID)
    end
    if instData.mapID then
        tinsert(infoParts, L["QUESTS_MAPID"] .. ": " .. instData.mapID)
    end
    infoLine:SetText(table.concat(infoParts, "  |  "))
    infoLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    table.insert(detailElements, infoLine)
    yOffset = yOffset - 20

    if InstanceHasGuidePage(instData) then
        local instanceLore = LiveInstanceDescription(instData.instanceID)
        if instanceLore then
            local lore = LorePlain(instanceLore)
            if lore then
                yOffset = AppendLorePanel(parent, yOffset, {
                    { kind = "label", text = OVERVIEW },
                    { kind = "body", text = lore },
                })
            end
        end
    end

    local divider1 = OneWoW_GUI:CreateDivider(parent, { yOffset = yOffset })
    table.insert(detailElements, divider1)
    yOffset = yOffset - 8

    if instData.instanceType ~= "delve" then
        yOffset = BuildCollectionsSummary(parent, instData, yOffset, addon)
    end

    yOffset = BuildAchievementsTable(parent, instData, yOffset)

    if #(instData.encounters or {}) == 0 then
        if instData.instanceType ~= "delve" then
            -- The card is hydrated by the time the detail pane builds, so an
            -- empty encounter list means empty, not pending.
            local emptyLine = OneWoW_GUI:CreateFS(parent, 12)
            emptyLine:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
            emptyLine:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
            emptyLine:SetJustifyH("LEFT")
            emptyLine:SetText(L["JOURNAL_EMPTY"])
            emptyLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            table.insert(detailElements, emptyLine)
            yOffset = yOffset - 24
        end
        parent:SetHeight(math.abs(yOffset) + 20)
        panels.UpdateDetailThumb()
        if panels.rightStatusText then
            panels.rightStatusText:SetText(FormatDetailStatusLine(instData))
        end
        return
    end

    local divider2 = OneWoW_GUI:CreateDivider(parent, { yOffset = yOffset })
    table.insert(detailElements, divider2)
    yOffset = yOffset - 10

    local colHdrFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    colHdrFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    colHdrFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
    colHdrFrame:SetHeight(20)
    colHdrFrame:SetBackdrop(BACKDROP_SIMPLE)
    colHdrFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    colHdrFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    table.insert(detailElements, colHdrFrame)

    -- Header toggle: collapses/expands every encounter at once. Shows minus when
    -- all encounters are already open, plus otherwise, mirroring the per-encounter icons.
    local allExpanded = true
    for _, encounter in ipairs(instData.encounters) do
        if not encounter.sectionHeader and expandedEncounters[encounter.encounterID] ~= true then
            allExpanded = false
            break
        end
    end

    local expandAllBtn = CreateFrame("Button", nil, colHdrFrame)
    expandAllBtn:SetSize(16, 16)
    expandAllBtn:SetPoint("LEFT", colHdrFrame, "LEFT", 6, 0)
    local expandAllIcon = expandAllBtn:CreateTexture(nil, "ARTWORK")
    expandAllIcon:SetSize(14, 14)
    expandAllIcon:SetPoint("CENTER")
    expandAllIcon:SetAtlas(allExpanded and "Gamepad_Rev_Minus_64" or "Gamepad_Rev_Plus_64")
    table.insert(detailElements, expandAllBtn)
    expandAllBtn:SetScript("OnClick", function()
        local expand = not allExpanded
        for _, encounter in ipairs(instData.encounters) do
            if not encounter.sectionHeader then
                expandedEncounters[encounter.encounterID] = expand or nil
            end
        end
        RefreshDetailView(false)
    end)

    local hdrItem = OneWoW_GUI:CreateFS(colHdrFrame, 10)
    hdrItem:SetText(L["ITEM"])
    hdrItem:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    hdrItem:SetWordWrap(false)

    local hdrType = OneWoW_GUI:CreateFS(colHdrFrame, 10)
    hdrType:SetText(TYPE)
    hdrType:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    hdrType:SetWordWrap(false)

    local hdrStatus = OneWoW_GUI:CreateFS(colHdrFrame, 10)
    hdrStatus:SetText(STATUS)
    hdrStatus:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    hdrStatus:SetWordWrap(false)

    local hdrDiff = OneWoW_GUI:CreateFS(colHdrFrame, 10)
    hdrDiff:SetText(L["JOURNAL_COL_HDR_DIFFICULTY"])
    hdrDiff:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    hdrDiff:SetWordWrap(false)

    local hdrSource = OneWoW_GUI:CreateFS(colHdrFrame, 10)
    hdrSource:SetText(SOURCES)
    hdrSource:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    hdrSource:SetWordWrap(false)

    colHdrFrame._lootCols = {
        leadW = LOOT_PAD + LOOT_ICON + LOOT_GAP,
        name = hdrItem,
        type = hdrType,
        status = hdrStatus,
        diff = hdrDiff,
        source = hdrSource,
    }
    colHdrFrame:SetScript("OnSizeChanged", function(myself)
        LayoutLootTableRow(myself)
    end)
    LayoutLootTableRow(colHdrFrame)

    yOffset = yOffset - 24

    for _, encounter in ipairs(instData.encounters) do
        if encounter.sectionHeader then
            local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            section:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
            section:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
            section:SetHeight(22)
            section:SetBackdrop(BACKDROP_SIMPLE)
            section:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            section:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            table.insert(detailElements, section)
            local sectionName = OneWoW_GUI:CreateFS(section, 12)
            sectionName:SetPoint("LEFT", section, "LEFT", 10, 0)
            sectionName:SetText(encounter.name)
            sectionName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            yOffset = yOffset - 26
        else
        local isExpanded = expandedEncounters[encounter.encounterID] == true

        local filteredItems = {}
        for _, item in ipairs(encounter.items) do
            if ItemMatchesFilters(item, addon) then
                table.insert(filteredItems, item)
            end
        end

        if encounter.worldRare and isExpanded then
            ScheduleRareNameRefresh(encounter)
        end

        local displayID = ResolveEncounterDisplayID(encounter)
        local ringKind = ns.CardChrome.PortraitKindForEncounter(encounter, instData.instanceType)
        local showPortrait = displayID and ringKind

        local encBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        encBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
        encBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
        encBtn:SetHeight(showPortrait and ENC_ROW_HEIGHT_PORTRAIT or ENC_ROW_HEIGHT)
        encBtn:SetBackdrop(BACKDROP_SIMPLE)
        encBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        encBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        table.insert(detailElements, encBtn)

        local expandIcon = encBtn:CreateTexture(nil, "ARTWORK")
        expandIcon:SetSize(14, 14)
        expandIcon:SetPoint("LEFT", encBtn, "LEFT", 8, 0)
        expandIcon:SetAtlas(isExpanded and "Gamepad_Rev_Minus_64" or "Gamepad_Rev_Plus_64")

        local nameAnchor = expandIcon
        local nameLeft = 8 + 14 + 6
        if showPortrait then
            local portrait = encBtn:CreateTexture(nil, "ARTWORK")
            portrait:SetSize(ENC_PORTRAIT_SIZE, ENC_PORTRAIT_SIZE)
            portrait:SetPoint("LEFT", expandIcon, "RIGHT", 6, 0)
            SetPortraitTextureFromCreatureDisplayID(portrait, displayID)
            local ring = ns.CardChrome.CreatePortraitRing(encBtn, portrait)
            ns.CardChrome.ApplyPortraitRing(ring, ringKind)
            nameAnchor = portrait
            nameLeft = nameLeft + 6 + ENC_PORTRAIT_SIZE
        end

        local encName = OneWoW_GUI:CreateFS(encBtn, 12)
        encName:SetPoint("LEFT", nameAnchor, "RIGHT", 6, 0)
        encName:SetText(EncounterDisplayName(encounter))
        encName:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        encName:SetJustifyH("LEFT")
        encName:SetWordWrap(false)
        encBtn.encName = encName
        encBtn._nameLeft = nameLeft + 6

        local itemCountStr = string.format(L["JOURNAL_ITEMS_COUNT"], #filteredItems)
        if #filteredItems ~= #encounter.items then
            itemCountStr = string.format(L["D_OF_D_ITEMS"], #filteredItems, #encounter.items)
        end
        local encCount = OneWoW_GUI:CreateFS(encBtn, 10)
        encCount:SetText(itemCountStr)
        encCount:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        encBtn.encCount = encCount

        local encSource = AddSourceIcon(encBtn, encounter, nil, true)
        encBtn.encSource = encSource
        local jumpBtn = AddZoneJumpButton(encBtn, instData, encounter.zoneMapID)
        encBtn.jumpBtn = jumpBtn
        AddEncounterNavLinks(encBtn, encounter)

        encBtn:SetScript("OnSizeChanged", function(myself)
            LayoutEncounterHeaderRow(myself)
        end)
        LayoutEncounterHeaderRow(encBtn)

        local capturedEncID = encounter.encounterID
        encBtn:SetScript("OnClick", function(myself)
            if EncounterHeaderClickOnLink(myself) then
                return
            end
            expandedEncounters[capturedEncID] = not expandedEncounters[capturedEncID]
            RefreshDetailView(false)
        end)
        local isQuestCategory = encounter.questCategory
        encBtn:SetScript("OnEnter", function(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            if isQuestCategory then
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:AddLine(L["JOURNAL_QUEST_CAT_TT"], 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        encBtn:SetScript("OnLeave", function(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            GameTooltip:Hide()
        end)

        yOffset = yOffset - ((showPortrait and ENC_ROW_HEIGHT_PORTRAIT or ENC_ROW_HEIGHT) + 2)

        if isExpanded then
            yOffset = AppendLiveEncounterGuide(parent, encounter, yOffset)
            if #filteredItems > 0 then
            if encounter.questCategory then
                for i, item in ipairs(filteredItems) do
                    yOffset = BuildQuestItemRow(parent, item, yOffset, i)
                end
            else
            for i, item in ipairs(filteredItems) do
                local itemRow = CreateFrame("Frame", nil, parent, "BackdropTemplate")
                itemRow:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
                itemRow:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
                itemRow:SetHeight(ITEM_ROW_HEIGHT)
                itemRow:SetBackdrop(BACKDROP_SIMPLE)
                itemRow._zebraIndex = i
                PaintDetailItemRow(itemRow, false)
                table.insert(detailElements, itemRow)

                local iconFrame = CreateFrame("Frame", nil, itemRow, "BackdropTemplate")
                iconFrame:SetSize(26, 26)
                iconFrame:SetPoint("LEFT", itemRow, "LEFT", 6, 0)
                iconFrame:SetBackdrop(BACKDROP_EDGE)
                iconFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
                iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetItemQualityColor(item.quality))
                table.insert(detailElements, iconFrame)

                local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
                iconTex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
                iconTex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
                iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                iconTex:SetTexture(item.icon or 134400)

                local itemName = OneWoW_GUI:CreateFS(itemRow, 12)
                itemName:SetJustifyH("LEFT")
                itemName:SetWordWrap(false)
                itemName:SetText(item.name)
                itemName:SetTextColor(OneWoW_GUI:GetItemQualityColor(item.quality))

                local sourceIcon = AddSourceIcon(itemRow, item, nil, true)

                FillVisibleItemRow(item, itemRow, itemName, iconTex, iconFrame)

                local diffText = OneWoW_GUI:CreateFS(itemRow, 10)
                diffText:SetJustifyH("LEFT")
                diffText:SetWordWrap(false)
                diffText:SetText(FormatDifficulties(item.difficulties))
                diffText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

                local typeText = OneWoW_GUI:CreateFS(itemRow, 10)
                typeText:SetJustifyH("LEFT")
                typeText:SetWordWrap(false)
                local typeLabel, specialColorKey = LootRowTypeLabel(item)
                if typeLabel then
                    typeText:SetText(typeLabel)
                    local sc = specialColorKey and SPECIAL_COLORS[specialColorKey]
                    if sc then
                        typeText:SetTextColor(sc[1], sc[2], sc[3], 1.0)
                    else
                        typeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                    end
                else
                    typeText:SetText("")
                end

                local statusText = OneWoW_GUI:CreateFS(itemRow, 10)
                statusText:SetJustifyH("LEFT")
                statusText:SetWordWrap(false)
                local status, isCollected = LootRowStatus(item, addon)
                if status then
                    statusText:SetText(status)
                    if isCollected then
                        statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
                    else
                        statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
                    end
                else
                    statusText:SetText("")
                end

                local listBtn = ns.AttachListButton(itemRow, item.itemID, {
                    name = item.name,
                    instance_name = instData and instData.name or "",
                    encounter = encounter and encounter.name or "",
                    instance = instData and instData.id or 0,
                    point = "RIGHT",
                    x = -4,
                    y = 0,
                })
                itemRow._lootCols = {
                    leadW = LOOT_PAD + LOOT_ICON + LOOT_GAP,
                    name = itemName,
                    type = typeText,
                    status = statusText,
                    diff = diffText,
                    source = sourceIcon,
                    list = listBtn,
                }
                itemRow:SetScript("OnSizeChanged", function(myself)
                    LayoutLootTableRow(myself)
                end)
                LayoutLootTableRow(itemRow)

                itemRow:EnableMouse(true)
                itemRow:SetScript("OnMouseUp", function(self, button)
                    if button == "RightButton" and ns.AttachListButton then
                        local api = OneWoW_ShoppingList_API
                        if api and api.ShowAddToListMenu then
                            api.ShowAddToListMenu(self, item.itemID, {
                                name = item.name,
                                instance_name = instData and instData.name or "",
                                encounter = encounter and encounter.name or "",
                                instance = instData and instData.id or 0,
                            })
                        end
                    end
                end)
                itemRow:SetScript("OnEnter", function(self)
                    PaintDetailItemRow(self, true)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    local scaledLink = GetScaledItemLink(item, capturedEncID)
                    if scaledLink then
                        GameTooltip:SetHyperlink(scaledLink)
                    else
                        GameTooltip:SetItemByID(item.itemID)
                    end
                    GameTooltip:Show()
                end)
                itemRow:SetScript("OnLeave", function(self)
                    PaintDetailItemRow(self, false)
                    GameTooltip:Hide()
                end)

                yOffset = yOffset - (ITEM_ROW_HEIGHT + 2)
            end
            end
            end
        end

        yOffset = yOffset - 4
        end
    end

    parent:SetHeight(math.abs(yOffset) + 20)
    panels.UpdateDetailThumb()

    if panels.rightStatusText and instData then
        panels.rightStatusText:SetText(FormatDetailStatusLine(instData))
    end

    if not isSecondRefresh then
        C_Timer.After(0.1, function()
            if panels and panels.detailScrollChild:IsVisible() and selectedInstance then
                RefreshDetailView(true)
            end
        end)
    end
end

function ShowInstanceDetail(panels, instData, encounterID)
    if not instData then return end
    selectedInstance = instData
    expandedEncounters = {}
    encounterID = tonumber(encounterID)
    if encounterID then
        expandedEncounters[encounterID] = true
    end
    achievementsExpanded = true
    panels_ref = panels

    local dataAddon = GetDataAddon()
    if dataAddon then
        dataAddon.EnsureEncounters(instData)
        if instData.instanceType ~= "delve" and instData.instanceType ~= "zone"
            and instData.instanceID and instData.instanceID > 0 then
            dataAddon.SetLiveMergeTarget(instData)
            dataAddon.MergeInstance(instData)
        else
            dataAddon.SetLiveMergeTarget(nil)
        end
        dataAddon.MergeLiveATTExtras(instData)
    end
    -- Hydrate mutates the cache entry after SetSelectedIndex already bound the
    -- row. Refresh rebinds visible cards; do not SetSelectedIndex (re-enters).
    if journalListAPI then
        journalListAPI.Refresh()
    end

    if panels.diffDropdown then
        local isDelve = instData.instanceType == "delve"
        local diffs = isDelve and {} or GetUniqueDifficulties(instData)
        if isDelve or #diffs > 0 then
            panels.diffDropdown:Show()
            panels.diffText:SetText(L["ALL_DIFFICULTIES"])
            if isDelve then
                SetDifficultyDropdownInteractive(panels.diffDropdown, panels.diffText, false)
            else
                SetDifficultyDropdownInteractive(panels.diffDropdown, panels.diffText, true)
                OneWoW_GUI:AttachFilterMenu(panels.diffDropdown, {
                    searchable = false,
                    getActiveValue = function() return selectedDifficulty end,
                    buildItems = function()
                        local items = { { value = "all", text = L["ALL_DIFFICULTIES"] } }
                        local curDiffs = GetUniqueDifficulties(selectedInstance)
                        for _, diff in ipairs(curDiffs) do
                            table.insert(items, {
                                value = diff.id,
                                text  = FormatDifficultyMenuLabel(diff),
                            })
                        end
                        return items
                    end,
                    onSelect = function(value, text)
                        selectedDifficulty = value
                        panels.diffText:SetText(value == "all" and L["ALL_DIFFICULTIES"] or text)
                        RefreshDetailView(false)
                    end,
                })
            end
        else
            panels.diffDropdown:Hide()
        end
    end

    selectedDifficulty = "all"
    if panels.detailPinBtn then
        BindJournalPinButton(panels.detailPinBtn, instData)
    end
    if panels.ejBtn then
        if instData.instanceType ~= "delve" and instData.instanceType ~= "zone"
            and instData.instanceID and instData.instanceID > 0 then
            panels.ejBtn:Show()
        else
            panels.ejBtn:Hide()
        end
    end
    RefreshDetailView(false)
end

-- "Has uncollected" has to hydrate a card's loot before it can test collection
-- state, and with the expansion filter on "All" that is every card in the index.
-- Run it time-budgeted so the client stays responsive, and let the list fill as
-- matches arrive rather than blocking on the whole walk.
local journalUncollectedJob = nil
local FinishJournalList
local FillJournalList
local StartUncollectedFilter

local function CancelUncollectedFilter()
    if journalUncollectedJob then
        journalUncollectedJob:Cancel()
        journalUncollectedJob = nil
    end
end

local function InstanceHasUncollected(inst, addon)
    if not addon or not inst or not inst.encounters then
        return false
    end
    for _, enc in ipairs(inst.encounters) do
        for _, item in ipairs(enc.items or {}) do
            if item.special then
                local collected = addon.IsItemCollected(item.itemID, item.itemData, item.special)
                if collected == false then
                    return true
                end
            end
        end
    end
    return false
end

local function JournalHasListFilter()
    return ns.CatalogListHasSearchText(searchText)
        or expansionFilter ~= 0
        or instanceTypeFilter ~= "all"
        or hasUncollectedOnly
        or showBountifulOnly
end

---@param panels table
---@param candidates table cards to test, in display order
StartUncollectedFilter = function(panels, candidates)
    local addon = GetDataAddon()
    local matches = {}

    if panels.emptyList then
        panels.emptyList:Hide()
    end

    journalUncollectedJob = OneWoW.ChunkedJob.Start({
        run = function(shouldYield)
            for i = 1, #candidates do
                local inst = candidates[i]
                addon.EnsureEncounters(inst)
                if InstanceHasUncollected(inst, addon) then
                    matches[#matches + 1] = inst
                end
                -- Yield between cards only: one card's hydrate is indivisible.
                OneWoW.ChunkedJob.YieldIfNeeded(shouldYield)
            end
        end,
        onProgress = function()
            wipe(listResults)
            local cap = ns.GetCatalogListCap(JournalHasListFilter())
            local n = #matches
            if n > cap then
                n = cap
            end
            for i = 1, n do
                listResults[i] = matches[i]
            end
            if journalListAPI then
                journalListAPI.Refresh()
            end
            if panels.leftStatusText then
                panels.leftStatusText:SetText(string.format(L["JOURNAL_STATS"], #matches))
            end
        end,
        onComplete = function()
            journalUncollectedJob = nil
            FinishJournalList(panels, matches)
        end,
        onCancel = function()
            journalUncollectedJob = nil
        end,
    })
end

FillJournalList = function(panels)
    CancelUncollectedFilter()
    if panels.listScrollFrame and panels.listScrollFrame.SetVerticalScroll then
        panels.listScrollFrame:SetVerticalScroll(0)
    end

    local addon = GetDataAddon()
    if not addon then
        if panels.emptyList then
            panels.emptyList:Show()
        end
        if journalListAPI then
            journalListAPI.SetSelectedIndex(nil)
        end
        return
    end

    if instanceTypeFilter == "delve" or instanceTypeFilter == "all" or showBountifulOnly then
        addon.RefreshBountiful()
    end

    local filtKey = string.format("%d\0%s\0%s\0%s", expansionFilter, searchText or "", tostring(instanceTypeFilter or "all"), tostring(showBountifulOnly))
    if journalBaseListKey ~= filtKey or not journalBaseList then
        journalBaseList = addon.GetSortedInstances(expansionFilter, searchText, instanceTypeFilter)
        journalBaseListKey = filtKey
    end

    local sorted = {}
    for i = 1, #journalBaseList do
        sorted[i] = journalBaseList[i]
    end

    if hasUncollectedOnly then
        StartUncollectedFilter(panels, sorted)
        return
    end

    FinishJournalList(panels, sorted)
end

function RefreshJournalList(panels)
    wipe(listResults)
    ns.EnsureCatalogPack("journal")
    OneWoW:EnsureJournalShardsForFilter(expansionFilter, function()
        local p = panels_ref or panels
        if not p then
            return
        end
        InvalidateJournalFilterCache()
        FillJournalList(p)
    end)
    FillJournalList(panels)
end

--- Bountiful filter, favourites hoist, list population and selection restore.
--- Split out of RefreshJournalList so the chunked uncollected filter can run the
--- same tail once its walk finishes.
---@param panels table
---@param sorted table
FinishJournalList = function(panels, sorted)
    local addon = GetDataAddon()
    -- The chunked filter paints partial results into listResults as it goes, and
    -- the bountiful pass below can still shrink the set, so start from empty.
    wipe(listResults)

    if showBountifulOnly then
        local filtered = {}
        for _, inst in ipairs(sorted) do
            if inst.instanceType == "delve" and addon.IsDelveBountiful(inst.mapID) then
                tinsert(filtered, inst)
            end
        end
        sorted = filtered
    end

    if ns.Favorites then
        local keyFn = JournalInstanceOrderKey
        local origOrder = {}
        for i, inst in ipairs(sorted) do
            origOrder[keyFn(inst)] = i
        end
        local function cmpBaseOrder(a, b)
            return (origOrder[keyFn(a)] or 0) < (origOrder[keyFn(b)] or 0)
        end
        local favInsts, restInsts = {}, {}
        for _, inst in ipairs(sorted) do
            if IsJournalFavorite(inst) then
                tinsert(favInsts, inst)
            else
                tinsert(restInsts, inst)
            end
        end
        sort(favInsts, cmpBaseOrder)
        sort(restInsts, cmpBaseOrder)
        local pos = 0
        for _, inst in ipairs(favInsts) do
            pos = pos + 1
            sorted[pos] = inst
        end
        for _, inst in ipairs(restInsts) do
            pos = pos + 1
            sorted[pos] = inst
        end
        for i = pos + 1, #sorted do
            sorted[i] = nil
        end
    end

    local isFiltered = JournalHasListFilter()
    local totalMatched = #sorted
    local truncated = ns.CapCatalogList(sorted, isFiltered)
    local totalSorted = #sorted

    if totalSorted == 0 then
        if panels.emptyList then
            panels.emptyList:Show()
        end
        if panels.leftStatusText then
            panels.leftStatusText:SetText("")
        end
        if journalListAPI then
            journalListAPI.SetSelectedIndex(nil)
        end
        return
    end

    if panels.emptyList then
        panels.emptyList:Hide()
    end

    for i = 1, totalSorted do
        listResults[i] = sorted[i]
    end
    if truncated then
        ns.AppendCatalogListCapNotice(listResults)
    end

    local keepKey = selectedInstance and JournalCacheKey(selectedInstance)
    local keepIndex = nil
    if keepKey ~= "" then
        for i, inst in ipairs(listResults) do
            if JournalCacheKey(inst) == keepKey then
                keepIndex = i
                break
            end
        end
    end

    if journalListAPI then
        if keepIndex then
            -- Restoring the same row must not re-fire onSelect. That re-enters
            -- ShowInstanceDetail → MergeInstance → this refresh (stack overflow).
            if journalListAPI.GetSelectedIndex() == keepIndex then
                journalListAPI.Refresh()
            else
                journalListAPI.SetSelectedIndex(keepIndex)
            end
        else
            journalListAPI.SetSelectedIndex(nil)
            journalListAPI.Refresh()
        end
    end

    if panels.leftStatusText then
        if truncated then
            panels.leftStatusText:SetText(string.format(L["JOURNAL_STATS_SHOWING"], totalSorted, totalMatched))
        else
            panels.leftStatusText:SetText(string.format(L["JOURNAL_STATS"], totalSorted))
        end
    end
end

ns.UI.RefreshJournalList = RefreshJournalList

local function ExpansionFilterLabel()
    if expansionFilter == 0 then
        return L["JOURNAL_EXPANSION_ALL"]
    end
    local expansions = OneWoW.CatalogData:GetWantedJournalExpansions()
    for i = 1, #expansions do
        if expansions[i].expansionID == expansionFilter then
            return expansions[i].displayName
        end
    end
    return L["JOURNAL_EXPANSION_ALL"]
end

local function SnapExpansionToType(panels)
    if instanceTypeFilter ~= "delve" then
        return
    end
    if expansionFilter ~= 0 and expansionFilter ~= 11 and expansionFilter ~= 12 then
        expansionFilter = 0
        if panels.expText then
            panels.expText:SetText(L["JOURNAL_EXPANSION_ALL"])
        end
    end
end

local function SetBountifulFilterVisible(panels, visible)
    local chk = panels.bountifulChk
    if not chk then
        return
    end
    if visible then
        chk:Show()
    else
        chk:Hide()
        chk:SetChecked(false)
        showBountifulOnly = false
    end
end

local function ResetBountifulFilter(panels)
    showBountifulOnly = false
    SetBountifulFilterVisible(panels, instanceTypeFilter == "delve")
    if panels and panels.bountifulChk then
        panels.bountifulChk:SetChecked(false)
    end
end

local function InitializeDropdowns(panels)
    local addon = GetDataAddon()
    if not addon then return end

    if panels.expDropdown then
        panels.expText:SetText(ExpansionFilterLabel())
        -- Tall enough for All + every expansion (default menuHeight clips the last row).
        OneWoW_GUI:AttachFilterMenu(panels.expDropdown, {
            searchable = false,
            menuHeight = 400,
            getActiveValue = function() return expansionFilter end,
            buildItems = function()
                local items = { { value = 0, text = L["JOURNAL_EXPANSION_ALL"] } }
                local expansions = OneWoW.CatalogData:GetWantedJournalExpansions()
                for _, exp in ipairs(expansions) do
                    if instanceTypeFilter ~= "delve" or exp.expansionID == 11 or exp.expansionID == 12 then
                        table.insert(items, {
                            value = exp.expansionID,
                            text  = exp.displayName,
                        })
                    end
                end
                return items
            end,
            onSelect = function(value, text)
                expansionFilter = value
                panels.expText:SetText(value == 0 and L["JOURNAL_EXPANSION_ALL"] or text)
                RefreshJournalList(panels)
            end,
        })
    end

    if panels.typeDropdown then
        local typeLabelFor = {
            all   = L["JOURNAL_FILTER_SHOW_ALL"],
            party = DUNGEONS,
            raid  = RAIDS,
            world = WORLD,
            zone  = L["JOURNAL_FILTER_ZONES"],
            city  = L["JOURNAL_FILTER_CITIES"],
            delve = DELVES_LABEL,
        }
        panels.typeText:SetText(typeLabelFor[instanceTypeFilter] or L["JOURNAL_FILTER_SHOW_ALL"])
        OneWoW_GUI:AttachFilterMenu(panels.typeDropdown, {
            searchable = false,
            menuHeight = 280,
            getActiveValue = function() return instanceTypeFilter end,
            buildItems = function()
                return {
                    { value = "all",   text = L["JOURNAL_FILTER_SHOW_ALL"] },
                    { value = "party", text = DUNGEONS },
                    { value = "raid",  text = RAIDS },
                    { value = "world", text = WORLD },
                    { value = "zone",  text = L["JOURNAL_FILTER_ZONES"] },
                    { value = "city",  text = L["JOURNAL_FILTER_CITIES"] },
                    { value = "delve", text = DELVES_LABEL },
                }
            end,
            onSelect = function(value, text)
                instanceTypeFilter = value
                panels.typeText:SetText(text)
                SnapExpansionToType(panels)
                SetBountifulFilterVisible(panels, value == "delve")
                RefreshJournalList(panels)
            end,
        })
    end

    if panels.itemFilterDropdown then
        panels.itemFilterText:SetText(GetItemTypeFilterLabel())
        OneWoW_GUI:AttachFilterMenu(panels.itemFilterDropdown, {
            searchable = false,
            buildItems = function()
                local items = {}
                for _, def in ipairs(ITEM_TYPE_DEFS) do
                    local capKey = def.key
                    table.insert(items, {
                        type    = "checkbox",
                        text    = L[def.labelKey],
                        checked = filterItemTypes[capKey] == true,
                        onToggle = function(checked)
                            filterItemTypes[capKey] = checked and true or nil
                            panels.itemFilterText:SetText(GetItemTypeFilterLabel())
                            if selectedInstance then
                                RefreshDetailView(false)
                            end
                        end,
                    })
                end
                table.insert(items, { type = "divider" })
                table.insert(items, {
                    value = "__reset__",
                    text  = RESET,
                })
                return items
            end,
            onSelect = function(value)
                if value == "__reset__" then
                    ResetItemTypeFilter()
                    panels.itemFilterText:SetText(GetItemTypeFilterLabel())
                    if selectedInstance then
                        RefreshDetailView(false)
                    end
                end
            end,
        })
    end

    if panels.collectionFilterDropdown then
        panels.collectionFilterText:SetText(L["JOURNAL_FILTER_SHOW_ALL"])
        OneWoW_GUI:AttachFilterMenu(panels.collectionFilterDropdown, {
            searchable = false,
            getActiveValue = function() return filterCollection end,
            buildItems = function()
                return {
                    { value = "all",          text = L["JOURNAL_FILTER_SHOW_ALL"]      },
                    { value = "collected",    text = L["JOURNAL_FILTER_COLLECTED"]     },
                    { value = "notcollected", text = L["JOURNAL_FILTER_NOT_COLLECTED"] },
                }
            end,
            onSelect = function(value, text)
                filterCollection = value
                panels.collectionFilterText:SetText(value == "all" and L["JOURNAL_FILTER_SHOW_ALL"] or text)
                if selectedInstance then
                    RefreshDetailView(false)
                end
            end,
        })
    end
end

function ns.UI.CreateJournalTab(parent)
    local LEFT_W = ns.Constants.GUI.LEFT_PANEL_WIDTH
    local GAP    = ns.Constants.GUI.PANEL_GAP
    local HDR_H  = 86  -- was 80; adds bottom padding for expansion dropdown

    local leftHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HDR_H, offset = 0 })
    leftHeader:ClearAllPoints()
    leftHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    leftHeader:SetWidth(LEFT_W)

    local rightHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HDR_H, offset = 0 })
    rightHeader:ClearAllPoints()
    rightHeader:SetPoint("TOPLEFT", leftHeader, "TOPRIGHT", GAP, 0)
    rightHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 0, -GAP)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local panels = OneWoW_GUI:CreateSplitPanel(contentArea, { hideTitles = true })

    journalListAPI = OneWoW_GUI:CreateVirtualizer(panels.listPanel, {
        name = "CatalogJournalList",
        rowHeight = CARD_STRIDE,
        minRowHeight = CARD_STRIDE,
        numVisibleRows = 10,
        rowInset = 0,
        scrollFrame = panels.listScrollFrame,
        content = panels.listScrollChild,
        getCount = function()
            return #listResults
        end,
        getEntry = function(index)
            return listResults[index]
        end,
        isSelectable = function(_, inst)
            return inst ~= nil and not ns.IsCatalogListCap(inst)
        end,
        onSelect = function(_, inst)
            if inst and not ns.IsCatalogListCap(inst) then
                ShowInstanceDetail(panels, inst)
            end
        end,
        createRow = CreateInstanceListRow,
        bindRow = BindInstanceListRow,
    })
    panels.virtualizedList = journalListAPI

    local clearBtn = OneWoW_GUI:CreateFitTextButton(leftHeader, { text = L["JOURNAL_FILTER_CLEAR"], height = 26, minWidth = 34 })
    clearBtn:SetPoint("TOPRIGHT", leftHeader, "TOPRIGHT", -8, -8)

    local searchBox = OneWoW_GUI:CreateEditBox(leftHeader, {
        height = 26,
        placeholderText = L["JOURNAL_SEARCH"],
        onTextChanged = function(text)
            searchText = text
            if panels._searchTimer then panels._searchTimer:Cancel() end
            panels._searchTimer = C_Timer.NewTimer(0.3, function()
                RefreshJournalList(panels)
            end)
        end,
    })
    searchBox:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -8)
    searchBox:SetPoint("TOPRIGHT", clearBtn, "TOPLEFT", -4, 0)

    -- LEFT HEADER: Expansion dropdown (no label — dropdown text is self-explanatory)
    -- then "Has uncollected" checkbox under it.
    expansionFilter = OneWoW.CatalogData:GetCurrentSuiteExpansionID()
    local expDropdown, expText = OneWoW_GUI:CreateDropdown(leftHeader, { width = LEFT_W - 16, text = ExpansionFilterLabel() })
    expDropdown:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -38)

    local hasUncollectedChk = OneWoW_GUI:CreateCheckbox(leftHeader, {
        label = L["JOURNAL_HAS_UNCOLLECTED"],
        checked = false,
        onClick = function()
            hasUncollectedOnly = not hasUncollectedOnly
            RefreshJournalList(panels)
        end,
    })
    hasUncollectedChk:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -64)

    local bountifulChk = OneWoW_GUI:CreateCheckbox(leftHeader, {
        label = L["JOURNAL_SHOW_BOUNTIFUL"],
        checked = false,
        onClick = function()
            showBountifulOnly = not showBountifulOnly
            RefreshJournalList(panels)
        end,
    })
    bountifulChk:SetPoint("LEFT", hasUncollectedChk.label, "RIGHT", 16, 0)
    bountifulChk:SetPoint("TOP", hasUncollectedChk, "TOP", 0, 0)
    bountifulChk:Hide()

    -- RIGHT HEADER: Instance Type → Item Type → Collection (left-packed)
    local DROP_W = 130
    local DROP_GAP = 6

    local typeLabel = OneWoW_GUI:CreateFS(rightHeader, 10)
    typeLabel:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", 8, -8)
    typeLabel:SetText(L["JOURNAL_LABEL_INST_TYPE"])
    typeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local typeDropdown, typeText = OneWoW_GUI:CreateDropdown(rightHeader, {
        width = DROP_W,
        text = L["JOURNAL_FILTER_SHOW_ALL"],
    })
    typeDropdown:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", 8, -22)

    local itemTypeLabel = OneWoW_GUI:CreateFS(rightHeader, 10)
    itemTypeLabel:SetText(L["JOURNAL_LABEL_ITEM_TYPE"])
    itemTypeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local itemFilterDropdown, itemFilterText = OneWoW_GUI:CreateDropdown(rightHeader, {
        width = DROP_W,
        text = L["JOURNAL_FILTER_SHOW_ALL"],
    })
    itemFilterDropdown:SetPoint("TOPLEFT", typeDropdown, "TOPRIGHT", DROP_GAP, 0)
    itemTypeLabel:SetPoint("BOTTOMLEFT", itemFilterDropdown, "TOPLEFT", 0, 2)

    local collLabel = OneWoW_GUI:CreateFS(rightHeader, 10)
    collLabel:SetText(L["JOURNAL_LABEL_COLLECTION"])
    collLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local collectionFilterDropdown, collectionFilterText = OneWoW_GUI:CreateDropdown(rightHeader, {
        width = DROP_W,
        text = L["JOURNAL_FILTER_SHOW_ALL"],
    })
    collectionFilterDropdown:SetPoint("TOPLEFT", itemFilterDropdown, "TOPRIGHT", DROP_GAP, 0)
    collLabel:SetPoint("BOTTOMLEFT", collectionFilterDropdown, "TOPLEFT", 0, 2)

    local chkBox = OneWoW_GUI:CreateCheckbox(rightHeader, {
        label = L["JOURNAL_HIDE_NON_COLLECTABLE"],
        checked = false,
        onClick = function()
            hideNonCollectable = not hideNonCollectable
            if selectedInstance then
                RefreshDetailView(false)
            end
        end,
    })
    chkBox:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", 8, -54)

    if C_AddOns.IsAddOnLoaded("AllTheThings") then
        local attBadge = CreateFrame("Frame", nil, rightHeader)
        attBadge:SetSize(18, 18)
        attBadge:SetPoint("BOTTOMRIGHT", rightHeader, "BOTTOMRIGHT", -8, 8)

        local attIcon = attBadge:CreateTexture(nil, "ARTWORK")
        attIcon:SetAllPoints()
        attIcon:SetTexture(ATT_SOURCE_TEXTURE)

        attBadge:EnableMouse(true)
        attBadge:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(L["JOURNAL_ATT_DETECTED"])
            GameTooltip:AddLine(L["JOURNAL_ATT_DETECTED_TT"], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        attBadge:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    -- Clear button resets all filters
    clearBtn:SetScript("OnClick", function()
        searchText         = ""
        expansionFilter    = 0
        instanceTypeFilter = "all"
        ResetItemTypeFilter()
        filterCollection   = "all"
        hideNonCollectable = false
        hasUncollectedOnly = false
        showBountifulOnly  = false
        searchBox:SetText("")
        searchBox:ClearFocus()
        searchBox:RestorePlaceholder()
        expText:SetText(L["JOURNAL_EXPANSION_ALL"])
        typeText:SetText(L["JOURNAL_FILTER_SHOW_ALL"])
        itemFilterText:SetText(GetItemTypeFilterLabel())
        collectionFilterText:SetText(L["JOURNAL_FILTER_SHOW_ALL"])
        chkBox:SetChecked(false)
        hasUncollectedChk:SetChecked(false)
        SetBountifulFilterVisible(panels, false)
        RefreshJournalList(panels)
        if selectedInstance then
            RefreshDetailView(false)
        end
    end)

    -- Empty state labels
    local emptyList = OneWoW_GUI:CreateFS(panels.listScrollFrame, 12)
    emptyList:SetPoint("CENTER", panels.listScrollFrame, "CENTER", 0, 0)
    emptyList:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    panels.emptyList = emptyList

    local emptyDetail = OneWoW_GUI:CreateFS(panels.detailPanel, 12)
    emptyDetail:SetPoint("CENTER", panels.detailPanel, "CENTER", 0, 0)
    emptyDetail:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    panels.emptyDetail = emptyDetail

    -- Difficulty dropdown stays in detail panel (no Instances/Details titles).
    local diffDropdown, diffText = OneWoW_GUI:CreateDropdown(panels.detailPanel, { width = 180, text = L["ALL_DIFFICULTIES"] })
    diffDropdown:SetPoint("TOPLEFT", panels.detailPanel, "TOPLEFT", 8, -8)
    diffDropdown:Hide()
    panels.diffDropdown = diffDropdown
    panels.diffText = diffText

    -- Same atlas pin as the list cards. Lives on the detail chrome strip so
    -- RefreshDetailView rebuilds do not recreate it.
    local detailPinBtn = OneWoW_GUI:CreateFavoriteToggleButton(panels.detailPanel, {
        size = 26,
        favorite = false,
        atlasOn = "Waypoint-MapPin-Untracked",
        atlasOff = "Waypoint-MapPin-Untracked",
        tooltipTitle = MAP_PIN,
        tooltipText = L["JOURNAL_MAP_PIN_TT"],
        onClick = function(myself)
            myself:SetFavorite(false)
            local instData = selectedInstance
            if not instData or not instData.instanceID then
                return
            end
            ns.Navigation:OpenInstanceEntrance(instData.instanceID, instData.entrances)
        end,
    })
    detailPinBtn:SetPoint("TOPRIGHT", panels.detailPanel, "TOPRIGHT", -32, -8)
    detailPinBtn:SetFrameLevel((panels.detailPanel:GetFrameLevel() or 0) + 10)
    detailPinBtn:Hide()
    WireJournalPinButton(detailPinBtn, function()
        return selectedInstance
    end)
    detailPinBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    detailPinBtn:SetScript("OnClick", function(myself, button)
        myself:SetFavorite(false)
        local instData = selectedInstance
        if not instData or not instData.instanceID then
            return
        end
        if button == "RightButton" then
            if ns.Navigation:IsWayPinsEnabled() then
                ns.Navigation:SaveInstanceEntranceWayPin(instData)
            end
            return
        end
        ns.Navigation:OpenInstanceEntrance(instData.instanceID, instData.entrances)
    end)
    panels.detailPinBtn = detailPinBtn

    local ejBtn = OneWoW_GUI:CreateFitTextButton(panels.detailPanel, {
        text = ADVENTURE_JOURNAL,
        height = 26,
    })
    ejBtn:SetPoint("RIGHT", detailPinBtn, "LEFT", -8, 0)
    ejBtn:SetFrameLevel((panels.detailPanel:GetFrameLevel() or 0) + 10)
    ejBtn:Hide()
    ejBtn:SetScript("OnClick", function()
        local instData = selectedInstance
        if not instData or instData.instanceType == "delve" or not instData.instanceID then
            return
        end
        local ok = OneWoW:EnsureLoaded("Blizzard_EncounterJournal")
        if not ok then
            return
        end
        local diffID = selectedDifficulty ~= "all" and selectedDifficulty or nil
        EncounterJournal_OpenJournal(diffID, instData.instanceID)
    end)
    ejBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(ADVENTURE_JOURNAL, 1, 1, 1)
        GameTooltip:AddLine(L["JOURNAL_ADVENTURE_GUIDE_TT"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    ejBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    panels.ejBtn = ejBtn

    LayoutJournalDetailHeader(panels)

    panels.expDropdown              = expDropdown
    panels.expText                  = expText
    panels.typeDropdown             = typeDropdown
    panels.typeText                 = typeText
    panels.itemFilterDropdown       = itemFilterDropdown
    panels.itemFilterText           = itemFilterText
    panels.collectionFilterDropdown = collectionFilterDropdown
    panels.collectionFilterText     = collectionFilterText
    panels.searchBox                = searchBox
    panels.hasUncollectedChk        = hasUncollectedChk
    panels.bountifulChk             = bountifulChk

    ns.UI.journalPanels = panels
    panels_ref = panels

    local mainWindow = OneWoWMainWindow
    if mainWindow and not mainWindow._oneWoWJournalBountifulReset then
        mainWindow._oneWoWJournalBountifulReset = true
        mainWindow:HookScript("OnHide", function()
            local p = panels_ref or ns.UI.journalPanels
            local addon = GetDataAddon()
            if addon then
                addon.SetLiveMergeTarget(nil)
            end
            ResetBountifulFilter(p)
            if p then
                InvalidateJournalFilterCache()
                RefreshJournalList(p)
            end
        end)
    end

    -- Start in the no-data state; WatchCatalogDataReady swaps to the live view
    -- once the Journal data unit's data is queryable. Catch-up covers a tab opened
    -- after data was already ready; the signal covers a mid-session load.
    panels.listScrollChild:SetHeight(100)
    panels.detailScrollChild:SetHeight(100)

    ns.WatchCatalogDataReady("journal", {
        emptyList = emptyList,
        emptyDetail = emptyDetail,
        noDataText = L["JOURNAL_NO_DATA"],
        emptyText = L["JOURNAL_EMPTY"],
        selectText = L["JOURNAL_SELECT"],
        isReady = function()
            return GetDataAddon() ~= nil
        end,
        onReady = function()
            local addon = GetDataAddon()
            panels.detailScrollChild:SetHeight(100)

            if addon.RegisterScanCallback then
                addon.RegisterScanCallback(function(reason)
                    local p = ns.UI.journalPanels
                    if not p then return end
                    -- Per-card live merge: refresh the open card and list chrome only.
                    -- RefreshJournalList re-selects and would re-enter MergeInstance.
                    if reason == "ej_merge" then
                        if journalListAPI then
                            journalListAPI.Refresh()
                        end
                        if selectedInstance then
                            RefreshDetailView(false)
                        end
                        return
                    end
                    InvalidateJournalFilterCache()
                    RefreshJournalList(p)
                    if selectedInstance then
                        local keepKey = JournalCacheKey(selectedInstance)
                        for _, inst in ipairs(listResults) do
                            if JournalCacheKey(inst) == keepKey then
                                selectedInstance = inst
                                break
                            end
                        end
                        RefreshDetailView(false)
                    end
                end)
            end

            InitializeDropdowns(panels)
            RefreshJournalList(panels)
        end,
    })

    function parent.GetNavEntity()
        if selectedInstance then
            return "instance", JournalCacheKey(selectedInstance)
        end
    end

    function parent.RestoreNavEntity(kind, id)
        if kind ~= "instance" or id == nil then
            return
        end
        id = tostring(id)
        local inst, keepIndex
        for i, row in ipairs(listResults) do
            if JournalCacheKey(row) == id
                or (row.mapID and tostring(row.mapID) == id)
                or (row.instanceID and tostring(row.instanceID) == id) then
                inst = row
                keepIndex = i
                break
            end
        end
        if not inst then
            local mapID = tonumber(id)
            if mapID then
                local journalAPI = GetDataAddon()
                inst = journalAPI and journalAPI.GetInstanceByMapID(mapID)
            end
        end
        if not inst then
            return
        end
        if keepIndex and journalListAPI then
            journalListAPI.SetSelectedIndex(keepIndex)
            return
        end
        ShowInstanceDetail(panels, inst)
    end
end

--- Open Zones (Journal) on one place. Number is a mapID (toast / map pin).
--- Table selects by placeKey / instanceID / mapID and can expand an encounter.
---@param spec number|table
function ns.UI.OpenToInstance(spec)
    local mapID, instanceID, placeKey, encounterID
    if type(spec) == "table" then
        mapID = tonumber(spec.mapID) or tonumber(spec.uiMapID)
        instanceID = tonumber(spec.instanceID)
        placeKey = spec.placeKey
        encounterID = tonumber(spec.encounterID)
    else
        mapID = tonumber(spec)
    end

    local packName = ns.EnsureCatalogPack("journal")
    OneWoW:EnsureJournalShards(OneWoW.CatalogData:GetCurrentSuiteExpansionID())
    local journalAPI = GetDataAddon()
    if not journalAPI then
        if packName then
            OneWoW:WithAddon(packName, function()
                ns.UI.OpenToInstance(spec)
            end)
        end
        return
    end

    local function FindInstance()
        local inst
        if encounterID then
            local enc = journalAPI.GetEncounter(encounterID)
            local encInstanceID = enc and tonumber(enc.instanceID)
            if encInstanceID and encInstanceID > 0 then
                inst = journalAPI.GetInstanceByInstanceID(encInstanceID)
            end
        end
        if not inst and type(placeKey) == "string" and placeKey ~= "" then
            inst = journalAPI.GetInstanceByPlaceKey(placeKey)
        end
        if not inst and instanceID and instanceID > 0 then
            inst = journalAPI.GetInstanceByInstanceID(instanceID)
        end
        if not inst and mapID then
            inst = journalAPI.GetInstanceByMapID(mapID)
            if not inst then
                inst = journalAPI.GetZoneInstance(nil, mapID)
            end
        end
        return inst
    end

    local instData = FindInstance()
    if not instData then
        OneWoW:EnsureCatalogJournalPlaces()
        instData = FindInstance()
    end
    if not instData then
        return
    end

    OneWoW.UI:Show("catalog")
    OneWoW.UI:SelectSubTab("catalog", "journal")
    OneWoW.UI:CommitNavEntity("instance", JournalCacheKey(instData))

    local function apply()
        local panels = panels_ref or ns.UI.journalPanels
        if not panels then
            return false
        end
        selectedInstance = instData
        ShowInstanceDetail(panels, instData, encounterID)
        if journalListAPI then
            local keepKey = JournalCacheKey(instData)
            local keepIndex
            for i, inst in ipairs(listResults) do
                if JournalCacheKey(inst) == keepKey then
                    keepIndex = i
                    break
                end
            end
            if keepIndex then
                journalListAPI.SetSelectedIndex(keepIndex)
            end
        end
        return true
    end

    if not apply() then
        C_Timer.After(0.15, apply)
        C_Timer.After(0.35, apply)
    end
end
