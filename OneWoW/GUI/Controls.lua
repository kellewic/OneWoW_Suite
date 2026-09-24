local OneWoW_GUI = OneWoW_GUI

local CreateFrame = CreateFrame
local IsMouseButtonDown = IsMouseButtonDown
local unpack = unpack
local tinsert = tinsert

local Constants = OneWoW_GUI.Constants
local noop = OneWoW_GUI.noop

local _dropdownMenuCount = 0
local _activeDropdownMenu = nil
local _activeDropdownOverlay = nil

--- Dismiss the open AttachFilterMenu popup (menu + overlay). Menus auto-dismiss via OnUpdate when the user
--- clicks outside their bounds; call this for programmatic teardown (e.g. before reparenting).
function OneWoW_GUI:CloseAttachFilterMenu()
    if _activeDropdownMenu then
        _activeDropdownMenu:Hide()
    elseif _activeDropdownOverlay then
        _activeDropdownOverlay:Hide()
    end
    _activeDropdownMenu = nil
    _activeDropdownOverlay = nil
end

function OneWoW_GUI:CreateToggleRow(parent, options)
    options = options or {}
    local yOffset = options.yOffset or 0
    local label = options.label or ""
    local description = options.description
    local createContent = options.createContent
    local value = options.value
    local isEnabled = options.isEnabled
    local onValueChange = options.onValueChange
    local onLabel = options.onLabel or "On"
    local offLabel = options.offLabel or "Off"
    local buttonWidth = options.buttonWidth or Constants.GUI.TOGGLE_BUTTON_WIDTH
    local buttonHeight = options.buttonHeight or Constants.GUI.TOGGLE_BUTTON_HEIGHT
    local alignLeft = (options.align == "left")

    local BTN_GAP = 8
    local LABEL_DESC_GAP = 3
    local ROW_BOTTOM_PAD = 10

    local labelFs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SetFontBaseSize(labelFs, 12)
    OneWoW_GUI:SafeSetFont(labelFs, OneWoW_GUI:GetFont(), 12)
    labelFs:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    labelFs:SetJustifyH("LEFT")
    labelFs:SetText(label)
    if label == "" then
        labelFs:Hide()
    end

    local btn, refresh = self:CreateOnOffToggleButtons(parent, {
        onLabel = onLabel,
        offLabel = offLabel,
        width = buttonWidth,
        height = buttonHeight,
        isEnabled = isEnabled,
        value = value,
        onValueChange = onValueChange,
        clickTooltipFormat = options.clickTooltipFormat,
    })

    -- Card hosts often have width 0 when rows are built (scroll child not sized
    -- yet). Prefer options.contentWidth so wrap/measure is not a collapsed column
    -- that truncates with "..." and then explodes on the first OnSizeChanged.
    local fixedWrap = tonumber(options.contentWidth) or 0
    if fixedWrap < 50 then
        fixedWrap = 0
    end
    local btnW = btn:GetWidth() or buttonWidth
    local reserveRight = 12 + btnW + BTN_GAP
    local textColW = 0
    if fixedWrap > 0 then
        textColW = math.max(50, fixedWrap - 12 - (alignLeft and 0 or reserveRight))
    end

    if alignLeft then
        if label ~= "" then
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", labelFs, "RIGHT", BTN_GAP, 0)
        else
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
        end
        if textColW > 0 and label ~= "" then
            labelFs:SetWidth(textColW)
        end
    else
        btn:ClearAllPoints()
        btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
        if label ~= "" then
            labelFs:ClearAllPoints()
            labelFs:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
            if textColW > 0 then
                labelFs:SetWidth(textColW)
            else
                labelFs:SetPoint("RIGHT", btn, "LEFT", -BTN_GAP, 0)
            end
        end
    end

    -- Left column: title, then description/content anchored under the title so wrap
    -- changes on resize keep title→desc spacing (absolute Y from GetStringHeight does not).
    local labelHeight = (label ~= "" and labelFs:GetStringHeight()) or 0

    local descFs
    local contentArea
    local belowHeight = 0

    if description then
        descFs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        OneWoW_GUI:SetFontBaseSize(descFs, 10)
        OneWoW_GUI:SafeSetFont(descFs, OneWoW_GUI:GetFont(), 10)
        descFs:SetJustifyH("LEFT")
        descFs:SetWordWrap(true)
        descFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        if label ~= "" then
            descFs:SetPoint("TOPLEFT", labelFs, "BOTTOMLEFT", 0, -LABEL_DESC_GAP)
            if textColW > 0 then
                descFs:SetWidth(textColW)
            else
                descFs:SetPoint("TOPRIGHT", labelFs, "BOTTOMRIGHT", 0, -LABEL_DESC_GAP)
            end
        else
            descFs:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
            if textColW > 0 then
                descFs:SetWidth(textColW)
            elseif alignLeft then
                descFs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
            else
                descFs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -reserveRight, yOffset)
            end
        end
        descFs:SetText(description)
        belowHeight = (label ~= "" and LABEL_DESC_GAP or 0) + (descFs:GetStringHeight() or 14) + 6
    elseif createContent then
        contentArea = CreateFrame("Frame", nil, parent)
        if label ~= "" then
            contentArea:SetPoint("TOPLEFT", labelFs, "BOTTOMLEFT", 0, -LABEL_DESC_GAP)
            if textColW > 0 then
                contentArea:SetWidth(textColW)
            else
                contentArea:SetPoint("TOPRIGHT", labelFs, "BOTTOMRIGHT", 0, -LABEL_DESC_GAP)
            end
        else
            contentArea:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
            if textColW > 0 then
                contentArea:SetWidth(textColW)
            elseif alignLeft then
                contentArea:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
            else
                contentArea:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -reserveRight, yOffset)
            end
        end
        local _, contentHeight = createContent(contentArea)
        contentHeight = contentHeight or 0
        contentArea:SetHeight(contentHeight)
        if label ~= "" then
            belowHeight = LABEL_DESC_GAP + contentHeight + 6
        else
            belowHeight = contentHeight + 6
        end
    end

    local leftBottom = yOffset - labelHeight - belowHeight
    local buttonBottom = yOffset - buttonHeight
    local stackBottom = math.min(leftBottom, buttonBottom)
    local newYOffset = stackBottom - ROW_BOTTOM_PAD

    local function rowRefresh(enabled, val)
        refresh(enabled, val)
        if enabled then
            labelFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            if descFs then
                descFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        else
            labelFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            if descFs then
                descFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        end
    end

    rowRefresh(isEnabled, value)

    return newYOffset, rowRefresh, { label = labelFs, contentArea = contentArea, button = btn }
end

function OneWoW_GUI:CreateCheckbox(parent, options)
    options = options or {}
    local name = options.name
    local label = options.label or ""
    local checked = options.checked
    local onClick = options.onClick
    local labelSide = options.labelSide or "right"
    local labelMaxWidth = options.labelMaxWidth
    local wrap = options.wrap
    local labelGap = OneWoW_GUI:GetSpacing("XS")

    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetSize(Constants.GUI.CHECKBOX_SIZE, Constants.GUI.CHECKBOX_SIZE)
    cb:SetChecked(checked and true or false)

    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SetFontBaseSize(cb.label, 12)
    OneWoW_GUI:SafeSetFont(cb.label, OneWoW_GUI:GetFont(), 12)
    if labelSide == "left" then
        cb.label:SetPoint("RIGHT", cb, "LEFT", -labelGap, 0)
        cb.label:SetJustifyH("RIGHT")
    else
        cb.label:SetPoint("LEFT", cb, "RIGHT", labelGap, 0)
        cb.label:SetJustifyH("LEFT")
    end
    cb.label:SetText(label)
    cb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    if labelMaxWidth and labelMaxWidth > 0 then
        cb.label:SetWidth(labelMaxWidth)
        cb.label:SetWordWrap(wrap and true or false)
        cb.label:SetNonSpaceWrap(false)
    elseif wrap then
        cb.label:SetWordWrap(true)
    else
        cb.label:SetWordWrap(false)
    end

    cb._labelSide = labelSide
    cb._labelGap = labelGap

    function cb:GetLabelStringWidth()
        if not self.label then return 0 end
        local w = self.label:GetStringWidth() or 0
        if labelMaxWidth and labelMaxWidth > 0 and w > labelMaxWidth then
            w = labelMaxWidth
        end
        return w
    end

    function cb:GetMeasuredWidth()
        local boxW = self:GetWidth() or Constants.GUI.CHECKBOX_SIZE
        local textW = self:GetLabelStringWidth()
        if textW <= 0 then return boxW end
        return boxW + self._labelGap + textW
    end

    function cb:GetMeasuredHeight()
        local boxH = self:GetHeight() or Constants.GUI.CHECKBOX_SIZE
        local textH = self.label and (self.label:GetStringHeight() or 0) or 0
        if textH > boxH then return textH end
        return boxH
    end

    if type(onClick) == "function" then
        cb:SetScript("OnClick", onClick)
    end

    return cb
end

function OneWoW_GUI:CreateDropdown(parent, options)
    options = options or {}
    local width = options.width or 200
    local height = options.height or 26
    local defaultText = options.text or ""

    local dropdown = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dropdown:SetSize(width, height)
    dropdown:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    dropdown:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    dropdown:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SetFontBaseSize(text, 10)
    OneWoW_GUI:SafeSetFont(text, OneWoW_GUI:GetFont(), 10)
    text:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 8, -2)
    text:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -20, 2)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    text:SetText(defaultText)
    text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local arrow = dropdown:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("CENTER", dropdown, "RIGHT", -10, 0)
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    dropdown:SetScript("OnEnter", function(myself)
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    end)
    dropdown:SetScript("OnLeave", function(myself)
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)

    dropdown._text = text
    dropdown._activeValue = nil

    return dropdown, text
end

function OneWoW_GUI:AttachFilterMenu(dropdown, options)
    options = options or {}
    local searchable = options.searchable ~= false
    local buildItems = options.buildItems
    local onSelect = options.onSelect
    local menuHeight = options.menuHeight or 314
    local menuWidth = options.menuWidth
    local getActiveValue = options.getActiveValue

    dropdown:SetScript("OnClick", function(myself)
        if myself._menu and myself._menu:IsShown() then
            myself._menu:Hide()
            return
        end

        -- Only one AttachFilterMenu may be open: hide previous menu+overlay and clear globals (avoids orphan overlays if strata/order prevented a clean hide).
        if _activeDropdownMenu then
            _activeDropdownMenu:Hide()
        end
        if _activeDropdownOverlay then
            _activeDropdownOverlay:Hide()
        end
        _activeDropdownMenu = nil
        _activeDropdownOverlay = nil

        local items = buildItems and buildItems() or {}

        _dropdownMenuCount = _dropdownMenuCount + 1
        local uid = _dropdownMenuCount

        -- Walk up to the top-level frame under UIParent (e.g. DevTool window). The overlay sits BELOW
        -- the host so it only blocks game-world clicks; in-host dismiss is handled by the menu's OnUpdate.
        -- Host OnHide hook handles ESC key close (menu is a UIParent child, won't hide with host).
        local host = myself
        while host:GetParent() and host:GetParent() ~= UIParent do
            host = host:GetParent()
        end
        if not host._oneWoWFilterMenuOnHide then
            host._oneWoWFilterMenuOnHide = true
            host:HookScript("OnHide", function()
                OneWoW_GUI:CloseAttachFilterMenu()
            end)
        end
        local hostStrata = host:GetFrameStrata()
        local hostLevel = host:GetFrameLevel() or 0

        -- Use a higher stratum for the menu so it stays visible above toplevel host windows.
        local menuStrata = hostStrata
        if hostStrata == "BACKGROUND" or hostStrata == "LOW" or hostStrata == "MEDIUM" or hostStrata == "HIGH" then
            menuStrata = "DIALOG"
        end
        local menuLevel = (menuStrata ~= hostStrata) and 100 or math.max(100, hostLevel + 40)

        local overlay = CreateFrame("Button", "OneWoWGUI_DropOverlay_" .. uid, UIParent)
        overlay:SetAllPoints(UIParent)
        overlay:SetFrameStrata(hostStrata)
        overlay:SetFrameLevel(math.max(0, hostLevel - 2))
        overlay:SetToplevel(true)
        overlay:EnableMouse(true)
        overlay:RegisterForClicks("AnyDown", "AnyUp")

        local menu = CreateFrame("Frame", "OneWoWGUI_DropMenuFrame_" .. uid, UIParent, "BackdropTemplate")
        myself._menu = menu
        _activeDropdownMenu = menu
        _activeDropdownOverlay = overlay
        menu._ownerDropdown = myself
        menu._boundOverlay = overlay
        menu:SetFrameStrata(menuStrata)
        menu:SetFrameLevel(menuLevel)
        menu:SetToplevel(true)
        menu:SetClampedToScreen(true)
        -- Prefer an explicit width; otherwise grow from the trigger so short labels
        -- (e.g. "New") do not crush item text into wrapped stubs.
        local width = menuWidth or ((myself:GetWidth() or 0) + 20)
        if width < 120 then width = 120 end
        menu:SetSize(width, menuHeight)

        local screenH = UIParent:GetHeight()
        local dropdownBottom = myself:GetBottom() or 0
        local spaceBelow = dropdownBottom
        local spaceAbove = screenH - (myself:GetTop() or screenH)
        local openUpward = spaceBelow < menuHeight and spaceAbove > spaceBelow

        if openUpward then
            menu:SetPoint("BOTTOMLEFT", myself, "TOPLEFT", 0, 2)
        else
            menu:SetPoint("TOPLEFT", myself, "BOTTOMLEFT", 0, -2)
        end

        menu:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
        menu:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        menu:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        menu:EnableMouse(true)

        -- Dismiss on any mouse-down outside the menu's bounds. Input (OnClick on controls)
        -- is processed before OnUpdate, so the clicked control fires first, then the menu
        -- closes in the same frame — single click, no consumed events.
        local wasDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
        menu:SetScript("OnUpdate", function(innerself)
            local isDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
            if isDown and not wasDown then
                if not innerself:IsMouseOver() then
                    innerself:Hide()
                end
            end
            wasDown = isDown
        end)

        overlay:SetScript("OnClick", function()
            menu:Hide()
        end)
        menu:SetScript("OnHide", function(m)
            local ov = m._boundOverlay
            if ov then
                ov:Hide()
            end
            if m._ownerDropdown and m._ownerDropdown._menu == m then
                m._ownerDropdown._menu = nil
            end
            if _activeDropdownMenu == m then
                _activeDropdownMenu = nil
            end
            if ov and _activeDropdownOverlay == ov then
                _activeDropdownOverlay = nil
            end
        end)

        local searchBox
        local contentTopY = -2

        if searchable then
            searchBox = CreateFrame("EditBox", "OneWoWGUI_DropSearchBox_" .. uid, menu, "BackdropTemplate")
            searchBox:SetSize(menu:GetWidth() - 15, 28)
            searchBox:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
            searchBox:SetBackdrop(Constants.BACKDROP_INNER)
            searchBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            searchBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            searchBox:SetFontObject(GameFontHighlight)
            searchBox:SetTextInsets(8, 8, 0, 0)
            searchBox:SetAutoFocus(false)
            searchBox:SetMaxLetters(50)
            searchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            searchBox:SetScript("OnEditFocusGained", function(s)
                s:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            end)
            searchBox:SetScript("OnEditFocusLost", function(s)
                s:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end)

            local separator = menu:CreateTexture(nil, "ARTWORK")
            separator:SetSize(menu:GetWidth() - 4, 1)
            separator:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -32)
            separator:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

            contentTopY = -36
        end

        local scrollContainer = CreateFrame("Frame", "OneWoWGUI_DropScrollContainer_" .. uid, menu)
        scrollContainer:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, contentTopY)
        scrollContainer:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -2, 2)

        local scrollFrame = CreateFrame("ScrollFrame", "OneWoWGUI_DropMenu_" .. uid, scrollContainer, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 0, 0)
        scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", 0, 0)
        scrollFrame:EnableMouseWheel(true)

        OneWoW_GUI:StyleScrollBar(scrollFrame, { container = scrollContainer, offset = -2 })

        local scrollChild = CreateFrame("Frame", "OneWoWGUI_DropMenuContent_" .. uid, scrollFrame)
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)
        scrollFrame:HookScript("OnSizeChanged", function(_, w)
            scrollChild:SetWidth(w)
        end)

        local elements = {}
        local activeValue = getActiveValue and getActiveValue() or dropdown._activeValue
        local elemIdx = 0

        for _, item in ipairs(items) do
            elemIdx = elemIdx + 1
            local itemType = item.type or "item"

            if itemType == "header" then
                local header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                OneWoW_GUI:SafeSetFont(header, OneWoW_GUI:GetFont(), 12)
                header:SetText(item.text)
                header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                tinsert(elements, { frame = header, type = "header", height = 24 })

            elseif itemType == "divider" then
                local divider = scrollChild:CreateTexture(nil, "ARTWORK")
                divider:SetHeight(1)
                divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                tinsert(elements, { frame = divider, type = "divider", height = 10 })

            elseif itemType == "checkbox" then
                local row = CreateFrame("Button", "OneWoWGUI_DropItem_" .. uid .. "_" .. elemIdx, scrollChild, "BackdropTemplate")
                row:SetHeight(26)
                row:SetBackdrop(Constants.BACKDROP_SIMPLE)
                row:SetBackdropColor(0, 0, 0, 0)

                local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                cb:SetSize(18, 18)
                cb:SetPoint("LEFT", row, "LEFT", 4, 0)
                cb:SetChecked(item.checked or false)

                local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                OneWoW_GUI:SafeSetFont(label, OneWoW_GUI:GetFont(), 12)
                label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
                label:SetText(item.text)
                label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

                row:SetScript("OnEnter", function(r)
                    r:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                end)
                row:SetScript("OnLeave", function(r)
                    r:SetBackdropColor(0, 0, 0, 0)
                    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end)

                local onToggle = item.onToggle
                cb:SetScript("OnClick", function(c)
                    if onToggle then onToggle(c:GetChecked()) end
                end)
                row:SetScript("OnClick", function()
                    cb:SetChecked(not cb:GetChecked())
                    if onToggle then onToggle(cb:GetChecked()) end
                end)

                row.checkbox = cb
                if item.onBind then
                    item.onBind(cb)
                end
                -- Strip UI escape codes so class-colored names still filter by plain text.
                local filterSrc = item.filterKey or item.text or ""
                local filterKey = tostring(filterSrc)
                    :gsub("|c%x%x%x%x%x%x%x%x", "")
                    :gsub("|r", "")
                    :lower()
                tinsert(elements, { frame = row, type = "checkbox", height = 26, filterKey = filterKey })

            else
                -- Items may opt into rendering their label in a custom font
                -- (e.g. font pickers want each row drawn in its own typeface
                -- as a live preview). Falls back to the global UI font.
                local rowHeight = item.fontPath and 28 or 26
                local btn = CreateFrame("Button", "OneWoWGUI_DropItem_" .. uid .. "_" .. elemIdx, scrollChild, "BackdropTemplate")
                btn:SetSize(scrollChild:GetWidth() or (menu:GetWidth() - 20), rowHeight)
                btn:SetBackdrop(Constants.BACKDROP_SIMPLE)

                if activeValue == item.value then
                    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                else
                    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                end

                local iconTex
                local leftPad = 8
                if item.iconAtlas or item.icon then
                    local iconSize = item.iconSize or 14
                    iconTex = btn:CreateTexture(nil, "ARTWORK")
                    iconTex:SetSize(iconSize, iconSize)
                    iconTex:SetPoint("LEFT", btn, "LEFT", 8, 0)
                    if item.iconAtlas then
                        iconTex:SetAtlas(item.iconAtlas)
                    else
                        iconTex:SetTexture(item.icon)
                    end
                    leftPad = 8 + iconSize + 6
                end

                local rightFS
                if item.rightText and item.rightText ~= "" then
                    rightFS = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    OneWoW_GUI:SafeSetFont(rightFS, OneWoW_GUI:GetFont(), item.fontSize or 12)
                    rightFS:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
                    rightFS:SetJustifyH("RIGHT")
                    rightFS:SetText(item.rightText)
                    rightFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                end

                local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                OneWoW_GUI:SafeSetFont(txt, item.fontPath or OneWoW_GUI:GetFont(), item.fontSize or 12)
                txt:SetPoint("LEFT", btn, "LEFT", leftPad, 0)
                if rightFS then
                    txt:SetPoint("RIGHT", rightFS, "LEFT", -8, 0)
                else
                    txt:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
                end
                txt:SetJustifyH("LEFT")
                txt:SetWordWrap(false)
                local label = item.text or item.value or ""
                txt:SetText(label)
                txt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

                btn:SetScript("OnEnter", function(b)
                    if activeValue ~= item.value then
                        b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                        txt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                        if rightFS then
                            rightFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                        end
                    end
                    local tip = item.tooltip
                    if tip then
                        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
                        if type(tip) == "table" then
                            GameTooltip:SetText(tip.title or label, 1, 1, 1)
                            if tip.desc and tip.desc ~= "" then
                                GameTooltip:AddLine(tip.desc, 0.85, 0.85, 0.85, true)
                            end
                        else
                            GameTooltip:SetText(label, 1, 1, 1)
                            if tip ~= "" then
                                GameTooltip:AddLine(tip, 0.85, 0.85, 0.85, true)
                            end
                        end
                        GameTooltip:Show()
                    end
                    if item.onEnter then item.onEnter(b) end
                end)
                btn:SetScript("OnLeave", function(b)
                    if activeValue ~= item.value then
                        b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                        txt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                        if rightFS then
                            rightFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                        end
                    end
                    if item.tooltip then
                        GameTooltip:Hide()
                    end
                    if item.onLeave then item.onLeave(b) end
                end)
                btn:SetScript("OnClick", function()
                    menu:Hide()
                    dropdown._activeValue = item.value
                    if onSelect then
                        onSelect(item.value, item.text or item.value)
                    end
                end)

                btn.filterKey = tostring(item.filterKey or label):lower()
                btn:Hide()
                tinsert(elements, { frame = btn, type = "item", height = rowHeight + 2, filterKey = btn.filterKey })
            end
        end

        local function renderList(filter)
            local yPos = -2
            local shown = 0
            local isFiltering = filter ~= ""
            for _, elem in ipairs(elements) do
                if isFiltering and (elem.type == "header" or elem.type == "divider") then
                    elem.frame:Hide()
                elseif elem.type == "item" or elem.type == "checkbox" then
                    if not isFiltering or (elem.filterKey and string.find(elem.filterKey, filter, 1, true)) then
                        -- Scroll frame must list every row; do not cap with maxVisible (that hid options 11+).
                        elem.frame:ClearAllPoints()
                        elem.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, yPos)
                        elem.frame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -2, yPos)
                        elem.frame:Show()
                        yPos = yPos - elem.height
                        shown = shown + 1
                    else
                        elem.frame:Hide()
                    end
                elseif elem.type == "header" then
                    elem.frame:ClearAllPoints()
                    elem.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, yPos - 4)
                    elem.frame:Show()
                    yPos = yPos - elem.height
                elseif elem.type == "divider" then
                    elem.frame:ClearAllPoints()
                    elem.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, yPos - 4)
                    elem.frame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -8, yPos - 4)
                    elem.frame:Show()
                    yPos = yPos - elem.height
                end
            end
            local actualHeight = math.max(1, math.abs(yPos))
            scrollChild:SetHeight(actualHeight)
            return actualHeight
        end

        local contentHeight = renderList("")
        local dynamicHeight = contentHeight + math.abs(contentTopY) + 2
        local finalHeight = math.min(dynamicHeight, menuHeight)
        finalHeight = math.max(finalHeight, 40)
        menu:SetHeight(finalHeight)

        if searchBox then
            searchBox:SetScript("OnTextChanged", function(s)
                renderList(s:GetText():lower())
            end)
            searchBox:SetScript("OnEscapePressed", function(s)
                if s:GetText() ~= "" then
                    s:SetText("")
                    renderList("")
                else
                    menu:Hide()
                end
            end)
            OneWoW_GUI:AttachClearButton(searchBox)
        end

        menu:Show()
        menu:Raise()
        if searchBox then
            searchBox:SetFocus()
        end
    end)
end

--- OptionsSliderTemplate Low/High labels reset when frames are reused (e.g. after ClearFrame orphans globals).
--- Keeps custom endpoint text by applying on configure and on each Show (single HookScript per slider).
function OneWoW_GUI:ConfigureOptionsSliderEnds(slider, lowText, highText)
    if not slider then return end
    slider.__OneWoWSliderEndLow = lowText
    slider.__OneWoWSliderEndHigh = highText

    local function apply()
        local low = slider.__OneWoWSliderEndLow
        local high = slider.__OneWoWSliderEndHigh
        if slider.Low then
            slider.Low:SetText(low)
        else
            local name = slider:GetName()
            if name then
                local lo = _G[name .. "Low"]
                if lo then lo:SetText(low) end
            end
        end
        if slider.High then
            slider.High:SetText(high)
        else
            local name = slider:GetName()
            if name then
                local hi = _G[name .. "High"]
                if hi then hi:SetText(high) end
            end
        end
    end

    apply()

    if not slider.__OneWoWSliderEndsHooked then
        slider.__OneWoWSliderEndsHooked = true
        slider:HookScript("OnShow", apply)
    end
end

function OneWoW_GUI:CreateSlider(parent, options)
    options = options or {}
    local minVal = options.minVal or 0
    local maxVal = options.maxVal or 100
    local step = options.step or 1
    local currentVal = options.currentVal or minVal
    local onChange = options.onChange or noop
    local width = options.width or 200
    local fmt = options.fmt or "%.1f"
    local getLabel = options.getLabel
    local getValue = options.getValue
    local function formatVal(pos)
        if getLabel then return getLabel(pos) end
        return string.format(fmt, pos)
    end
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 36)

    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT",  container, "TOPLEFT",  0,   0)
    slider:SetPoint("TOPRIGHT", container, "TOPRIGHT", -40, 0)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetValue(currentVal)
    slider:SetObeyStepOnDrag(true)

    local valLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SafeSetFont(valLabel, OneWoW_GUI:GetFont(), 12)
    valLabel:SetPoint("LEFT", slider, "RIGHT", 6, 0)
    valLabel:SetText(formatVal(currentVal))
    valLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    self:ConfigureOptionsSliderEnds(slider, formatVal(minVal), formatVal(maxVal))
    if slider.Text then slider.Text:SetText("") end

    slider:SetScript("OnValueChanged", function(_, val)
        local rounded = math.floor(val / step + 0.5) * step
        rounded = math.max(minVal, math.min(maxVal, rounded))
        valLabel:SetText(formatVal(rounded))
        if getValue then
            onChange(getValue(rounded), rounded)
        else
            onChange(rounded)
        end
    end)

    container.slider = slider
    container.valLabel = valLabel
    return container
end

function OneWoW_GUI:GetProgressColor(current, max)
    local colors = Constants.PROGRESS_COLORS
    if max == 0 then return unpack(colors.NONE) end
    local pct = current / max
    if pct >= 1.0 then return unpack(colors.FULL)
    elseif pct >= 0.5 then return unpack(colors.MID)
    else return unpack(colors.LOW) end
end

--- Gold normal + yellow highlight tint for Blizzard collapse/expand reorder arrows.
function OneWoW_GUI:TintScrollReorderButtons(upBtn, downBtn)
    local gold = Constants.WOW_QUEST_GOLD
    local hi = Constants.REORDER_BTN_HIGHLIGHT
    local function tint(btn)
        if not btn then return end
        local normal = btn:GetNormalTexture()
        if normal then normal:SetVertexColor(unpack(gold)) end
        local highlight = btn:GetHighlightTexture()
        if highlight then highlight:SetVertexColor(unpack(hi)) end
    end
    tint(upBtn)
    tint(downBtn)
end

function OneWoW_GUI:CreateColorSwatch(parent, options)
    options = options or {}
    local size = options.size or 24
    local getColor = options.getColor
    local onColorChanged = options.onColorChanged
    local hasOpacity = options.hasOpacity or false
    local getOpacity = options.getOpacity
    local onOpacityChanged = options.onOpacityChanged

    local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    swatch:SetSize(size, size)
    swatch:SetBackdrop(Constants.BACKDROP_SOFT)
    swatch:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local function refresh()
        if getColor then
            local r, g, b = getColor()
            swatch:SetBackdropColor(r, g, b, 1)
        end
    end
    refresh()

    swatch:SetScript("OnClick", function()
        local r, g, b = 1, 1, 1
        if getColor then
            r, g, b = getColor()
        end
        local info = {
            r = r, g = g, b = b,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                if onColorChanged then
                    onColorChanged(nr, ng, nb)
                end
                refresh()
            end,
            cancelFunc = function(prev)
                if prev and onColorChanged then
                    onColorChanged(prev.r, prev.g, prev.b)
                    refresh()
                end
            end,
        }
        if hasOpacity then
            info.hasOpacity = true
            if getOpacity then
                info.opacity = getOpacity()
            end
            info.opacityFunc = function()
                local a = ColorPickerFrame:GetColorAlpha()
                if onOpacityChanged then
                    onOpacityChanged(a)
                end
            end
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    swatch.refresh = refresh
    return swatch
end

function OneWoW_GUI:CreateProgressBar(parent, options)
    options = options or {}
    local height = options.height or Constants.PROGRESS_BAR.HEIGHT
    local min = options.min or 0
    local max = options.max or 100
    local value = options.value or 0
    local bgColor = Constants.PROGRESS_BAR.BG_COLOR

    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(Constants.BAR_TEXTURE)
    bar:GetStatusBarTexture():SetHorizTile(false)
    bar:SetMinMaxValues(min, max)
    bar:SetValue(value)
    bar:SetHeight(height)

    local pR, pG, pB = self:GetProgressColor(value, max)
    bar:SetStatusBarColor(pR, pG, pB)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(unpack(bgColor))
    bar._bg = bg

    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SafeSetFont(text, OneWoW_GUI:GetFont(), 10)
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetText(string.format("%d/%d", value, max))
    text:SetTextColor(unpack(Constants.ICON_OVERLAY_TEXT))
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    bar._text = text

    function bar:UpdateProgress(current, maximum)
        self:SetMinMaxValues(0, maximum)
        self:SetValue(current)
        local r, g, b = OneWoW_GUI:GetProgressColor(current, maximum)
        self:SetStatusBarColor(r, g, b)
        self._text:SetText(string.format("%d/%d", current, maximum))
    end

    return bar
end

function OneWoW_GUI:CreateIntegrationRow(parent, options)
    options = options or {}
    local addonName = options.addonName
    local displayName = options.displayName or addonName
    local height = options.height or 30
    local isEnabled = options.isEnabled
    local onToggle = options.onToggle
    local notDetectedText = options.notDetectedText or "Not Detected"
    local enabledText = options.enabledText or "Enabled"
    local disabledText = options.disabledText or "Disabled"
    local notCompatible = options.notCompatible
    local notCompatibleText = options.notCompatibleText or "Not Compatible"
    local detectedText = options.detectedText or "Detected"
    local isDetected = options.isDetected

    local detected = isDetected and isDetected() or (not isDetected and C_AddOns.IsAddOnLoaded(addonName))
    local canToggle = detected and not notCompatible and isEnabled and onToggle

    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(height)
    row:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local nameFs = OneWoW_GUI:CreateFS(row, 12)
    nameFs:SetPoint("LEFT", row, "LEFT", 10, 0)
    nameFs:SetJustifyH("LEFT")
    nameFs:SetWordWrap(false)
    nameFs:SetText(displayName)
    nameFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local refresh
    if canToggle then
        -- Detected + compatible: Enabled/Disabled only (same chrome as feature headers).
        local toggleBtn, toggleRefresh = self:CreateFeatureHeaderToggle(row, {
            isEnabled = isEnabled,
            onToggle = onToggle,
            onLabel = enabledText,
            offLabel = disabledText,
        })
        toggleBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        nameFs:SetPoint("RIGHT", toggleBtn, "LEFT", -8, 0)
        refresh = toggleRefresh
    else
        local statusFs = OneWoW_GUI:CreateFS(row, 12)
        statusFs:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        statusFs:SetJustifyH("RIGHT")
        nameFs:SetPoint("RIGHT", statusFs, "LEFT", -8, 0)
        if not detected then
            statusFs:SetText(notDetectedText)
            statusFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        else
            statusFs:SetText(detectedText .. " (" .. notCompatibleText .. ")")
            statusFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
        end
        refresh = function() end
    end

    row.refresh = refresh
    return row
end

--- Feature detail header toggle — Enabled/Disabled state chrome (same as Features On/Off).
--- Caller SetPoints the button (typically TOPRIGHT) and pins the title to it.
--- options: isEnabled (fun(): boolean), onToggle (fun(newState: boolean)|nil),
--- selectedRow (optional, syncs .dot), onLabel/offLabel/clickTooltipFormat (optional).
---@param parent Frame
---@param options table|nil
---@return Button toggleBtn
---@return fun() refresh
function OneWoW_GUI:CreateFeatureHeaderToggle(parent, options)
    options = options or {}
    local isEnabledFn = options.isEnabled
    local onToggle = options.onToggle
    local selectedRow = options.selectedRow
    local onLabel = options.onLabel
        or OneWoW.Locale:GetOptional("shared", "FEATURE_ENABLED")
        or "Enabled"
    local offLabel = options.offLabel
        or OneWoW.Locale:GetOptional("shared", "FEATURE_DISABLED")
        or "Disabled"

    local current = isEnabledFn and isEnabledFn() or false

    local toggleBtn, onOffRefresh = self:CreateOnOffToggleButtons(parent, {
        onLabel = onLabel,
        offLabel = offLabel,
        isEnabled = true,
        value = current,
        clickTooltipFormat = options.clickTooltipFormat,
        onValueChange = function(newVal)
            if onToggle then
                onToggle(newVal)
            end
            if selectedRow and selectedRow.dot then
                selectedRow.dot:SetStatus(newVal)
            end
        end,
    })

    local function refresh()
        local enabled = isEnabledFn and isEnabledFn() or false
        onOffRefresh(true, enabled)
    end

    return toggleBtn, refresh
end
