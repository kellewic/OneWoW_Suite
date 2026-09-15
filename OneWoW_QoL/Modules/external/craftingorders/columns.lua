local _, ns = ...
local M, L = ns.ModuleRegistry:Current()
if not M then return end

local OneWoW_GUI = OneWoW_GUI
local C_AddOns = C_AddOns
local CopyTable = CopyTable

-- ============================================================================
-- Column layout
-- ============================================================================
-- Player-owned overlay columns. Order name stays pinned left. Everything else
-- is a right-packed lane list: show, hide, reorder, resize. Bump
-- LAYOUT_REVISION when factory defaults change so existing preview layouts
-- pick them up once; later tweaks stay in the player's save.
-- ============================================================================

local SPACING = OneWoW_GUI.Constants.SPACING

local MAX_YOU = 4
local MAX_CUST = 4
local MAX_REWARDS = 4
local MAT_GAP = SPACING.XS
local COL_GAP = SPACING.SM
local COL_PAD = SPACING.SM
-- Compact "6 d 15 h 10 m" (DAY/HOUR/MINUTE_ONELETTER_ABBR); tooltip has full text.
local TIME_W = 108
local CART_W = 40
local GOLD_W = 100
local PROFIT_W = 100
-- Fits PROFESSIONS_COMPLETE_ORDER in every locale (e.g. "Terminer la commande").
local ACTION_W = 140
local DEFAULT_ROW_H = 64
-- ProfessionsCrafterOrderListElementTemplate Size y="20".
local TIGHT_ROW_H = 20
local SIZE_MIN = 16
local SIZE_MAX = 48
-- First id sits nearest the order name; last id sits on the right edge.
local LAYOUT_REVISION = 3
local COLUMN_IDS = { "you", "cart", "profit", "time", "action", "gold", "customer", "reward" }

local COLUMN_META = {
    you = { kind = "icons", sizeKey = "you", maxIcons = MAX_YOU, labelKey = "CRAFTORDERS_COL_YOU", justify = "LEFT" },
    cart = { kind = "cart", width = CART_W, labelKey = "CRAFTORDERS_COL_CART", justify = "CENTER" },
    customer = { kind = "icons", sizeKey = "customer", maxIcons = MAX_CUST, labelKey = "CRAFTORDERS_COL_CUSTOMER", justify = "LEFT" },
    reward = { kind = "icons", sizeKey = "reward", maxIcons = MAX_REWARDS, labelKey = "CRAFTORDERS_COL_REWARD", justify = "LEFT" },
    time = { kind = "text", width = TIME_W, labelKey = nil, justify = "RIGHT" },
    gold = { kind = "text", width = GOLD_W, labelKey = "CRAFTORDERS_COL_GOLD", justify = "RIGHT" },
    profit = { kind = "profit", width = PROFIT_W, labelKey = "CRAFTORDERS_COL_PROFIT", justify = "RIGHT" },
    action = { kind = "action", width = ACTION_W, labelKey = "CRAFTORDERS_COL_ACTION", justify = "CENTER" },
}

local DEFAULT_HIDDEN = { gold = true, customer = true, reward = true }
local DEFAULT_SIZES = { product = 27, you = 27, customer = 27, reward = 27 }
-- Player maximums per column. Layout shrinks toward WIDTH_MIN when the strip
-- does not fit beside the order name. Icon lanes still grow with the icon
-- cluster if that cluster is wider than the slider.
local WIDTH_KEYS = { "you", "cart", "profit", "time", "action", "gold", "customer", "reward" }
local DEFAULT_WIDTHS = {
    you = 50,
    cart = CART_W,
    profit = PROFIT_W,
    time = TIME_W,
    action = ACTION_W,
    gold = GOLD_W,
    customer = 50,
    reward = 50,
}
local WIDTH_MIN = {
    you = 32,
    cart = 24,
    profit = 56,
    time = 52,
    action = 72,
    gold = 56,
    customer = 32,
    reward = 32,
}
local WIDTH_MAX = {
    you = 200,
    cart = 64,
    profit = 160,
    time = 140,
    action = 200,
    gold = 160,
    customer = 200,
    reward = 200,
}

local function ClusterW(n, size)
    return n * (size + MAT_GAP) - MAT_GAP
end

local function CopyLayoutDefaults()
    return {
        revision = LAYOUT_REVISION,
        order = CopyTable(COLUMN_IDS),
        hidden = CopyTable(DEFAULT_HIDDEN),
        sizes = CopyTable(DEFAULT_SIZES),
        hideHaveMats = false,
        tight = true,
        hideScrollBar = false,
        priceSource = "onewow",
        widths = CopyTable(DEFAULT_WIDTHS),
    }
end

local function ClampSize(n)
    n = tonumber(n) or 27
    if n < SIZE_MIN then return SIZE_MIN end
    if n > SIZE_MAX then return SIZE_MAX end
    return math.floor(n + 0.5)
end

local function ClampWidth(id, n)
    local lo = WIDTH_MIN[id]
    local hi = WIDTH_MAX[id]
    n = tonumber(n) or DEFAULT_WIDTHS[id]
    if n < lo then return lo end
    if n > hi then return hi end
    return math.floor(n + 0.5)
end

local function KnownId(id)
    return COLUMN_META[id] ~= nil
end

--- Keep known ids, drop dupes, append any missing factory ids.
local function MergeOrder(savedOrder)
    local seen = {}
    local order = {}
    if type(savedOrder) == "table" then
        for i = 1, #savedOrder do
            local id = savedOrder[i]
            if KnownId(id) and not seen[id] then
                seen[id] = true
                order[#order + 1] = id
            end
        end
    end
    for i = 1, #COLUMN_IDS do
        local id = COLUMN_IDS[i]
        if not seen[id] then
            order[#order + 1] = id
        end
    end
    return order
end

local function MergeLayout(saved)
    local layout = CopyLayoutDefaults()
    if type(saved) ~= "table" or saved.revision ~= LAYOUT_REVISION then
        return layout
    end
    if type(saved.order) == "table" then
        layout.order = MergeOrder(saved.order)
    end
    if type(saved.hidden) == "table" then
        for i = 1, #COLUMN_IDS do
            local id = COLUMN_IDS[i]
            if saved.hidden[id] ~= nil then
                layout.hidden[id] = saved.hidden[id] == true
            end
        end
    end
    if type(saved.sizes) == "table" then
        for key in pairs(DEFAULT_SIZES) do
            if saved.sizes[key] ~= nil then
                layout.sizes[key] = ClampSize(saved.sizes[key])
            end
        end
    end
    if saved.hideHaveMats ~= nil then
        layout.hideHaveMats = saved.hideHaveMats == true
    end
    if saved.tight ~= nil then
        layout.tight = saved.tight == true
    end
    if saved.hideScrollBar ~= nil then
        layout.hideScrollBar = saved.hideScrollBar == true
    end
    if type(saved.priceSource) == "string" then
        layout.priceSource = saved.priceSource
    end
    if type(saved.widths) == "table" then
        for i = 1, #WIDTH_KEYS do
            local id = WIDTH_KEYS[i]
            if saved.widths[id] ~= nil then
                layout.widths[id] = ClampWidth(id, saved.widths[id])
            end
        end
    end
    return layout
end

local function InvalidateFit()
    M._fit = nil
end

function M:EnsureLayout()
    local bucket = ns.ModuleRegistry:GetModuleBucket("craftingorders")
    if type(bucket.layout) ~= "table" or M._layoutObj ~= bucket.layout then
        bucket.layout = MergeLayout(bucket.layout)
        M._layoutObj = bucket.layout
        InvalidateFit()
    end
    return bucket.layout
end

function M:GetLayout()
    return M:EnsureLayout()
end

function M:ResetLayout()
    local bucket = ns.ModuleRegistry:GetModuleBucket("craftingorders")
    bucket.layout = CopyLayoutDefaults()
    M._layoutObj = bucket.layout
    M:OnLayoutChanged(true)
end

function M:ColumnIds()
    return COLUMN_IDS
end

function M:ColumnMeta(id)
    return COLUMN_META[id]
end

function M:ColumnLabel(id)
    if id == "time" then
        return CLOSES_IN
    end
    local meta = COLUMN_META[id]
    if meta and meta.labelKey then
        return L[meta.labelKey]
    end
    return id
end

function M:IsColumnVisible(id)
    local layout = M:EnsureLayout()
    return layout.hidden[id] ~= true
end

function M:SetColumnHidden(id, hidden)
    if not KnownId(id) then return end
    local layout = M:EnsureLayout()
    layout.hidden[id] = hidden == true
    M:OnLayoutChanged()
end

function M:SetColumnOrder(order)
    local layout = M:EnsureLayout()
    layout.order = MergeOrder(order)
    M:OnLayoutChanged()
end

function M:SetIconSize(key, value)
    if not DEFAULT_SIZES[key] then return end
    local layout = M:EnsureLayout()
    local nextSize = ClampSize(value)
    if layout.sizes[key] == nextSize then
        return
    end
    layout.sizes[key] = nextSize
    M:OnLayoutChanged()
end

function M:SetHideHaveMats(hidden)
    local layout = M:EnsureLayout()
    layout.hideHaveMats = hidden == true
    M:OnLayoutChanged(true)
end

--- Compact View matches Blizzard's 20px order-row height.
---@return boolean
function M:IsTight()
    return M:EnsureLayout().tight == true
end

--- Compact View row height; icon sliders apply when this is off.
---@param tight boolean
function M:SetTight(tight)
    local layout = M:EnsureLayout()
    local nextTight = tight == true
    if layout.tight == nextTight then
        return
    end
    layout.tight = nextTight
    M:OnLayoutChanged()
end

function M:SetColumnWidth(id, value)
    if not WIDTH_MIN[id] then return end
    local layout = M:EnsureLayout()
    local nextW = ClampWidth(id, value)
    if layout.widths[id] == nextW then
        return
    end
    layout.widths[id] = nextW
    M:OnLayoutChanged()
end

function M:ColumnWidthRange(id)
    return WIDTH_MIN[id], WIDTH_MAX[id], DEFAULT_WIDTHS[id]
end

function M:ColumnWidthIds()
    return WIDTH_KEYS
end

function M:IsHideScrollBar()
    return M:EnsureLayout().hideScrollBar == true
end

function M:SetHideScrollBar(hidden)
    local layout = M:EnsureLayout()
    local nextHide = hidden == true
    if layout.hideScrollBar == nextHide then
        return
    end
    layout.hideScrollBar = nextHide
    M:OnLayoutChanged()
end

function M:SetPriceSource(source)
    local layout = M:EnsureLayout()
    layout.priceSource = source
    M:OnLayoutChanged()
end

function M:ClusterWidth(n, size)
    return ClusterW(n, size)
end

function M:LaneConstants()
    return {
        maxYou = MAX_YOU,
        maxCust = MAX_CUST,
        maxRewards = MAX_REWARDS,
        matGap = MAT_GAP,
        colGap = COL_GAP,
        colPad = COL_PAD,
        timeW = TIME_W,
        cartW = CART_W,
        goldW = GOLD_W,
        profitW = PROFIT_W,
        actionW = ACTION_W,
        defaultRowH = DEFAULT_ROW_H,
        tightRowH = TIGHT_ROW_H,
        sizeMin = SIZE_MIN,
        sizeMax = SIZE_MAX,
    }
end

local MIN_NAME_W = 140
-- Last-resort name width after icon and text lanes have already shrunk.
local NAME_FLOOR = 72
-- Keeps header labels readable when a lane holds a single small icon.
local LANE_MIN_W = 50
-- Order-cell chrome inside a row: product icon left inset + icon-to-name gap.
local NAME_LEFT_PAD = 4
local NAME_GAP = 6
local LANE_KEYS = { "you", "customer", "reward" }

--- Icon slots the current entry list actually uses, per lane (1..maxIcons).
--- The overlay reports them after each entry build; nil means no data yet
--- (reserve the full maxIcons). Returns true when widths need re-applying.
function M:SetLaneCounts(counts)
    local prev = M._laneCounts
    if counts == nil then
        M._laneCounts = nil
        if prev ~= nil then
            InvalidateFit()
        end
        return prev ~= nil
    end
    local next = {}
    local changed = prev == nil
    for i = 1, #LANE_KEYS do
        local key = LANE_KEYS[i]
        local n = counts[key] or 1
        if n < 1 then n = 1 end
        local cap = COLUMN_META[key].maxIcons
        if n > cap then n = cap end
        next[key] = n
        if prev and prev[key] ~= n then
            changed = true
        end
    end
    next.cart = counts.cart == true
    if prev and prev.cart ~= next.cart then
        changed = true
    end
    M._laneCounts = next
    if changed then
        InvalidateFit()
    end
    return changed
end

local function LaneWidth(id, sizes, widths, laneMin)
    local meta = COLUMN_META[id]
    if meta.kind == "icons" then
        local count = (M._laneCounts and M._laneCounts[id]) or meta.maxIcons
        local cluster = ClusterW(count, sizes[meta.sizeKey])
        local pref = (widths and widths[id]) or LANE_MIN_W
        -- Last-resort fit (laneMin 0): honor the shrunk slider even if icons clip.
        if laneMin == 0 then
            return pref
        end
        if cluster > pref then
            return cluster
        end
        return pref
    end
    -- No cart buttons in this list (Craftable now / public buckets): take no width.
    if id == "cart" and M._laneCounts and not M._laneCounts.cart then
        return 0
    end
    if widths and widths[id] then
        return widths[id]
    end
    return meta.width
end

local function LaneHeight(id, sizes)
    local meta = COLUMN_META[id]
    if meta.kind == "icons" then
        return sizes[meta.sizeKey]
    end
    local tight = M:EnsureLayout().tight == true
    if meta.kind == "cart" then
        return tight and SIZE_MIN or 20
    end
    if meta.kind == "action" then
        return tight and SIZE_MIN or 22
    end
    return 16
end

--- Overlay row interior width (overlay width minus list/scroll/row chrome).
--- The overlay owns the frame and reports it here; nil means unknown (no
--- clip budget until the first real measure).
function M:SetRowContentWidth(width)
    local next
    if width and width >= 100 then
        next = math.floor(width + 0.5)
    else
        next = nil
    end
    if M._rowContentW == next then
        return
    end
    M._rowContentW = next
    InvalidateFit()
end

local function PackWidth(layout, sizes, widths, laneMin)
    local total = COL_PAD
    for i = 1, #layout.order do
        local id = layout.order[i]
        if layout.hidden[id] ~= true then
            local w = LaneWidth(id, sizes, widths, laneMin)
            if w > 0 then
                total = total + w + COL_GAP
            end
        end
    end
    return total
end

local function StripFits(layout, sizes, widths, nameMin, laneMin, w)
    return PackWidth(layout, sizes, widths, laneMin)
        + NAME_LEFT_PAD + sizes.product + NAME_GAP + nameMin <= w
end

local SIZE_KEYS = { "product", "you", "customer", "reward" }

local function ScaledSizes(base, f)
    local sizes = {}
    for i = 1, #SIZE_KEYS do
        local key = SIZE_KEYS[i]
        local s = math.floor(base[key] * f)
        if s < SIZE_MIN then
            s = SIZE_MIN
        elseif s > base[key] then
            s = base[key]
        end
        sizes[key] = s
    end
    return sizes
end

local function TightSizes()
    return {
        product = SIZE_MIN,
        you = SIZE_MIN,
        customer = SIZE_MIN,
        reward = SIZE_MIN,
    }
end

local function CopySizes(src)
    local sizes = {}
    for i = 1, #SIZE_KEYS do
        local key = SIZE_KEYS[i]
        sizes[key] = src[key]
    end
    return sizes
end

local function CopyWidths(src)
    local widths = {}
    for i = 1, #WIDTH_KEYS do
        local id = WIDTH_KEYS[i]
        widths[id] = src[id]
    end
    return widths
end

local function ScaledWidths(base, f)
    local widths = {}
    for i = 1, #WIDTH_KEYS do
        local id = WIDTH_KEYS[i]
        local floorW = WIDTH_MIN[id]
        local s = math.floor(base[id] * f)
        if s < floorW then
            s = floorW
        elseif s > base[id] then
            s = base[id]
        end
        widths[id] = s
    end
    return widths
end

-- Fit every checked column on the row: slider values are maximums.
-- 1. Compact View caps icons at SIZE_MIN; otherwise scale icons toward SIZE_MIN.
-- 2. Scale every column width toward WIDTH_MIN.
-- 3. Drop the icon-lane header floor so a single small icon can go narrower.
-- 4. Let the order name shrink toward NAME_FLOOR.
-- The overlay clip host only trims the strip if it still overflows after that.
local function ComputeFit()
    local layout = M:EnsureLayout()
    local baseSizes = layout.sizes
    local baseWidths = layout.widths
    local sizes = layout.tight and TightSizes() or CopySizes(baseSizes)
    local widths = CopyWidths(baseWidths)
    local nameMin = MIN_NAME_W
    local laneMin = LANE_MIN_W
    local w = M._rowContentW

    local function fits()
        if not w then
            return true
        end
        return StripFits(layout, sizes, widths, nameMin, laneMin, w)
    end

    if fits() then
        return {
            sizes = layout.tight and sizes or baseSizes,
            widths = baseWidths,
            nameMin = nameMin,
            laneMin = laneMin,
        }
    end

    if not layout.tight then
        local lo, hi = 0, 1
        local best
        for _ = 1, 12 do
            local mid = (lo + hi) / 2
            local trial = ScaledSizes(baseSizes, mid)
            if StripFits(layout, trial, widths, nameMin, laneMin, w) then
                best = trial
                lo = mid
            else
                hi = mid
            end
        end
        sizes = best or ScaledSizes(baseSizes, 0)
        if fits() then
            return {
                sizes = sizes,
                widths = baseWidths,
                nameMin = nameMin,
                laneMin = laneMin,
            }
        end
    end

    local lo, hi = 0, 1
    local bestW
    for _ = 1, 12 do
        local mid = (lo + hi) / 2
        local trial = ScaledWidths(baseWidths, mid)
        if StripFits(layout, sizes, trial, nameMin, laneMin, w) then
            bestW = trial
            lo = mid
        else
            hi = mid
        end
    end
    widths = bestW or ScaledWidths(baseWidths, 0)
    if fits() then
        return {
            sizes = sizes,
            widths = widths,
            nameMin = nameMin,
            laneMin = laneMin,
        }
    end

    laneMin = 0
    if fits() then
        return {
            sizes = sizes,
            widths = widths,
            nameMin = nameMin,
            laneMin = laneMin,
        }
    end

    local used = PackWidth(layout, sizes, widths, laneMin)
        + NAME_LEFT_PAD + sizes.product + NAME_GAP
    nameMin = w - used
    if nameMin < NAME_FLOOR then
        nameMin = NAME_FLOOR
    end
    return {
        sizes = sizes,
        widths = widths,
        nameMin = nameMin,
        laneMin = laneMin,
    }
end

function M:GetFit()
    if M._fit then
        return M._fit
    end
    M._fit = ComputeFit()
    return M._fit
end

function M:IconSizes()
    return M:GetFit().sizes
end

--- Max width the right-packed column strip may occupy in a row before it
--- clips: row width minus the product icon and the fitted name minimum.
--- nil when the overlay width is not measured yet (no clipping).
function M:LaneStripBudget()
    local w = M._rowContentW
    if not w then
        return nil
    end
    local fit = M:GetFit()
    local budget = w - NAME_LEFT_PAD - fit.sizes.product - NAME_GAP - fit.nameMin
    if budget < 1 then
        budget = 1
    end
    return budget
end

function M:ColumnWidth(id)
    local fit = M:GetFit()
    return LaneWidth(id, fit.sizes, fit.widths, fit.laneMin)
end

function M:ColumnHeight(id)
    return LaneHeight(id, M:IconSizes())
end

function M:ComputeInsets()
    local layout = M:EnsureLayout()
    local fit = M:GetFit()
    local sizes = fit.sizes
    local right = COL_PAD
    local map = {}
    for i = #layout.order, 1, -1 do
        local id = layout.order[i]
        if layout.hidden[id] ~= true then
            local width = LaneWidth(id, sizes, fit.widths, fit.laneMin)
            if width > 0 then
                map[id] = {
                    right = right,
                    width = width,
                    height = LaneHeight(id, sizes),
                    justify = COLUMN_META[id].justify,
                }
                right = right + width + COL_GAP
            end
        end
    end
    map.orderRight = right
    return map
end

function M:RowHeight()
    local layout = M:EnsureLayout()
    if layout.tight then
        return TIGHT_ROW_H
    end
    local sizes = M:IconSizes()
    local h = DEFAULT_ROW_H
    local product = sizes.product + 16
    if product > h then
        h = product
    end
    for i = 1, #layout.order do
        local id = layout.order[i]
        if layout.hidden[id] ~= true then
            local laneH = LaneHeight(id, sizes) + 16
            if laneH > h then
                h = laneH
            end
        end
    end
    return h
end

local function AddonEnabled(name)
    if not C_AddOns.DoesAddOnExist(name) then
        return false
    end
    if C_AddOns.IsAddOnLoaded(name) then
        return true
    end
    return C_AddOns.GetAddOnEnableState(name) > Enum.AddOnEnableState.None
end

function M:IsPriceSourceAvailable(source)
    if source == "tsm" then
        return AddonEnabled("TradeSkillMaster")
    end
    if source == "auctionator" then
        return AddonEnabled("Auctionator")
    end
    return source == "onewow"
end

function M:DefaultPriceSource()
    if AddonEnabled("TradeSkillMaster") then
        return "tsm"
    end
    if AddonEnabled("Auctionator") then
        return "auctionator"
    end
    return "onewow"
end

function M:GetPriceSource()
    local src = M:EnsureLayout().priceSource
    if src and M:IsPriceSourceAvailable(src) then
        return src
    end
    return M:DefaultPriceSource()
end

--- TSM custom-price string from QoL Tooltips > Value (default dbmarket).
---@return string
function M:GetTSMPriceString()
    local cfg = OneWoW.ItemPrices:GetValueCfg()
    local s = cfg and cfg.tsmPriceString
    if type(s) == "string" and s ~= "" then
        return s
    end
    return "dbmarket"
end

--- Tip after Consortium Cut. Returns net, gross commission, cut.
---@param tip number|nil
---@param cut number|nil
---@return number net
---@return number gross
---@return number cut
function M:GetGoldReceived(tip, cut)
    tip = tip or 0
    cut = cut or 0
    local net = tip - cut
    if net < 0 then
        net = 0
    end
    return net, tip, cut
end

function M:DetectedPriceSources()
    local list = {}
    if AddonEnabled("TradeSkillMaster") then
        list[#list + 1] = "tsm"
    end
    if AddonEnabled("Auctionator") then
        list[#list + 1] = "auctionator"
    end
    list[#list + 1] = "onewow"
    return list
end

function M:PriceSourceIcon(source)
    if source == "tsm" then
        local icon = C_AddOns.GetAddOnMetadata("TradeSkillMaster", "IconTexture")
        if icon and icon ~= "" then
            return icon
        end
        return "Interface\\Icons\\INV_Misc_Coin_02"
    end
    if source == "auctionator" then
        local icon = C_AddOns.GetAddOnMetadata("Auctionator", "IconTexture")
        if icon and icon ~= "" then
            return icon
        end
        return "Interface\\Icons\\INV_Misc_Coin_01"
    end
    -- OneWoW's own brand icon, following the player's icon theme setting.
    return OneWoW_GUI:GetBrandIcon(OneWoW_GUI:GetSetting("minimap.theme"))
end

function M:PriceSourceLabel(source)
    local shared = OneWoW.Locale:GetTable("shared")
    if source == "tsm" then
        return shared["SHARED_AH_SOURCE_TSM"]
    end
    if source == "auctionator" then
        return shared["SHARED_AH_SOURCE_AUCTIONATOR"]
    end
    return shared["SHARED_AH_SOURCE_ONEWOW"]
end

function M:FilterYouReagents(list)
    if not M:EnsureLayout().hideHaveMats then
        return list
    end
    local out = {}
    if not list then
        return out
    end
    for i = 1, #list do
        local row = list[i]
        if row.short and row.short > 0 then
            out[#out + 1] = row
        end
    end
    return out
end

local function ResolveItemName(itemID, itemLink)
    if itemLink then
        local name = C_Item.GetItemInfo(itemLink)
        if name then
            return name
        end
    end
    if itemID then
        local name = C_Item.GetItemNameByID(itemID)
        if name then
            return name
        end
    end
    return UNKNOWN
end

--- Gold, priced rewards, and priced You Provide mats that make Profit / Loss.
--- Unpriced items stay in rewards/mats with copper nil so the tooltip can list them.
---@param entry table|nil
---@return table|nil breakdown
function M:ComputeOrderProfitBreakdown(entry)
    if not entry or entry.kind == "header" then
        return nil
    end
    local source = M:GetPriceSource()
    local prices = OneWoW.ItemPrices
    local net, gross, cut = M:GetGoldReceived(entry.gold, entry.consortiumCut)
    local profit = net
    local rewardsOut = {}
    local matsOut = {}
    local raw = entry.raw
    local rewards = raw and raw.npcOrderRewards
    if rewards then
        for i = 1, #rewards do
            local reward = rewards[i]
            if reward.itemLink or reward.itemID then
                local itemID = reward.itemID
                if not itemID and reward.itemLink then
                    itemID = C_Item.GetItemInfoInstant(reward.itemLink)
                end
                local count = reward.count or 1
                local price = prices:GetUnitAHPriceFrom(source, itemID, reward.itemLink)
                if price then
                    profit = profit + price * count
                end
                rewardsOut[#rewardsOut + 1] = {
                    name = ResolveItemName(itemID, reward.itemLink),
                    count = count,
                    copper = price,
                }
            end
        end
    end
    local you = entry.youReagents
    if you then
        for i = 1, #you do
            local mat = you[i]
            if mat.itemID then
                local link = mat.itemLink or ("item:" .. mat.itemID)
                local need = mat.need or 1
                local price = prices:GetUnitAHPriceFrom(source, mat.itemID, link)
                if price then
                    profit = profit - price * need
                end
                matsOut[#matsOut + 1] = {
                    name = ResolveItemName(mat.itemID, mat.itemLink),
                    count = need,
                    copper = price,
                }
            end
        end
    end
    return {
        profit = profit,
        net = net,
        gross = gross,
        cut = cut,
        source = source,
        rewards = rewardsOut,
        mats = matsOut,
    }
end

---@param entry table|nil
---@return number|nil profit
function M:ComputeOrderProfit(entry)
    local breakdown = M:ComputeOrderProfitBreakdown(entry)
    return breakdown and breakdown.profit
end

--- Geometry changes (sizes, hidden, order) re-apply in place: icons SetSize,
--- lanes re-anchor, the virtualizer refreshes row heights. entriesChanged is
--- for settings that alter the entry list itself (hideHaveMats), which also
--- re-derives lane counts.
function M:OnLayoutChanged(entriesChanged)
    InvalidateFit()
    if entriesChanged and M:WantsOverlay() then
        M:RefreshOverlay()
    end
    M:ApplyOverlayLayout()
end
