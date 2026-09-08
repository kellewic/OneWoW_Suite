local _, ns = ...
local ESCPanelModule, L = ns.ModuleRegistry:Current()
if not ESCPanelModule then return end

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI
local math = math

-- Session-only collapse memory (survives tab switches; cleared on /reload)
local collapsedCards = {}

local TOGGLE_TO_DB = {
    esc_show_character_info = "escShowCharacterInfo",
    esc_show_here           = "escShowHere",
    esc_show_portals        = "escPortalsEnabled",
    esc_skin_game_menu      = "escSkinGameMenu",
}

local CARD_PREVIEW_BASE = "Interface\\AddOns\\OneWoW_QoL\\Modules\\external\\escpanel\\Media\\"
local CARD_PREVIEW_ASPECT = 420 / 517

function ESCPanelModule:OnEnable()
    local ph = OneWoW:GetPortalHub()
    ph.escEnabled = true
    for toggleId, dbKey in pairs(TOGGLE_TO_DB) do
        if ph[dbKey] ~= nil then
            ns.ModuleRegistry:SetToggleValue(self.id, toggleId, ph[dbKey])
        end
    end
    if GameMenuFrame and GameMenuFrame:IsShown() then
        ns.PortalHubEsc:ShowPortalFrames()
    end
end

function ESCPanelModule:OnDisable()
    local ph = OneWoW:GetPortalHub()
    ph.escEnabled = false
    ns.PortalHubEsc:HidePortalFrames()
end

function ESCPanelModule:OnToggle(toggleId, value)
    local ph = OneWoW:GetPortalHub()
    local dbKey = TOGGLE_TO_DB[toggleId]
    if dbKey then
        ph[dbKey] = value
    end
    ns.PortalHubEsc:Reload()
end

function ESCPanelModule:CreateCustomDetail(detailScrollChild, yOffset, _, registerRefresh)
    local cardsHost = CreateFrame("Frame", nil, detailScrollChild)
    cardsHost:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
    cardsHost:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)

    local stack = OneWoW_GUI:CreateCardStack(cardsHost, {
        getCollapsed = function(key) return collapsedCards[key] end,
        setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    })

    local function applyHostHeight()
        local h = math.max(1, cardsHost:GetHeight())
        if detailScrollChild.UpdateDetailHeight then
            detailScrollChild:SetHeight(h)
            detailScrollChild.UpdateDetailHeight()
        else
            detailScrollChild:SetHeight(math.abs(yOffset) + h + 20)
            if detailScrollChild.updateThumb then
                detailScrollChild.updateThumb()
            end
        end
    end
    stack.OnRelayout = applyHostHeight

    local layoutRefresh

    stack:AddCard("escpanel:layout", L["ESCPANEL_LAYOUT_HEADER"], function(content, contentWidth)
        local gap = 8
        local descText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        descText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        descText:SetJustifyH("LEFT")
        descText:SetWordWrap(true)
        descText:SetSpacing(2)
        local w = tonumber(contentWidth) or 0
        if w < 1 then
            w = content:GetWidth() or 0
        end
        if w >= 1 then
            descText:SetWidth(w)
        else
            descText:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
        end
        descText:SetText(L["ESCPANEL_LAYOUT_DESC"])
        descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local previewWidth = w
        if previewWidth < 1 then
            previewWidth = 280
        end
        previewWidth = math.min(previewWidth, 280)
        local previewHeight = math.floor(previewWidth * CARD_PREVIEW_ASPECT + 0.5)

        local charCaption = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        charCaption:SetPoint("TOPLEFT", descText, "BOTTOMLEFT", 0, -gap)
        charCaption:SetText(L["ESCPANEL_TOGGLE_SHOW_CHARACTER"])
        charCaption:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local charImg = content:CreateTexture(nil, "ARTWORK")
        charImg:SetPoint("TOPLEFT", charCaption, "BOTTOMLEFT", 0, -4)
        charImg:SetSize(previewWidth, previewHeight)
        charImg:SetTexture(CARD_PREVIEW_BASE .. "character-card.png")

        local zoneCaption = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        zoneCaption:SetPoint("TOPLEFT", charImg, "BOTTOMLEFT", 0, -gap)
        zoneCaption:SetText(L["ESCPANEL_TOGGLE_SHOW_HERE"])
        zoneCaption:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local zoneImg = content:CreateTexture(nil, "ARTWORK")
        zoneImg:SetPoint("TOPLEFT", zoneCaption, "BOTTOMLEFT", 0, -4)
        zoneImg:SetSize(previewWidth, previewHeight)
        zoneImg:SetTexture(CARD_PREVIEW_BASE .. "zone-card.png")

        local ph0 = OneWoW:GetPortalHub()
        local panelsSide = (ph0.escPanelsSide == "right") and "right" or "left"
        local portalsSide = (ph0.escPortalsSide == "left") and "left" or "right"
        local currentIconSize = ph0.escIconSize or 40

        local iconSizeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        iconSizeLabel:SetPoint("TOPLEFT", zoneImg, "BOTTOMLEFT", 0, -14)
        iconSizeLabel:SetText(L["ESCPANEL_ICON_SIZE_LABEL"])
        iconSizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local iconSizeSlider = OneWoW_GUI:CreateSlider(content, {
            width      = 220,
            minVal     = 20,
            maxVal     = 64,
            step       = 2,
            currentVal = currentIconSize,
            fmt        = "%dpx",
            onChange   = function(val)
                OneWoW:GetPortalHub().escIconSize = val
                ns.PortalHubEsc:Reload()
            end,
        })
        iconSizeSlider:SetPoint("TOPLEFT", iconSizeLabel, "BOTTOMLEFT", 0, -4)

        local panelsRowLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        panelsRowLabel:SetPoint("TOPLEFT", iconSizeSlider, "BOTTOMLEFT", 0, -14)
        panelsRowLabel:SetText(L["ESCPANEL_PANELS_SIDE_LABEL"])
        panelsRowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local panelsDD, panelsDDText = OneWoW_GUI:CreateDropdown(content, {
            width = 220,
            text = panelsSide == "right" and (L["ESCPANEL_SIDE_RIGHT"]) or (L["ESCPANEL_SIDE_LEFT"]),
        })
        OneWoW_GUI:AttachFilterMenu(panelsDD, {
            searchable = false,
            buildItems = function()
                return {
                    { text = L["ESCPANEL_SIDE_LEFT"], value = "left" },
                    { text = L["ESCPANEL_SIDE_RIGHT"], value = "right" },
                }
            end,
            onSelect = function(value, text)
                panelsDDText:SetText(text)
                OneWoW:GetPortalHub().escPanelsSide = value
                ns.PortalHubEsc:Reload()
            end,
            getActiveValue = function()
                return (OneWoW:GetPortalHub().escPanelsSide == "right") and "right" or "left"
            end,
        })
        panelsDD:SetPoint("TOPLEFT", panelsRowLabel, "BOTTOMLEFT", 0, -4)

        local portalsRowLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        portalsRowLabel:SetPoint("TOPLEFT", panelsDD, "BOTTOMLEFT", 0, -14)
        portalsRowLabel:SetText(L["ESCPANEL_PORTALS_SIDE_LABEL"])
        portalsRowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local portalsDD, portalsDDText = OneWoW_GUI:CreateDropdown(content, {
            width = 220,
            text = portalsSide == "left" and (L["ESCPANEL_SIDE_LEFT"]) or (L["ESCPANEL_SIDE_RIGHT"]),
        })
        OneWoW_GUI:AttachFilterMenu(portalsDD, {
            searchable = false,
            buildItems = function()
                return {
                    { text = L["ESCPANEL_SIDE_LEFT"], value = "left" },
                    { text = L["ESCPANEL_SIDE_RIGHT"], value = "right" },
                }
            end,
            onSelect = function(value, text)
                portalsDDText:SetText(text)
                OneWoW:GetPortalHub().escPortalsSide = value
                ns.PortalHubEsc:Reload()
            end,
            getActiveValue = function()
                return (OneWoW:GetPortalHub().escPortalsSide == "left") and "left" or "right"
            end,
        })
        portalsDD:SetPoint("TOPLEFT", portalsRowLabel, "BOTTOMLEFT", 0, -4)

        layoutRefresh = function()
            local p = OneWoW:GetPortalHub()
            local ps = (p.escPanelsSide == "right") and "right" or "left"
            local pr = (p.escPortalsSide == "left") and "left" or "right"
            panelsDDText:SetText(ps == "right" and (L["ESCPANEL_SIDE_RIGHT"]) or (L["ESCPANEL_SIDE_LEFT"]))
            portalsDDText:SetText(pr == "left" and (L["ESCPANEL_SIDE_LEFT"]) or (L["ESCPANEL_SIDE_RIGHT"]))
            local sz = p.escIconSize or 40
            if iconSizeSlider.slider:GetValue() ~= sz then
                iconSizeSlider.slider:SetValue(sz)
            end
        end

        local descH = descText:GetStringHeight() or 14
        local charCaptionH = charCaption:GetStringHeight() or 12
        local zoneCaptionH = zoneCaption:GetStringHeight() or 12
        local iconLabelH = iconSizeLabel:GetStringHeight() or 12
        local panelsLabelH = panelsRowLabel:GetStringHeight() or 12
        local portalsLabelH = portalsRowLabel:GetStringHeight() or 12
        local sliderH = iconSizeSlider:GetHeight() or 36
        return math.max(1,
            descH + gap
            + charCaptionH + 4 + previewHeight + gap
            + zoneCaptionH + 4 + previewHeight + 14
            + iconLabelH + 4 + sliderH + 14
            + panelsLabelH + 4 + 26 + 14
            + portalsLabelH + 4 + 26 + 4)
    end)

    stack:Finish()
    applyHostHeight()

    if registerRefresh then
        registerRefresh(function()
            if layoutRefresh then
                layoutRefresh()
            end
        end)
    end

    return yOffset - cardsHost:GetHeight()
end
