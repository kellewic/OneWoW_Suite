local OneWoW_GUI = OneWoW_GUI
local Constants = OneWoW_GUI.Constants

local CreateFrame = CreateFrame
local unpack = unpack

local ICON_TRIM_COORDS = { 0.07, 0.93, 0.07, 0.93 }
local ICON_FULL_COORDS = { 0, 1, 0, 1 }

local ICON_STYLE_PRESETS = {
    clean = {
        borderSize = 1,
        padding = 1,
        trimIcon = true,
        showHighlight = true,
        highlightAlpha = 0.3,
        bgAlpha = 0.9,
    },
    thick = {
        borderSize = 2,
        padding = 1,
        trimIcon = true,
        showHighlight = true,
        highlightAlpha = 0.3,
        bgAlpha = 0.9,
    },
    minimal = {
        borderSize = 1,
        padding = 0,
        trimIcon = true,
        showHighlight = true,
        highlightAlpha = 0.2,
        bgAlpha = 0.8,
    },
    none = {
        borderSize = 0,
        padding = 0,
        trimIcon = true,
        showHighlight = false,
        highlightAlpha = 0,
        bgAlpha = 0,
    },
}

local BORDER_EDGE_FILE = "Interface\\Buttons\\WHITE8X8"

local function ApplyBorderBackdrop(border, edgeSize)
    border:SetBackdrop({
        edgeFile = BORDER_EDGE_FILE,
        edgeSize = edgeSize,
    })
end

-- Uses Blizzard's BackdropTemplate (not custom OVERLAY textures) so 1px edges
-- pixel-snap reliably even when the parent lands on non-integer physical pixels.
-- FrameLevel = parent + 1 so the border draws above the icon (same plane as
-- Overlays Quality Border chrome). Overlay containers (ilvl, icon overlays)
-- render at parent + 2 so content stays above chrome.
local function CreateEdgeBorder(frame, edgeSize)
    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetAllPoints(frame)
    border:SetFrameLevel(frame:GetFrameLevel() + 1)
    border:EnableMouse(false)
    ApplyBorderBackdrop(border, edgeSize)
    border:SetBackdropBorderColor(1, 1, 1, 1)
    border._edgeSize = edgeSize
    return border
end

function OneWoW_GUI:CreateItemIcon(parent, options)
    options = options or {}
    local size = options.size or 48
    local showIlvl = options.showIlvl ~= false
    local itemLink = options.itemLink
    local itemID = options.itemID
    local quality = options.quality or 1
    local itemLevel = options.itemLevel
    local iconTexture = options.iconTexture

    local iconFrame = CreateFrame("Button", nil, parent, "BackdropTemplate")
    iconFrame:SetSize(size, size)

    local tex = iconFrame:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints(iconFrame)

    if iconTexture then
        tex:SetTexture(iconTexture)
    elseif itemID then
        local icon = C_Item.GetItemIconByID(itemID)
        tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    else
        tex:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    end

    local borderFrame = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
    borderFrame:SetAllPoints(iconFrame)
    borderFrame:SetFrameLevel(iconFrame:GetFrameLevel() + 1)

    if itemLink or itemID then
        borderFrame:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        borderFrame:SetBackdropBorderColor(OneWoW_GUI:GetItemQualityColor(quality))
    else
        borderFrame:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        borderFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end

    local ilvlText = nil
    if showIlvl then
        ilvlText = iconFrame:CreateFontString(nil, "OVERLAY")
        ilvlText:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
        ilvlText:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -2, 2)
        ilvlText:SetTextColor(unpack(Constants.ICON_OVERLAY_TEXT))
        ilvlText:SetShadowColor(0, 0, 0, 1)
        ilvlText:SetShadowOffset(1, -1)

        if itemLevel and itemLevel > 0 then
            ilvlText:SetText(tostring(itemLevel))
        else
            ilvlText:SetText("")
        end
    end

    if itemLink then
        iconFrame:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink)
            GameTooltip:Show()
        end)
        iconFrame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return {
        frame = iconFrame,
        texture = tex,
        border = borderFrame,
        ilvlText = ilvlText,
    }
end

--- Portrait with a faction badge on the corner. Call :SetUnit / :SetFaction.
---@param parent Frame
---@param options { size: number|nil, badgeSize: number|nil }
---@return Frame
function OneWoW_GUI:CreatePortraitWithFaction(parent, options)
    options = options or {}
    local size = options.size or 56
    local badgeSize = options.badgeSize or 18
    local C = OneWoW_GUI.Constants

    local frame = OneWoW_GUI:CreateFrame(parent, {
        width = size + 8,
        height = size + 8,
        backdrop = C.BACKDROP_INNER_NO_INSETS,
        bgColor = "BG_TERTIARY",
        borderColor = "BORDER_ACCENT",
    })
    frame:EnableMouse(false)

    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(size, size)
    portrait:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.portrait = portrait

    local factionIcon = frame:CreateTexture(nil, "OVERLAY")
    factionIcon:SetSize(badgeSize, badgeSize)
    factionIcon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
    frame.factionIcon = factionIcon

    function frame:SetUnit(unit)
        SetPortraitTexture(self.portrait, unit)
    end

    function frame:SetFaction(faction)
        local icons = C.ICON_TEXTURES
        if faction == "Horde" then
            self.factionIcon:SetTexture(icons.horde)
        elseif faction == "Alliance" then
            self.factionIcon:SetTexture(icons.alliance)
        else
            self.factionIcon:SetTexture(icons.neutral)
        end
    end

    function frame:SetClassBorder(classFile)
        local color = (classFile and RAID_CLASS_COLORS[classFile]) or { r = 1, g = 1, b = 1 }
        self:SetBackdropBorderColor(color.r, color.g, color.b, 1)
    end

    return frame
end

function OneWoW_GUI:CreateFactionIcon(parent, options)
    options = options or {}
    local faction = options.faction or "Alliance"
    local size = options.size or 18
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size, size)
    icon:SetPoint("CENTER")
    if faction == "Alliance" then
        icon:SetTexture("Interface\\FriendsFrame\\PlusManz-Alliance")
    elseif faction == "Horde" then
        icon:SetTexture("Interface\\FriendsFrame\\PlusManz-Horde")
    else
        icon:SetTexture("Interface\\FriendsFrame\\PlusManz-Alliance")
        icon:SetDesaturated(true)
    end
    frame.icon = icon
    return frame
end

function OneWoW_GUI:CreateMailIcon(parent, options)
    options = options or {}
    local hasMail = options.hasMail or false
    local size = options.size or 16
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size, size)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")
    if hasMail then
        icon:SetVertexColor(1, 1, 0, 1)
    else
        icon:SetVertexColor(0.3, 0.3, 0.3, 0.5)
    end
    frame.icon = icon
    return frame
end

function OneWoW_GUI:GetIconStylePreset(name)
    return ICON_STYLE_PRESETS[name] or ICON_STYLE_PRESETS.clean
end

function OneWoW_GUI:SkinIconFrame(frame, options)
    options = options or {}
    local preset = options.preset and ICON_STYLE_PRESETS[options.preset] or ICON_STYLE_PRESETS.clean
    local borderSize = preset.borderSize
    if options.borderSize ~= nil then
        borderSize = options.borderSize
    end
    local padding = options.padding or preset.padding
    local trimIcon = options.trimIcon ~= nil and options.trimIcon or preset.trimIcon
    local showHighlight = options.showHighlight ~= nil and options.showHighlight or preset.showHighlight
    local highlightAlpha = options.highlightAlpha or preset.highlightAlpha
    local bgAlpha = preset.bgAlpha
    if options.bgAlpha ~= nil then
        bgAlpha = options.bgAlpha
    end
    local quality = options.quality
    local borderColorKey = options.borderColorKey or "BORDER_DEFAULT"
    local hoverBorderColorKey = options.hoverBorderColorKey or "BORDER_ACCENT"
    local desaturate = options.desaturate or false
    local iconTexture = options.iconTexture

    local iconTex = frame._skinnedIcon
    if not iconTex then
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            if region:IsObjectType("Texture") and region:GetDrawLayer() ~= "OVERLAY" then
                iconTex = region
                break
            end
        end
    end

    if iconTex then
        if trimIcon then
            iconTex:SetTexCoord(unpack(ICON_TRIM_COORDS))
        else
            iconTex:SetTexCoord(unpack(ICON_FULL_COORDS))
        end
        iconTex:ClearAllPoints()
        iconTex:SetPoint("TOPLEFT", frame, "TOPLEFT", padding + borderSize, -(padding + borderSize))
        iconTex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(padding + borderSize), padding + borderSize)
        iconTex:SetDesaturated(desaturate)
        if iconTexture then
            iconTex:SetTexture(iconTexture)
        end
        frame._skinnedIcon = iconTex
    end

    if not frame._skinBg then
        frame._skinBg = frame:CreateTexture(nil, "BORDER")
        frame._skinBg:SetAllPoints(frame)
    end
    frame._skinBg:SetColorTexture(0, 0, 0, bgAlpha)
    if bgAlpha > 0 then
        frame._skinBg:Show()
    else
        frame._skinBg:Hide()
    end

    if borderSize > 0 then
        if not frame._skinBorder then
            frame._skinBorder = CreateEdgeBorder(frame, borderSize)
        else
            ApplyBorderBackdrop(frame._skinBorder, borderSize)
            frame._skinBorder._edgeSize = borderSize
        end

        if quality and quality > 1 then
            frame._skinBorder:SetBackdropBorderColor(self:GetItemQualityColor(quality))
        else
            frame._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor(borderColorKey))
        end
        frame._skinBorderColorKey = borderColorKey
        frame._skinHoverBorderColorKey = hoverBorderColorKey
        frame._skinQuality = quality
    elseif frame._skinBorder then
        frame._skinBorder:SetBackdrop(nil)
    end

    if showHighlight then
        if not frame._skinHighlight then
            frame._skinHighlight = frame:CreateTexture(nil, "HIGHLIGHT")
            frame._skinHighlight:SetPoint("TOPLEFT", frame, "TOPLEFT", padding + borderSize, -(padding + borderSize))
            frame._skinHighlight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(padding + borderSize), padding + borderSize)
            frame._skinHighlight:SetColorTexture(1, 1, 1, highlightAlpha)
            frame._skinHighlight:SetBlendMode("ADD")
        else
            frame._skinHighlight:ClearAllPoints()
            frame._skinHighlight:SetPoint("TOPLEFT", frame, "TOPLEFT", padding + borderSize, -(padding + borderSize))
            frame._skinHighlight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(padding + borderSize), padding + borderSize)
            frame._skinHighlight:SetColorTexture(1, 1, 1, highlightAlpha)
        end
    elseif frame._skinHighlight then
        frame._skinHighlight:SetColorTexture(1, 1, 1, 0)
    end

    frame._skinOptions = options

    return frame
end

function OneWoW_GUI:UpdateIconQuality(frame, quality)
    if not frame or not frame._skinBorder then return end
    frame._skinQuality = quality
    if quality and quality > 1 then
        frame._skinBorder:SetBackdropBorderColor(self:GetItemQualityColor(quality))
    else
        local key = frame._skinBorderColorKey or "BORDER_DEFAULT"
        frame._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor(key))
    end
end

function OneWoW_GUI:UpdateIconTexture(frame, texture)
    if not frame or not frame._skinnedIcon then return end
    frame._skinnedIcon:SetTexture(texture)
end

function OneWoW_GUI:SetIconDesaturated(frame, desaturate)
    if not frame or not frame._skinnedIcon then return end
    frame._skinnedIcon:SetDesaturated(desaturate)
end

function OneWoW_GUI:CreateSkinnedIcon(parent, options)
    options = options or {}
    local size = options.size or 36
    local preset = options.preset or "clean"
    local iconTexture = options.iconTexture
    local quality = options.quality
    local itemLink = options.itemLink
    local itemID = options.itemID
    local showIlvl = options.showIlvl
    local itemLevel = options.itemLevel
    local showCount = options.showCount
    local count = options.count
    local onClick = options.onClick
    local onEnter = options.onEnter
    local onLeave = options.onLeave
    local tooltip = options.tooltip

    local frameType = (onClick or itemLink or tooltip) and "Button" or "Frame"
    local iconFrame = CreateFrame(frameType, nil, parent)
    iconFrame:SetSize(size, size)

    local presetData = ICON_STYLE_PRESETS[preset] or ICON_STYLE_PRESETS.clean
    local borderSize = options.borderSize or presetData.borderSize
    local padding = options.padding or presetData.padding
    local inset = padding + borderSize

    local bg = iconFrame:CreateTexture(nil, "BORDER")
    bg:SetAllPoints(iconFrame)
    bg:SetColorTexture(0, 0, 0, presetData.bgAlpha)
    iconFrame._skinBg = bg

    local tex = iconFrame:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", inset, -inset)
    tex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -inset, inset)

    if presetData.trimIcon then
        tex:SetTexCoord(unpack(ICON_TRIM_COORDS))
    end

    if iconTexture then
        tex:SetTexture(iconTexture)
    elseif itemID then
        local icon = C_Item.GetItemIconByID(itemID)
        tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    else
        tex:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    end
    iconFrame._skinnedIcon = tex

    if borderSize > 0 then
        local border = CreateEdgeBorder(iconFrame, borderSize)

        if quality and quality > 1 then
            border:SetBackdropBorderColor(self:GetItemQualityColor(quality))
        else
            border:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor(options.borderColorKey or "BORDER_DEFAULT"))
        end
        iconFrame._skinBorder = border
        iconFrame._skinBorderColorKey = options.borderColorKey or "BORDER_DEFAULT"
        iconFrame._skinHoverBorderColorKey = options.hoverBorderColorKey or "BORDER_ACCENT"
        iconFrame._skinQuality = quality
    end

    if presetData.showHighlight then
        local highlight = iconFrame:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", inset, -inset)
        highlight:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -inset, inset)
        highlight:SetColorTexture(1, 1, 1, presetData.highlightAlpha)
        highlight:SetBlendMode("ADD")
        iconFrame._skinHighlight = highlight
    end

    if showIlvl then
        local ilvlText = iconFrame:CreateFontString(nil, "OVERLAY")
        ilvlText:SetFont("Fonts\\ARIALN.TTF", math.max(9, math.floor(size * 0.24)), "OUTLINE")
        ilvlText:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -2, 2)
        ilvlText:SetTextColor(unpack(Constants.ICON_OVERLAY_TEXT))
        ilvlText:SetShadowColor(0, 0, 0, 1)
        ilvlText:SetShadowOffset(1, -1)
        if itemLevel and itemLevel > 0 then
            ilvlText:SetText(tostring(itemLevel))
        else
            ilvlText:SetText("")
        end
        iconFrame._ilvlText = ilvlText
    end

    if showCount then
        local countText = iconFrame:CreateFontString(nil, "OVERLAY")
        countText:SetFont("Fonts\\ARIALN.TTF", math.max(9, math.floor(size * 0.24)), "OUTLINE")
        countText:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -2, 2)
        countText:SetTextColor(unpack(Constants.ICON_OVERLAY_TEXT))
        countText:SetShadowColor(0, 0, 0, 1)
        countText:SetShadowOffset(1, -1)
        if count and count > 1 then
            countText:SetText(tostring(count))
        else
            countText:SetText("")
        end
        iconFrame._countText = countText
    end

    local hasHoverBorder = iconFrame._skinBorder and not (quality and quality > 1)
    if itemLink then
        iconFrame:SetScript("OnEnter", function(myself)
            if hasHoverBorder then
                myself._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor(myself._skinHoverBorderColorKey or "BORDER_ACCENT"))
            end
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink)
            GameTooltip:Show()
            if onEnter then onEnter(myself) end
        end)
        iconFrame:SetScript("OnLeave", function(myself)
            if hasHoverBorder then
                myself._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor(myself._skinBorderColorKey or "BORDER_DEFAULT"))
            end
            GameTooltip:Hide()
            if onLeave then onLeave(myself) end
        end)
    elseif tooltip then
        iconFrame:SetScript("OnEnter", function(myself)
            if hasHoverBorder then
                myself._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor(myself._skinHoverBorderColorKey or "BORDER_ACCENT"))
            end
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            if type(tooltip) == "function" then
                tooltip(myself)
            else
                GameTooltip:SetText(tostring(tooltip), 1, 1, 1)
            end
            GameTooltip:Show()
            if onEnter then onEnter(myself) end
        end)
        iconFrame:SetScript("OnLeave", function(myself)
            if hasHoverBorder then
                myself._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor(myself._skinBorderColorKey or "BORDER_DEFAULT"))
            end
            GameTooltip:Hide()
            if onLeave then onLeave(myself) end
        end)
    elseif hasHoverBorder then
        iconFrame:EnableMouse(true)
        iconFrame:SetScript("OnEnter", function(myself)
            myself._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor(myself._skinHoverBorderColorKey or "BORDER_ACCENT"))
            if onEnter then onEnter(myself) end
        end)
        iconFrame:SetScript("OnLeave", function(myself)
            myself._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor(myself._skinBorderColorKey or "BORDER_DEFAULT"))
            if onLeave then onLeave(myself) end
        end)
    end

    if onClick and frameType == "Button" then
        iconFrame:SetScript("OnClick", function(myself, button)
            onClick(myself, button)
        end)
    end

    iconFrame._skinOptions = options

    return iconFrame
end

function OneWoW_GUI:CreateIconRow(parent, options)
    options = options or {}
    local icons = options.icons or {}
    local iconSize = options.iconSize or 36
    local spacing = options.spacing or 4
    local preset = options.preset or "clean"
    local anchorPoint = options.anchorPoint or "LEFT"

    local container = CreateFrame("Frame", nil, parent)
    local totalWidth = (#icons * iconSize) + (math.max(0, #icons - 1) * spacing)
    container:SetSize(totalWidth, iconSize)

    container._icons = {}

    for i, iconData in ipairs(icons) do
        iconData.size = iconData.size or iconSize
        iconData.preset = iconData.preset or preset
        local iconFrame = self:CreateSkinnedIcon(container, iconData)

        if i == 1 then
            if anchorPoint == "CENTER" then
                iconFrame:SetPoint("LEFT", container, "LEFT", 0, 0)
            else
                iconFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            end
        else
            iconFrame:SetPoint("LEFT", container._icons[i - 1], "RIGHT", spacing, 0)
        end

        container._icons[i] = iconFrame
    end

    return container
end

function OneWoW_GUI:SkinCooldown(cooldown, options)
    options = options or {}
    if not cooldown then return end

    local swipeR = options.swipeR or 0
    local swipeG = options.swipeG or 0
    local swipeB = options.swipeB or 0
    local swipeAlpha = options.swipeAlpha or 0.6
    local hideEdge = options.hideEdge ~= false
    local hideBling = options.hideBling ~= false

    cooldown:SetSwipeColor(swipeR, swipeG, swipeB, swipeAlpha)

    if hideEdge and cooldown.SetEdgeTexture then
        cooldown:SetEdgeTexture("")
    end
    if hideBling and cooldown.SetBlingTexture then
        cooldown:SetBlingTexture("")
    end

    if cooldown:GetDrawSwipe() == false then
        cooldown:SetDrawSwipe(true)
    end

    return cooldown
end
