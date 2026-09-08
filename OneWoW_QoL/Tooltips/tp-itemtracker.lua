local _, ns = ...

local OneWoW = OneWoW
local tinsert, sort, pairs, format = tinsert, sort, pairs, format
local RETRIEVING_DATA = RETRIEVING_DATA
local RETRIEVING_ITEM_INFO = RETRIEVING_ITEM_INFO
local UNKNOWNOBJECT = UNKNOWNOBJECT
local BATTLE_PET_SOURCE_1 = BATTLE_PET_SOURCE_1
local BATTLE_PET_SOURCE_2 = BATTLE_PET_SOURCE_2
local BATTLE_PET_SOURCE_3 = BATTLE_PET_SOURCE_3
local BATTLE_PET_SOURCE_4 = BATTLE_PET_SOURCE_4
local BATTLE_PET_SOURCE_6 = BATTLE_PET_SOURCE_6
local CLUB_FINDER_MULTIPLE_CHECKED = CLUB_FINDER_MULTIPLE_CHECKED
local GUILD = GUILD
local C_Map = C_Map
local GetAchievementInfo = GetAchievementInfo

local CATDB_RARE_BASE = 10000000
local CATDB_GENERAL_MIN = 20000000
local JOURNAL_RARE_BASE = -1000000
local WHERE_LIST_CAP = 3
local WHERE_HEADER_PAD = "  "
local WHERE_CHILD_PAD = "    "

---@param name string|nil
---@return boolean
local function IsMissingWhereName(name)
    if not name or name == "" then
        return true
    end
    if name == "?" or name == "???" then
        return true
    end
    if name == RETRIEVING_DATA or name == RETRIEVING_ITEM_INFO or name == UNKNOWNOBJECT then
        return true
    end
    if name:find("^NPC #%d") or name:find("^NPC %d") then
        return true
    end
    return false
end

local function GetItemIndex()
    local api = OneWoW_AltTracker_Storage_API
    return api and api.GetItemIndex() or nil
end

local function GetVendorData(itemID)
    local api = OneWoW:GetCatalogPackAPI("vendors")
    if not api then
        return {}
    end
    return api.GetVendorsByItem(itemID) or {}
end

-- The Journal store owns the drop index and dedupes per instance+encounter, so
-- this only has to supply the tooltip's display fallback. Do not load Zones
-- from a tooltip; drop lines appear when that pack is already loaded.
local function GetInstanceData(itemID)
    local results = {}
    local api = OneWoW:GetCatalogPackAPI("journal")
    if not api then
        return results
    end
    for _, drop in ipairs(api.GetItemDropLocations(itemID)) do
        tinsert(results, drop)
    end
    return results
end

local function GetAchievementIDs(itemID)
    local api = OneWoW:GetCatalogPackAPI("journal")
    if not api then
        return {}
    end
    return api.GetAchievementsForItem(itemID) or {}
end

local function GetCraftData(itemID)
    local results = {}
    local api = OneWoW:GetCatalogPackAPI("tradeskills")
    if not api then
        return results
    end
    local seen = {}
    for _, recipe in ipairs(api.GetRecipesByItem(itemID)) do
        local label = recipe.prof or api.GetRecipeProfession(recipe.id)
        if label and not seen[label] then
            seen[label] = true
            results[#results + 1] = { name = label }
        end
    end
    return results
end

---@param name string|nil
---@return string|nil
local function CleanWhereName(name)
    if IsMissingWhereName(name) then
        return nil
    end
    return name
end

---@param drop table
---@return string|nil
local function DropKind(drop)
    local encID = drop.encounterID
    if drop.worldRare then
        return "rare"
    end
    if encID then
        if encID >= CATDB_RARE_BASE and encID < CATDB_GENERAL_MIN then
            return "rare"
        end
        if encID <= JOURNAL_RARE_BASE then
            return "rare"
        end
    end
    local instType = drop.instanceType
    local isWorld = instType == "world" or instType == "zone"
        or ((not drop.instanceID or drop.instanceID == 0)
            and instType ~= "party" and instType ~= "raid" and instType ~= "delve")
    if isWorld then
        if encID and encID > 0 and encID < CATDB_RARE_BASE then
            return "worldBoss"
        end
        if drop.npcID then
            return "rare"
        end
        return nil
    end
    if instType == "party" then
        return "dungeon"
    end
    if instType == "delve" then
        return "delve"
    end
    if instType == "raid" then
        return "raid"
    end
    if drop.instanceID and drop.instanceID > 0 then
        return "raid"
    end
    if drop.npcID then
        return "rare"
    end
    return nil
end

---@param drop table
---@return string|nil
local function DropZoneName(drop)
    if drop.uiMapID and drop.uiMapID > 0 then
        local info = C_Map.GetMapInfo(drop.uiMapID)
        local mapName = info and CleanWhereName(info.name)
        if mapName then
            return mapName
        end
    end
    return CleanWhereName(drop.instanceName)
end

---@param lines table
---@param header string
---@param r number
---@param g number
---@param b number
local function AppendCategoryHeader(lines, header, r, g, b)
    tinsert(lines, {
        type = "header",
        text = WHERE_HEADER_PAD .. header,
        r = r, g = g, b = b,
    })
end

---@param lines table
---@param left string
---@param right string|nil
---@param r number
---@param g number
---@param b number
local function AppendCategoryChild(lines, left, right, r, g, b)
    tinsert(lines, {
        type = "double",
        left = WHERE_CHILD_PAD .. left,
        right = right or "",
        lr = r, lg = g, lb = b,
        rr = 0.85, rg = 0.85, rb = 0.85,
    })
end

--- 1-3 rows: list all. More than 3: first 2 real rows, then Multiple / see Catalog.
---@param lines table
---@param header string
---@param rows table
---@param r number
---@param g number
---@param b number
---@param seeCatalog string
local function AppendCappedCategory(lines, header, rows, r, g, b, seeCatalog)
    if #rows == 0 then
        return
    end
    AppendCategoryHeader(lines, header, r, g, b)
    local overflow = #rows > WHERE_LIST_CAP
    local n = overflow and 2 or #rows
    for i = 1, n do
        AppendCategoryChild(lines, rows[i].left, rows[i].right, r, g, b)
    end
    if overflow then
        AppendCategoryChild(lines, CLUB_FINDER_MULTIPLE_CHECKED, seeCatalog, r, g, b)
    end
end

---@param vendor table
---@return string|nil
local function VendorZoneName(vendor)
    local locs = vendor.locations
    if not locs then
        return nil
    end
    for _, loc in pairs(locs) do
        local zone = CleanWhereName(loc.zone)
        if zone then
            return zone
        end
    end
    return nil
end

---@param drop table
---@return string|nil left
---@return string|nil right
local function DropRowLabels(drop)
    local kind = DropKind(drop)
    if kind == "rare" or kind == "worldBoss" then
        return DropZoneName(drop), CleanWhereName(drop.encounterName)
    end
    local inst = CleanWhereName(drop.instanceName)
    if inst or kind then
        return inst, CleanWhereName(drop.encounterName)
    end
    return nil, nil
end

---@param lines table
---@param seeCatalog string
---@param drops table
local function AppendDropSourceLines(lines, seeCatalog, drops)
    local rows = {}
    local seen = {}
    for i = 1, #drops do
        local left, right = DropRowLabels(drops[i])
        if left then
            local key = left .. "\0" .. (right or "")
            if not seen[key] then
                seen[key] = true
                tinsert(rows, { left = left, right = right })
            end
        end
    end
    AppendCappedCategory(lines, BATTLE_PET_SOURCE_1, rows, 0.7, 0.9, 0.7, seeCatalog)
end

---@param lines table
---@param seeCatalog string
---@param vendors table
local function AppendVendorLines(lines, seeCatalog, vendors)
    local rows = {}
    local seen = {}
    for i = 1, #vendors do
        local name = CleanWhereName(vendors[i].name)
        if name and not seen[name] then
            seen[name] = true
            tinsert(rows, { left = name, right = VendorZoneName(vendors[i]) })
        end
    end
    sort(rows, function(a, b)
        return a.left < b.left
    end)
    AppendCappedCategory(lines, BATTLE_PET_SOURCE_3, rows, 0.9, 0.8, 0.5, seeCatalog)
end

---@param lines table
---@param seeCatalog string
---@param questAPI table
---@param questIDs table
local function AppendQuestLines(lines, seeCatalog, questAPI, questIDs)
    local unique = {}
    local order = {}
    for i = 1, #questIDs do
        local id = tonumber(questIDs[i])
        if id and not unique[id] then
            unique[id] = true
            tinsert(order, id)
        end
    end
    sort(order)
    local rows = {}
    for i = 1, #order do
        local id = order[i]
        local name = CleanWhereName(questAPI.GetQuestName(id))
        tinsert(rows, {
            left = name or "",
            right = format("QuestID:[%d]", id),
        })
    end
    AppendCappedCategory(lines, BATTLE_PET_SOURCE_2, rows, 0.9, 0.85, 0.5, seeCatalog)
end

---@param lines table
---@param seeCatalog string
---@param achIDs table
local function AppendAchievementLines(lines, seeCatalog, achIDs)
    local unique = {}
    local order = {}
    for i = 1, #achIDs do
        local id = tonumber(achIDs[i])
        if id and not unique[id] then
            unique[id] = true
            tinsert(order, id)
        end
    end
    sort(order)
    local rows = {}
    for i = 1, #order do
        local id = order[i]
        local name = CleanWhereName(select(2, GetAchievementInfo(id)))
        tinsert(rows, {
            left = name or "",
            right = format("AchievementID:[%d]", id),
        })
    end
    AppendCappedCategory(lines, BATTLE_PET_SOURCE_6, rows, 0.9, 0.8, 0.4, seeCatalog)
end

---@param lines table
---@param seeCatalog string
---@param crafts table
local function AppendCraftLines(lines, seeCatalog, crafts)
    local rows = {}
    local seen = {}
    for i = 1, #crafts do
        local name = CleanWhereName(crafts[i].name)
        if name and not seen[name] then
            seen[name] = true
            tinsert(rows, { left = name, right = "" })
        end
    end
    AppendCappedCategory(lines, BATTLE_PET_SOURCE_4, rows, 0.7, 0.8, 1.0, seeCatalog)
end

local function GetClassColor(class)
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    return 0.9, 0.9, 0.9
end

ns.GetClassColor = GetClassColor

-- Aggregate a flat family-location list into one row per (owner, location[, rank])
-- bucket. Owner is the character (by charKey), the warband, or a guild bank.
--
-- When `groupByRank` is true, each rank becomes its own row (Shift breakdown).
-- When false, all ranks for a given (owner, location) collapse into one row
-- whose count is the sum across the whole item family.
--
-- Honors cfg.showBags / showBank / showEquipped / showAuctions / showWarbandBank /
-- showGuildBanks toggles. Entries whose locationType is filtered out are dropped.
local function AggregateFamilyRows(locations, cfg, L, groupByRank)
    local showBags     = cfg == nil or cfg.showBags        ~= false
    local showBank     = cfg == nil or cfg.showBank        ~= false
    local showEquipped = cfg == nil or cfg.showEquipped    ~= false
    local showAuctions = cfg == nil or cfg.showAuctions    ~= false
    local showWarband  = cfg == nil or cfg.showWarbandBank ~= false
    local showGuilds   = cfg == nil or cfg.showGuildBanks  ~= false

    local locLabels = {
        bags     = L["TIPS_ITEMTRACKER_BAGS"],
        bank     = L["TIPS_ITEMTRACKER_BANK"],
        equipped = L["TIPS_ITEMTRACKER_EQUIPPED"],
        auction  = L["TIPS_ITEMTRACKER_AUCTION"],
        warband  = L["TIPS_ITEMTRACKER_BANK"],
        guild    = L["TIPS_ITEMTRACKER_BANK"],
    }

    local buckets = {}
    local order   = {}

    local function bucket(key, ownerName, ownerKind, class, locationType, rank, charKey)
        local b = buckets[key]
        if not b then
            b = {
                ownerName    = ownerName,
                ownerKind    = ownerKind,    -- "char" | "warband" | "guild"
                class        = class,
                charKey      = charKey,
                locationType = locationType,
                rank         = rank,
                count        = 0,
            }
            buckets[key] = b
            table.insert(order, key)
        end
        return b
    end

    for _, loc in ipairs(locations) do
        local locType = loc.locationType
        local allowed =
            (locType == "bags"     and showBags)     or
            (locType == "bank"     and showBank)     or
            (locType == "equipped" and showEquipped) or
            (locType == "auction"  and showAuctions) or
            (locType == "warband"  and showWarband)  or
            (locType == "guild"    and showGuilds)

        if allowed then
            -- In ranked mode, drop entries that have no decoded rank (we don't
            -- want bogus "R?" rows). In total mode, all family entries count.
            local rankSlot
            if groupByRank then
                if not loc.rank then
                    allowed = false
                else
                    rankSlot = loc.rank
                end
            end

            if allowed then
                if locType == "warband" then
                    local key = "WARBAND|" .. (rankSlot or "_")
                    local b = bucket(key, L["TIPS_ITEMTRACKER_WARBAND"], "warband", nil, locType, rankSlot)
                    b.count = b.count + (loc.count or 0)
                elseif locType == "guild" then
                    local gn = loc.guildName or GUILD
                    local key = "GUILD|" .. gn .. "|" .. (rankSlot or "_")
                    local b = bucket(key, gn, "guild", nil, locType, rankSlot)
                    b.count = b.count + (loc.count or 0)
                elseif loc.charKey then
                    local key = loc.charKey .. "|" .. locType .. "|" .. (rankSlot or "_")
                    local b = bucket(key, loc.name or loc.charKey, "char", loc.class, locType, rankSlot, loc.charKey)
                    b.count = b.count + (loc.count or 0)
                end
            end
        end
    end

    -- Display order: chars first (alpha), then warband, then guilds.
    -- Within an owner: location asc, then rank asc.
    table.sort(order, function(a, b)
        local ea, eb = buckets[a], buckets[b]
        local kindOrder = { char = 1, warband = 2, guild = 3 }
        local ka, kb = kindOrder[ea.ownerKind] or 9, kindOrder[eb.ownerKind] or 9
        if ka ~= kb then return ka < kb end
        if (ea.ownerName or "") ~= (eb.ownerName or "") then
            return (ea.ownerName or "") < (eb.ownerName or "")
        end
        if (ea.locationType or "") ~= (eb.locationType or "") then
            return (ea.locationType or "") < (eb.locationType or "")
        end
        return (ea.rank or 0) < (eb.rank or 0)
    end)

    local rows  = {}
    local total = 0
    for _, key in ipairs(order) do
        local b = buckets[key]
        total = total + b.count
        table.insert(rows, {
            ownerName    = b.ownerName,
            ownerKind    = b.ownerKind,
            class        = b.class,
            charKey      = b.charKey,
            locationType = b.locationType,
            label        = locLabels[b.locationType] or b.locationType,
            rank         = b.rank,
            count        = b.count,
        })
    end

    return rows, total
end

-- Render one tracker row to a tooltip line of the shape:
--   "  OwnerName       Loc xN"      (groupByRank = false)
--   "  OwnerName       Loc R# xN"   (groupByRank = true)
-- Warband / guild owners get the matching atlas icon prefixed.
local function FormatTrackerRow(row, colorByClass)
    local right = row.label
    if row.rank then
        right = right .. "  R" .. row.rank
    end
    right = right .. " x" .. row.count

    if row.ownerKind == "char" then
        local r, g, b = 0.9, 0.9, 0.9
        if colorByClass and row.class then r, g, b = GetClassColor(row.class) end
        return {
            type  = "double",
            left  = "  " .. row.ownerName,
            right = right,
            lr = r,   lg = g,   lb = b,
            rr = 1.0, rg = 1.0, rb = 1.0,
        }
    elseif row.ownerKind == "warband" then
        local icon = CreateAtlasMarkup("warband-icon", 16, 16)
        return {
            type  = "double",
            left  = "  " .. icon .. " " .. row.ownerName,
            right = right,
            lr = 0.7, lg = 0.7, lb = 0.7,
            rr = 1.0, rg = 1.0, rb = 1.0,
        }
    elseif row.ownerKind == "guild" then
        local icon = CreateAtlasMarkup("communities-icon-guild", 16, 16)
        return {
            type  = "double",
            left  = "  " .. icon .. " " .. row.ownerName,
            right = right,
            lr = 0.7, lg = 0.7, lb = 0.7,
            rr = 1.0, rg = 1.0, rb = 1.0,
        }
    end
end

local function ItemTrackerProvider(_, context)
    if not context.itemID then return nil end

    local L   = ns.L
    local cfg = OneWoW.SettingsFeatureRegistry:GetFeatureSettings("tooltips", "itemtracker")

    local showAlts      = cfg.showAlts      ~= false
    local showVendors   = cfg.showVendors   ~= false
    local showInstances = cfg.showInstances ~= false
    local showQuests    = cfg.showQuests    ~= false
    local showCrafted   = cfg.showCrafted   ~= false
    local altScope      = cfg.altScope

    local maxChars     = cfg.characterLimit
    local colorByClass = cfg.colorByClass ~= false

    local lines = {}

    -- The "item family" = hovered itemID + all sibling rank itemIDs of the same
    -- crafted item. Tooltip behavior is identical regardless of which rank is
    -- hovered; Shift switches between family-totals and per-rank breakdown.
    local idx        = GetItemIndex()
    local familyLocs = idx and idx:GetFamilyLocations(context.itemID) or nil

    if familyLocs then
        -- Count distinct decoded ranks across the family. The Shift breakdown
        -- only makes sense when ≥ 2 ranks exist; otherwise the hint is hidden.
        local rankSet = {}
        for _, loc in ipairs(familyLocs) do
            if loc.rank then rankSet[loc.rank] = true end
        end
        local distinctRanks = 0
        for _ in pairs(rankSet) do distinctRanks = distinctRanks + 1 end
        local hasMultipleRanks = distinctRanks > 1
        local shiftExpand      = hasMultipleRanks and IsShiftKeyDown()

        local rows, total = AggregateFamilyRows(familyLocs, cfg, L, shiftExpand)

        if rows and #rows > 0 then
            table.insert(lines, {
                type  = "double",
                left  = "  " .. L["TIPS_ITEMTRACKER_WHERE_IS"],
                right = string.format(L["TIPS_ITEMTRACKER_TOTAL"], total),
                lr = 0.4, lg = 0.8, lb = 1.0,
                rr = 1.0, rg = 1.0, rb = 1.0,
            })

            local shownChars     = {}
            local shownCharCount = 0
            local capped         = false
            for _, row in ipairs(rows) do
                if row.ownerKind == "char" then
                    if showAlts and OneWoW.AltScope:IsCharIncluded(row.charKey, altScope) then
                        if not shownChars[row.ownerName] then
                            if shownCharCount >= maxChars then
                                capped = true
                                break
                            end
                            shownChars[row.ownerName] = true
                            shownCharCount = shownCharCount + 1
                        end
                        table.insert(lines, FormatTrackerRow(row, colorByClass))
                    end
                else
                    table.insert(lines, FormatTrackerRow(row, colorByClass))
                end
            end

            if capped then
                table.insert(lines, { type = "text", text = "  ...", r = 0.7, g = 0.7, b = 0.7 })
            end

            if hasMultipleRanks and not shiftExpand then
                table.insert(lines, {
                    type = "text",
                    text = "  " .. L["TIPS_ITEMTRACKER_HOLD_SHIFT"],
                    r = 0.5, g = 0.5, b = 0.5,
                })
            end
        end
    end

    local sourceStart = #lines
    local seeCatalog = L["TIPS_ITEMTRACKER_SEE_CATALOG"]

    if showVendors then
        local vendors = GetVendorData(context.itemID)
        if vendors and #vendors > 0 then
            AppendVendorLines(lines, seeCatalog, vendors)
        end
    end

    if showQuests then
        local questAPI = OneWoW:GetCatalogPackAPI("quests")
        local questIDs = questAPI and questAPI.GetQuestsRewardingItem(context.itemID, false)
        if questIDs and #questIDs > 0 then
            AppendQuestLines(lines, seeCatalog, questAPI, questIDs)
        end
    end

    if showInstances then
        local instEntries = GetInstanceData(context.itemID)
        if instEntries and #instEntries > 0 then
            AppendDropSourceLines(lines, seeCatalog, instEntries)
        end
        local achIDs = GetAchievementIDs(context.itemID)
        if #achIDs > 0 then
            AppendAchievementLines(lines, seeCatalog, achIDs)
        end
    end

    if showCrafted then
        local crafts = GetCraftData(context.itemID)
        if #crafts > 0 then
            AppendCraftLines(lines, seeCatalog, crafts)
        end
    end

    if #lines > sourceStart then
        tinsert(lines, sourceStart + 1, {
            type = "text",
            text = "  " .. L["TIPS_ITEMTRACKER_WHERE_TO_GET"],
            r = 0.4, g = 0.8, b = 1.0,
        })
    elseif showVendors or showQuests or showInstances or showCrafted then
        local roles = {}
        if showVendors then
            tinsert(roles, "vendors")
        end
        if showQuests then
            tinsert(roles, "quests")
        end
        if showInstances then
            tinsert(roles, "journal")
        end
        if showCrafted then
            tinsert(roles, "tradeskills")
        end
        local notice = OneWoW:GetCatalogUnavailableNotice(roles)
        if notice then
            tinsert(lines, {
                type = "text",
                text = "  " .. L["TIPS_ITEMTRACKER_WHERE_TO_GET"],
                r = 0.4, g = 0.8, b = 1.0,
            })
            tinsert(lines, {
                type = "text",
                text = "  " .. notice,
                r = 1.0, g = 0.75, b = 0.3,
            })
        end
    end

    if #lines == 0 then return nil end

    return lines
end

OneWoW.TooltipEngine:RegisterProvider({
    id           = "itemtracker",
    order        = 20,
    featureId    = "itemtracker",
    tooltipTypes = {"item"},
    callback     = ItemTrackerProvider,
})

-- Re-run the tooltip data pipeline whenever Shift state changes while a
-- non-action-bar item tooltip is up. RefreshDataNextUpdate() re-fires every
-- TooltipDataProcessor postcall on the tooltip's next OnUpdate (Blizzard's
-- deferred path), including ours, so the provider can rebuild its lines with
-- the new shift state and produce the compact / expanded view.
--
-- Direct RefreshData() from addon code is unsafe: action-bar tooltips (GetAction)
-- and lines with secret unitToken values error when rebuilt from tainted code.
-- Shift-for-drag off the locked action bar fires MODIFIER_STATE_CHANGED and
-- must be ignored here.
local function RequestItemTrackerTooltipRefresh(tooltip)
    if not tooltip or not tooltip:IsShown() or not tooltip.RefreshDataNextUpdate then
        return
    end

    local data = tooltip.GetPrimaryTooltipData and tooltip:GetPrimaryTooltipData()
    if not data or data.type ~= Enum.TooltipDataType.Item then return end
    if OneWoW.Restriction.IsSecret(data.type) then return end

    local info = tooltip.GetPrimaryTooltipInfo and tooltip:GetPrimaryTooltipInfo()
    if info and info.getterName == "GetAction" then return end

    if GetCursorInfo() then return end

    tooltip:RefreshDataNextUpdate()
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("MODIFIER_STATE_CHANGED")
    f:SetScript("OnEvent", function(_, _, key)
        if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
        if OneWoW.Restriction.IsInCombat() then return end
        if not OneWoW.TooltipEngine:IsFeatureEnabled("itemtracker") then return end

        RequestItemTrackerTooltipRefresh(GameTooltip)
        RequestItemTrackerTooltipRefresh(ItemRefTooltip)
    end)
end
