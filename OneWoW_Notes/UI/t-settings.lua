local ADDON_NAME, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local backdrop = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = true, tileSize = 16, edgeSize = 1,
}

local function CreateDetectionRow(parent, labelKey, descKey, isEnabled, onToggle, yPos)
    local rowFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    rowFrame:SetPoint("TOPLEFT",  parent, "TOPLEFT",  16, yPos)
    rowFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, yPos)
    rowFrame:SetHeight(62)
    rowFrame:SetBackdrop(backdrop)
    rowFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    rowFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local toggleBtn = CreateFrame("Button", nil, rowFrame, "BackdropTemplate")
    toggleBtn:SetSize(70, 28)
    toggleBtn:SetPoint("LEFT", rowFrame, "LEFT", 10, 0)
    toggleBtn:SetBackdrop(BACKDROP_INNER_NO_INSETS)

    local toggleLabel = OneWoW_GUI:CreateFS(toggleBtn, 12)
    toggleLabel:SetPoint("CENTER")

    local function RefreshToggle(enabled)
        if enabled then
            toggleBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            toggleBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            toggleLabel:SetText(L["SETTINGS_ENABLED"])
            toggleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        else
            toggleBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            toggleBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            toggleLabel:SetText(L["SETTINGS_DISABLED"])
            toggleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    RefreshToggle(isEnabled())

    toggleBtn:SetScript("OnClick", function()
        local newState = onToggle()
        RefreshToggle(newState)
    end)
    toggleBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
    end)
    toggleBtn:SetScript("OnLeave", function()
        RefreshToggle(isEnabled())
    end)

    local label = OneWoW_GUI:CreateFS(rowFrame, 12)
    label:SetPoint("TOPLEFT",  rowFrame, "TOPLEFT", 90, -12)
    label:SetPoint("TOPRIGHT", rowFrame, "TOPRIGHT", -10, -12)
    label:SetJustifyH("LEFT")
    label:SetText(L[labelKey])
    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local desc = OneWoW_GUI:CreateFS(rowFrame, 10)
    desc:SetPoint("TOPLEFT",  label, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("TOPRIGHT", rowFrame, "TOPRIGHT", -10, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetText(OneWoW.Locale:GetOptional(ADDON_NAME, descKey) or "")
    desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    rowFrame.Sync = function()
        RefreshToggle(isEnabled())
    end
    return rowFrame
end

function ns.UI.CreateSettingsTab(parent)
    local scrollObj = ns.UI.CreateCustomScroll(parent)
    if not scrollObj then return end

    scrollObj.container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scrollObj.container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local scrollChild = scrollObj.scrollChild

    local yOffset = -20
    local PinSupport = ns.PinSupport

    local displaySection = OneWoW_GUI:CreateSectionHeader(scrollChild, { title = DISPLAY, yOffset = yOffset })
    yOffset = displaySection.bottomY - 8

    local scaleDesc = OneWoW_GUI:CreateFS(scrollChild, 12)
    scaleDesc:SetPoint("TOPLEFT", 16, yOffset)
    scaleDesc:SetPoint("TOPRIGHT", -16, yOffset)
    scaleDesc:SetJustifyH("LEFT")
    scaleDesc:SetWordWrap(true)
    scaleDesc:SetSpacing(3)
    scaleDesc:SetText(L["SETTINGS_PINNED_SCALE_DESC"])
    scaleDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    local wrapWidth = (scrollChild:GetWidth() or 0) - 32
    if wrapWidth < 200 then wrapWidth = 740 end
    scaleDesc:SetWidth(wrapWidth)
    yOffset = yOffset - math.max(scaleDesc:GetStringHeight(), 12) - 10

    local scaleLbl = OneWoW_GUI:CreateFS(scrollChild, 12)
    scaleLbl:SetPoint("TOPLEFT", 16, yOffset)
    scaleLbl:SetText(L["SETTINGS_PINNED_SCALE"])
    scaleLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - 18

    local scaleSlider = OneWoW_GUI:CreateSlider(scrollChild, {
        width = math.max(140, wrapWidth - 40),
        minVal = PinSupport.SCALE_MIN,
        maxVal = PinSupport.SCALE_MAX,
        step = PinSupport.SCALE_STEP,
        currentVal = PinSupport.ClampScalePercent(ns.db.global.pinnedScale),
        onChange = function(val)
            ns.db.global.pinnedScale = PinSupport.ClampScalePercent(val)
            PinSupport.ApplyAllPinScales()
        end,
        fmt = "%d%%",
    })
    scaleSlider:SetPoint("TOPLEFT", 16, yOffset)
    yOffset = yOffset - 48

    yOffset = yOffset - 20
    local waypinsSection = OneWoW_GUI:CreateSectionHeader(scrollChild, { title = L["TAB_WAYPINS"], yOffset = yOffset })
    yOffset = waypinsSection.bottomY - 16

    local waypinsRow = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    waypinsRow:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  16, yOffset)
    waypinsRow:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -16, yOffset)
    waypinsRow:SetHeight(62)
    waypinsRow:SetBackdrop(backdrop)
    waypinsRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    waypinsRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local waypinsBtn = OneWoW_GUI:CreateFitTextButton(waypinsRow, { text = SETTINGS, height = 26 })
    waypinsBtn:SetPoint("LEFT", waypinsRow, "LEFT", 10, 0)
    waypinsBtn:SetScript("OnClick", function()
        ns.UI.OpenWayPinSettings()
    end)

    local waypinsLabel = OneWoW_GUI:CreateFS(waypinsRow, 12)
    waypinsLabel:SetPoint("TOPLEFT", waypinsRow, "TOPLEFT", 90, -12)
    waypinsLabel:SetPoint("TOPRIGHT", waypinsRow, "TOPRIGHT", -10, -12)
    waypinsLabel:SetJustifyH("LEFT")
    waypinsLabel:SetText(L["WAYPINS_SETTINGS_TITLE"])
    waypinsLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local waypinsDesc = OneWoW_GUI:CreateFS(waypinsRow, 10)
    waypinsDesc:SetPoint("TOPLEFT", waypinsLabel, "BOTTOMLEFT", 0, -4)
    waypinsDesc:SetPoint("TOPRIGHT", waypinsRow, "TOPRIGHT", -10, 0)
    waypinsDesc:SetJustifyH("LEFT")
    waypinsDesc:SetWordWrap(true)
    waypinsDesc:SetText(L["WAYPINS_SETTINGS_HINT"])
    waypinsDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    yOffset = yOffset - 70

    yOffset = yOffset - 20
    local detectionSection = OneWoW_GUI:CreateSectionHeader(scrollChild, { title = L["SETTINGS_DETECTION"], yOffset = yOffset })
    yOffset = detectionSection.bottomY - 16

    CreateDetectionRow(
        scrollChild,
        "SETTINGS_ZONE_ALERTS",
        "SETTINGS_ZONE_ALERTS_DESC",
        function() return ns.Zones and ns.Zones:IsScanning() end,
        function()
            if ns.Zones then
                if ns.Zones:IsScanning() then
                    ns.Zones:DisableScanning()
                    return false
                else
                    ns.Zones:EnableScanning()
                    return true
                end
            end
            return false
        end,
        yOffset
    )
    yOffset = yOffset - 70

    CreateDetectionRow(
        scrollChild,
        "SETTINGS_ZONE_PINNED_WINDOW",
        "SETTINGS_ZONE_PINNED_WINDOW_DESC",
        function() return ns.Zones:IsPinnedWindowEnabled() end,
        function()
            local nextState = not ns.Zones:IsPinnedWindowEnabled()
            ns.Zones:SetPinnedWindowEnabled(nextState)
            return nextState
        end,
        yOffset
    )
    yOffset = yOffset - 70

    -- Vendor collectible capture: off | prompt | auto. A dropdown rather
    -- than a toggle because it is tri-state; changing it reconciles the merchant
    -- subscription via ns.CollectiblesMerchant.
    yOffset = yOffset - 10
    local captureSection = OneWoW_GUI:CreateSectionHeader(scrollChild, {
        title = L["TAB_COLLECTIBLES"], yOffset = yOffset,
    })
    yOffset = captureSection.bottomY - 16

    local captureRow = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    captureRow:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  16, yOffset)
    captureRow:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -16, yOffset)
    captureRow:SetHeight(62)
    captureRow:SetBackdrop(backdrop)
    captureRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    captureRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    -- No label prefix: the section header and the adjacent label already name
    -- this control, so the dropdown shows just the selected mode (Off/Prompt/…).
    local captureDD = ns.UI.CreateThemedDropdown(captureRow, nil, 130, 26)
    captureDD:SetPoint("LEFT", captureRow, "LEFT", 10, 0)
    captureDD:SetOptions({
        { text = OFF,                             value = "off"    },
        { text = L["COLLECTIBLE_CAPTURE_PROMPT"], value = "prompt" },
        { text = L["COLLECTIBLE_CAPTURE_AUTO"],   value = "auto"   },
    })
    captureDD:SetSelected(ns.CollectiblesMerchant and ns.CollectiblesMerchant:GetCaptureMode() or "off")
    captureDD.onSelect = function(value)
        if ns.CollectiblesMerchant then
            ns.CollectiblesMerchant:SetCaptureMode(value)
        end
    end

    local captureLabel = OneWoW_GUI:CreateFS(captureRow, 12)
    captureLabel:SetPoint("TOPLEFT",  captureRow, "TOPLEFT", 145, -12)
    captureLabel:SetPoint("TOPRIGHT", captureRow, "TOPRIGHT", -10, -12)
    captureLabel:SetJustifyH("LEFT")
    captureLabel:SetText(L["SETTINGS_COLLECTIBLE_CAPTURE"])
    captureLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local captureDesc = OneWoW_GUI:CreateFS(captureRow, 10)
    captureDesc:SetPoint("TOPLEFT",  captureLabel, "BOTTOMLEFT", 0, -4)
    captureDesc:SetPoint("TOPRIGHT", captureRow, "TOPRIGHT", -10, 0)
    captureDesc:SetJustifyH("LEFT")
    captureDesc:SetWordWrap(true)
    captureDesc:SetText(OneWoW.Locale:GetOptional(ADDON_NAME, "SETTINGS_COLLECTIBLE_CAPTURE_DESC") or "")
    captureDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    yOffset = yOffset - 72

    -- Auto-delete collected items: soft recycle-bin flow. The toggle governs the
    -- auto-recycle + purge sweep; the TTL sets the purge delay; the button empties
    -- the Delete List on demand (useful even with the toggle off).
    CreateDetectionRow(
        scrollChild,
        "SETTINGS_AUTODELETE",
        "SETTINGS_AUTODELETE_DESC",
        function() return ns.Collectibles and ns.Collectibles:IsAutoDeleteEnabled() end,
        function()
            local enabled = ns.Collectibles:IsAutoDeleteEnabled()
            ns.Collectibles:SetAutoDeleteEnabled(not enabled)
            return not enabled
        end,
        yOffset
    )
    yOffset = yOffset - 70

    local purgeRow = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    purgeRow:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  16, yOffset)
    purgeRow:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -16, yOffset)
    purgeRow:SetHeight(62)
    purgeRow:SetBackdrop(backdrop)
    purgeRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    purgeRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local ttlDD = ns.UI.CreateThemedDropdown(purgeRow, nil, 130, 26)
    ttlDD:SetPoint("LEFT", purgeRow, "LEFT", 10, 0)
    ttlDD:SetOptions({
        { text = L["COLLECTIBLE_TTL_IMMEDIATE"], value = 0  },
        { text = string.format(D_DAYS, 1),       value = 1  },
        { text = string.format(D_DAYS, 7),       value = 7  },
        { text = string.format(D_DAYS, 14),      value = 14 },
    })
    ttlDD:SetSelected(ns.Collectibles and ns.Collectibles:GetPurgeTTLDays() or 7)
    ttlDD.onSelect = function(value)
        if ns.Collectibles then ns.Collectibles:SetPurgeTTLDays(value) end
    end

    local ttlLabel = OneWoW_GUI:CreateFS(purgeRow, 12)
    ttlLabel:SetPoint("TOPLEFT",  purgeRow, "TOPLEFT", 150, -12)
    ttlLabel:SetPoint("TOPRIGHT", purgeRow, "TOPRIGHT", -150, -12)
    ttlLabel:SetJustifyH("LEFT")
    ttlLabel:SetText(L["SETTINGS_AUTODELETE_TTL"])
    ttlLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local emptyBtn = OneWoW_GUI:CreateFitTextButton(purgeRow, {
        text = L["COLLECTIBLE_EMPTY_DELETE_LIST"], height = 26, minWidth = 120,
    })
    emptyBtn:SetPoint("RIGHT", purgeRow, "RIGHT", -10, 0)
    emptyBtn:SetScript("OnClick", function()
        local count = ns.Collectibles and ns.Collectibles:CountDeleteList() or 0
        StaticPopupDialogs["ONEWOW_NOTES_EMPTY_DELETE_LIST"] = {
            text = string.format(L["POPUP_EMPTY_DELETE_LIST"], count),
            button1 = DELETE, button2 = CANCEL,
            OnAccept = function()
                ns.Collectibles:EmptyDeleteList()
                if ns.UI and ns.UI.RefreshCollectiblesList then
                    ns.UI.RefreshCollectiblesList()
                end
            end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        StaticPopup_Show("ONEWOW_NOTES_EMPTY_DELETE_LIST")
    end)
    yOffset = yOffset - 72

    scrollChild:SetHeight(math.abs(yOffset) + 20)
end
