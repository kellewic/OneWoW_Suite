local _, ns = ...
local M, L = ns.ModuleRegistry:Current()
if not M then return end

-- ============================================================================
-- Crafting Orders — Features layout editor
-- ============================================================================
-- Vertical column list (show/hide + CreateReorderDrag), icon-size sliders,
-- column-width sliders, Compact View, Hide scrollbar, hide-have-mats, and
-- the profit price-source picker. Overlay headers click to sort; column
-- reorder stays in Features (CreateReorderDrag), not header drag.
-- Features On/Off only enables the existing controls; rebuilding the card
-- stack from that click broke the toggle.
-- ============================================================================

local OneWoW_GUI = OneWoW_GUI

local collapsedCards = {}

local ROW_H = 28
local ROW_GAP = 4
local DESC_GAP = 4
local OPTION_GAP = 8

local function ApplyMutedWrap(fs, text, width)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    if width >= 1 then
        fs:SetWidth(width)
    end
    OneWoW_GUI:SetFontBaseSize(fs, 10)
    OneWoW_GUI:SafeSetFont(fs, OneWoW_GUI:GetFont(), 10)
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
end

local function PlaceCheckThenDesc(content, cb, desc, y)
    cb:ClearAllPoints()
    cb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    y = y - cb:GetMeasuredHeight() - DESC_GAP
    desc:ClearAllPoints()
    desc:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    return y - (desc:GetStringHeight() or 14) - OPTION_GAP
end

local function CopyOrder(src)
    local out = {}
    for i = 1, #src do
        out[i] = src[i]
    end
    return out
end

local function SetControlEnabled(widget, enabled)
    if not widget then return end
    if enabled then
        widget:Enable()
    else
        widget:Disable()
    end
end

local function BuildContent(cardsHost, isEnabled, applyHostHeight)
    local detailEnabled = isEnabled == true
    local function IsDetailEnabled()
        return detailEnabled
    end

    local stack = OneWoW_GUI:CreateCardStack(cardsHost, {
        getCollapsed = function(key) return collapsedCards[key] end,
        setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    })
    stack.OnRelayout = applyHostHeight

    local widgets = {
        sliders = {},
        widthSliders = {},
        widthLabels = {},
    }
    local refreshLayoutWidgets
    local applyEnabled

    local function SyncSizeControls()
        local sizesOn = IsDetailEnabled() and not M:IsTight()
        if widgets.tightCb then
            widgets.tightCb:SetChecked(M:IsTight())
            SetControlEnabled(widgets.tightCb, IsDetailEnabled())
        end
        for i = 1, #widgets.sliders do
            SetControlEnabled(widgets.sliders[i].slider, sizesOn)
        end
        if widgets.sizeLabels then
            local color = sizesOn and "TEXT_PRIMARY" or "TEXT_MUTED"
            for i = 1, #widgets.sizeLabels do
                widgets.sizeLabels[i]:SetTextColor(OneWoW_GUI:GetThemeColor(color))
            end
        end
    end

    local function RefreshShownSliders()
        if widgets.relayoutSizeSliders then
            widgets.relayoutSizeSliders()
        end
        if widgets.relayoutWidthSliders then
            widgets.relayoutWidthSliders()
        end
        stack:Relayout()
    end

    local incompat = M:CollectIncompatibleTitles()
    if #incompat > 0 then
        widgets.incompatCard = stack:AddCard("craftingorders:incompat", L["CRAFTORDERS_INCOMPATIBLE_TITLE"], function(content, contentWidth)
            local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(true)
            local w = tonumber(contentWidth) or 0
            if w >= 1 then
                fs:SetWidth(w)
            else
                fs:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
            end
            fs:SetTextColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
            fs:SetText(L["CRAFTORDERS_INCOMPATIBLE_BODY"]:format(table.concat(incompat, ", ")))
            return math.max(1, fs:GetStringHeight())
        end)
    end

    stack:AddCard("craftingorders:columns", L["CRAFTORDERS_LAYOUT_COLUMNS"], function(content, contentWidth)
        local hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        hint:SetJustifyH("LEFT")
        hint:SetWordWrap(true)
        local w = tonumber(contentWidth) or 0
        if w >= 1 then
            hint:SetWidth(w)
        else
            hint:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
        end
        hint:SetText(L["CRAFTORDERS_DRAG_HINT"])
        hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local host = CreateFrame("Frame", nil, content)
        local hintH = hint:GetStringHeight() or 14
        host:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(hintH + 8))
        host:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(hintH + 8))

        local rows = {}
        local reorderCtrl
        widgets.columnRows = rows

        local function RelayoutRows()
            local y = 0
            for i = 1, #rows do
                rows[i]:ClearAllPoints()
                rows[i]:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y)
                rows[i]:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, y)
                y = y - ROW_H - ROW_GAP
            end
            host:SetHeight(math.max(1, -y))
        end

        local function RebuildRows()
            for i = 1, #rows do
                if reorderCtrl then
                    reorderCtrl:Detach(rows[i])
                end
                rows[i]:Hide()
                rows[i]:SetParent(nil)
            end
            wipe(rows)

            local layout = M:GetLayout()
            for i = 1, #layout.order do
                local id = layout.order[i]
                local row = OneWoW_GUI:CreateFrame(host, {
                    height = ROW_H,
                    bgColor = "BG_TERTIARY",
                    borderColor = "BORDER_SUBTLE",
                })
                row:EnableMouse(true)
                row._colId = id

                local cb = OneWoW_GUI:CreateCheckbox(row, {
                    label = M:ColumnLabel(id),
                    checked = layout.hidden[id] ~= true,
                    onClick = function(myself)
                        M:SetColumnHidden(id, not myself:GetChecked())
                        RefreshShownSliders()
                    end,
                })
                cb:SetPoint("LEFT", row, "LEFT", 4, 0)
                row.cb = cb
                SetControlEnabled(cb, IsDetailEnabled())

                local gripA = row:CreateTexture(nil, "ARTWORK")
                gripA:SetSize(2, 12)
                gripA:SetPoint("RIGHT", row, "RIGHT", -10, 0)
                gripA:SetColorTexture(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                gripA:SetAlpha(0.55)
                local gripB = row:CreateTexture(nil, "ARTWORK")
                gripB:SetSize(2, 12)
                gripB:SetPoint("RIGHT", gripA, "LEFT", -3, 0)
                gripB:SetColorTexture(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                gripB:SetAlpha(0.55)

                rows[#rows + 1] = row
                if reorderCtrl then
                    reorderCtrl:Attach(row, #rows)
                    row._reorderAttached = true
                    row:EnableMouse(IsDetailEnabled())
                end
            end
            RelayoutRows()
        end

        local r, g, b = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
        reorderCtrl = OneWoW_GUI:CreateReorderDrag({
            getItems = function()
                return rows
            end,
            dropIndicator = {
                thickness = 2,
                horizontalPadding = 4,
                color = { r, g, b, 1 },
            },
            onReorder = function(fromIdx, toIdx, insertBefore)
                local destIdx = insertBefore and toIdx or (toIdx + 1)
                if destIdx > fromIdx then
                    destIdx = destIdx - 1
                end
                if destIdx == fromIdx then
                    return
                end
                local order = CopyOrder(M:GetLayout().order)
                local id = tremove(order, fromIdx)
                tinsert(order, destIdx, id)
                M:SetColumnOrder(order)
                RebuildRows()
                RefreshShownSliders()
            end,
            onPickup = function(row)
                row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            end,
            onRestore = function(row)
                row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end,
        })
        widgets.reorderCtrl = reorderCtrl

        RebuildRows()

        local goldOnlyCb = OneWoW_GUI:CreateCheckbox(content, {
            label = L["CRAFTORDERS_GOLD_ONLY"],
            checked = M:GetLayout().goldOnly == true,
            onClick = function(myself)
                M:SetGoldOnly(myself:GetChecked())
            end,
        })
        goldOnlyCb:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, -8)
        SetControlEnabled(goldOnlyCb, IsDetailEnabled())
        widgets.goldOnlyCb = goldOnlyCb

        local goldOnlyDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        goldOnlyDesc:SetPoint("TOPLEFT", goldOnlyCb, "BOTTOMLEFT", 0, -2)
        goldOnlyDesc:SetJustifyH("LEFT")
        goldOnlyDesc:SetWordWrap(true)
        if w >= 1 then
            goldOnlyDesc:SetWidth(w)
        else
            goldOnlyDesc:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
        end
        goldOnlyDesc:SetText(L["CRAFTORDERS_GOLD_ONLY_DESC"])
        goldOnlyDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local resetBtn = OneWoW_GUI:CreateFitTextButton(content, {
            text = RESET,
            height = 22,
        })
        resetBtn:SetPoint("TOPLEFT", goldOnlyDesc, "BOTTOMLEFT", 0, -8)
        resetBtn:SetScript("OnClick", function()
            M:ResetLayout()
            if refreshLayoutWidgets then
                refreshLayoutWidgets()
            end
        end)
        SetControlEnabled(resetBtn, IsDetailEnabled())
        widgets.resetBtn = resetBtn

        refreshLayoutWidgets = function()
            RebuildRows()
            local layout = M:GetLayout()
            for i = 1, #widgets.sliders do
                local sl = widgets.sliders[i]
                sl.slider:SetValue(layout.sizes[sl._sizeKey])
            end
            for i = 1, #widgets.widthSliders do
                local sl = widgets.widthSliders[i]
                sl.slider:SetValue(layout.widths[sl._widthId])
            end
            if widgets.hideHaveCb then
                widgets.hideHaveCb:SetChecked(layout.hideHaveMats == true)
            end
            if widgets.goldOnlyCb then
                widgets.goldOnlyCb:SetChecked(layout.goldOnly == true)
            end
            if widgets.hideScrollCb then
                widgets.hideScrollCb:SetChecked(layout.hideScrollBar == true)
            end
            if widgets.profitDd then
                local src = M:GetPriceSource()
                widgets.profitDd._activeValue = src
                widgets.profitDdText:SetText(M:PriceSourceLabel(src))
                widgets.profitIcon:SetTexture(M:PriceSourceIcon(src))
            end
            if widgets.updateProfitSourceDetail then
                widgets.updateProfitSourceDetail()
            end
            SyncSizeControls()
            RefreshShownSliders()
        end

        local goldOnlyH = goldOnlyCb:GetHeight() + 2 + (goldOnlyDesc:GetStringHeight() or 14)
        return hintH + 8 + host:GetHeight() + 8 + goldOnlyH + 8 + 22
    end)

    widgets.sizeCard = stack:AddCard("craftingorders:sizes", L["CRAFTORDERS_LAYOUT_SIZES"], function(content, contentWidth)
        wipe(widgets.sliders)
        local layout = M:GetLayout()
        local y = 0

        local tightCb = OneWoW_GUI:CreateCheckbox(content, {
            label = L["CRAFTORDERS_TIGHT"],
            checked = layout.tight == true,
            onClick = function(myself)
                M:SetTight(myself:GetChecked())
                SyncSizeControls()
            end,
        })
        SetControlEnabled(tightCb, IsDetailEnabled())
        widgets.tightCb = tightCb

        local descW = tonumber(contentWidth) or 0
        local tightDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ApplyMutedWrap(tightDesc, L["CRAFTORDERS_TIGHT_DESC"], descW)
        widgets.tightDesc = tightDesc
        y = PlaceCheckThenDesc(content, tightCb, tightDesc, y)

        local hideScrollCb = OneWoW_GUI:CreateCheckbox(content, {
            label = L["CRAFTORDERS_HIDE_SCROLLBAR"],
            checked = layout.hideScrollBar == true,
            onClick = function(myself)
                M:SetHideScrollBar(myself:GetChecked())
            end,
        })
        SetControlEnabled(hideScrollCb, IsDetailEnabled())
        widgets.hideScrollCb = hideScrollCb

        local hideScrollDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ApplyMutedWrap(hideScrollDesc, L["CRAFTORDERS_HIDE_SCROLLBAR_DESC"], descW)
        widgets.hideScrollDesc = hideScrollDesc
        y = PlaceCheckThenDesc(content, hideScrollCb, hideScrollDesc, y)

        local keys = {
            { key = "product", label = L["CRAFTORDERS_SIZE_ITEM"] },
            { key = "you", label = L["CRAFTORDERS_SIZE_YOU"], colId = "you" },
            { key = "customer", label = L["CRAFTORDERS_SIZE_CUSTOMER"], colId = "customer" },
            { key = "reward", label = L["CRAFTORDERS_SIZE_REWARD"], colId = "reward" },
        }
        local lane = M:LaneConstants()
        widgets.sizeLabels = {}
        widgets.sizeRows = {}
        for i = 1, #keys do
            local spec = keys[i]
            local lbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            lbl:SetText(spec.label)
            lbl:SetTextColor(OneWoW_GUI:GetThemeColor(IsDetailEnabled() and "TEXT_PRIMARY" or "TEXT_MUTED"))
            widgets.sizeLabels[#widgets.sizeLabels + 1] = lbl
            y = y - (lbl:GetStringHeight() or 14) - 4

            local sl = OneWoW_GUI:CreateSlider(content, {
                minVal = lane.sizeMin,
                maxVal = lane.sizeMax,
                step = 1,
                currentVal = layout.sizes[spec.key],
                width = 240,
                fmt = "%.0f",
                onChange = function(val)
                    M:SetIconSize(spec.key, val)
                end,
            })
            sl:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            sl._sizeKey = spec.key
            widgets.sliders[#widgets.sliders + 1] = sl
            widgets.sizeRows[#widgets.sizeRows + 1] = { lbl = lbl, sl = sl, colId = spec.colId }
            y = y - 42
        end
        SyncSizeControls()

        widgets.relayoutSizeSliders = function()
            local shown = M:GetLayout()
            local nextY = 0
            if widgets.tightCb and widgets.tightDesc then
                nextY = PlaceCheckThenDesc(content, widgets.tightCb, widgets.tightDesc, nextY)
            end
            if widgets.hideScrollCb and widgets.hideScrollDesc then
                nextY = PlaceCheckThenDesc(content, widgets.hideScrollCb, widgets.hideScrollDesc, nextY)
            end
            for i = 1, #widgets.sizeRows do
                local row = widgets.sizeRows[i]
                local show = not row.colId or shown.hidden[row.colId] ~= true
                if show then
                    row.lbl:Show()
                    row.sl:Show()
                    row.lbl:ClearAllPoints()
                    row.lbl:SetPoint("TOPLEFT", content, "TOPLEFT", 0, nextY)
                    nextY = nextY - (row.lbl:GetStringHeight() or 14) - 4
                    row.sl:ClearAllPoints()
                    row.sl:SetPoint("TOPLEFT", content, "TOPLEFT", 12, nextY)
                    nextY = nextY - 42
                else
                    row.lbl:Hide()
                    row.sl:Hide()
                end
            end
            local h = math.max(1, -nextY)
            if widgets.sizeCard then
                widgets.sizeCard:SetContentHeight(h)
            end
            return h
        end
        return widgets.relayoutSizeSliders()
    end)

    widgets.widthCard = stack:AddCard("craftingorders:widths", L["CRAFTORDERS_LAYOUT_WIDTHS"], function(content, contentWidth)
        wipe(widgets.widthSliders)
        wipe(widgets.widthLabels)
        widgets.widthById = {}
        local layout = M:GetLayout()
        local y = 0

        local hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        hint:SetJustifyH("LEFT")
        hint:SetWordWrap(true)
        local hintW = tonumber(contentWidth) or 0
        if hintW >= 1 then
            hint:SetWidth(hintW)
        else
            hint:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
        end
        hint:SetText(L["CRAFTORDERS_WIDTH_HINT"])
        hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        y = y - (hint:GetStringHeight() or 14) - 10
        local widthStartY = y

        local ids = M:ColumnIds()
        for i = 1, #ids do
            local id = ids[i]
            local minW, maxW = M:ColumnWidthRange(id)
            local lbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            lbl:SetText(M:ColumnLabel(id))
            lbl:SetTextColor(OneWoW_GUI:GetThemeColor(IsDetailEnabled() and "TEXT_PRIMARY" or "TEXT_MUTED"))
            widgets.widthLabels[#widgets.widthLabels + 1] = lbl
            y = y - (lbl:GetStringHeight() or 14) - 4

            local sl = OneWoW_GUI:CreateSlider(content, {
                minVal = minW,
                maxVal = maxW,
                step = 1,
                currentVal = layout.widths[id],
                width = 240,
                fmt = "%.0f",
                onChange = function(val)
                    M:SetColumnWidth(id, val)
                end,
            })
            sl:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            sl._widthId = id
            SetControlEnabled(sl.slider, IsDetailEnabled())
            widgets.widthSliders[#widgets.widthSliders + 1] = sl
            widgets.widthById[id] = { lbl = lbl, sl = sl }
            y = y - 42
        end

        widgets.relayoutWidthSliders = function()
            local shown = M:GetLayout()
            local nextY = widthStartY
            for i = 1, #shown.order do
                local id = shown.order[i]
                local row = widgets.widthById[id]
                if shown.hidden[id] ~= true then
                    row.lbl:Show()
                    row.sl:Show()
                    row.lbl:ClearAllPoints()
                    row.lbl:SetPoint("TOPLEFT", content, "TOPLEFT", 0, nextY)
                    nextY = nextY - (row.lbl:GetStringHeight() or 14) - 4
                    row.sl:ClearAllPoints()
                    row.sl:SetPoint("TOPLEFT", content, "TOPLEFT", 12, nextY)
                    nextY = nextY - 42
                else
                    row.lbl:Hide()
                    row.sl:Hide()
                end
            end
            local h = math.max(1, -nextY)
            if widgets.widthCard then
                widgets.widthCard:SetContentHeight(h)
            end
            return h
        end
        return widgets.relayoutWidthSliders()
    end)

    stack:AddCard("craftingorders:mats", L["CRAFTORDERS_LAYOUT_MATS"], function(content, contentWidth)
        local layout = M:GetLayout()
        local cb = OneWoW_GUI:CreateCheckbox(content, {
            label = L["CRAFTORDERS_HIDE_HAVE"],
            checked = layout.hideHaveMats == true,
            onClick = function(myself)
                M:SetHideHaveMats(myself:GetChecked())
            end,
        })
        cb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        SetControlEnabled(cb, IsDetailEnabled())
        widgets.hideHaveCb = cb

        local desc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        desc:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -32)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        local w = tonumber(contentWidth) or 0
        if w >= 1 then
            desc:SetWidth(w)
        else
            desc:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -32)
        end
        desc:SetText(L["CRAFTORDERS_HIDE_HAVE_DESC"])
        desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        return 32 + (desc:GetStringHeight() or 14)
    end)

    stack:AddCard("craftingorders:profit", L["CRAFTORDERS_LAYOUT_PROFIT"], function(content, contentWidth)
        local src = M:GetPriceSource()
        local icon = content:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -2)
        icon:SetTexture(M:PriceSourceIcon(src))
        widgets.profitIcon = icon

        local lbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        lbl:SetText(L["CRAFTORDERS_PROFIT_SOURCE"])
        lbl:SetTextColor(OneWoW_GUI:GetThemeColor(IsDetailEnabled() and "TEXT_PRIMARY" or "TEXT_MUTED"))
        widgets.profitLbl = lbl

        local dd, ddText = OneWoW_GUI:CreateDropdown(content, {
            width = 220,
            height = 26,
            text = M:PriceSourceLabel(src),
        })
        dd:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -28)
        dd._activeValue = src
        OneWoW_GUI:AttachFilterMenu(dd, {
            searchable = false,
            menuHeight = 140,
            buildItems = function()
                local items = {}
                local list = M:DetectedPriceSources()
                for i = 1, #list do
                    local id = list[i]
                    items[#items + 1] = { value = id, text = M:PriceSourceLabel(id) }
                end
                return items
            end,
            getActiveValue = function()
                return M:GetPriceSource()
            end,
            onSelect = function(value, text)
                M:SetPriceSource(value)
                dd._activeValue = value
                ddText:SetText(text)
                icon:SetTexture(M:PriceSourceIcon(value))
                if widgets.updateProfitSourceDetail then
                    widgets.updateProfitSourceDetail()
                end
                M:ApplyOverlayLayout()
            end,
        })
        widgets.profitDd = dd
        widgets.profitDdText = ddText
        if IsDetailEnabled() then
            dd:Enable()
            ddText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            dd:Disable()
            ddText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end

        local tsmLine = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tsmLine:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -8)
        tsmLine:SetJustifyH("LEFT")
        widgets.profitTsmLine = tsmLine

        local tsmHint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tsmHint:SetPoint("TOPLEFT", tsmLine, "BOTTOMLEFT", 0, -4)
        tsmHint:SetJustifyH("LEFT")
        tsmHint:SetWordWrap(true)
        local hintW = tonumber(contentWidth) or 0
        if hintW >= 1 then
            tsmHint:SetWidth(hintW)
        else
            tsmHint:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
        end
        tsmHint:SetText(L["CRAFTORDERS_PROFIT_TSM_HINT"])
        tsmHint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        widgets.profitTsmHint = tsmHint

        local function UpdateProfitSourceDetail()
            local cur = M:GetPriceSource()
            if cur == "tsm" then
                tsmLine:SetText(M:GetTSMPriceString())
                tsmLine:SetTextColor(OneWoW_GUI:GetThemeColor(IsDetailEnabled() and "TEXT_PRIMARY" or "TEXT_MUTED"))
                tsmLine:Show()
                tsmHint:Show()
            else
                tsmLine:SetText("")
                tsmLine:Hide()
                tsmHint:Hide()
            end
        end
        widgets.updateProfitSourceDetail = UpdateProfitSourceDetail
        UpdateProfitSourceDetail()

        return 28 + 26 + 8 + 18 + 4 + (tsmHint:GetStringHeight() or 14)
    end)

    applyEnabled = function(enabled)
        detailEnabled = enabled == true
        local rows = widgets.columnRows
        if rows then
            for i = 1, #rows do
                local row = rows[i]
                SetControlEnabled(row.cb, detailEnabled)
                row:EnableMouse(detailEnabled)
            end
        end
        SetControlEnabled(widgets.resetBtn, detailEnabled)
        SetControlEnabled(widgets.goldOnlyCb, detailEnabled)
        SyncSizeControls()
        SetControlEnabled(widgets.hideHaveCb, detailEnabled)
        SetControlEnabled(widgets.hideScrollCb, detailEnabled)
        for i = 1, #widgets.widthSliders do
            SetControlEnabled(widgets.widthSliders[i].slider, detailEnabled)
        end
        if widgets.widthLabels then
            local color = detailEnabled and "TEXT_PRIMARY" or "TEXT_MUTED"
            for i = 1, #widgets.widthLabels do
                widgets.widthLabels[i]:SetTextColor(OneWoW_GUI:GetThemeColor(color))
            end
        end
        if widgets.profitLbl then
            widgets.profitLbl:SetTextColor(OneWoW_GUI:GetThemeColor(detailEnabled and "TEXT_PRIMARY" or "TEXT_MUTED"))
        end
        if widgets.profitDd then
            SetControlEnabled(widgets.profitDd, detailEnabled)
            widgets.profitDdText:SetTextColor(OneWoW_GUI:GetThemeColor(detailEnabled and "TEXT_PRIMARY" or "TEXT_MUTED"))
        end
        if widgets.updateProfitSourceDetail then
            widgets.updateProfitSourceDetail()
        end

        local incompatCard = widgets.incompatCard
        if incompatCard then
            local titles = M:CollectIncompatibleTitles()
            if #titles == 0 then
                incompatCard:Hide()
                for i = 1, #stack.items do
                    if stack.items[i] == incompatCard then
                        tremove(stack.items, i)
                        break
                    end
                end
                widgets.incompatCard = nil
                stack:Relayout()
            end
        end
    end

    stack:Finish()
    return stack, applyEnabled, refreshLayoutWidgets
end

function M:CreateCustomDetail(parent, yOffset, isEnabled, registerRefresh)
    local cardsHost = CreateFrame("Frame", nil, parent)
    cardsHost:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    cardsHost:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)

    local function applyHostHeight()
        local h = math.max(1, cardsHost:GetHeight())
        if parent.UpdateDetailHeight then
            parent:SetHeight(h)
            parent.UpdateDetailHeight()
        else
            parent:SetHeight(math.abs(yOffset) + h + 20)
            if parent.updateThumb then
                parent.updateThumb()
            end
        end
    end

    local _, applyEnabled, refreshLayoutWidgets = BuildContent(cardsHost, isEnabled, applyHostHeight)
    applyHostHeight()
    M._refreshCustomDetail = refreshLayoutWidgets

    if registerRefresh then
        registerRefresh(function()
            if applyEnabled then
                applyEnabled(ns.ModuleRegistry:IsEnabled("craftingorders"))
            end
        end)
    end

    return yOffset - cardsHost:GetHeight()
end
