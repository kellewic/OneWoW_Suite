local OneWoW_GUI = OneWoW_GUI

local Constants = OneWoW_GUI.Constants
local noop = OneWoW_GUI.noop

local pairs, ipairs = pairs, ipairs
local floor, ceil = math.floor, math.ceil
local min, max = math.min, math.max
local abs = math.abs
local CreateFrame = CreateFrame


function OneWoW_GUI:CreateFilterBar(parent, config)
    config = config or {}
    local height = config.height or 40
    local anchorBelow = config.anchorBelow
    local offset = config.offset or -5

    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if anchorBelow then
        bar:SetPoint("TOPLEFT", anchorBelow, "BOTTOMLEFT", 0, offset)
        bar:SetPoint("TOPRIGHT", anchorBelow, "BOTTOMRIGHT", 0, offset)
    else
        bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, offset)
        bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, offset)
    end
    bar:SetHeight(height)
    bar:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    bar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    bar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    return bar
end

function OneWoW_GUI:CreateSortControls(parent, options)
    options = options or {}
    local sortFields   = options.sortFields   or {}
    local defaultField = options.defaultField or (sortFields[1] and sortFields[1].key) or ""
    local defaultAsc   = options.defaultAsc ~= false
    local onChange     = options.onChange or noop
    local dropWidth    = options.dropdownWidth or 110

    local state = { field = defaultField, ascending = defaultAsc }

    local dropdown, textFS = self:CreateDropdown(parent, { width = dropWidth, height = 25 })

    local function RefreshDropText()
        for _, f in ipairs(sortFields) do
            if f.key == state.field then
                textFS:SetText(f.label)
                break
            end
        end
    end
    RefreshDropText()
    dropdown._activeValue = defaultField

    self:AttachFilterMenu(dropdown, {
        searchable = false,
        buildItems = function()
            local items = {}
            for _, f in ipairs(sortFields) do
                items[#items + 1] = { text = f.label, value = f.key }
            end
            return items
        end,
        onSelect = function(value, label)
            state.field = value
            textFS:SetText(label)
            dropdown._activeValue = value
            onChange(state.field, state.ascending)
        end,
        getActiveValue = function() return state.field end,
    })

    local dirBtn = CreateFrame("Button", nil, parent)
    dirBtn:SetSize(24, 25)

    local function UpdateDirAtlas()
        local atlas = state.ascending and "common-button-collapseExpand-up" or "common-button-collapseExpand-down"
        dirBtn:SetNormalAtlas(atlas)
        dirBtn:SetPushedAtlas(atlas)
        dirBtn:SetHighlightAtlas(atlas)
        if dirBtn:GetHighlightTexture() then
            dirBtn:GetHighlightTexture():SetAlpha(0.5)
        end
    end
    UpdateDirAtlas()

    dirBtn:SetScript("OnClick", function()
        state.ascending = not state.ascending
        UpdateDirAtlas()
        onChange(state.field, state.ascending)
    end)

    local handle = { dropdown = dropdown, dirBtn = dirBtn }

    function handle:GetSort()
        return state.field, state.ascending
    end

    function handle:SetSort(field, ascending)
        state.field     = field
        state.ascending = ascending ~= false
        dropdown._activeValue = field
        RefreshDropText()
        UpdateDirAtlas()
    end

    return handle
end

function OneWoW_GUI:CreateHeader(parent, options)
    options = options or {}
    local text = options.text or ""
    local yOffset = options.yOffset or -OneWoW_GUI:GetSpacing("MD")
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    OneWoW_GUI:SetFontBaseSize(header, 16)
    OneWoW_GUI:SafeSetFont(header, OneWoW_GUI:GetFont(), 16)
    header:SetPoint("TOPLEFT", OneWoW_GUI:GetSpacing("MD"), yOffset)
    header:SetText(text)
    header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    return header
end

function OneWoW_GUI:CreateDivider(parent, options)
    options = options or {}
    local yOffset = options.yOffset or 0
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("LEFT", OneWoW_GUI:GetSpacing("MD"), 0)
    divider:SetPoint("RIGHT", -OneWoW_GUI:GetSpacing("MD"), 0)
    divider:SetPoint("TOP", 0, yOffset)
    divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    return divider
end

function OneWoW_GUI:CreateSection(parent, options)
    options = options or {}
    local title = options.title or ""
    local yOffset = options.yOffset or 0
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SetFontBaseSize(header, 12)
    OneWoW_GUI:SafeSetFont(header, OneWoW_GUI:GetFont(), 12)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", OneWoW_GUI:GetSpacing("MD"), yOffset)
    header:SetText(title)
    header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - header:GetStringHeight() - 6

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", OneWoW_GUI:GetSpacing("MD"), yOffset)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -OneWoW_GUI:GetSpacing("MD"), yOffset)
    divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    return yOffset
end

function OneWoW_GUI:CreateTitleBar(parent, options)
    options = options or {}
    local title = options.title or ""
    local height = options.height or Constants.GUI.TITLEBAR_HEIGHT
    local onClose = options.onClose
    local showBrand = options.showBrand

    local titleBg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    titleBg:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
    titleBg:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
    titleBg:SetHeight(height)
    titleBg:SetBackdrop(Constants.BACKDROP_SIMPLE)
    titleBg:SetBackdropColor(OneWoW_GUI:GetThemeColor("TITLEBAR_BG"))
    titleBg:SetFrameLevel(parent:GetFrameLevel() + 1)

    titleBg._titleText = titleBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SetFontBaseSize(titleBg._titleText, 12)
    OneWoW_GUI:SafeSetFont(titleBg._titleText, OneWoW_GUI:GetFont(), 12)

    if showBrand then
        local factionTheme = options.factionTheme
        if not factionTheme then
            factionTheme = (self.GetSetting and self:GetSetting("minimap.theme")) or "horde"
        end
        local brandIcon = titleBg:CreateTexture(nil, "OVERLAY")
        brandIcon:SetSize(14, 14)
        brandIcon:SetPoint("LEFT", titleBg, "LEFT", OneWoW_GUI:GetSpacing("SM"), 0)
        brandIcon:SetTexture(self:GetBrandIcon(factionTheme))
        titleBg.brandIcon = brandIcon

        self:RegisterSettingsCallback("OnIconThemeChanged", titleBg, function(owner)
            if owner.brandIcon and owner:IsVisible() then
                owner.brandIcon:SetTexture(OneWoW_GUI:GetBrandIcon(
                    (OneWoW_GUI.GetSetting and OneWoW_GUI:GetSetting("minimap.theme")) or "horde"))
            end
        end)

        local brandText = titleBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        OneWoW_GUI:SetFontBaseSize(brandText, 12)
        OneWoW_GUI:SafeSetFont(brandText, OneWoW_GUI:GetFont(), 12)
        brandText:SetPoint("LEFT", brandIcon, "RIGHT", 4, 0)
        brandText:SetText("OneWoW")
        brandText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        titleBg._titleText:SetPoint("CENTER", titleBg, "CENTER", 0, 0)
        titleBg._titleText:SetText(title)
        titleBg._titleText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    else
        titleBg._titleText:SetPoint("LEFT", titleBg, "LEFT", OneWoW_GUI:GetSpacing("MD"), 0)
        titleBg._titleText:SetText(title)
        titleBg._titleText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    end

    if onClose then
        local closeBtn = self:CreateButton(titleBg, { text = "X", width = 20, height = 20 })
        closeBtn:SetPoint("RIGHT", titleBg, "RIGHT", -OneWoW_GUI:GetSpacing("XS") / 2, 0)
        closeBtn:SetScript("OnClick", onClose)
        titleBg._closeBtn = closeBtn
    end

    return titleBg
end

function OneWoW_GUI:CreateSectionHeader(parent, options)
    options = options or {}
    local title = options.title or ""
    local rightText = options.rightText
    local yOffset = options.yOffset or 0
    local fontSize = options.fontSize or 12
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetPoint("TOPLEFT", 0, yOffset)
    section:SetPoint("TOPRIGHT", 0, yOffset)
    section:SetHeight(30)
    section:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    section:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    section:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local countFS
    if rightText and rightText ~= "" then
        countFS = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        OneWoW_GUI:SetFontBaseSize(countFS, fontSize)
        OneWoW_GUI:SafeSetFont(countFS, OneWoW_GUI:GetFont(), fontSize)
        countFS:SetPoint("RIGHT", -12, 0)
        countFS:SetJustifyH("RIGHT")
        countFS:SetText(rightText)
        countFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        section.rightText = countFS
    end

    local titleText = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SetFontBaseSize(titleText, fontSize)
    OneWoW_GUI:SafeSetFont(titleText, OneWoW_GUI:GetFont(), fontSize)
    titleText:SetPoint("LEFT", 12, 0)
    if countFS then
        titleText:SetPoint("RIGHT", countFS, "LEFT", -8, 0)
    else
        titleText:SetPoint("RIGHT", -12, 0)
    end
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)
    titleText:SetText(title)
    titleText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    section.titleText = titleText

    local sectionHeight = max(30, titleText:GetStringHeight() + 14)
    section:SetHeight(sectionHeight)
    section.bottomY = yOffset - sectionHeight
    section._minHeight = 30
    section._yOffset = yOffset

    function section:GetMeasuredHeight()
        local titleH = titleText:GetStringHeight() or 0
        return max(self._minHeight, titleH + 14)
    end

    section:HookScript("OnSizeChanged", function()
        local newH = section:GetMeasuredHeight()
        if abs(newH - (section:GetHeight() or 0)) > 0.5 then
            section:SetHeight(newH)
            section.bottomY = section._yOffset - newH
        end
    end)

    return section
end

function OneWoW_GUI:StackVertically(parent, items, options)
    options = options or {}
    local defaultGap = options.gap or OneWoW_GUI:GetSpacing("SM")
    local gaps = options.gaps or {}
    local topPad = options.topPadding or 0
    local sidePad = options.sidePadding or 0
    local onLayout = options.onLayout
    local autoHeight = options.autoHeight ~= false

    local stack = {
        parent = parent,
        items = {},
        _laying = false,
    }

    local function ChildHeight(child)
        if not child then return 0 end
        if type(child.GetMeasuredHeight) == "function" then
            local h = child:GetMeasuredHeight() or 0
            if h > 0 then return h end
        end
        return child:GetHeight() or 0
    end

    local function AnchorAll(yByIndex)
        for i, child in ipairs(stack.items) do
            if child and child.SetPoint then
                child:ClearAllPoints()
                local y = yByIndex and yByIndex[i] or 0
                local leftInset = sidePad + (child._stackLeftInset or 0)
                child:SetPoint("TOPLEFT", parent, "TOPLEFT", leftInset, -y)
                child:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -sidePad, -y)
            end
        end
    end

    local function RemeasureAll()
        for _, child in ipairs(stack.items) do
            if child and type(child._relayout) == "function" then
                child:_relayout()
            end
        end
    end

    function stack:Layout()
        if self._laying then return end
        self._laying = true
        AnchorAll(nil)
        RemeasureAll()
        local cursor = topPad
        local yByIndex = {}
        for i, child in ipairs(self.items) do
            if child and child.SetPoint then
                yByIndex[i] = cursor
                local h = ChildHeight(child)
                if h <= 0 then h = 1 end
                cursor = cursor + h
                if i < #self.items then
                    cursor = cursor + (gaps[i] or defaultGap)
                end
            end
        end
        AnchorAll(yByIndex)
        if autoHeight and parent.SetHeight then
            parent:SetHeight(max(1, cursor))
        end
        self._totalHeight = cursor
        if onLayout then onLayout(cursor) end
        self._laying = false
    end

    function stack:GetTotalHeight()
        return self._totalHeight or 0
    end

    local function HookSizeChanged(child)
        if not child or not child.HookScript or not child.GetObjectType then return end
        local kind = child:GetObjectType()
        if kind == "FontString" or kind == "Texture" or kind == "Line" then return end
        child:HookScript("OnSizeChanged", function() stack:Layout() end)
    end

    function stack:Add(child, gap)
        table.insert(self.items, child)
        if gap then gaps[#self.items] = gap end
        HookSizeChanged(child)
        if child and type(child.OnHeightChanged) == "function" then
            child:OnHeightChanged(function() stack:Layout() end)
        end
        self:Layout()
    end

    function stack:Refresh()
        self:Layout()
    end

    if items then
        for _, child in ipairs(items) do
            if child then
                table.insert(stack.items, child)
                HookSizeChanged(child)
                if type(child.OnHeightChanged) == "function" then
                    child:OnHeightChanged(function() stack:Layout() end)
                end
            end
        end
    end

    if parent and parent.HookScript and parent.GetObjectType then
        local kind = parent:GetObjectType()
        if kind ~= "FontString" and kind ~= "Texture" and kind ~= "Line" then
            parent:HookScript("OnSizeChanged", function()
                stack:Layout()
                C_Timer.After(0, function() stack:Layout() end)
            end)
        end
    end

    stack:Layout()
    C_Timer.After(0, function() stack:Layout() end)
    C_Timer.After(0.05, function() stack:Layout() end)

    return stack
end

function OneWoW_GUI:CreateActionBar(parent, options)
    options = options or {}
    local yOffset = options.yOffset or 0
    local insetX = options.insetX or 0
    local gap = options.gap or OneWoW_GUI:GetSpacing("MD")
    local rowHeight = options.rowHeight or Constants.GUI.ACTION_BAR_HEIGHT
    local rowGap = options.rowGap or OneWoW_GUI:GetSpacing("SM")

    local bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", insetX, yOffset)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -insetX, yOffset)
    bar:SetHeight(rowHeight)
    bar._yOffset = yOffset
    bar._minRowHeight = rowHeight
    bar._heightListeners = {}

    local left = CreateFrame("Frame", nil, bar)
    left:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    left:SetHeight(rowHeight)
    bar.left = left

    local right = CreateFrame("Frame", nil, bar)
    right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    right:SetHeight(rowHeight)
    bar.right = right

    local function ClusterWidth(cluster)
        if not cluster then return 0 end
        local explicit = cluster:GetWidth() or 0
        if explicit > 0 then return explicit end
        local sumW = 0
        for i = 1, cluster:GetNumChildren() do
            local child = select(i, cluster:GetChildren())
            if child and child.GetWidth then
                local w
                if type(child.GetMeasuredWidth) == "function" then
                    w = child:GetMeasuredWidth() or 0
                else
                    w = child:GetWidth() or 0
                end
                sumW = sumW + w
            end
        end
        return sumW
    end

    local function ClusterHeight(cluster)
        if not cluster then return rowHeight end
        local explicit = cluster:GetHeight() or 0
        if explicit > rowHeight then return explicit end
        local maxH = rowHeight
        for i = 1, cluster:GetNumChildren() do
            local child = select(i, cluster:GetChildren())
            if child and child.GetHeight then
                local h
                if type(child.GetMeasuredHeight) == "function" then
                    h = child:GetMeasuredHeight() or 0
                else
                    h = child:GetHeight() or 0
                end
                if h > maxH then maxH = h end
            end
        end
        return maxH
    end

    bar._isResizing = false
    function bar:Refresh()
        if self._isResizing then return end
        local w = self:GetWidth() or 0
        local lW = ClusterWidth(left)
        local rW = ClusterWidth(right)
        local lH = ClusterHeight(left)
        local rH = ClusterHeight(right)
        local needWrap = false
        if w > 0 and (lW + rW + gap) > w then
            needWrap = true
        end
        if options.minBarWidth and w < options.minBarWidth then
            needWrap = true
        end

        left:ClearAllPoints()
        right:ClearAllPoints()
        local total
        if needWrap then
            left:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
            left:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
            left:SetHeight(lH)
            right:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -(lH + rowGap))
            right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, -(lH + rowGap))
            right:SetHeight(rH)
            total = lH + rowGap + rH
        else
            local rowH = max(lH, rH, rowHeight)
            left:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
            left:SetWidth(max(1, lW))
            left:SetHeight(rowH)
            right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
            right:SetWidth(max(1, rW))
            right:SetHeight(rowH)
            total = rowH
        end

        if abs(total - (bar:GetHeight() or 0)) > 0.5 then
            self._isResizing = true
            bar:SetHeight(total)
            self._isResizing = false
        end
        bar.bottomY = bar._yOffset - total
        for _, fn in ipairs(bar._heightListeners) do
            fn(bar, total)
        end
    end

    function bar:GetMeasuredHeight()
        local lH = ClusterHeight(left)
        local rH = ClusterHeight(right)
        local w = self:GetWidth() or 0
        local lW = ClusterWidth(left)
        local rW = ClusterWidth(right)
        if w > 0 and (lW + rW + gap) > w then
            return lH + rowGap + rH
        end
        return max(lH, rH, rowHeight)
    end

    function bar:OnHeightChanged(fn)
        if type(fn) == "function" then
            table.insert(self._heightListeners, fn)
        end
    end

    bar:HookScript("OnSizeChanged", function() bar:Refresh() end)
    C_Timer.After(0, function() bar:Refresh() end)

    return bar
end

function OneWoW_GUI:CreateHeroPanel(parent, options)
    options = options or {}
    local minHeight = options.height or Constants.GUI.HERO_PANEL_HEIGHT
    local insetX = options.insetX or OneWoW_GUI:GetSpacing("MD")
    local yOffset = options.yOffset or -OneWoW_GUI:GetSpacing("MD")
    local panel = self:CreateFrame(parent, {
        height = minHeight,
        backdrop = Constants.BACKDROP_INNER_NO_INSETS,
        bgColor = options.bgColor or "BG_SECONDARY",
        borderColor = options.borderColor or "BORDER_ACCENT",
    })
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", insetX, yOffset)
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -insetX, yOffset)
    panel._minHeight = minHeight
    panel._yOffset = yOffset
    panel._heightListeners = {}

    local accent = panel:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(4)
    accent:SetColorTexture(OneWoW_GUI:GetThemeColor(options.accentColor or "ACCENT_PRIMARY"))
    panel.accent = accent

    local iconSize = options.iconSize or 48
    local iconFrame = self:CreateFrame(panel, {
        width = iconSize + 10,
        height = iconSize + 10,
        backdrop = Constants.BACKDROP_INNER_NO_INSETS,
        bgColor = "BG_TERTIARY",
        borderColor = "BORDER_ACCENT",
    })
    iconFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", OneWoW_GUI:GetSpacing("LG"), -OneWoW_GUI:GetSpacing("LG"))

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(iconSize, iconSize)
    icon:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    if options.iconAtlas then
        icon:SetAtlas(options.iconAtlas)
    else
        icon:SetTexture(options.iconTexture or self:GetBrandIcon())
    end
    panel.icon = icon

    local title = self:CreateFS(panel, options.titleSize or 18)
    title:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", OneWoW_GUI:GetSpacing("MD"), -2)
    title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -OneWoW_GUI:GetSpacing("LG"), -2)
    title:SetJustifyH("LEFT")
    title:SetText(options.title or "")
    title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    panel.title = title

    local subtitle = self:CreateFS(panel, options.subtitleSize or 12)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -4)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(options.subtitle or "")
    subtitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    panel.subtitle = subtitle

    local description = self:CreateFS(panel, options.descriptionSize or 11)
    description:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -6)
    description:SetPoint("TOPRIGHT", subtitle, "BOTTOMRIGHT", 0, -6)
    description:SetJustifyH("LEFT")
    description:SetWordWrap(true)
    description:SetText(options.description or "")
    description:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    panel.description = description

    if options.calloutText and options.calloutText ~= "" then
        local callout = self:CreateFrame(panel, {
            width = options.calloutWidth or 185,
            height = Constants.GUI.BADGE_HEIGHT,
            backdrop = Constants.BACKDROP_INNER_NO_INSETS,
            bgColor = "BG_ACTIVE",
            borderColor = "BORDER_ACCENT",
        })
        callout:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("MD"), OneWoW_GUI:GetSpacing("MD"))
        callout.text = self:CreateFS(callout, 10)
        callout.text:SetPoint("CENTER", callout, "CENTER", 0, 0)
        callout.text:SetText(options.calloutText)
        callout.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        panel.callout = callout
    end

    panel.bottomY = yOffset - minHeight

    local pad = OneWoW_GUI:GetSpacing("LG")

    local function MeasureFSHeight(fs, availW)
        if not fs then return 0 end
        if availW > 20 and fs.SetWidth then
            fs:SetWidth(availW)
        end
        local _, fontSize = fs:GetFont()
        local lineH = (fontSize or 12) * 1.2
        local h1 = fs:GetStringHeight() or 0
        local unboundedW = 0
        if fs.GetUnboundedStringWidth then
            unboundedW = fs:GetUnboundedStringWidth() or 0
        end
        if unboundedW <= 0 and fs.GetStringWidth then
            unboundedW = fs:GetStringWidth() or 0
        end
        local h2 = lineH
        if availW > 0 and unboundedW > availW then
            local lines = ceil(unboundedW / availW)
            if lines > 1 then lines = lines + 1 end
            h2 = lines * lineH
        end
        if h1 > h2 then return h1 end
        return h2
    end

    local function ComputeTextWidth()
        local panelW = panel:GetWidth() or 0
        if panelW <= 0 then return 0 end
        local iconBoxW = (options.iconSize or 48) + 10
        return panelW - iconBoxW - (pad * 2) - OneWoW_GUI:GetSpacing("MD")
    end

    local function MeasureHeight()
        local textW = ComputeTextWidth()
        local titleH = MeasureFSHeight(panel.title, textW)
        local subtitleH = MeasureFSHeight(panel.subtitle, textW)
        local descH = MeasureFSHeight(panel.description, textW)
        local textTotal = pad + titleH + 4 + subtitleH + 6 + descH + pad
        local iconH = (options.iconSize or 48) + 10 + (pad * 2)
        local desired = max(panel._minHeight, textTotal, iconH)
        if panel.callout then
            local calloutBottom = (Constants.GUI.BADGE_HEIGHT or 18) + OneWoW_GUI:GetSpacing("MD") * 2
            if calloutBottom > desired then desired = calloutBottom end
        end
        return desired
    end

    panel._isResizing = false
    local function Relayout()
        if panel._isResizing then return end
        local desired = MeasureHeight()
        local current = panel:GetHeight() or 0
        if abs(desired - current) > 0.5 then
            panel._isResizing = true
            panel:SetHeight(desired)
            panel._isResizing = false
        end
        panel.bottomY = panel._yOffset - desired
        for _, fn in ipairs(panel._heightListeners) do
            fn(panel, desired)
        end
    end
    panel._relayout = Relayout

    function panel:GetMeasuredHeight()
        return MeasureHeight()
    end

    function panel:OnHeightChanged(fn)
        if type(fn) == "function" then
            table.insert(self._heightListeners, fn)
        end
    end

    panel:HookScript("OnSizeChanged", function() Relayout() end)
    C_Timer.After(0, Relayout)

    return panel
end

function OneWoW_GUI:CreateSummaryStrip(parent, options)
    options = options or {}
    local minHeight = options.height or Constants.GUI.SUMMARY_STRIP_HEIGHT
    local insetX = options.insetX or OneWoW_GUI:GetSpacing("MD")
    local yOffset = options.yOffset or 0
    local items = options.items or {}
    local strip = self:CreateFrame(parent, {
        height = minHeight,
        backdrop = Constants.BACKDROP_INNER_NO_INSETS,
        bgColor = options.bgColor or "BG_PRIMARY",
        borderColor = options.borderColor or "BORDER_SUBTLE",
    })
    strip:SetPoint("TOPLEFT", parent, "TOPLEFT", insetX, yOffset)
    strip:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -insetX, yOffset)
    strip.itemBoxes = {}
    strip._minHeight = minHeight
    strip._yOffset = yOffset
    strip._heightListeners = {}

    for i, item in ipairs(items) do
        local box = self:CreateFrame(strip, {
            backdrop = Constants.BACKDROP_INNER_NO_INSETS,
            bgColor = "BG_TERTIARY",
            borderColor = "BORDER_SUBTLE",
        })
        box.value = self:CreateFS(box, item.valueSize or 15)
        box.value:SetPoint("TOPLEFT", box, "TOPLEFT", OneWoW_GUI:GetSpacing("SM"), -7)
        box.value:SetPoint("TOPRIGHT", box, "TOPRIGHT", -OneWoW_GUI:GetSpacing("SM"), -7)
        box.value:SetJustifyH("LEFT")
        box.value:SetText(item.value or "")
        box.value:SetTextColor(OneWoW_GUI:GetThemeColor(item.valueColor or "TEXT_ACCENT"))

        box.label = self:CreateFS(box, item.labelSize or 10)
        box.label:SetPoint("TOPLEFT", box.value, "BOTTOMLEFT", 0, -4)
        box.label:SetPoint("TOPRIGHT", box.value, "BOTTOMRIGHT", 0, -4)
        box.label:SetJustifyH("LEFT")
        box.label:SetText(item.label or "")
        box.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        strip.itemBoxes[i] = box
    end

    strip._isResizing = false
    local function MeasureHeight()
        local maxText = 0
        for _, box in ipairs(strip.itemBoxes) do
            local vH = box.value and (box.value:GetStringHeight() or 0) or 0
            local lH = box.label and (box.label:GetStringHeight() or 0) or 0
            local total = 7 + vH + 4 + lH + 7
            if total > maxText then maxText = total end
        end
        local pad = OneWoW_GUI:GetSpacing("SM") * 2
        return max(strip._minHeight, maxText + pad)
    end

    local function LayoutBoxes()
        local count = #strip.itemBoxes
        if count == 0 then return end
        local width = strip:GetWidth()
        if width <= 0 then return end
        local gap = OneWoW_GUI:GetSpacing("SM")
        local innerX = OneWoW_GUI:GetSpacing("SM")
        local boxWidth = (width - (innerX * 2) - (gap * (count - 1))) / count
        local textWidth = max(20, boxWidth - (OneWoW_GUI:GetSpacing("SM") * 2))
        for _, box in ipairs(strip.itemBoxes) do
            if box.value and box.value.SetWidth then box.value:SetWidth(textWidth) end
            if box.label and box.label.SetWidth then box.label:SetWidth(textWidth) end
        end
        local desired = MeasureHeight()
        if not strip._isResizing then
            local current = strip:GetHeight() or 0
            if abs(desired - current) > 0.5 then
                strip._isResizing = true
                strip:SetHeight(desired)
                strip._isResizing = false
            end
        end
        strip.bottomY = strip._yOffset - desired
        for i, box in ipairs(strip.itemBoxes) do
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", strip, "TOPLEFT", innerX + ((i - 1) * (boxWidth + gap)), -OneWoW_GUI:GetSpacing("SM"))
            box:SetSize(boxWidth, desired - (gap * 2))
        end
        for _, fn in ipairs(strip._heightListeners) do
            fn(strip, desired)
        end
    end
    strip._relayout = LayoutBoxes

    strip:HookScript("OnSizeChanged", LayoutBoxes)
    C_Timer.After(0, LayoutBoxes)

    function strip:SetItemValue(index, value)
        local box = self.itemBoxes and self.itemBoxes[index]
        if box and box.value then
            box.value:SetText(value or "")
            if self._relayout then self._relayout() end
        end
    end

    function strip:GetMeasuredHeight()
        return MeasureHeight()
    end

    function strip:OnHeightChanged(fn)
        if type(fn) == "function" then
            table.insert(self._heightListeners, fn)
        end
    end

    strip.bottomY = yOffset - minHeight
    return strip
end

function OneWoW_GUI:CreateSelectableCard(parent, options)
    options = options or {}
    local minHeight = options.height or Constants.GUI.SELECTABLE_CARD_HEIGHT
    local card = CreateFrame("Button", options.name, parent, "BackdropTemplate")
    card:SetHeight(minHeight)
    card:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    card:RegisterForClicks("LeftButtonUp")
    card._checked = options.checked and true or false
    card._onToggle = options.onToggle
    card._minHeight = minHeight
    card._heightListeners = {}
    -- Sub-row support: non-interactive (bundled/forced), muted (parent off), and a
    -- left inset honored by StackVertically so children sit under their parent.
    card._interactive = options.interactive ~= false
    card._muted = options.muted and true or false
    if options.indent then
        card._stackLeftInset = options.indent
    end

    local selectedAccent = card:CreateTexture(nil, "ARTWORK")
    selectedAccent:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
    selectedAccent:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0)
    selectedAccent:SetWidth(4)
    selectedAccent:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    card.selectedAccent = selectedAccent

    local iconSize = options.iconSize or Constants.GUI.SELECTABLE_CARD_ICON_SIZE
    local iconPlate = options.iconPlate ~= false
    local iconFrame
    if iconPlate then
        iconFrame = self:CreateFrame(card, {
            width = iconSize + 8,
            height = iconSize + 8,
            backdrop = Constants.BACKDROP_INNER_NO_INSETS,
            bgColor = "BG_TERTIARY",
            borderColor = "BORDER_SUBTLE",
        })
    else
        iconFrame = self:CreateLayoutFrame(card, {
            width = iconSize + 8,
            height = iconSize + 8,
        })
    end
    iconFrame:SetPoint("LEFT", card, "LEFT", OneWoW_GUI:GetSpacing("MD"), 0)
    card.iconFrame = iconFrame
    card._iconPlate = iconPlate

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(iconSize, iconSize)
    icon:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    if options.iconAtlas then
        icon:SetAtlas(options.iconAtlas, false)
    else
        icon:SetTexture(options.iconTexture or self:GetBrandIcon())
    end
    if options.iconTexCoords then
        icon:SetTexCoord(unpack(options.iconTexCoords))
    end
    card.icon = icon

    local check = self:CreateCheckbox(card, {
        label = "",
        checked = card._checked,
        onClick = function(myself)
            if not card._interactive then
                myself:SetChecked(card._checked)
                return
            end
            card:SetChecked(myself:GetChecked() and true or false)
        end,
    })
    check:SetPoint("RIGHT", card, "RIGHT", -OneWoW_GUI:GetSpacing("MD"), 0)
    card.checkbox = check
    if not card._interactive then
        check:Disable()
    end

    local title = self:CreateFS(card, options.titleSize or 13)
    title:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", OneWoW_GUI:GetSpacing("MD"), -5)
    title:SetJustifyH("LEFT")
    title:SetText(options.title or "")
    card.title = title

    local summary = self:CreateFS(card, options.summarySize or 11)
    summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    summary:SetJustifyH("LEFT")
    summary:SetWordWrap(true)
    summary:SetText(options.summary or "")
    card.summary = summary

    -- Right cluster, laid out right-to-left: checkbox, optional "What's affected?"
    -- link, optional badge. Re-run whenever the badge appears/disappears so the
    -- title/summary always stop at the leftmost visible element.
    local function LayoutRightCluster()
        local anchor = check
        if card.affectedBtn then
            card.affectedBtn:SetPoint("RIGHT", anchor, "LEFT", -OneWoW_GUI:GetSpacing("SM"), 0)
            anchor = card.affectedBtn
        end
        if card.badge and card.badge:IsShown() then
            card.badge:SetPoint("RIGHT", anchor, "LEFT", -OneWoW_GUI:GetSpacing("SM"), 0)
            anchor = card.badge
        end
        card.title:SetPoint("RIGHT", anchor, "LEFT", -OneWoW_GUI:GetSpacing("MD"), 0)
        card.summary:SetPoint("RIGHT", anchor, "LEFT", -OneWoW_GUI:GetSpacing("MD"), 0)
    end

    local function EnsureBadge()
        if card.badge then return card.badge end
        local badge = self:CreateFrame(card, {
            width = Constants.GUI.BADGE_HEIGHT,
            height = Constants.GUI.BADGE_HEIGHT,
            backdrop = Constants.BACKDROP_INNER_NO_INSETS,
            bgColor = "BG_TERTIARY",
            borderColor = "BORDER_SUBTLE",
        })
        badge:SetPoint("RIGHT", check, "LEFT", -OneWoW_GUI:GetSpacing("SM"), 0)
        badge.text = self:CreateFS(badge, 9)
        badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)
        card.badge = badge
        return badge
    end

    if options.affectedText and options.onAffectedClick then
        local affectedBtn = self:CreateFitTextButton(card, {
            text = options.affectedText,
            height = 18,
            minWidth = 40,
            paddingX = 8,
        })
        affectedBtn:SetScript("OnClick", options.onAffectedClick)
        card.affectedBtn = affectedBtn
    end

    local function ApplyVisual(myself, hover)
        if myself._muted then
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            myself.selectedAccent:Hide()
            myself.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            myself.summary:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            myself.icon:SetDesaturated(true)
            myself.icon:SetAlpha(0.4)
            if myself._iconPlate then
                myself.iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end
            if myself.badge then
                myself.badge:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                myself.badge.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
            return
        end
        if myself._checked then
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor(hover and "BG_HOVER" or "BG_ACTIVE"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor(hover and "BORDER_FOCUS" or "BORDER_ACCENT"))
            myself.selectedAccent:Show()
            myself.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            myself.summary:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            myself.icon:SetDesaturated(false)
            myself.icon:SetAlpha(1)
            if myself._iconPlate then
                myself.iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            end
            if myself.badge then
                myself.badge:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                myself.badge.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        else
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor(hover and "BG_HOVER" or "BG_SECONDARY"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor(hover and "BORDER_FOCUS" or "BORDER_SUBTLE"))
            myself.selectedAccent:Hide()
            myself.title:SetTextColor(OneWoW_GUI:GetThemeColor(hover and "TEXT_ACCENT" or "TEXT_PRIMARY"))
            myself.summary:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            myself.icon:SetDesaturated(true)
            myself.icon:SetAlpha(0.68)
            if myself._iconPlate then
                myself.iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end
            if myself.badge then
                myself.badge:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                myself.badge.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            end
        end
    end

    function card:SetChecked(checked, silent)
        self._checked = checked and true or false
        self.checkbox:SetChecked(self._checked)
        ApplyVisual(self, self:IsMouseOver())
        if not silent and self._onToggle then
            self._onToggle(self, self._checked)
        end
    end

    function card:GetChecked()
        return self._checked
    end

    function card:SetMuted(muted)
        self._muted = muted and true or false
        ApplyVisual(self, self:IsMouseOver())
    end

    function card:SetInteractive(interactive)
        self._interactive = interactive and true or false
        if self._interactive then
            self.checkbox:Enable()
        else
            self.checkbox:Disable()
        end
    end

    function card:SetBadgeText(text)
        if not text or text == "" then
            if self.badge then self.badge:Hide() end
            LayoutRightCluster()
            return
        end
        local b = EnsureBadge()
        b.text:SetText(text)
        local badgeMeasure = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        OneWoW_GUI:SafeSetFont(badgeMeasure, OneWoW_GUI:GetFont(), 9)
        badgeMeasure:SetText(text)
        b:SetWidth(max(options.badgeWidth or 0, badgeMeasure:GetStringWidth() + 18))
        badgeMeasure:Hide()
        badgeMeasure:SetParent(nil)
        b:Show()
        LayoutRightCluster()
        ApplyVisual(self, self:IsMouseOver())
    end

    LayoutRightCluster()
    if options.badgeText and options.badgeText ~= "" then
        card:SetBadgeText(options.badgeText)
    end

    card:SetScript("OnEnter", function(myself) ApplyVisual(myself, true) end)
    card:SetScript("OnLeave", function(myself) ApplyVisual(myself, false) end)
    card:SetScript("OnClick", function(myself)
        if not myself._interactive then return end
        myself:SetChecked(not myself._checked)
    end)

    card:SetChecked(card._checked, true)

    local pad = OneWoW_GUI:GetSpacing("SM")
    local titleTopOffset = 5
    local summaryGap = 5
    local bottomPad = pad

    local function MeasureFSHeight(fs, availW)
        if not fs then return 0 end
        if availW > 20 and fs.SetWidth then
            fs:SetWidth(availW)
        end
        local _, fontSize = fs:GetFont()
        local lineH = (fontSize or 12) * 1.2
        local h1 = fs:GetStringHeight() or 0
        local unboundedW = 0
        if fs.GetUnboundedStringWidth then
            unboundedW = fs:GetUnboundedStringWidth() or 0
        end
        if unboundedW <= 0 and fs.GetStringWidth then
            unboundedW = fs:GetStringWidth() or 0
        end
        local h2 = lineH
        if availW > 0 and unboundedW > availW then
            local lines = ceil(unboundedW / availW)
            if lines > 1 then lines = lines + 1 end
            h2 = lines * lineH
        end
        if h1 > h2 then return h1 end
        return h2
    end

    local function ComputeTextWidth()
        local cardW = card:GetWidth() or 0
        if cardW <= 0 then return 0 end
        local iconFrameW = card.iconFrame and (card.iconFrame:GetWidth() or 0) or 0
        local checkW = card.checkbox and (card.checkbox:GetWidth() or 0) or 0
        return cardW - iconFrameW - checkW - (OneWoW_GUI:GetSpacing("MD") * 4)
    end

    local function MeasureHeight()
        local textW = ComputeTextWidth()
        local titleH = MeasureFSHeight(card.title, textW)
        local summaryH = MeasureFSHeight(card.summary, textW)
        local iconH = card.iconFrame and (card.iconFrame:GetHeight() or 0) or 0
        local textTotal = titleTopOffset + titleH + summaryGap + summaryH + bottomPad
        local iconTotal = iconH + (pad * 2)
        return max(card._minHeight, textTotal, iconTotal)
    end

    card._isResizing = false
    local function Relayout()
        if card._isResizing then return end
        local desired = MeasureHeight()
        local current = card:GetHeight() or 0
        if abs(desired - current) > 0.5 then
            card._isResizing = true
            card:SetHeight(desired)
            card._isResizing = false
        end
        card.bottomY = -desired
        for _, fn in ipairs(card._heightListeners) do
            fn(card, desired)
        end
    end
    card._relayout = Relayout

    function card:GetMeasuredHeight()
        return MeasureHeight()
    end

    function card:OnHeightChanged(fn)
        if type(fn) == "function" then
            table.insert(self._heightListeners, fn)
        end
    end

    card:HookScript("OnSizeChanged", function()
        Relayout()
        C_Timer.After(0, Relayout)
    end)
    C_Timer.After(0, Relayout)
    C_Timer.After(0.05, Relayout)

    return card
end

--- Indented selectable row for Manage Features data-store sub-rows.
--- Thin preset over CreateSelectableCard: smaller icon/text and a left inset so
--- children align under the midpoint of their parent's icon. Returns the card
--- frame (same stacking contract as CreateSelectableCard) and reuses all of its
--- behavior (muted, non-interactive, badge, "What's affected?" link).
---@param parent Frame
---@param options table?
---@return Button card
function OneWoW_GUI:CreateSelectableSubCard(parent, options)
    options = options or {}
    local parentIconSize = Constants.GUI.SELECTABLE_CARD_ICON_SIZE
    local defaultIndent = OneWoW_GUI:GetSpacing("MD") + (parentIconSize + 8) / 2

    local subOptions = {}
    for k, v in pairs(options) do
        subOptions[k] = v
    end
    subOptions.indent = options.indent or defaultIndent
    subOptions.height = options.height or Constants.GUI.SELECTABLE_SUB_CARD_HEIGHT
    subOptions.iconSize = options.iconSize or 26
    subOptions.titleSize = options.titleSize or 12
    subOptions.summarySize = options.summarySize or 10

    return OneWoW_GUI:CreateSelectableCard(parent, subOptions)
end

function OneWoW_GUI:CreateVerticalPaneResizer(options)
    options = options or {}
    local parent = options.parent
    local leftPanel = options.leftPanel
    local rightPanel = options.rightPanel
    if not parent or not leftPanel or not rightPanel then
        error("OneWoW_GUI:CreateVerticalPaneResizer requires parent, leftPanel, and rightPanel")
    end

    local dividerWidth = options.dividerWidth or 6
    local leftMinWidth = options.leftMinWidth or 200
    local rightMinWidth = options.rightMinWidth or 280
    local splitPadding = options.splitPadding
    if splitPadding == nil then
        splitPadding = dividerWidth + 10
    end
    local bottomOuterInset = options.bottomOuterInset or 5
    local rightOuterInset = options.rightOuterInset or 5
    local resizeCap = options.resizeCap or 0.95
    local mainFrame = options.mainFrame -- widened when drag would leave less than dynamic right reserve
    local getMinRightWidth = options.getMinRightWidth -- fun() -> number; used only to grow mainFrame (e.g. unbounded text width)
    local onWidthChanged = options.onWidthChanged -- fun(leftWidth) after mouse release (persist)
    local maxAutoGrowSteps = options.maxAutoGrowSteps or 12 -- max mainFrame widen attempts per drag tick; handles deferred layout width

    local function effectiveRightReserveForGrow()
        local r = rightMinWidth
        if getMinRightWidth then
            local n = getMinRightWidth()
            if type(n) == "number" and n > r then
                r = n
            end
        end
        return r
    end

    local divider = CreateFrame("Button", nil, parent)
    divider:SetWidth(dividerWidth)
    divider:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 0, 0)
    divider:SetPoint("BOTTOM", parent, "BOTTOM", 0, bottomOuterInset)
    divider:EnableMouse(true)

    local dividerTex = divider:CreateTexture(nil, "OVERLAY")
    dividerTex:SetWidth(2)
    dividerTex:SetPoint("TOP", divider, "TOP", 0, 0)
    dividerTex:SetPoint("BOTTOM", divider, "BOTTOM", 0, 0)
    dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    divider:SetScript("OnEnter", function()
        dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        SetCursor("UI_RESIZE_CURSOR")
    end)
    divider:SetScript("OnLeave", function(myself)
        if not myself._owPaneDragActive then
            dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            SetCursor(nil)
        end
    end)

    divider:SetScript("OnMouseDown", function(myself, button)
        if button == "LeftButton" then
            myself._owPaneDragActive = true
            local x = GetCursorPosition()
            myself._owPaneStartCursorX = x / myself:GetEffectiveScale()
            myself._owPaneStartLeftW = leftPanel:GetWidth()
        end
    end)

    divider:SetScript("OnMouseUp", function(myself, button)
        if button == "LeftButton" and myself._owPaneDragActive then
            myself._owPaneDragActive = false
            dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            SetCursor(nil)
            if onWidthChanged then
                onWidthChanged(leftPanel:GetWidth())
            end
        end
    end)

    divider:SetScript("OnUpdate", function(myself)
        if not myself._owPaneDragActive then return end
        local cursorX = GetCursorPosition() / myself:GetEffectiveScale()
        local delta = cursorX - myself._owPaneStartCursorX
        local desiredLeftWidth = max(leftMinWidth, myself._owPaneStartLeftW + delta)

        local neededRightGrow = effectiveRightReserveForGrow()
        local screenMax = floor(GetScreenWidth() * resizeCap)
        -- Grow host until tab can fit desiredLeft + dynamic right reserve (handles layout lag with multiple steps).
        if mainFrame then
            for _ = 1, maxAutoGrowSteps do
                local tabW = parent:GetWidth()
                local minTabW = desiredLeftWidth + neededRightGrow + splitPadding
                if tabW >= minTabW then
                    break
                end
                local gap = minTabW - tabW
                local shortage = max(1, ceil(gap - 1e-6))
                local currentMainW = mainFrame:GetWidth()
                local newMainW = min(currentMainW + shortage, screenMax)
                if newMainW <= currentMainW then
                    break
                end
                mainFrame:SetWidth(newMainW)
            end
        end

        local tabWidth = parent:GetWidth()
        -- Clamp uses fixed rightMinWidth only
        local maxLeftWidth = tabWidth - rightMinWidth - splitPadding
        if maxLeftWidth < leftMinWidth then
            maxLeftWidth = leftMinWidth
        end
        local newLeftWidth = max(leftMinWidth, min(desiredLeftWidth, maxLeftWidth))
        leftPanel:SetWidth(newLeftWidth)
    end)

    rightPanel:ClearAllPoints()
    rightPanel:SetPoint("TOPLEFT", divider, "TOPRIGHT", 0, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -rightOuterInset, bottomOuterInset)

    parent:HookScript("OnSizeChanged", function(_, w)
        local maxLeftWidth = w - rightMinWidth - splitPadding
        if maxLeftWidth < leftMinWidth then
            maxLeftWidth = leftMinWidth
        end
        local currentLeftWidth = leftPanel:GetWidth()
        if currentLeftWidth > maxLeftWidth then
            leftPanel:SetWidth(maxLeftWidth)
        end
    end)

    return divider
end

function OneWoW_GUI:CreateHorizontalPaneResizer(options)
    options = options or {}
    local parent = options.parent
    local topPanel = options.topPanel
    local bottomPanel = options.bottomPanel
    if not parent or not topPanel or not bottomPanel then
        error("OneWoW_GUI:CreateHorizontalPaneResizer requires parent, topPanel, and bottomPanel")
    end

    local dividerHeight = options.dividerHeight or 6
    local topMinHeight = options.topMinHeight or 100
    local bottomMinHeight = options.bottomMinHeight or 60
    local onHeightChanged = options.onHeightChanged

    local divider = CreateFrame("Button", nil, parent)
    divider:SetHeight(dividerHeight)
    divider:SetPoint("TOPLEFT", topPanel, "BOTTOMLEFT", 0, 0)
    divider:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    divider:EnableMouse(true)

    local dividerTex = divider:CreateTexture(nil, "OVERLAY")
    dividerTex:SetHeight(2)
    dividerTex:SetPoint("LEFT", divider, "LEFT", 0, 0)
    dividerTex:SetPoint("RIGHT", divider, "RIGHT", 0, 0)
    dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    divider:SetScript("OnEnter", function()
        dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        SetCursor("UI_RESIZE_CURSOR")
    end)
    divider:SetScript("OnLeave", function(myself)
        if not myself._owPaneDragActive then
            dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            SetCursor(nil)
        end
    end)

    divider:SetScript("OnMouseDown", function(myself, button)
        if button == "LeftButton" then
            myself._owPaneDragActive = true
            local _, y = GetCursorPosition()
            myself._owPaneStartCursorY = y / myself:GetEffectiveScale()
            myself._owPaneStartTopH = topPanel:GetHeight()
        end
    end)

    divider:SetScript("OnMouseUp", function(myself, button)
        if button == "LeftButton" and myself._owPaneDragActive then
            myself._owPaneDragActive = false
            dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            SetCursor(nil)
            if onHeightChanged then
                onHeightChanged(bottomPanel:GetHeight())
            end
        end
    end)

    divider:SetScript("OnUpdate", function(myself)
        if not myself._owPaneDragActive then return end
        local _, cursorY = GetCursorPosition()
        cursorY = cursorY / myself:GetEffectiveScale()
        local delta = myself._owPaneStartCursorY - cursorY
        local desiredTopH = max(topMinHeight, myself._owPaneStartTopH + delta)

        local totalH = parent:GetHeight()
        local maxTopH = totalH - bottomMinHeight - dividerHeight
        if maxTopH < topMinHeight then maxTopH = topMinHeight end
        local newTopH = max(topMinHeight, min(desiredTopH, maxTopH))
        topPanel:SetHeight(newTopH)
    end)

    bottomPanel:ClearAllPoints()
    bottomPanel:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, 0)
    bottomPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    parent:HookScript("OnSizeChanged", function(_, _, h)
        if not h then return end
        local maxTopH = h - bottomMinHeight - dividerHeight
        if maxTopH < topMinHeight then maxTopH = topMinHeight end
        local currentTopH = topPanel:GetHeight()
        if currentTopH > maxTopH then
            topPanel:SetHeight(maxTopH)
        end
    end)

    return divider
end
