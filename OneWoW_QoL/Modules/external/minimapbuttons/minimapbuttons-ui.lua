local _, ns = ...
local MinimapButtonsModule, L = ns.ModuleRegistry:Current()

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

-- Session-only collapse memory (survives tab switches; cleared on /reload).
local collapsedCards = {}

local function GetSettings()
    return MinimapButtonsModule.GetSettings()
end

-- ─── Detected minimap icons (per-button Collector / Map / Hide) ────────────

-- Build one row for a single detected (or previously-detected) minimap icon:
--
--   [X]  Outfitter             Enabled    [Collector ▼]
--
-- The X drops the entry from the DB (useful for stale addons that were
-- uninstalled). The dropdown sets the user's preference; ApplyButtonPref
-- moves the button between the collector panel, the minimap, or an offscreen
-- hidden frame. Enabled/Disabled reflects whether the owning addon is loaded.
local ROW_PADDING_X   = 12
local ICON_ROW_HEIGHT = 28
local ICON_ROW_GAP    = 4

local function PrefLabel(pref)
    if pref == "mini" then return L["MMBTNS_ICONS_MINI"] end
    if pref == "map" then return L["MMBTNS_ICONS_MAP"] end
    if pref == "hide" then return HIDE end
    return L["MMBTNS_ICONS_MINI"]
end

local function BuildIconRow(parent, info, yOffset, refreshFn, zebraIndex)
    local capturedName = info.name
    local pref = info.pref or "mini"

    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(ICON_ROW_HEIGHT)
    row:SetPoint("TOPLEFT",  parent, "TOPLEFT",   ROW_PADDING_X, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -ROW_PADDING_X, yOffset)
    row:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    row._zebraIndex = zebraIndex or 1
    OneWoW_GUI:ApplyListRowFill(row, { zebraIndex = row._zebraIndex })
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    -- Removal is only allowed for stale entries (addon currently disabled /
    -- unloaded). Enabled rows keep the X visible for alignment but greyed out
    -- and non-clickable, so the user can't accidentally drop a row they're
    -- actively using.
    local removeBtn = CreateFrame("Button", nil, row)
    removeBtn:SetSize(14, 14)
    removeBtn:SetPoint("LEFT", row, "LEFT", 6, 0)
    removeBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    if info.seen then
        removeBtn:EnableMouse(false)
        local tex = removeBtn:GetNormalTexture()
        if tex then tex:SetVertexColor(0.4, 0.4, 0.4, 0.6) end
        removeBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L["MMBTNS_ICONS_REMOVE_LOCKED_TT"], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        removeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
        removeBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["MMBTNS_ICONS_REMOVE_TT"])
            GameTooltip:Show()
        end)
        removeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        removeBtn:SetScript("OnClick", function()
            MinimapButtonsModule.RemoveKnownButton(capturedName)
            if refreshFn then refreshFn() end
        end)
    end

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", removeBtn, "RIGHT", 8, 0)
    label:SetJustifyH("LEFT")
    label:SetText(info.displayName or capturedName)
    label:SetTextColor(OneWoW_GUI:GetThemeColor(info.seen and "TEXT_PRIMARY" or "TEXT_MUTED"))

    local prefDropdown, prefDropdownText = OneWoW_GUI:CreateDropdown(row, {
        width = 110,
        height = 22,
        text = PrefLabel(pref),
    })
    prefDropdown:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    prefDropdown._activeValue = pref

    OneWoW_GUI:AttachFilterMenu(prefDropdown, {
        searchable = false,
        menuHeight = 110,
        buildItems = function()
            return {
                { value = "mini", text = L["MMBTNS_ICONS_MINI"] },
                { value = "map", text = L["MMBTNS_ICONS_MAP"] },
                { value = "hide", text = HIDE },
            }
        end,
        getActiveValue = function()
            return prefDropdown._activeValue
        end,
        onSelect = function(value, text)
            prefDropdown._activeValue = value
            prefDropdownText:SetText(text)
            MinimapButtonsModule:ApplyButtonPref(capturedName, value)
        end,
    })

    local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("RIGHT", prefDropdown, "LEFT", -10, 0)
    statusText:SetJustifyH("RIGHT")
    statusText:SetText(info.seen and L["MMBTNS_ICONS_ENABLED"] or L["MMBTNS_ICONS_DISABLED"])
    statusText:SetTextColor(OneWoW_GUI:GetThemeColor(
        info.seen and "TEXT_FEATURES_ENABLED" or "TEXT_FEATURES_DISABLED"))

    label:SetPoint("RIGHT", statusText, "LEFT", -8, 0)

    return yOffset - ICON_ROW_HEIGHT - ICON_ROW_GAP
end

-- Card title is MMBTNS_ICONS_HEADER; body is desc + icon rows only.
-- IMPORTANT: never anchor the next element with yOffset arithmetic off a
-- wrapped FontString — GetStringHeight() can return the unwrapped (single
-- line) value if the parent's width hasn't propagated at build time,
-- which makes the rows render on top of the description. Anchor the rows
-- container to desc:BOTTOMLEFT/RIGHT instead so layout follows whatever
-- the engine actually paints.
local function BuildMinimapIconsSection(parent, yOffset, refreshFn)
    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT",  parent, "TOPLEFT",   ROW_PADDING_X, yOffset)
    desc:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -ROW_PADDING_X, yOffset)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetSpacing(2)
    desc:SetText(L["MMBTNS_ICONS_DESC"]
        or "Each detected minimap icon is listed here. Pick where it should live: Collector (inside the OneWoW panel), Map (back on the minimap), or Hide (out of sight entirely). The X removes a stale entry for an addon you've uninstalled.")
    desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    -- Re-scan every time the settings panel is rebuilt so the Enabled /
    -- Disabled status reflects the current addon state, not whatever was
    -- cached at module load time.
    MinimapButtonsModule:DiscoverButtons()

    local buttons = MinimapButtonsModule:GetKnownButtons()

    local rowsContainer = CreateFrame("Frame", nil, parent)
    rowsContainer:SetPoint("TOPLEFT",  desc, "BOTTOMLEFT",  0, -10)
    rowsContainer:SetPoint("TOPRIGHT", desc, "BOTTOMRIGHT", 0, -10)

    if #buttons == 0 then
        local empty = rowsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        empty:SetPoint("TOPLEFT",  rowsContainer, "TOPLEFT",  0, 0)
        empty:SetPoint("TOPRIGHT", rowsContainer, "TOPRIGHT", 0, 0)
        empty:SetJustifyH("CENTER")
        empty:SetWordWrap(true)
        empty:SetText(L["MMBTNS_ICONS_EMPTY"]
            or "No minimap icons detected yet. Open the collector to trigger a scan, then re-open Settings.")
        empty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        rowsContainer:SetHeight((empty:GetStringHeight() or 14) + 8)
    else
        local localY = 0
        for i, info in ipairs(buttons) do
            localY = BuildIconRow(rowsContainer, info, localY, refreshFn, i)
        end
        rowsContainer:SetHeight(math.abs(localY) + 4)
    end

    -- For the outer yOffset accounting we still need *some* estimate of the
    -- description's rendered height. GetStringHeight may under-report on
    -- first build; pad generously so the scroll area is never shorter than
    -- the content. The rows themselves are positioned correctly regardless
    -- because rowsContainer is anchored relative to desc, not via this math.
    local descH = desc:GetStringHeight() or 14
    if descH < 28 then descH = 28 end
    return yOffset - descH - 10 - rowsContainer:GetHeight() - 4
end

-- ─── Helpers ────────────────────────────────────────────────────────────────

local ROW_HEIGHT   = 28
local SLIDER_HEIGHT = 42

local function AddLabel(parent, cy, text, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, cy)
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor(color or "TEXT_SECONDARY"))
    return fs, cy - fs:GetStringHeight() - 4
end

local function AddDescription(parent, cy, text, contentWidth)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local left, right = 36, 12
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", left, cy)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetSpacing(2)
    -- Card content width may still be 0 at build time; SetWidth from the
    -- stack's contentWidth so GetStringHeight reflects wrapped lines.
    local w = tonumber(contentWidth) or 0
    if w < 1 then
        w = parent:GetWidth() or 0
    end
    if w >= 1 then
        fs:SetWidth(math.max(1, w - left - right))
    else
        fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -right, cy)
    end
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    return fs, cy - (fs:GetStringHeight() or 14) - 8
end

-- ─── Main settings content builder ─────────────────────────────────────────

local function BuildContent(container, onRelayout)
    local s = GetSettings()

    local stack = OneWoW_GUI:CreateCardStack(container, {
        getCollapsed = function(key) return collapsedCards[key] end,
        setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    })
    if onRelayout then
        stack.OnRelayout = onRelayout
    end

    -- ── Behavior ────────────────────────────────────────────────────────────
    stack:AddCard("mmbtns:behavior", L["MMBTNS_BEHAVIOR_HEADER"], function(content, contentWidth)
        local cy = 0

        local closeMode = s.closeMode or "autoclose"
        local closeLabels = {
            stayopen = L["MMBTNS_STAY_OPEN"],
            autoclose = L["MMBTNS_AUTO_CLOSE"],
        }

        local closeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        closeLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 12, cy)
        closeLabel:SetText(L["MMBTNS_CLOSE_MODE"] .. ":")
        closeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local closeDropdown, closeDropdownText = OneWoW_GUI:CreateDropdown(content, {
            width = 140,
            height = 26,
            text = closeLabels[closeMode] or closeLabels.autoclose,
        })
        closeDropdown:SetPoint("LEFT", closeLabel, "RIGHT", 8, 0)
        closeDropdown._activeValue = closeMode

        OneWoW_GUI:AttachFilterMenu(closeDropdown, {
            searchable = false,
            menuHeight = 90,
            buildItems = function()
                return {
                    { value = "stayopen", text = L["MMBTNS_STAY_OPEN"] },
                    { value = "autoclose", text = L["MMBTNS_AUTO_CLOSE"] },
                }
            end,
            getActiveValue = function()
                return GetSettings().closeMode or "autoclose"
            end,
            onSelect = function(value, text)
                local prev = s.closeMode
                s.closeMode = value
                closeDropdown._activeValue = value
                closeDropdownText:SetText(text)
                if value == "stayopen" then
                    MinimapButtonsModule:CancelAutoCloseTimer()
                end
                if prev ~= value then
                    MinimapButtonsModule._refreshCustomDetail()
                end
            end,
        })
        cy = cy - 32

        if s.closeMode == "autoclose" then
            local delayLabel
            delayLabel, cy = AddLabel(content, cy,
                string.format("%s: %d", L["MMBTNS_AUTO_CLOSE_DELAY"], s.autoCloseDelay or 3))

            local delaySlider = OneWoW_GUI:CreateSlider(content, {
                minVal     = 1,
                maxVal     = 10,
                step       = 1,
                currentVal = s.autoCloseDelay or 3,
                width      = 260,
                fmt        = "%d",
                onChange    = function(val)
                    s.autoCloseDelay = val
                    delayLabel:SetText(string.format("%s: %d", L["MMBTNS_AUTO_CLOSE_DELAY"], val))
                end,
            })
            delaySlider:SetPoint("TOPLEFT", content, "TOPLEFT", 24, cy)
            cy = cy - SLIDER_HEIGHT
        end

        local enhCB = OneWoW_GUI:CreateCheckbox(content, {
            label  = L["MMBTNS_ENHANCED_MENU"],
            checked = s.enhancedMenu,
            onClick = function(self)
                s.enhancedMenu = self:GetChecked()
                MinimapButtonsModule:Refresh()
                MinimapButtonsModule._refreshCustomDetail()
            end,
        })
        enhCB:SetPoint("TOPLEFT", content, "TOPLEFT", 12, cy)
        cy = cy - ROW_HEIGHT

        local enhDesc, descCy = AddDescription(content, cy, L["MMBTNS_ENHANCED_MENU_DESC"], contentWidth)
        cy = descCy

        local extrasShown = false
        if s.enhancedMenu then
            extrasShown = true

            local style = OneWoW_GUI:GetSetting("featureIcons.style")
            if style ~= "ringless" then
                style = "ring"
            end
            local styleLabels = {
                ring = L["MMBTNS_FEATURE_ICON_RING"],
                ringless = L["MMBTNS_FEATURE_ICON_RINGLESS"],
            }

            local styleLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            styleLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 12, cy)
            styleLabel:SetText(L["MMBTNS_FEATURE_ICON_STYLE"] .. ":")
            styleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

            local styleDropdown, styleDropdownText = OneWoW_GUI:CreateDropdown(content, {
                width = 140,
                height = 26,
                text = styleLabels[style],
            })
            styleDropdown:SetPoint("LEFT", styleLabel, "RIGHT", 8, 0)
            styleDropdown._activeValue = style

            OneWoW_GUI:AttachFilterMenu(styleDropdown, {
                searchable = false,
                menuHeight = 90,
                buildItems = function()
                    return {
                        { value = "ring", text = L["MMBTNS_FEATURE_ICON_RING"] },
                        { value = "ringless", text = L["MMBTNS_FEATURE_ICON_RINGLESS"] },
                    }
                end,
                getActiveValue = function()
                    local v = OneWoW_GUI:GetSetting("featureIcons.style")
                    if v ~= "ringless" then
                        return "ring"
                    end
                    return v
                end,
                onSelect = function(value, text)
                    styleDropdown._activeValue = value
                    styleDropdownText:SetText(text)
                    OneWoW_GUI:SetSetting("featureIcons.style", value)
                end,
            })
            cy = cy - 32

            local _, styleCy = AddDescription(content, cy, L["MMBTNS_FEATURE_ICON_STYLE_DESC"], contentWidth)
            cy = styleCy

            local _, extrasCy = AddDescription(content, cy, L["MMBTNS_ENHANCED_EXTRAS_DESC"], contentWidth)
            cy = extrasCy

            for _, tile in ipairs(MinimapButtonsModule:GetEnhancedTileCatalog()) do
                local capturedId = tile.id
                local cb = OneWoW_GUI:CreateCheckbox(content, {
                    label   = tile.label,
                    checked = tile.shown,
                    onClick = function(myself)
                        MinimapButtonsModule:SetEnhancedTileShown(capturedId, myself:GetChecked())
                    end,
                })
                cb:SetPoint("TOPLEFT", content, "TOPLEFT", 36, cy)
                if not tile.available then
                    cb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                end
                cy = cy - ROW_HEIGHT
            end
        end

        local lockCB = OneWoW_GUI:CreateCheckbox(content, {
            label   = L["MMBTNS_LOCK_POSITION"],
            checked = s.locked,
            onClick = function(self)
                s.locked = self:GetChecked()
            end,
        })
        lockCB:ClearAllPoints()
        if extrasShown then
            lockCB:SetPoint("TOPLEFT", content, "TOPLEFT", 12, cy)
            cy = cy - ROW_HEIGHT
        else
            -- Relative to desc so wrap-height mistakes cannot overlap the next row.
            lockCB:SetPoint("LEFT", content, "LEFT", 12, 0)
            lockCB:SetPoint("TOP", enhDesc, "BOTTOM", 0, -8)
            cy = descCy - ROW_HEIGHT
        end

        -- Also Show on Minimap: collected buttons keep their normal entry in the
        -- collector AND get a click-through copy back on the minimap edge.
        local alsoShowCB = OneWoW_GUI:CreateCheckbox(content, {
            label   = L["MMBTNS_ALSO_SHOW_ON_MINIMAP"],
            checked = s.alsoShowOnMinimap,
            onClick = function(self)
                s.alsoShowOnMinimap = self:GetChecked()
                MinimapButtonsModule:Refresh()
            end,
        })
        alsoShowCB:SetPoint("TOPLEFT", content, "TOPLEFT", 12, cy)
        cy = cy - ROW_HEIGHT

        local alsoDesc, alsoDescCy = AddDescription(content, cy, L["MMBTNS_ALSO_SHOW_ON_MINIMAP_DESC"], contentWidth)
        cy = alsoDescCy

        local tipCB = OneWoW_GUI:CreateCheckbox(content, {
            label   = L["MMBTNS_SHOW_TOOLTIPS"],
            checked = s.showTooltips,
            onClick = function(self)
                s.showTooltips = self:GetChecked()
            end,
        })
        tipCB:ClearAllPoints()
        tipCB:SetPoint("LEFT", content, "LEFT", 12, 0)
        tipCB:SetPoint("TOP", alsoDesc, "BOTTOM", 0, -8)
        cy = alsoDescCy - ROW_HEIGHT

        local growDir = s.growDirection or "down"
        local growDirLabels = {
            down = L["DOWN"],
            up = L["UP"],
            left = L["MMBTNS_GROW_LEFT"],
            right = L["MMBTNS_GROW_RIGHT"],
        }

        local growDirLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        growDirLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 12, cy)
        growDirLabel:SetText(L["GROW_DIRECTION"] .. ":")
        growDirLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local growDirDropdown, growDirDropdownText = OneWoW_GUI:CreateDropdown(content, {
            width = 120,
            height = 26,
            text = growDirLabels[growDir] or growDirLabels.down,
        })
        growDirDropdown:SetPoint("LEFT", growDirLabel, "RIGHT", 8, 0)
        growDirDropdown._activeValue = growDir

        OneWoW_GUI:AttachFilterMenu(growDirDropdown, {
            searchable = false,
            menuHeight = 140,
            buildItems = function()
                return {
                    { value = "down", text = L["DOWN"] },
                    { value = "up", text = L["UP"] },
                    { value = "left", text = L["MMBTNS_GROW_LEFT"] },
                    { value = "right", text = L["MMBTNS_GROW_RIGHT"] },
                }
            end,
            getActiveValue = function()
                return GetSettings().growDirection or "down"
            end,
            onSelect = function(value, text)
                s.growDirection = value
                growDirDropdown._activeValue = value
                growDirDropdownText:SetText(text)
                MinimapButtonsModule:LayoutContainer()
            end,
        })
        cy = cy - 32

        return math.max(1, math.abs(cy))
    end)

    -- ── Layout ──────────────────────────────────────────────────────────────
    stack:AddCard("mmbtns:layout", L["MMBTNS_LAYOUT_HEADER"], function(content, _)
        local cy = 0

        local colsLabel
        colsLabel, cy = AddLabel(content, cy,
            string.format("%s: %d", L["MMBTNS_MAX_COLUMNS"], s.maxColumns))

        local colsSlider = OneWoW_GUI:CreateSlider(content, {
            minVal     = 1,
            maxVal     = 20,
            step       = 1,
            currentVal = s.maxColumns,
            width      = 260,
            fmt        = "%d",
            onChange    = function(val)
                s.maxColumns = val
                colsLabel:SetText(string.format("%s: %d", L["MMBTNS_MAX_COLUMNS"], val))
                MinimapButtonsModule:LayoutContainer()
            end,
        })
        colsSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 24, cy)
        cy = cy - SLIDER_HEIGHT

        local rowsDisplay = s.maxRows == 0 and "∞" or tostring(s.maxRows)
        local rowsLabel
        rowsLabel, cy = AddLabel(content, cy,
            string.format("%s: %s", L["MMBTNS_MAX_ROWS"], rowsDisplay))

        local rowsSlider = OneWoW_GUI:CreateSlider(content, {
            minVal     = 0,
            maxVal     = 10,
            step       = 1,
            currentVal = s.maxRows,
            width      = 260,
            fmt        = "%d",
            onChange    = function(val)
                s.maxRows = val
                local display = val == 0 and "∞" or tostring(val)
                rowsLabel:SetText(string.format("%s: %s", L["MMBTNS_MAX_ROWS"], display))
                MinimapButtonsModule:LayoutContainer()
            end,
        })
        rowsSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 24, cy)
        cy = cy - SLIDER_HEIGHT

        local rowsDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rowsDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 24, cy)
        rowsDesc:SetText(L["MMBTNS_MAX_ROWS_DESC"])
        rowsDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        cy = cy - rowsDesc:GetStringHeight() - 10

        local sizeLabel
        sizeLabel, cy = AddLabel(content, cy,
            string.format("%s: %d", L["BUTTON_SIZE"], s.buttonSize))

        local sizeSlider = OneWoW_GUI:CreateSlider(content, {
            minVal     = 24,
            maxVal     = 48,
            step       = 2,
            currentVal = s.buttonSize,
            width      = 260,
            fmt        = "%d",
            onChange    = function(val)
                s.buttonSize = val
                sizeLabel:SetText(string.format("%s: %d", L["BUTTON_SIZE"], val))
                MinimapButtonsModule:LayoutContainer()
            end,
        })
        sizeSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 24, cy)
        cy = cy - SLIDER_HEIGHT

        local scaleLabel
        scaleLabel, cy = AddLabel(content, cy,
            string.format("%s: %.1f", L["MMBTNS_BUTTON_SCALE"], (s.buttonScale or 10) / 10))

        local scaleSlider = OneWoW_GUI:CreateSlider(content, {
            minVal     = 1,
            maxVal     = 50,
            step       = 1,
            currentVal = s.buttonScale or 10,
            width      = 260,
            fmt        = "%d",
            onChange    = function(val)
                s.buttonScale = val
                scaleLabel:SetText(string.format("%s: %.1f", L["MMBTNS_BUTTON_SCALE"], val / 10))
                MinimapButtonsModule:ApplyButtonScale()
            end,
        })
        scaleSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 24, cy)
        cy = cy - SLIDER_HEIGHT

        local spacingLabel
        spacingLabel, cy = AddLabel(content, cy,
            string.format("%s: %d", L["MMBTNS_BUTTON_SPACING"], s.buttonSpacing))

        local spacingSlider = OneWoW_GUI:CreateSlider(content, {
            minVal     = 0,
            maxVal     = 8,
            step       = 1,
            currentVal = s.buttonSpacing,
            width      = 260,
            fmt        = "%d",
            onChange    = function(val)
                s.buttonSpacing = val
                spacingLabel:SetText(string.format("%s: %d", L["MMBTNS_BUTTON_SPACING"], val))
                MinimapButtonsModule:LayoutContainer()
            end,
        })
        spacingSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 24, cy)
        cy = cy - SLIDER_HEIGHT + 4

        return math.max(1, math.abs(cy))
    end)

    -- ── Detected Minimap Icons ──────────────────────────────────────────────
    stack:AddCard("mmbtns:icons", L["MMBTNS_ICONS_HEADER"], function(content, _)
        local cy = BuildMinimapIconsSection(content, 0, function()
            MinimapButtonsModule._refreshCustomDetail()
        end)
        return math.max(1, math.abs(cy))
    end)

    stack:Finish()
    return -container:GetHeight()
end

-- ─── CreateCustomDetail (called by the module feature panel framework) ──────

function MinimapButtonsModule:CreateCustomDetail(detailScrollChild, yOffset, _)
    if detailScrollChild._mmbtnContainer then
        OneWoW_GUI:ClearFrame(detailScrollChild._mmbtnContainer)
    end

    local container = detailScrollChild._mmbtnContainer or CreateFrame("Frame", nil, detailScrollChild)
    detailScrollChild._mmbtnContainer = container
    container:SetParent(detailScrollChild)
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT",  detailScrollChild, "TOPLEFT",  0, yOffset)
    container:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)
    container:Show()

    local capturedYOffset = yOffset

    local function updateDetailHeight()
        detailScrollChild:SetHeight(math.abs(capturedYOffset) + container:GetHeight() + 20)
        if detailScrollChild.updateThumb then
            detailScrollChild.updateThumb()
        end
    end

    self._refreshCustomDetail = function()
        OneWoW_GUI:ClearFrame(container)
        BuildContent(container, updateDetailHeight)
        updateDetailHeight()
    end

    local cy = BuildContent(container, updateDetailHeight)

    return yOffset + cy
end
