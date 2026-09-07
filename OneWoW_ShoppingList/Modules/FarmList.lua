local _, ns = ...
local L = ns.L

-- ============================================================================
-- FarmList
-- ============================================================================
-- One account-wide farming list, stored at ns.db.global.farmList.items[itemID].
-- style is kept as "farming" for CompSync compat; the UI does not split Wanted
-- vs Farming. Owned counts reuse DataAccess with searchAlts so "anywhere"
-- matches Shopping List alt/warband scanning. Catalog sources and buy-instead
-- vendor lines read pack APIs only when that pack is already loaded -- never
-- EnsureCatalogPack.
-- ============================================================================

ns.FarmList = {}
local FarmList = ns.FarmList

local STYLE_FARMING = "farming"
local QTY_MIN = 1
local QTY_MAX = 9999
local SOURCE_LINE_CAP = 4
local KIND_RANK = {
    instance = 1,
    vendor = 2,
    quest = 3,
    profession = 4,
    other = 5,
}

local function GetItems()
    return ns.db.global.farmList.items
end

local function ScheduleRefresh()
    if ns.ShoppingList and ns.ShoppingList.RequestRefresh then
        ns.ShoppingList:RequestRefresh()
    end
end

local function ClampQuantity(qty)
    qty = tonumber(qty) or 1
    if qty < QTY_MIN then qty = QTY_MIN end
    if qty > QTY_MAX then qty = QTY_MAX end
    return qty
end

--- Best catalog place label when the row has no stored instance_name.
---@param itemID number
---@return string|nil title
---@return string kind
local function InferPlace(itemID)
    local journal = OneWoW:GetCatalogPackAPI("journal")
    if journal then
        local drops = journal.GetItemDropLocations(itemID) or {}
        local drop = drops[1]
        if drop and drop.instanceName and drop.instanceName ~= "" then
            return drop.instanceName, "instance"
        end
    end
    local vendorsAPI = OneWoW:GetCatalogPackAPI("vendors")
    if vendorsAPI then
        local vendors = vendorsAPI.GetVendorsByItem(itemID) or {}
        local vendor = vendors[1]
        if vendor and vendor.name and vendor.name ~= "" then
            return vendor.name, "vendor"
        end
    end
    local questAPI = OneWoW:GetCatalogPackAPI("quests")
    if questAPI then
        local ids = questAPI.GetQuestsRewardingItem(itemID)
        if ids and ids[1] then
            local name = questAPI.GetQuestName(ids[1])
            if name and name ~= "" then
                return name, "quest"
            end
        end
    end
    local tsAPI = OneWoW:GetCatalogPackAPI("tradeskills")
    if tsAPI then
        local recipes = tsAPI.GetRecipesByItem(itemID) or {}
        local recipe = recipes[1]
        if recipe then
            local label = recipe.prof or tsAPI.GetRecipeProfession(recipe.id)
            if label and label ~= "" then
                return label, "profession"
            end
        end
    end
    return nil, "other"
end

local function ResolveName(itemID, stored)
    local name = C_Item.GetItemNameByID(itemID)
    if name and name ~= "" then
        return name
    end
    C_Item.RequestLoadItemDataByID(itemID)
    if stored and stored ~= "" then
        return stored
    end
    return string.format(L["OWSL_ITEM_PREFIX"], itemID)
end

function FarmList:Initialize()
    self.initialized = true
end

--- Canonical farm row for itemID, or nil.
---@param itemID number|string
---@return table|nil
function FarmList:GetItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    return GetItems()[itemID]
end

--- True when itemID is on the account farm list.
---@param itemID number|string
---@return boolean
---@return string|nil style
function FarmList:IsOnFarmList(itemID)
    local row = self:GetItem(itemID)
    if not row then return false end
    return true, row.style
end

--- Add or update a farm row. extras.mergeQuantity adds onto an existing qty.
---@param itemID number|string
---@param style string|nil
---@param extras table|nil
---@return boolean
function FarmList:AddItem(itemID, style, extras)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then
        return false, L["OWSL_INVALID_ITEM"]
    end
    extras = extras or {}
    style = STYLE_FARMING
    local now = GetServerTime()
    local instanceName = extras.instance_name or ""
    if instanceName == "" then
        local inferred = InferPlace(itemID)
        if inferred then
            instanceName = inferred
        end
    end
    local items = GetItems()
    local existing = items[itemID]
    if existing then
        existing.style = style
        existing.modified = now
        if extras.name and extras.name ~= "" then
            existing.name = extras.name
        else
            existing.name = ResolveName(itemID, existing.name)
        end
        if extras.mergeQuantity then
            existing.quantity = ClampQuantity((existing.quantity or 1) + (extras.quantity or 1))
        elseif extras.quantity then
            existing.quantity = ClampQuantity(extras.quantity)
        end
        if extras.notes ~= nil then
            existing.notes = extras.notes
        end
        if extras.instance_name and extras.instance_name ~= "" then
            existing.instance_name = extras.instance_name
        elseif instanceName ~= "" and (not existing.instance_name or existing.instance_name == "") then
            existing.instance_name = instanceName
        end
        if extras.encounter and extras.encounter ~= "" then
            existing.encounter = extras.encounter
        end
        if extras.instance then
            existing.instance = tonumber(extras.instance) or existing.instance or 0
        end
        if extras.tier then
            existing.tier = tonumber(extras.tier) or existing.tier or 0
        end
        ScheduleRefresh()
        return true
    end

    items[itemID] = {
        itemID        = itemID,
        name          = extras.name and extras.name ~= "" and extras.name or ResolveName(itemID),
        quantity      = ClampQuantity(extras.quantity or 1),
        style         = style,
        notes         = extras.notes or "",
        instance_name = instanceName,
        encounter     = extras.encounter or "",
        instance      = tonumber(extras.instance) or 0,
        tier          = tonumber(extras.tier) or 0,
        added         = now,
        modified      = now,
    }
    ScheduleRefresh()
    return true
end

---@param itemID number|string
---@return boolean
function FarmList:RemoveItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then return false, L["OWSL_INVALID_ITEM"] end
    local items = GetItems()
    if not items[itemID] then return false, L["OWSL_LIST_NOT_FOUND"] end
    items[itemID] = nil
    ScheduleRefresh()
    return true
end

---@param itemID number|string
---@param style string
---@return boolean
function FarmList:SetStyle(itemID, style)
    local row = self:GetItem(itemID)
    if not row then return false, L["OWSL_LIST_NOT_FOUND"] end
    row.style = STYLE_FARMING
    row.modified = GetServerTime()
    ScheduleRefresh()
    return true
end

---@param itemID number|string
---@param quantity number
---@return boolean
function FarmList:SetQuantity(itemID, quantity)
    local row = self:GetItem(itemID)
    if not row then return false, L["OWSL_LIST_NOT_FOUND"] end
    row.quantity = ClampQuantity(quantity)
    row.modified = GetServerTime()
    ScheduleRefresh()
    return true
end

---@param itemID number|string
---@param notes string|nil
---@return boolean
function FarmList:SetNotes(itemID, notes)
    local row = self:GetItem(itemID)
    if not row then return false, L["OWSL_LIST_NOT_FOUND"] end
    row.notes = notes or ""
    row.modified = GetServerTime()
    ScheduleRefresh()
    return true
end

--- Copy farm quantity onto a named shopping list (keeps the farm row).
---@param itemID number|string
---@param listName string
---@return boolean
function FarmList:SendToShoppingList(itemID, listName)
    local row = self:GetItem(itemID)
    if not row then return false, L["OWSL_LIST_NOT_FOUND"] end
    if not listName or listName == "" then
        return false, L["OWSL_LIST_NOT_FOUND"]
    end
    return ns.ShoppingList:AddItemToList(listName, row.itemID, row.quantity, row.notes)
end

--- Copy a shopping-list item onto the farm list (keeps the shop row).
---@param itemID number|string
---@param listName string
---@param style string|nil
---@return boolean
function FarmList:AddFromShoppingList(itemID, listName, style)
    itemID = tonumber(itemID)
    if not itemID then return false, L["OWSL_INVALID_ITEM"] end
    local list = ns.ShoppingList:GetList(listName)
    local shopRow = list and list.items and list.items[itemID]
    local qty = shopRow and shopRow.quantity or 1
    local notes = shopRow and shopRow.notes or ""
    return self:AddItem(itemID, style, {
        quantity = qty,
        notes = notes,
        mergeQuantity = true,
    })
end

local function SortByName(a, b)
    return (a.name or "") < (b.name or "")
end

local function CopyRow(itemID, row)
    local copy = {
        itemID        = itemID,
        name          = ResolveName(itemID, row.name),
        quantity      = row.quantity or 1,
        style         = STYLE_FARMING,
        notes         = row.notes or "",
        instance_name = row.instance_name or "",
        encounter     = row.encounter or "",
        instance      = row.instance or 0,
        tier          = row.tier or 0,
        added         = row.added or 0,
        modified      = row.modified or 0,
    }
    row.name = copy.name
    return copy
end

--- All farm rows, name-sorted, with live display names.
---@return table[]
function FarmList:GetAll()
    local items = {}
    for itemID, row in pairs(GetItems()) do
        items[#items + 1] = CopyRow(itemID, row)
    end
    sort(items, SortByName)
    return items
end

--- Farm rows grouped by catalog place (instance, vendor, quest, profession).
---@return { key: string, title: string, kind: string, items: table[] }[]
function FarmList:GetPlaceGroups()
    local groupsByKey = {}
    local order = {}
    for itemID, row in pairs(GetItems()) do
        local copy = CopyRow(itemID, row)
        local title = copy.instance_name
        local kind = "instance"
        if title == "" then
            title, kind = InferPlace(itemID)
            if not title or title == "" then
                title = L["OWSL_FARM_NO_PLACE"]
                kind = "other"
            end
        end
        local key = kind .. ":" .. title
        local group = groupsByKey[key]
        if not group then
            group = { key = key, title = title, kind = kind, items = {} }
            groupsByKey[key] = group
            order[#order + 1] = group
        end
        group.items[#group.items + 1] = copy
    end
    for i = 1, #order do
        sort(order[i].items, SortByName)
    end
    sort(order, function(a, b)
        local ra = KIND_RANK[a.kind] or 9
        local rb = KIND_RANK[b.kind] or 9
        if ra ~= rb then
            return ra < rb
        end
        return (a.title or "") < (b.title or "")
    end)
    return order
end

--- Vendor buy-instead notice when the vendors pack is already loaded.
---@param itemID number|string
---@return { hasVendor: boolean, vendorName: string }
function FarmList:GetBuyInstead(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return { hasVendor = false, vendorName = "" }
    end
    local vendorsAPI = OneWoW:GetCatalogPackAPI("vendors")
    if not vendorsAPI then
        return { hasVendor = false, vendorName = "" }
    end
    local vendors = vendorsAPI.GetVendorsByItem(itemID) or {}
    local vendor = vendors[1]
    local name = vendor and vendor.name or ""
    if name == "" then
        return { hasVendor = false, vendorName = "" }
    end
    return { hasVendor = true, vendorName = name }
end

--- Owned vs needed using DataAccess (alts + warband + guild when Storage is up).
---@param itemID number|string
---@return table|nil
function FarmList:GetItemStatus(itemID)
    local row = self:GetItem(itemID)
    if not row then return nil end

    local needed = row.quantity or 1
    local inventoryData = ns.DataAccess:GetItemInventoryData(itemID, { searchAlts = true })
    local owned    = inventoryData.owned    or 0
    local altOwned = inventoryData.altOwned or 0
    local total    = owned + altOwned

    local status, statusColor
    if total >= needed then
        if owned >= needed then
            status = "green";  statusColor = {0, 1, 0}
        else
            status = "blue";   statusColor = {0.3, 0.5, 1}
        end
    elseif total > 0 then
        status = "yellow"; statusColor = {1, 1, 0}
    else
        status = "red";    statusColor = {1, 0, 0}
    end

    return {
        needed      = needed,
        owned       = owned,
        altOwned    = altOwned,
        totalOwned  = total,
        status      = status,
        statusColor = statusColor,
        locations   = inventoryData.locations or {},
    }
end

local function AppendSourceGroup(out, header, lines)
    if #lines == 0 then return end
    out[#out + 1] = { header = header, lines = lines }
end

local function CapLines(lines)
    if #lines <= SOURCE_LINE_CAP then return lines end
    local capped = {}
    for i = 1, SOURCE_LINE_CAP do
        capped[i] = lines[i]
    end
    return capped
end

--- Catalog sources for the detail pane. Pack APIs only when already loaded.
---@param itemID number
---@return { header: string, lines: string[] }[]
function FarmList:GetCatalogSources(itemID)
    itemID = tonumber(itemID)
    if not itemID then return {} end

    local out = {}

    local journal = OneWoW:GetCatalogPackAPI("journal")
    if journal then
        local drops = journal.GetItemDropLocations(itemID) or {}
        local dropLines = {}
        local seen = {}
        for i = 1, #drops do
            local drop = drops[i]
            local inst = drop.instanceName
            local enc  = drop.encounterName
            local label
            if inst and inst ~= "" and enc and enc ~= "" then
                label = inst .. " - " .. enc
            else
                label = inst or enc
            end
            if label and label ~= "" and not seen[label] then
                seen[label] = true
                dropLines[#dropLines + 1] = label
            end
        end
        AppendSourceGroup(out, BATTLE_PET_SOURCE_1, CapLines(dropLines))

        local achIDs = journal.GetAchievementsForItem(itemID)
        if achIDs then
            local achLines = {}
            for i = 1, #achIDs do
                local name = select(2, GetAchievementInfo(achIDs[i]))
                if name and name ~= "" then
                    achLines[#achLines + 1] = name
                end
            end
            AppendSourceGroup(out, BATTLE_PET_SOURCE_6, CapLines(achLines))
        end
    end

    local vendorsAPI = OneWoW:GetCatalogPackAPI("vendors")
    if vendorsAPI then
        local vendors = vendorsAPI.GetVendorsByItem(itemID) or {}
        local vendorLines = {}
        local seen = {}
        for i = 1, #vendors do
            local vendor = vendors[i]
            local name = vendor.name
            if name and name ~= "" and not seen[name] then
                seen[name] = true
                local zone
                local locs = vendor.locations
                if type(locs) == "table" then
                    for _, loc in pairs(locs) do
                        if type(loc) == "table" and loc.zone and loc.zone ~= "" then
                            zone = loc.zone
                            break
                        end
                    end
                end
                if zone then
                    vendorLines[#vendorLines + 1] = name .. " - " .. zone
                else
                    vendorLines[#vendorLines + 1] = name
                end
            end
        end
        AppendSourceGroup(out, BATTLE_PET_SOURCE_3, CapLines(vendorLines))
    end

    local questAPI = OneWoW:GetCatalogPackAPI("quests")
    if questAPI then
        local ids = questAPI.GetQuestsRewardingItem(itemID)
        if ids then
            local questLines = {}
            for i = 1, #ids do
                local name = questAPI.GetQuestName(ids[i])
                if name and name ~= "" then
                    questLines[#questLines + 1] = name
                end
            end
            AppendSourceGroup(out, BATTLE_PET_SOURCE_2, CapLines(questLines))
        end
    end

    local tsAPI = OneWoW:GetCatalogPackAPI("tradeskills")
    if tsAPI then
        local recipes = tsAPI.GetRecipesByItem(itemID) or {}
        local craftLines = {}
        local seen = {}
        if recipes then
            for i = 1, #recipes do
                local recipe = recipes[i]
                local label = recipe.prof or tsAPI.GetRecipeProfession(recipe.id)
                if label and label ~= "" and not seen[label] then
                    seen[label] = true
                    craftLines[#craftLines + 1] = label
                end
            end
        end
        AppendSourceGroup(out, BATTLE_PET_SOURCE_4, CapLines(craftLines))
    end

    return out
end
