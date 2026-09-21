local _, ns = ...
local M, L = ns.ModuleRegistry:Current()
if not M then return end

local OneWoW_GUI = OneWoW_GUI
local Restriction = OneWoW.Restriction

local CreateFrame = CreateFrame
local floor = math.floor

local SPACING = OneWoW_GUI.Constants.SPACING

local HEADER_H = 24
local STATUS_H = 20
local COL_H = 32
local ROW_INSET = 4
-- Must match OneWoW_GUI:CreateVirtualizer owned-scroll insets (4 / 14).
-- Right inset drops to 4 when the bar is hidden (option, or nothing to scroll).
local VIRT_LEFT = 4
local VIRT_RIGHT_BAR = 14
local VIRT_RIGHT_CLEAR = 4
local LIST_LEFT = 2
local LIST_RIGHT = 4
local HEADER_LEFT = LIST_LEFT + VIRT_LEFT + ROW_INSET

-- nil until the first measure: reserve the bar gutter so columns do not
-- jump wider, then narrower, when the list first fills.
local function OverlayVirtRight()
    if M._scrollBarShown == false then
        return VIRT_RIGHT_CLEAR
    end
    return VIRT_RIGHT_BAR
end

local function OverlayChromeRight()
    return LIST_RIGHT + OverlayVirtRight() + ROW_INSET
end
-- Profit header: punctuation-only, identical in every locale. The localized
-- "Profit / Loss" name still shows in the Features panel. The price-source
-- icon is embedded in the string (|T markup) so it always renders directly
-- after the text and updates with the label on every layout pass.
local PROFIT_HEADER = "+ / - |T%s:0|t"

local function PlaceColLabel(host, parent, rightInset, width, justifyH)
    host:ClearAllPoints()
    -- TOPRIGHT/BOTTOMRIGHT give the label the parent's height. RIGHT is a
    -- single midpoint, so TOP+BOTTOM on it would collapse the fontstring.
    host:SetPoint("TOPLEFT", parent, "TOPRIGHT", -(rightInset + width), 0)
    host:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -rightInset, 0)
    local fs = host.text or host
    if fs.SetJustifyH then
        fs:SetJustifyH(justifyH or "LEFT")
        fs:SetJustifyV("MIDDLE")
        fs:SetWordWrap(true)
        fs:SetMaxLines(2)
        if fs ~= host then
            fs:ClearAllPoints()
            fs:SetAllPoints(host)
        end
    end
end

local SORT_ARROW = "Interface\\Buttons\\UI-SortArrow"
local SORT_ARROW_SIZE = 8

local function EnsureSortArrow(host)
    local arrow = host.sortArrow
    if arrow then
        return arrow
    end
    arrow = host:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(SORT_ARROW_SIZE, SORT_ARROW_SIZE)
    arrow:SetPoint("RIGHT", host, "RIGHT", -2, 0)
    arrow:SetTexture(SORT_ARROW)
    host.sortArrow = arrow
    return arrow
end

local function ApplySortArrow(host, columnId)
    if not host then
        return
    end
    if M:GetSortColumn() == columnId then
        local arrow = EnsureSortArrow(host)
        arrow:Show()
        if M:GetSortAscending() then
            arrow:SetTexCoord(0, 0.5625, 1, 0)
        else
            arrow:SetTexCoord(0, 0.5625, 0, 1)
        end
    elseif host.sortArrow then
        host.sortArrow:Hide()
    end
end

local function ApplySortIndicators(overlay)
    ApplySortArrow(overlay.colCraft, "name")
    local labels = overlay.colLabels
    ApplySortArrow(labels.gold, "gold")
    ApplySortArrow(labels.profit, "profit")
    ApplySortArrow(labels.time, "time")
end

local function PlaceIconLane(frame, parent, rightInset, width, height)
    frame:ClearAllPoints()
    frame:SetPoint("RIGHT", parent, "RIGHT", -rightInset, 0)
    frame:SetSize(width, height)
end

-- The column strip (everything right of the order name) lives inside a
-- clipping host anchored to the right edge. Its width is the packed column
-- width, capped by LaneStripBudget. Fit-all already shrinks icons, then
-- text lanes, then the name; this host only trims the LEFT edge if the
-- strip still overflows after those floors.
local function LaneHostWidth(insets)
    local w = insets.orderRight
    local budget = M:LaneStripBudget()
    if budget and w > budget then
        w = budget
    end
    if w < 1 then
        w = 1
    end
    return w
end

function M:ApplyHeaderLayout(overlay)
    if not overlay then return end
    local insets = M:ComputeInsets()
    local host = overlay.headerLanes
    host:SetWidth(LaneHostWidth(insets))
    overlay.colCraft:ClearAllPoints()
    overlay.colCraft:SetPoint("TOPLEFT", overlay.headerBar, "TOPLEFT", 4, 0)
    overlay.colCraft:SetPoint("BOTTOMLEFT", overlay.headerBar, "BOTTOMLEFT", 4, 0)
    overlay.colCraft:SetPoint("RIGHT", host, "LEFT", 0, 0)
    local labels = overlay.colLabels
    local ids = M:ColumnIds()
    for i = 1, #ids do
        local id = ids[i]
        local fs = labels[id]
        local spec = insets[id]
        if spec then
            fs:Show()
            local text = fs.text or fs
            if id == "profit" then
                -- Header reads "+ / - [source icon]" as a single string; the
                -- full "Profit / Loss" name stays in Features (ColumnLabel).
                text:SetText(PROFIT_HEADER:format(M:PriceSourceIcon(M:GetPriceSource())))
            else
                text:SetText(M:ColumnLabel(id))
            end
            PlaceColLabel(fs, host, spec.right, spec.width, spec.justify)
            if M:IsSortableColumn(id) and fs.text then
                fs.text:ClearAllPoints()
                fs.text:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
                fs.text:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", -10, 0)
            end
        else
            fs:Hide()
        end
    end
    local craftText = overlay.colCraft.text or overlay.colCraft
    craftText:SetText(L["CRAFTORDERS_COL_CRAFT"])
    ApplySortIndicators(overlay)
end

local RELEASE_W = 18
local RELEASE_GAP = 4

local function LayoutActionLane(row, showRelease)
    local btn = row.actionBtn
    if not btn then
        return
    end
    local spec = M:ComputeInsets().action
    if not spec then
        return
    end
    local actionH = M:ColumnHeight("action")
    local release = row.releaseBtn
    btn:ClearAllPoints()
    if showRelease and release then
        release:SetSize(RELEASE_W, actionH)
        release:ClearAllPoints()
        release:SetPoint("RIGHT", row.actionLane, "RIGHT", 0, 0)
        btn:SetPoint("LEFT", row.actionLane, "LEFT", 0, 0)
        btn:SetPoint("RIGHT", release, "LEFT", -RELEASE_GAP, 0)
        btn:SetHeight(actionH)
        release:Show()
    else
        btn:SetPoint("CENTER", row.actionLane, "CENTER")
        btn:SetSize(spec.width, actionH)
        if release then
            release:Hide()
        end
    end
end

local function ApplyRowLayout(row)
    local insets = M:ComputeInsets()
    local host = row.laneHost
    host:SetWidth(LaneHostWidth(insets))
    if row.product:IsShown() then
        local tight = M:IsTight()
        local nameY = tight and 0 or 8
        row.nameText:ClearAllPoints()
        row.nameText:SetPoint("LEFT", row.product, "RIGHT", 6, nameY)
        row.nameText:SetPoint("RIGHT", host, "LEFT", -4, nameY)
        row.nameText:SetMaxLines(1)
        row.nameText:SetWordWrap(false)
        if tight then
            row.unlearnedText:Hide()
        else
            row.unlearnedText:Show()
        end
    end
    local function placeLane(id, frame)
        local spec = insets[id]
        if not spec then
            frame:Hide()
            return
        end
        frame:Show()
        if frame.text then
            PlaceIconLane(frame, host, spec.right, spec.width, spec.height)
            frame.text:ClearAllPoints()
            frame.text:SetAllPoints(frame)
            frame.text:SetJustifyH(spec.justify or "LEFT")
            frame.text:SetJustifyV("MIDDLE")
            frame.text:SetMaxLines(1)
            frame.text:SetWordWrap(false)
        elseif frame.SetJustifyH then
            PlaceColLabel(frame, host, spec.right, spec.width, spec.justify)
            frame:SetMaxLines(1)
            frame:SetWordWrap(false)
        else
            PlaceIconLane(frame, host, spec.right, spec.width, spec.height)
        end
    end
    placeLane("you", row.youLane)
    placeLane("customer", row.customerLane)
    placeLane("reward", row.rewardLane)
    placeLane("cart", row.cartLane)
    placeLane("time", row.timeLane)
    placeLane("gold", row.goldLane)
    placeLane("profit", row.profitLane)
    placeLane("action", row.actionLane)
    if row.actionBtn then
        LayoutActionLane(row, row.releaseBtn and row.releaseBtn:IsShown())
    end
end

local function ResizeStrip(icons, size)
    for i = 1, #icons do
        icons[i]:SetSize(size, size)
    end
end

-- Layout changes never rebuild frames: skinned icons are anchor-based and
-- scale with SetSize, lanes re-anchor, and the virtualizer refresh re-derives
-- row heights. This is what makes slider resizing live.
local function ApplyOverlayGeometry(overlay)
    local sizes = M:IconSizes()
    local rows = overlay._rows
    for i = 1, #rows do
        local row = rows[i]
        row.product:SetSize(sizes.product, sizes.product)
        ResizeStrip(row.youMats, sizes.you)
        ResizeStrip(row.customerMats, sizes.customer)
        ResizeStrip(row.rewards, sizes.reward)
        if row.addBtn then
            local cartH = M:ColumnHeight("cart")
            row.addBtn:SetSize(cartH, cartH)
        end
        ApplyRowLayout(row)
    end
    M:ApplyHeaderLayout(overlay)
end

function M:SyncOverlayScrollBar()
    local overlay = M._overlay
    if not overlay or not overlay.virt then
        return false
    end
    local scroll = overlay.virt.listScroll
    local sb = scroll.ScrollBar
    local hideWanted = M:IsHideScrollBar()
    OneWoW_GUI:SetScrollBarAlwaysHidden(scroll, hideWanted)
    local contentH = overlay.virt.listContent:GetHeight()
    local viewH = scroll:GetHeight()
    local shown = (not hideWanted) and contentH > viewH + 0.5
    local prevShown = M._scrollBarShown
    local prevW = M._rowContentW
    M._scrollBarShown = shown
    if shown then
        sb:Show()
    else
        sb:Hide()
    end
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", shown and -VIRT_RIGHT_BAR or -VIRT_RIGHT_CLEAR, 4)
    scroll:EnableMouseWheel(true)
    overlay.headerBar:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -OverlayChromeRight(), -(4 + STATUS_H))
    M:SetRowContentWidth((overlay:GetWidth() or 0) - HEADER_LEFT - OverlayChromeRight())
    return prevShown ~= shown or prevW ~= M._rowContentW
end

local function FinishOverlayList(overlay)
    overlay.virt.Refresh()
    if M:SyncOverlayScrollBar() then
        ApplyOverlayGeometry(overlay)
        overlay.virt.Refresh()
        M:SyncOverlayScrollBar()
    end
end

function M:ApplyOverlayLayout()
    local overlay = M._overlay
    if not overlay or not overlay.virt then return end
    ApplyOverlayGeometry(overlay)
    FinishOverlayList(overlay)
end

local function ModuleOn()
    return ns.ModuleRegistry:IsEnabled("craftingorders")
end

function M:WantsOverlay()
    return ModuleOn() and not ns.ModuleRegistry:GetToggleValue("craftingorders", "useBlizzardList")
end

local function GetOrdersPage()
    local pf = ProfessionsFrame
    return pf and pf.OrdersPage
end

local function GetBrowseFrame()
    local page = GetOrdersPage()
    return page and page.BrowseFrame, page
end

function M:GetClaimedOrderID()
    local claimed = C_CraftingOrders.GetClaimedOrder()
    return claimed and claimed.orderID or nil
end

function M:IsListCraftLocked(entry)
    local claimedID = M:GetClaimedOrderID()
    if not claimedID or not entry or entry.kind == "header" then
        return false
    end
    return entry.orderID ~= claimedID
end

function M:RowShowsListCraft(entry)
    if not entry or entry.kind ~= "order" or entry.isRecraft then
        return false
    end
    local claimedID = M:GetClaimedOrderID()
    if claimedID then
        return entry.orderID == claimedID
    end
    return entry.section == "ready"
end

--- Label/step for the list Craft button. Uses the live claimed order, not
--- Blizzard button :IsShown() (those lag a frame after Start).
---@param entry table|nil
---@return string kind
function M:GetListCraftKind(entry)
    if not entry then
        return "start"
    end
    local claimed = C_CraftingOrders.GetClaimedOrder()
    if not claimed or claimed.orderID ~= entry.orderID then
        return "start"
    end
    if claimed.isFulfillable then
        return "complete"
    end
    local view = M:GetOrderView()
    if view and view.order and view.order.orderID == claimed.orderID
        and M:ListCraftNeedsConcentration(view) then
        return "concentrate"
    end
    return "create"
end

--- Drop the claimed order (same as Blizzard Cancel Order).
---@param entry table|nil
function M:ReleaseListCraftOrder(entry)
    if Restriction.IsProtectedActionBlocked() then
        return
    end
    local claimed = C_CraftingOrders.GetClaimedOrder()
    if not claimed or not entry or claimed.orderID ~= entry.orderID then
        return
    end
    if claimed.isFulfillable then
        return
    end
    local page = GetOrdersPage()
    local profession = page and page.professionInfo and page.professionInfo.profession
    if not profession then
        return
    end
    C_CraftingOrders.ReleaseOrder(claimed.orderID, profession)
end

--- Browse snapshot after Start is still Created. Load the live claim instead.
---@param entry table|nil
---@return table|nil order
function M:GetListCraftOrder(entry)
    local claimed = C_CraftingOrders.GetClaimedOrder()
    if claimed and entry and claimed.orderID == entry.orderID then
        return claimed
    end
    return entry and entry.raw
end

--- Keep OrderView shown (required for /click) but behind the browse overlay
--- so list clicks land on the list. Stock ViewOrder hides BrowseFrame.
function M:ParkOrderViewBehindList()
    local page = GetOrdersPage()
    local view = page and page.OrderView
    local browse = page and page.BrowseFrame
    if not view or not browse then
        return
    end
    M._listCraftActive = true
    view:Show()
    view:SetAlpha(0)
    local browseLevel = browse:GetFrameLevel()
    if view:GetFrameLevel() >= browseLevel then
        view:SetFrameLevel(math.max(1, browseLevel - 2))
    end
    if not browse:IsShown() then
        browse:Show()
    end
end

function M:RestoreOrderViewChrome()
    local page = GetOrdersPage()
    local view = page and page.OrderView
    if not view then
        return
    end
    view:SetAlpha(1)
    if page then
        view:SetFrameLevel(page:GetFrameLevel() + 10)
    end
end

function M:LoadOrderBehindList(order)
    local page = GetOrdersPage()
    local view = page and page.OrderView
    if not page or not view or not order then
        return
    end
    -- Re-SetOrder of the browse snapshot after a claim resets the view to
    -- Start and eats the next clicks. Skip when this order is already loaded
    -- in the same state.
    local current = view.order
    if not current or current.orderID ~= order.orderID or current.orderState ~= order.orderState then
        view:SetOrder(order)
    end
    M:ParkOrderViewBehindList()
end

function M:StayOnListAfterViewOrder()
    if not M:WantsOverlay() then
        return
    end
    if M._openingOrderFromRow then
        M._listCraftActive = false
        M:RestoreOrderViewChrome()
        return
    end
    M:ParkOrderViewBehindList()
    M:ShowOverlay()
end

local function GetOrderList()
    local browse = GetBrowseFrame()
    return browse and browse.OrderList
end

local function QualityColor(quality)
    if quality and quality > 0 then
        return OneWoW_GUI:GetItemQualityColor(quality)
    end
    return OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
end

local function ApplyOverlayTheme(overlay)
    local bgR, bgG, bgB = OneWoW_GUI:GetThemeColor("BG_PRIMARY")
    local bdR, bdG, bdB = OneWoW_GUI:GetThemeColor("BORDER_DEFAULT")
    overlay:SetBackdropColor(bgR, bgG, bgB, 0.97)
    overlay:SetBackdropBorderColor(bdR, bdG, bdB, 1)
    local craftText = overlay.colCraft.text or overlay.colCraft
    craftText:SetText(L["CRAFTORDERS_COL_CRAFT"])
    local tpR, tpG, tpB = OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
    overlay.statusText:SetTextColor(tpR, tpG, tpB)
    craftText:SetTextColor(tpR, tpG, tpB)
    local labels = overlay.colLabels
    for _, host in pairs(labels) do
        local text = host.text or host
        text:SetTextColor(tpR, tpG, tpB)
    end
    M:ApplyHeaderLayout(overlay)
    overlay.emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    overlay.headerBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    overlay.headerBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
end

local function HideBlizzardOrderList()
    local list = GetOrderList()
    if list then
        list:Hide()
    end
end

local function ShowBlizzardOrderList()
    local list = GetOrderList()
    if list then
        list:Show()
    end
end

function M:IsOverlayActive()
    return M:WantsOverlay() and M._overlay and M._overlay:IsShown()
end

local function ApplyRowChrome(row, index, entry, selected, hover)
    if entry and entry.kind ~= "header" and M:IsListCraftLocked(entry) then
        row:SetAlpha(0.4)
    else
        row:SetAlpha(1)
    end
    if entry and entry.kind == "header" then
        OneWoW_GUI:ApplyListRowFill(row, { header = true })
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        return
    end
    if selected then
        OneWoW_GUI:ApplyListRowFill(row, { selected = true })
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        return
    end
    if hover then
        OneWoW_GUI:ApplyListRowFill(row, { hover = true })
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
        return
    end
    OneWoW_GUI:ApplyListRowFill(row, { zebraIndex = index })
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
end

local function HideStrip(icons)
    for i = 1, #icons do
        icons[i]:Hide()
    end
end

local function TooltipRGB(key)
    local r, g, b = OneWoW_GUI:GetThemeColor(key)
    return r, g, b
end

local function AddMoneyLine(label, copper, valueKey)
    local lr, lg, lb = TooltipRGB("TEXT_SECONDARY")
    local vr, vg, vb = TooltipRGB(valueKey or "TEXT_PRIMARY")
    GameTooltip:AddDoubleLine(label, OneWoW.Format.FormatGold(copper or 0), lr, lg, lb, vr, vg, vb)
end

local function QtyLabel(name, count)
    count = count or 1
    if count ~= 1 then
        return ("%s x%d"):format(name, count)
    end
    return name
end

local function AppendGoldBreakdown(net, gross, cut, tipAvg, tipMax)
    AddMoneyLine(PROFESSIONS_CRAFTER_FORM_TIP, gross)
    AddMoneyLine(CRAFTING_ORDER_CONSORTIUM_CUT, cut)
    AddMoneyLine(CRAFTING_ORDER_FINAL_TIP, net)
    if tipAvg and tipAvg > 0 and tipAvg ~= gross then
        AddMoneyLine(L["CRAFTORDERS_TIP_AVG"], tipAvg)
    end
    if tipMax and tipMax > 0 and tipMax ~= gross then
        AddMoneyLine(MAXIMUM, tipMax)
    end
end

local function ShowGoldBreakdownTooltip(owner, net, gross, cut, tipAvg, tipMax)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["CRAFTORDERS_COL_GOLD"])
    AppendGoldBreakdown(net, gross, cut, tipAvg, tipMax)
    GameTooltip:Show()
end

local function AppendPriceSourceLines()
    local src = M:GetPriceSource()
    GameTooltip:AddLine(M:PriceSourceLabel(src), TooltipRGB("TEXT_PRIMARY"))
    if src == "tsm" then
        GameTooltip:AddLine(M:GetTSMPriceString(), TooltipRGB("TEXT_SECONDARY"))
        local hr, hg, hb = TooltipRGB("TEXT_MUTED")
        GameTooltip:AddLine(L["CRAFTORDERS_PROFIT_TSM_HINT"], hr, hg, hb, true)
    end
end

local function ShowProfitSourceTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["CRAFTORDERS_COL_PROFIT"])
    AppendPriceSourceLines()
    GameTooltip:Show()
end

local function AppendPricedLines(rows, negate)
    local mr, mg, mb = TooltipRGB("TEXT_MUTED")
    for i = 1, #rows do
        local row = rows[i]
        local label = QtyLabel(row.name, row.count)
        if row.copper then
            local copper = row.copper * (row.count or 1)
            if negate then
                copper = -copper
            end
            local valueKey = (negate or copper < 0) and "TEXT_WARNING" or "TEXT_PRIMARY"
            AddMoneyLine(label, copper, valueKey)
        else
            GameTooltip:AddDoubleLine(label, UNKNOWN, mr, mg, mb, mr, mg, mb)
        end
    end
end

local function ShowProfitBreakdownTooltip(owner, entry)
    local bd = M:ComputeOrderProfitBreakdown(entry)
    if not bd then
        ShowProfitSourceTooltip(owner)
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["CRAFTORDERS_COL_PROFIT"])
    AppendGoldBreakdown(bd.net, bd.gross, bd.cut, entry.tipAvg, entry.tipMax)
    if #bd.rewards > 0 then
        GameTooltip:AddLine(L["CRAFTORDERS_COL_REWARD"], TooltipRGB("TEXT_ACCENT"))
        AppendPricedLines(bd.rewards, false)
    end
    if #bd.mats > 0 then
        GameTooltip:AddLine(L["CRAFTORDERS_COL_YOU"], TooltipRGB("TEXT_ACCENT"))
        AppendPricedLines(bd.mats, true)
    end
    local totalKey = (bd.profit or 0) < 0 and "TEXT_WARNING" or "TEXT_PRIMARY"
    AddMoneyLine(TOTAL, bd.profit, totalKey)
    GameTooltip:AddLine(" ")
    AppendPriceSourceLines()
    GameTooltip:Show()
end

local function FormatCompactDuration(seconds)
    seconds = floor(seconds)
    if seconds <= 0 then
        return ""
    end
    local days = floor(seconds / 86400)
    seconds = seconds - days * 86400
    local hours = floor(seconds / 3600)
    seconds = seconds - hours * 3600
    local minutes = floor(seconds / 60)
    seconds = seconds - minutes * 60
    local parts = {}
    if days > 0 then
        parts[#parts + 1] = DAY_ONELETTER_ABBR:format(days)
    end
    if hours > 0 then
        parts[#parts + 1] = HOUR_ONELETTER_ABBR:format(hours)
    end
    if minutes > 0 then
        parts[#parts + 1] = MINUTE_ONELETTER_ABBR:format(minutes)
    end
    if #parts == 0 then
        parts[1] = SECOND_ONELETTER_ABBR:format(seconds)
    end
    return table.concat(parts, TIME_UNIT_DELIMITER)
end

local function OnDataIconEnter(icon)
    GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
    if icon._itemLink then
        GameTooltip:SetHyperlink(icon._itemLink)
    elseif icon._itemID then
        GameTooltip:SetItemByID(icon._itemID)
        if icon._youProvide then
            GameTooltip:AddLine(PROFESSIONS_CUSTOMER_ORDER_REAGENT_NOTPROVIDED, OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            local tip = M:GetElsewhereTooltip({ missingReagents = { { itemID = icon._itemID } } })
            if tip then
                GameTooltip:AddLine(tip, OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        elseif icon._customerProvide then
            GameTooltip:AddLine(PROFESSIONS_CUSTOMER_ORDER_REAGENT_PROVIDED, OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
        if icon._subtitle and icon._subtitle ~= "" then
            GameTooltip:AddLine(icon._subtitle, OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
    elseif icon._currencyType then
        local info = C_CurrencyInfo.GetCurrencyInfo(icon._currencyType)
        GameTooltip:SetText(info and info.name or "")
        if icon._count and icon._count > 1 then
            GameTooltip:AddLine("x" .. icon._count, OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    elseif icon._gold then
        ShowGoldBreakdownTooltip(icon, icon._gold, icon._commission, icon._consortiumCut, icon._tipAvg, icon._tipMax)
        return
    else
        GameTooltip:Hide()
        return
    end
    GameTooltip:Show()
end

local function SetCountText(icon, text, warning)
    local fs = icon._countText
    if not fs then return end
    fs:SetText(text or "")
    if warning then
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    else
        fs:SetTextColor(1, 1, 1, 1)
    end
end

local function BindDataIcon(icon, data, role)
    icon._itemID = nil
    icon._itemLink = nil
    icon._currencyType = nil
    icon._gold = nil
    icon._commission = nil
    icon._consortiumCut = nil
    icon._count = nil
    icon._tipAvg = nil
    icon._tipMax = nil
    icon._youProvide = role == "you"
    icon._customerProvide = role == "customer"
    if not data then
        icon:Hide()
        SetCountText(icon, "")
        return
    end
    icon:Show()
    if data.kind == "gold" then
        OneWoW_GUI:UpdateIconTexture(icon, data.icon)
        icon._gold = data.amount
        icon._commission = data.commission
        icon._consortiumCut = data.consortiumCut
        icon._tipAvg = data.tipAvg
        icon._tipMax = data.tipMax
        local goldAmt = floor((data.amount or 0) / COPPER_PER_GOLD)
        SetCountText(icon, goldAmt > 0 and tostring(goldAmt) or "")
        return
    end
    if data.kind == "currency" then
        OneWoW_GUI:UpdateIconTexture(icon, data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        icon._currencyType = data.currencyType
        icon._count = data.count
        SetCountText(icon, (data.count and data.count > 1) and tostring(data.count) or "")
        return
    end
    local itemID = data.itemID
    local tex = data.icon or (itemID and C_Item.GetItemIconByID(itemID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
    OneWoW_GUI:UpdateIconTexture(icon, tex)
    icon._itemID = itemID
    icon._itemLink = data.itemLink
    if role == "you" then
        SetCountText(icon, (data.have or 0) .. "/" .. (data.need or 1), data.short and data.short > 0)
    elseif data.count and data.count > 1 then
        SetCountText(icon, tostring(data.count))
    elseif data.need and data.need > 1 then
        SetCountText(icon, tostring(data.need))
    else
        SetCountText(icon, "")
    end
end

local function BindStrip(icons, list, role)
    list = list or {}
    for i = 1, #icons do
        BindDataIcon(icons[i], list[i], role)
    end
end

local function FormatTimeLeft(entry)
    if entry.kind == "bucket" then return "", "" end
    local remaining = entry.remaining or 0
    if remaining <= 0 then return "", "" end
    local noSeconds = true
    return FormatCompactDuration(remaining), SecondsToTime(remaining, noSeconds)
end

local BindActionButton

local function BindHeader(row, entry)
    row.product:Hide()
    row.nameText:ClearAllPoints()
    row.nameText:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.nameText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    if entry.section == "ready" then
        row.nameText:SetText(L["CRAFTORDERS_SECTION_READY"] .. " (" .. entry.count .. ")")
    elseif entry.section == "unknown" then
        row.nameText:SetText(PROFESSIONS_RECIPE_UNLEARNED .. " (" .. entry.count .. ")")
    else
        row.nameText:SetText(L["CRAFTORDERS_SECTION_MISSING"] .. " (" .. entry.count .. ")")
    end
    row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    row.timeText:SetText("")
    row.goldText:SetText("")
    row.profitText:SetText("")
    row.unlearnedText:SetText("")
    row.product._subtitle = nil
    row.addBtn:Hide()
    row.addBtn._entry = nil
    HideStrip(row.youMats)
    HideStrip(row.customerMats)
    HideStrip(row.rewards)
    row.youLane:Hide()
    row.customerLane:Hide()
    row.rewardLane:Hide()
    row.cartLane:Hide()
    row.actionLane:Hide()
    if row.actionBtn then
        row.actionBtn:Hide()
        row.actionBtn._entry = nil
    end
    if row.releaseBtn then
        row.releaseBtn:Hide()
        row.releaseBtn._entry = nil
    end
    row.timeLane:Hide()
    row.goldLane:Hide()
    row.profitLane:Hide()
    row.timeLane._fullTime = nil
    row.goldLane._net = nil
    row.goldLane._gross = nil
    row.goldLane._cut = nil
    row.goldLane._tipAvg = nil
    row.goldLane._tipMax = nil
    row.profitLane._entry = nil
end

local function BindMoney(fs, copper, allowNegative)
    if not copper or (copper == 0 and not allowNegative) then
        fs:SetText("")
        return
    end
    fs:SetText(OneWoW.Format.FormatGold(copper))
    if copper < 0 then
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
        return
    end
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
end

--- Cart button only on orders that still need crafter mats.
---@param entry table|nil
---@return boolean
function M:RowShowsCart(entry)
    return entry and entry.kind == "order" and entry.section ~= "ready"
        and entry.missingReagents and #entry.missingReagents > 0
end

local function BindRow(row, entry)
    row.product:Show()
    ApplyRowLayout(row)
    local icon = entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    OneWoW_GUI:UpdateIconTexture(row.product, icon)
    OneWoW_GUI:SetIconDesaturated(row.product, not entry.learned)
    row.product._itemID = entry.itemID
    row.nameText:SetText(entry.name or "")
    row.nameText:SetTextColor(QualityColor(entry.quality))
    local subtitle = ""
    if not entry.learned then
        subtitle = PROFESSIONS_CRAFTER_CANT_CLAIM_UNLEARNED
        row.unlearnedText:SetText(subtitle)
        row.unlearnedText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    elseif entry.isRecraft then
        subtitle = PROFESSIONS_CRAFTING_RECRAFT
        row.unlearnedText:SetText(subtitle)
        row.unlearnedText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    elseif entry.kind == "bucket" then
        subtitle = L["CRAFTORDERS_BUCKET_COUNT"]:format(entry.numAvailable or 0)
        row.unlearnedText:SetText(subtitle)
        row.unlearnedText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    elseif entry.customerName and entry.customerName ~= "" then
        subtitle = entry.customerName
        row.unlearnedText:SetText(subtitle)
        row.unlearnedText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    else
        row.unlearnedText:SetText("")
    end
    row.product._subtitle = M:IsTight() and subtitle or nil
    local compact, fullTime = FormatTimeLeft(entry)
    row.timeText:SetText(compact)
    row.timeLane._fullTime = fullTime
    row.timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    local net, gross, cut = M:GetGoldReceived(entry.gold, entry.consortiumCut)
    BindMoney(row.goldText, net, false)
    row.goldLane._net = net
    row.goldLane._gross = gross
    row.goldLane._cut = cut
    row.goldLane._tipAvg = entry.tipAvg
    row.goldLane._tipMax = entry.tipMax
    BindMoney(row.profitText, M:ComputeOrderProfit(entry), true)
    row.profitLane._entry = entry

    BindStrip(row.youMats, M:FilterYouReagents(entry.youReagents), "you")
    BindStrip(row.customerMats, entry.customerReagents, "customer")
    BindStrip(row.rewards, entry.rewardIcons, "reward")

    local showAdd = M:RowShowsCart(entry)
    row.addBtn._entry = entry
    row.addBtn:SetShown(showAdd)
    BindActionButton(row, entry)
end

BindActionButton = function(row, entry)
    local btn = row.actionBtn
    if not btn then
        return
    end
    btn._entry = entry
    if row.releaseBtn then
        row.releaseBtn._entry = entry
    end
    if not M:RowShowsListCraft(entry) then
        btn:Hide()
        LayoutActionLane(row, false)
        return
    end
    btn:Show()
    local kind = M:GetListCraftKind(entry)
    local claimed = C_CraftingOrders.GetClaimedOrder()
    local showRelease = claimed and claimed.orderID == entry.orderID and not claimed.isFulfillable
    LayoutActionLane(row, showRelease)
    local blocked = Restriction.IsProtectedActionBlocked()
    if row.releaseBtn then
        row.releaseBtn:SetEnabled(not blocked)
        if blocked then
            row.releaseBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            row.releaseBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            row.releaseBtn.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        else
            row.releaseBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
            row.releaseBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
            row.releaseBtn.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end
    if kind == "start" then
        btn:SetEnabled(not blocked)
    elseif kind == "concentrate" then
        local conc = M:GetConcentrateToggle()
        local enough = not conc or not conc.HasEnoughConcentration or conc:HasEnoughConcentration()
        btn:SetEnabled(not blocked and enough)
    else
        local action = select(1, M:GetOrderAction(M:GetOrderView()))
        btn:SetEnabled(not blocked and (not action or action:IsEnabled()))
    end
    if kind == "complete" then
        btn.label:SetText(PROFESSIONS_COMPLETE_ORDER)
    elseif kind == "concentrate" then
        btn.label:SetText(PROFESSIONS_CRAFTING_STAT_CONCENTRATION)
    elseif kind == "create" then
        btn.label:SetText(CREATE_PROFESSION)
    else
        btn.label:SetText(PROFESSIONS_START_ORDER)
    end
    M:ApplyMagicChrome(btn, btn:IsMouseOver())
end

function M:ValidateListActionButtons()
    local overlay = M._overlay
    if not overlay then
        return
    end
    local rows = overlay._rows
    if not rows then
        return
    end
    for i = 1, #rows do
        local row = rows[i]
        if row:IsShown() and row._entry and row._entry.kind ~= "header" then
            BindActionButton(row, row._entry)
            ApplyRowChrome(row, row._rowIndex, row._entry, row._selected, row:IsMouseOver())
        end
    end
end

function M:EnsureOverlay()
    if M._overlay then return M._overlay end
    local browse = GetBrowseFrame()
    if not browse then return nil end

    local overlay = CreateFrame("Frame", nil, browse, "BackdropTemplate")
    overlay:ClearAllPoints()
    overlay:SetPoint("TOPLEFT", browse.RecipeList, "TOPRIGHT")
    overlay:SetPoint("BOTTOMLEFT", browse.RecipeList, "BOTTOMRIGHT")
    overlay:SetPoint("TOPRIGHT", browse, "TOPRIGHT")
    overlay:SetPoint("BOTTOMRIGHT", browse, "BOTTOMRIGHT")
    overlay:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    overlay:EnableMouse(true)
    overlay:SetFrameLevel(browse:GetFrameLevel() + 20)
    overlay:Hide()

    -- Header and rows both span the overlay minus list + scroll + row insets.
    -- Columns clamp icon lanes against this width so the order name keeps room.
    M:SetRowContentWidth((overlay:GetWidth() or 0) - HEADER_LEFT - OverlayChromeRight())
    overlay:SetScript("OnSizeChanged", function(myself, width)
        M:SetRowContentWidth((width or 0) - HEADER_LEFT - OverlayChromeRight())
        if M._overlay == myself then
            M:ApplyOverlayLayout()
        end
    end)
    OneWoW_GUI:RegisterFontRoot(overlay, function()
        if M:IsOverlayActive() then
            M:RefreshOverlay()
        end
    end)

    local statusText = OneWoW_GUI:CreateFS(overlay, 12)
    statusText:SetPoint("TOPLEFT", overlay, "TOPLEFT", 8, -4)
    statusText:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -8, -4)
    statusText:SetJustifyH("LEFT")
    overlay.statusText = statusText

    local headerBar = CreateFrame("Frame", nil, overlay, "BackdropTemplate")
    headerBar:SetPoint("TOPLEFT", overlay, "TOPLEFT", HEADER_LEFT, -(4 + STATUS_H))
    headerBar:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -OverlayChromeRight(), -(4 + STATUS_H))
    headerBar:SetHeight(COL_H)
    headerBar:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    overlay.headerBar = headerBar

    local colCraft = CreateFrame("Button", nil, headerBar)
    colCraft:SetScript("OnClick", function()
        M:CycleSortColumn("name")
    end)
    local colCraftText = OneWoW_GUI:CreateFS(colCraft, 11)
    colCraftText:SetPoint("TOPLEFT", colCraft, "TOPLEFT", 0, 0)
    colCraftText:SetPoint("BOTTOMRIGHT", colCraft, "BOTTOMRIGHT", -10, 0)
    colCraftText:SetJustifyH("LEFT")
    colCraftText:SetJustifyV("MIDDLE")
    colCraftText:SetText(L["CRAFTORDERS_COL_CRAFT"])
    colCraft.text = colCraftText
    overlay.colCraft = colCraft

    -- Clipping host for the header column labels; mirrors row.laneHost so an
    -- over-wide column strip clips instead of running over the Craft title.
    local headerLanes = CreateFrame("Frame", nil, headerBar)
    headerLanes:SetPoint("TOPRIGHT", headerBar, "TOPRIGHT", 0, 0)
    headerLanes:SetPoint("BOTTOMRIGHT", headerBar, "BOTTOMRIGHT", 0, 0)
    headerLanes:SetClipsChildren(true)
    overlay.headerLanes = headerLanes

    local colLabels = {}
    local colIds = M:ColumnIds()
    for i = 1, #colIds do
        local id = colIds[i]
        local host = CreateFrame("Frame", nil, headerLanes)
        host:EnableMouse(true)
        local fs = OneWoW_GUI:CreateFS(host, 11)
        fs:SetAllPoints(host)
        fs:SetMaxLines(2)
        fs:SetWordWrap(true)
        host.text = fs
        if id == "gold" then
            host:SetScript("OnEnter", function(myself)
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["CRAFTORDERS_COL_GOLD"])
                GameTooltip:AddLine(L["CRAFTORDERS_COL_GOLD_TIP"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                GameTooltip:Show()
            end)
            host:SetScript("OnLeave", GameTooltip_Hide)
        elseif id == "profit" then
            host:SetScript("OnEnter", function(myself)
                ShowProfitSourceTooltip(myself)
            end)
            host:SetScript("OnLeave", GameTooltip_Hide)
        elseif id == "time" then
            host:SetScript("OnEnter", function(myself)
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetText(CLOSES_IN)
                GameTooltip:AddLine(L["CRAFTORDERS_COL_TIME_TIP"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                GameTooltip:Show()
            end)
            host:SetScript("OnLeave", GameTooltip_Hide)
        end
        if M:IsSortableColumn(id) then
            host:SetScript("OnMouseUp", function(_, button)
                if button ~= "LeftButton" then
                    return
                end
                M:CycleSortColumn(id)
            end)
        end
        colLabels[id] = host
    end
    overlay.colLabels = colLabels

    local listHost = CreateFrame("Frame", nil, overlay)
    listHost:SetPoint("TOPLEFT", overlay, "TOPLEFT", LIST_LEFT, -(4 + STATUS_H + COL_H))
    listHost:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -LIST_RIGHT, 4)
    overlay.listHost = listHost

    local emptyText = OneWoW_GUI:CreateFS(overlay, 12)
    emptyText:SetPoint("CENTER", listHost, "CENTER")
    emptyText:SetWidth(280)
    emptyText:SetJustifyH("CENTER")
    overlay.emptyText = emptyText

    ApplyOverlayTheme(overlay)

    M._entries = {}
    overlay._rows = {}
    local lane = M:LaneConstants()
    local rowH = M:RowHeight()
    local virt = OneWoW_GUI:CreateVirtualizer(listHost, {
        getCount = function()
            return M._entries and #M._entries or 0
        end,
        getEntry = function(i)
            return M._entries[i]
        end,
        isSelectable = function(_, entry)
            return entry and entry.kind ~= "header"
        end,
        rowInset = ROW_INSET,
        rowHeight = rowH,
        getRowHeight = function(i)
            local entry = M._entries[i]
            if entry and entry.kind == "header" then return HEADER_H end
            return M:RowHeight()
        end,
        numVisibleRows = 16,
        onSelect = function(_, entry)
            M:OnRowActivate(entry)
        end,
        createRow = function(content)
            -- Fresh sizes per row: the pool can grow after a resize, and a
            -- stale capture would build new rows at the old icon size.
            local sizes = M:IconSizes()
            local row = CreateFrame("Button", nil, content, "BackdropTemplate")
            row:SetHeight(rowH)
            row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row:SetScript("OnClick", function(myself, button)
                if button == "RightButton" then
                    M:OnRowRightClick(myself._entry)
                end
            end)
            row:SetScript("OnEnter", function(myself)
                if myself._entry and myself._entry.kind ~= "header" then
                    ApplyRowChrome(myself, myself._rowIndex, myself._entry, myself._selected, true)
                end
            end)
            row:SetScript("OnLeave", function(myself)
                ApplyRowChrome(myself, myself._rowIndex, myself._entry, myself._selected, false)
            end)

            local function ActivateRow(button)
                local entry = row._entry
                if not entry or entry.kind == "header" then return end
                if button == "RightButton" then
                    M:OnRowRightClick(entry)
                else
                    M:OnRowActivate(entry)
                end
            end

            -- Everything right of the order name parents into this clipping
            -- host; ApplyRowLayout sets its width (packed columns, capped by
            -- LaneStripBudget) so overflow clips instead of covering the name.
            local laneHost = CreateFrame("Frame", nil, row)
            laneHost:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
            laneHost:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
            laneHost:SetClipsChildren(true)
            row.laneHost = laneHost

            local function MakeIcon(size, parent)
                local icon = OneWoW_GUI:CreateSkinnedIcon(parent, {
                    size = size,
                    preset = "clean",
                    showCount = true,
                    onClick = function(_, button)
                        ActivateRow(button)
                    end,
                    onEnter = OnDataIconEnter,
                    onLeave = GameTooltip_Hide,
                })
                icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                return icon
            end

            local product = OneWoW_GUI:CreateSkinnedIcon(row, {
                size = sizes.product,
                preset = "clean",
                onClick = function(_, button)
                    ActivateRow(button)
                end,
                onEnter = OnDataIconEnter,
                onLeave = GameTooltip_Hide,
            })
            product:SetPoint("LEFT", row, "LEFT", 4, 0)
            product:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row.product = product

            local nameText = OneWoW_GUI:CreateFS(row, 12)
            nameText:SetJustifyH("LEFT")
            row.nameText = nameText

            local unlearnedText = OneWoW_GUI:CreateFS(row, 10)
            unlearnedText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -1)
            unlearnedText:SetPoint("RIGHT", nameText, "RIGHT")
            unlearnedText:SetJustifyH("LEFT")
            row.unlearnedText = unlearnedText

            local function MakeTextLane()
                local textLane = CreateFrame("Frame", nil, laneHost)
                textLane:EnableMouse(true)
                local fs = OneWoW_GUI:CreateFS(textLane, 11)
                fs:SetAllPoints(textLane)
                fs:SetMaxLines(1)
                fs:SetWordWrap(false)
                textLane.text = fs
                textLane:SetScript("OnMouseUp", function(_, button)
                    ActivateRow(button)
                end)
                return textLane, fs
            end

            local timeLane, timeText = MakeTextLane()
            timeLane:SetScript("OnEnter", function(myself)
                if myself._fullTime and myself._fullTime ~= "" then
                    GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                    GameTooltip:SetText(myself._fullTime)
                    GameTooltip:Show()
                end
            end)
            timeLane:SetScript("OnLeave", GameTooltip_Hide)
            row.timeLane = timeLane
            row.timeText = timeText

            local goldLane, goldText = MakeTextLane()
            goldLane:SetScript("OnEnter", function(myself)
                if myself._net ~= nil then
                    ShowGoldBreakdownTooltip(
                        myself,
                        myself._net,
                        myself._gross,
                        myself._cut,
                        myself._tipAvg,
                        myself._tipMax
                    )
                end
            end)
            goldLane:SetScript("OnLeave", GameTooltip_Hide)
            row.goldLane = goldLane
            row.goldText = goldText

            local profitLane, profitText = MakeTextLane()
            profitLane:SetScript("OnEnter", function(myself)
                if myself._entry then
                    ShowProfitBreakdownTooltip(myself, myself._entry)
                else
                    ShowProfitSourceTooltip(myself)
                end
            end)
            profitLane:SetScript("OnLeave", GameTooltip_Hide)
            row.profitLane = profitLane
            row.profitText = profitText

            local function FillIconLane(count, size)
                local laneFrame = CreateFrame("Frame", nil, laneHost)
                laneFrame:SetClipsChildren(true)
                local icons = {}
                for i = 1, count do
                    local icon = MakeIcon(size, laneFrame)
                    if i == 1 then
                        icon:SetPoint("LEFT", laneFrame, "LEFT", 0, 0)
                    else
                        icon:SetPoint("LEFT", icons[i - 1], "RIGHT", lane.matGap, 0)
                    end
                    icons[i] = icon
                end
                return laneFrame, icons
            end

            row.rewardLane, row.rewards = FillIconLane(lane.maxRewards, sizes.reward)
            row.customerLane, row.customerMats = FillIconLane(lane.maxCust, sizes.customer)
            row.youLane, row.youMats = FillIconLane(lane.maxYou, sizes.you)

            local cartLane = CreateFrame("Frame", nil, laneHost)
            row.cartLane = cartLane

            local addBtn = OneWoW_GUI:CreateIconButton(cartLane, {
                atlas = "Perks-ShoppingCart",
                size = 20,
                onClick = function(btn, button)
                    M:OnAddButtonClick(btn, button)
                end,
            })
            addBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            addBtn:SetPoint("CENTER", cartLane, "CENTER")
            addBtn:SetScript("OnEnter", function(btn)
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                local active = M:GetActiveShoppingListName()
                if not M:HasShoppingList() then
                    GameTooltip:SetText(L["CRAFTORDERS_NO_SHOPPING"])
                elseif active then
                    GameTooltip:SetText(L["CRAFTORDERS_ADD_ACTIVE"]:format(active))
                    GameTooltip:AddLine(L["CRAFTORDERS_ADD_MENU_HINT"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                else
                    GameTooltip:SetText(L["CRAFTORDERS_MAKE_LIST"])
                end
                GameTooltip:Show()
            end)
            addBtn:SetScript("OnLeave", GameTooltip_Hide)
            row.addBtn = addBtn

            local actionLane = CreateFrame("Frame", nil, laneHost)
            row.actionLane = actionLane
            M:EnsureMagicButton()
            local actionBtn = CreateFrame("Button", nil, actionLane,
                "InsecureActionButtonTemplate, BackdropTemplate")
            actionBtn:SetSize(lane.actionW or 140, 22)
            actionBtn:SetPoint("CENTER", actionLane, "CENTER")
            actionBtn:RegisterForClicks("LeftButtonUp")
            actionBtn:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
            actionBtn:SetMotionScriptsWhileDisabled(true)
            local actionLabel = OneWoW_GUI:CreateFS(actionBtn, 11)
            actionLabel:SetPoint("LEFT", actionBtn, "LEFT", 4, 0)
            actionLabel:SetPoint("RIGHT", actionBtn, "RIGHT", -4, 0)
            actionLabel:SetJustifyH("CENTER")
            actionLabel:SetWordWrap(false)
            actionLabel:SetMaxLines(1)
            actionBtn.label = actionLabel
            actionBtn:SetScript("PreClick", function(myself)
                if Restriction.IsProtectedActionBlocked() then
                    return
                end
                local entry = myself._entry
                if not entry or not M:RowShowsListCraft(entry) or M:IsListCraftLocked(entry) then
                    return
                end
                M:PrepareListCraftClick(entry)
            end)
            actionBtn:SetScript("OnEnter", function(myself)
                M:ApplyMagicChrome(myself, true)
                if Restriction.IsProtectedActionBlocked() then
                    GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                    GameTooltip:SetText(SPELL_FAILED_AFFECTING_COMBAT)
                    GameTooltip:Show()
                    return
                end
                local entry = myself._entry
                local kind = M:GetListCraftKind(entry)
                if kind == "concentrate" then
                    GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                    GameTooltip:SetText(PROFESSIONS_CRAFTING_STAT_CONCENTRATION)
                    local conc = M:GetConcentrateToggle()
                    if conc and conc.HasEnoughConcentration and not conc:HasEnoughConcentration() then
                        local info = conc.GetCurrencyInfo and conc:GetCurrencyInfo()
                        GameTooltip:AddLine(
                            PROFESSIONS_CRAFTING_CONCENTRATION_TOGGLE_DISABLED:format(
                                (info and info.name) or PROFESSIONS_CRAFTING_STAT_CONCENTRATION
                            ),
                            OneWoW_GUI:GetThemeColor("TEXT_WARNING")
                        )
                    elseif conc and conc.GetConcentrationRequired then
                        GameTooltip:AddLine(
                            PROFESSIONS_CRAFTING_CONCENTRATION_TOGGLE_ON_DESC:format(conc:GetConcentrationRequired()),
                            OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
                        )
                    end
                    GameTooltip:Show()
                elseif entry and entry.orderID ~= M:GetClaimedOrderID() then
                    GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                    GameTooltip:SetText(PROFESSIONS_START_ORDER_TOOLTIP)
                    GameTooltip:Show()
                end
            end)
            actionBtn:SetScript("OnLeave", function(myself)
                M:ApplyMagicChrome(myself, false)
                GameTooltip_Hide()
            end)
            actionBtn:SetScript("OnMouseDown", function(myself)
                if not myself:IsEnabled() then return end
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED"))
            end)
            actionBtn:SetScript("OnMouseUp", function(myself)
                if not myself:IsEnabled() then return end
                M:ApplyMagicChrome(myself, myself:IsMouseOver())
            end)
            M:SecureRowActionButton(actionBtn)
            M:ApplyMagicChrome(actionBtn, false)
            row.actionBtn = actionBtn

            local releaseBtn = CreateFrame("Button", nil, actionLane, "BackdropTemplate")
            releaseBtn:SetSize(RELEASE_W, 22)
            releaseBtn:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
            releaseBtn:SetMotionScriptsWhileDisabled(true)
            local releaseLabel = OneWoW_GUI:CreateFS(releaseBtn, 11)
            releaseLabel:SetPoint("CENTER")
            releaseLabel:SetText("X")
            releaseBtn.label = releaseLabel
            releaseBtn:SetScript("OnClick", function(myself)
                if Restriction.IsProtectedActionBlocked() then
                    return
                end
                M:ReleaseListCraftOrder(myself._entry)
            end)
            releaseBtn:SetScript("OnEnter", function(myself)
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_HOVER"))
                myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER_HOVER"))
                myself.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                if Restriction.IsProtectedActionBlocked() then
                    GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                    GameTooltip:SetText(SPELL_FAILED_AFFECTING_COMBAT)
                    GameTooltip:Show()
                    return
                end
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetText(PROFESSIONS_CRAFTER_RELEASE_ORDER)
                GameTooltip:Show()
            end)
            releaseBtn:SetScript("OnLeave", function(myself)
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
                myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
                myself.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                GameTooltip_Hide()
            end)
            releaseBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
            releaseBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
            releaseLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            releaseBtn:Hide()
            row.releaseBtn = releaseBtn

            ApplyRowLayout(row)
            overlay._rows[#overlay._rows + 1] = row
            return row
        end,
        bindRow = function(row, index, entry, state)
            row._entry = entry
            row._rowIndex = index
            row._selected = state and state.selected
            if not entry then
                return
            end
            ApplyRowChrome(row, index, entry, row._selected, false)
            if entry.kind == "header" then
                BindHeader(row, entry)
            else
                BindRow(row, entry)
            end
        end,
    })
    overlay.virt = virt
    M._overlay = overlay
    M._virt = virt
    virt.listScroll:EnableMouseWheel(true)
    virt.listScroll:HookScript("OnVerticalScroll", function()
        local page = GetOrdersPage()
        if page then
            page:RequestMoreOrders()
        end
    end)
    return overlay
end

function M:OnAddButtonClick(btn, button)
    if not M:HasShoppingList() then return end
    local entry = btn._entry
    if not entry or not entry.missingReagents then return end
    if button == "RightButton" then
        M:ShowAddMenu(btn, entry)
        return
    end
    M:AddReagentsToActive(entry.missingReagents)
end

function M:OnRowActivate(entry)
    if not entry or entry.kind == "header" then return end
    if M:IsListCraftLocked(entry) then return end
    local page = GetOrdersPage()
    if not page then return end
    if entry.kind == "bucket" then
        page:SelectRecipeFromBucket(entry.raw)
        return
    end
    M._openingOrderFromRow = true
    page:ViewOrder(entry.raw)
    M._openingOrderFromRow = false
    M._listCraftActive = false
    M:RestoreOrderViewChrome()
end

function M:OnRowRightClick(entry)
    if not entry or entry.kind == "header" then return end
    local page = GetOrdersPage()
    if not page then return end
    MenuUtil.CreateContextMenu(M._overlay, function(_, rootDescription)
        local recipeID = entry.spellID
        if recipeID then
            local currentlyFavorite = C_TradeSkillUI.IsRecipeFavorite(recipeID)
            local text = currentlyFavorite and BATTLE_PET_UNFAVORITE or BATTLE_PET_FAVORITE
            rootDescription:CreateButton(text, function()
                C_TradeSkillUI.SetRecipeFavorite(recipeID, not currentlyFavorite)
            end)
        end
        if entry.kind == "order" and entry.orderType == Enum.CraftingOrderType.Personal then
            local professionInfo = page.professionInfo
            rootDescription:CreateButton(PROFESSIONS_DECLINE_ORDER, function()
                C_CraftingOrders.RejectOrder(entry.orderID, "", professionInfo.profession)
            end)
        end
    end)
end

function M:UpdateStatusHeader()
    local overlay = M._overlay
    if not overlay then return end
    local page = GetOrdersPage()
    local text = ""
    if page and page.orderType == Enum.CraftingOrderType.Npc then
        local profession = page.professionInfo and page.professionInfo.profession
        text = M:FormatWeeklyHeader(profession) or ""
    elseif page and page.orderType == Enum.CraftingOrderType.Public then
        local profession = page.professionInfo and page.professionInfo.profession
        if profession then
            local info = C_CraftingOrders.GetOrderClaimInfo(profession)
            text = PROFESSIONS_CRAFTING_ORDERS_REMAINING_ORDERS:format(info.claimsRemaining)
        end
    end
    overlay.statusText:SetText(text)
end

function M:PullCurrentOrders()
    local page = GetOrdersPage()
    if not page then return end
    -- Patron / Guild / Personal are always a flat list. Leftover public
    -- buckets from the previous tab must not be treated as the current browse.
    if page.orderType ~= Enum.CraftingOrderType.Public then
        M._rawOrders = C_CraftingOrders.GetCrafterOrders()
        M._browseIsBucket = false
        return
    end
    local last = page.lastRequest
    if last and last.selectedSkillLineAbility then
        M._rawOrders = C_CraftingOrders.GetCrafterOrders()
        M._browseIsBucket = false
        return
    end
    local buckets = C_CraftingOrders.GetCrafterBuckets()
    if buckets and #buckets > 0 then
        M._rawOrders = buckets
        M._browseIsBucket = true
        return
    end
    M._rawOrders = C_CraftingOrders.GetCrafterOrders()
    M._browseIsBucket = false
end

function M:EnsureModeButton()
    if M._modeBtn then
        M:UpdateModeButton()
        return M._modeBtn
    end
    local browse = GetBrowseFrame()
    if not browse or not browse.PersonalOrdersButton then return nil end
    local btn = OneWoW_GUI:CreateFitTextButton(browse, {
        text = L["CRAFTORDERS_USE_WOWUI"],
        height = 22,
        minWidth = 48,
        paddingX = 16,
    })
    btn:SetPoint("LEFT", browse.PersonalOrdersButton, "RIGHT", 8, 0)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(browse.PersonalOrdersButton:GetFrameLevel() + 2)
    btn:SetScript("OnClick", function()
        local useBlizzard = ns.ModuleRegistry:GetToggleValue("craftingorders", "useBlizzardList")
        ns.ModuleRegistry:SetToggleValue("craftingorders", "useBlizzardList", not useBlizzard)
    end)
    btn:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["CRAFTORDERS_TOGGLE_WOWUI"])
        GameTooltip:AddLine(L["CRAFTORDERS_TOGGLE_WOWUI_DESC"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    M._modeBtn = btn

    local settingsBtn = OneWoW_GUI:CreateIconButton(browse, {
        iconTexture = OneWoW_GUI.Constants.MEDIA_BASE .. "icon-gears.png",
        size = 22,
        tooltipTitle = L["OPEN_SETTINGS"],
        onClick = function()
            ns.UI.SelectFeature("craftingorders")
        end,
    })
    settingsBtn:SetPoint("LEFT", btn, "RIGHT", SPACING.SM, 0)
    settingsBtn:SetFrameStrata("HIGH")
    settingsBtn:SetFrameLevel(browse.PersonalOrdersButton:GetFrameLevel() + 2)
    M._settingsBtn = settingsBtn

    OneWoW_GUI:RegisterFontRoot(btn, function()
        M:UpdateModeButton()
    end)
    M:UpdateModeButton()
    return btn
end

function M:UpdateModeButton()
    local btn = M._modeBtn
    if not btn then return end
    if not ModuleOn() then
        btn:Hide()
        if M._settingsBtn then
            M._settingsBtn:Hide()
        end
        return
    end
    btn:Show()
    M._settingsBtn:Show()
    if M:WantsOverlay() then
        btn:SetFitText(L["CRAFTORDERS_USE_WOWUI"])
    else
        btn:SetFitText(L["CRAFTORDERS_USE_ONEUI"])
    end
end

--- Max icons per lane across the entry list (nil when there are no data
--- rows, meaning: keep the full-width default).
local function CountLaneUsage(entries)
    local any = false
    local you, customer, reward = 1, 1, 1
    local cart = false
    for i = 1, #entries do
        local e = entries[i]
        if e.kind ~= "header" then
            any = true
            local mats = M:FilterYouReagents(e.youReagents)
            if mats and #mats > you then
                you = #mats
            end
            if e.customerReagents and #e.customerReagents > customer then
                customer = #e.customerReagents
            end
            if e.rewardIcons and #e.rewardIcons > reward then
                reward = #e.rewardIcons
            end
            if M:RowShowsCart(e) then
                cart = true
            end
        end
    end
    if not any then
        return nil
    end
    return { you = you, customer = customer, reward = reward, cart = cart }
end

function M:RefreshOverlay()
    if not ModuleOn() then return end
    M:EnsureModeButton()
    if not M:WantsOverlay() then
        if M._overlay then
            M._overlay:Hide()
        end
        ShowBlizzardOrderList()
        return
    end
    local overlay = M:EnsureOverlay()
    if not overlay then return end
    local browse = GetBrowseFrame()
    if not browse or not browse:IsShown() then
        overlay:Hide()
        return
    end

    overlay:Show()
    HideBlizzardOrderList()
    ApplyOverlayTheme(overlay)
    M:UpdateStatusHeader()

    if not M._holdPull then
        M:PullCurrentOrders()
    end

    local page = GetOrdersPage()
    local orderType = page and page.orderType
    local entries, readyN, missingN = M:BuildOverlayEntries(M._rawOrders, M._browseIsBucket, orderType)
    M._entries = entries
    if M:SetLaneCounts(CountLaneUsage(entries)) then
        -- Lane widths follow the icons actually shown; re-anchor everything
        -- when the new entry list changes that usage.
        M:ApplyOverlayLayout()
    elseif overlay.virt then
        FinishOverlayList(overlay)
    end

    if M._loading and #entries == 0 then
        overlay.emptyText:SetText(L["CRAFTORDERS_LOADING"])
        overlay.emptyText:Show()
    elseif #entries == 0 then
        if orderType == Enum.CraftingOrderType.Public then
            overlay.emptyText:SetText(CRAFTER_CRAFTING_ORDERS_BROWSE_FAVORITES_TIP)
        else
            overlay.emptyText:SetText(PROFESSIONS_CUSTOMER_NO_ORDERS)
        end
        overlay.emptyText:Show()
    else
        overlay.emptyText:Hide()
    end
    return readyN, missingN
end

function M:ShowOverlay()
    if not ModuleOn() then return end
    M:EnsureModeButton()
    if not M:WantsOverlay() then
        M:HideOverlay()
        return
    end
    local overlay = M:EnsureOverlay()
    if not overlay then return end
    overlay:Show()
    -- The overlay can be created while the profession UI is hidden (width
    -- unknown); re-measure at show time and re-apply geometry in place.
    M:SetRowContentWidth((overlay:GetWidth() or 0) - HEADER_LEFT - OverlayChromeRight())
    M:ApplyOverlayLayout()
    HideBlizzardOrderList()
    M:RefreshOverlay()
end

function M:HideOverlay()
    if M._overlay then
        M._overlay:Hide()
    end
    M._listCraftActive = false
    M:RestoreOrderViewChrome()
    ShowBlizzardOrderList()
    M:UpdateModeButton()
end

function M:OnOrdersShown(page, orders)
    if not ModuleOn() then return end
    M._ordersPage = page
    M._loading = false
    if orders then
        M._rawOrders = orders
        local first = orders[1]
        M._browseIsBucket = first ~= nil and first.numAvailable ~= nil and first.orderID == nil
        if page.orderType ~= Enum.CraftingOrderType.Public then
            M._browseIsBucket = false
        end
    else
        M:PullCurrentOrders()
    end
    M._holdPull = true
    M:RefreshOverlay()
    M._holdPull = false
end

function M:OnOrderTypeChanged(page)
    if not ModuleOn() then return end
    M._ordersPage = page
    M._rawOrders = nil
    M._browseIsBucket = false
    -- Tab click still has the previous search in C_CraftingOrders until the
    -- new request returns. Do not pull that leftover list onto this tab.
    M._holdPull = true
    M._loading = false
    M:RefreshOverlay()
end

function M:OnOrdersRequestSent(page, request)
    if not ModuleOn() then return end
    M._ordersPage = page
    if request and request.offset and request.offset > 0 then
        return
    end
    M._holdPull = true
    M._loading = true
    M:RefreshOverlay()
end

function M:ApplyOverlayTheme()
    if M._overlay then
        ApplyOverlayTheme(M._overlay)
        M:RefreshOverlay()
    end
end
