local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local C = OneWoW_GUI.Constants
local C_Timer = C_Timer

-- ============================================================================
-- OneWay Pin create / edit dialog
-- ============================================================================

ns.UI = ns.UI or {}

local ICON_CELL = 26
local ICON_PAD = 4
local GRID_COLS = 10
local BG_CELL = 26
local ICON_SCROLL_H = 4 * (ICON_CELL + ICON_PAD)
local BG_SCROLL_H = 3 * (BG_CELL + ICON_PAD)
local DIALOG_WIDTH = 460
local DIALOG_PAD = 14
-- Titlebar + Save/Cancel row (CreateDialog buttonRowHeight = 28+10+10).
local DIALOG_CHROME = C.GUI.TITLEBAR_HEIGHT + 48

local dialog
local fields = {}
local selectedIcon
local selectedBg
local bgEnabled
local editingID
local iconButtons = {}
local bgButtons = {}
local previewReady = false
local previewTimer
local SchedulePreview
local LayoutDialog
local PREVIEW_DELAY = 1
-- True while OpenWayPinDialog writes seed values. Slider SetValue fires
-- onChange; that must not treat the seed as a custom-look pick.
local seeding = false

local function DefaultIcon()
    return { kind = "list", value = "VignetteEvent-SuperTracked" }
end

local function AsNumber(v)
    if type(v) == "number" then
        return v
    end
    if type(v) == "string" then
        return tonumber(v)
    end
    return nil
end

local function IconEquals(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    return (a.kind or "list") == (b.kind or "list") and a.value == b.value
end

--- Picking a look on a pack pin means that pin keeps its own look.
local function MarkCustomLook()
    if seeding or not fields.packPin or not fields.usePackLook then
        return
    end
    fields.usePackLook = false
    if fields.usePackLookCb then
        fields.usePackLookCb:SetChecked(false)
    end
    if LayoutDialog then
        LayoutDialog()
    end
end

local function SyncUsePackLook()
    if fields.usePackLookCb and fields.usePackLookCb:IsShown() then
        fields.usePackLook = fields.usePackLookCb:GetChecked() and true or false
    end
end

local function HonorPickedIcon(look)
    if not fields.packPin or not fields.usePackLook or not fields.packId or not look then
        return
    end
    local pack = ns.WayPinPacks:GetPack(fields.packId)
    if not pack then
        return
    end
    local packLook = ns.WayPinPacks:LookForPaint(pack)
    if not IconEquals(look.icon, packLook.icon) then
        fields.usePackLook = false
        if fields.usePackLookCb then
            fields.usePackLookCb:SetChecked(false)
        end
    end
end

local function ClearEditorFocus()
    if fields.title then
        fields.title:ClearFocus()
    end
    if fields.description then
        fields.description:ClearFocus()
    end
    if fields.mapID then
        fields.mapID:ClearFocus()
    end
    if fields.x then
        fields.x:ClearFocus()
    end
    if fields.y then
        fields.y:ClearFocus()
    end
end

local function PaintIconCell(btn, spec, selected)
    OneWoW.OverlayIcons:ApplyIconSpec(btn.tex, spec)
    btn.tex:SetAlpha(1)
    if selected then
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
    else
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end
end

local function RebuildIconGrid()
    if not dialog then return end
    local list = OneWoW.OverlayIcons:GetIconList()
    local i = 0
    for _, name in ipairs(list) do
        if ns.WayPinsVisual.IsPinIconName(name) then
            i = i + 1
            local btn = iconButtons[i]
            if not btn then
                btn = CreateFrame("Button", nil, dialog.iconChild, "BackdropTemplate")
                btn:SetSize(ICON_CELL, ICON_CELL)
                btn:SetBackdrop(C.BACKDROP_INNER_NO_INSETS)
                local tex = btn:CreateTexture(nil, "ARTWORK")
                tex:SetPoint("TOPLEFT", 2, -2)
                tex:SetPoint("BOTTOMRIGHT", -2, 2)
                btn.tex = tex
                btn:SetScript("OnClick", function(myself)
                    selectedIcon = { kind = "list", value = myself.iconName }
                    MarkCustomLook()
                    RebuildIconGrid()
                    SchedulePreview()
                end)
                btn:SetScript("OnEnter", function(myself)
                    GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                    GameTooltip:SetText(OneWoW.OverlayIcons:GetDisplayName(myself.iconName), 1, 1, 1)
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", GameTooltip_Hide)
                iconButtons[i] = btn
            end
            btn.iconName = name
            local col = (i - 1) % GRID_COLS
            local row = math.floor((i - 1) / GRID_COLS)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", dialog.iconChild, "TOPLEFT",
                col * (ICON_CELL + ICON_PAD),
                -row * (ICON_CELL + ICON_PAD))
            local spec = { kind = "list", value = name }
            local isSel = selectedIcon and selectedIcon.value == name
            PaintIconCell(btn, spec, isSel)
            btn:Show()
        end
    end
    local rows = math.ceil(i / GRID_COLS)
    dialog.iconChild:SetHeight(math.max(rows * (ICON_CELL + ICON_PAD), 1))
    for j = i + 1, #iconButtons do
        iconButtons[j]:Hide()
    end
end

local function RebuildBgGrid()
    if not dialog then return end
    local list = ns.WayPinsVisual.BG_STYLES
    for i, name in ipairs(list) do
        local btn = bgButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, dialog.bgChild, "BackdropTemplate")
            btn:SetSize(BG_CELL, BG_CELL)
            btn:SetBackdrop(C.BACKDROP_INNER_NO_INSETS)
            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetPoint("TOPLEFT", 2, -2)
            tex:SetPoint("BOTTOMRIGHT", -2, 2)
            btn.tex = tex
            btn:SetScript("OnClick", function(myself)
                selectedBg = myself.styleName
                MarkCustomLook()
                RebuildBgGrid()
                SchedulePreview()
            end)
            btn:SetScript("OnEnter", function(myself)
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetText(OneWoW.OverlayIcons:GetDisplayName(myself.styleName), 1, 1, 1)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", GameTooltip_Hide)
            bgButtons[i] = btn
        end
        btn.styleName = name
        local col = (i - 1) % GRID_COLS
        local row = math.floor((i - 1) / GRID_COLS)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", dialog.bgChild, "TOPLEFT",
            col * (BG_CELL + ICON_PAD),
            -row * (BG_CELL + ICON_PAD))
        PaintIconCell(btn, { kind = "list", value = name }, selectedBg == name)
        ns.WayPinsVisual.PaintStyle(btn.tex, name)
        btn:Show()
    end
    local rows = math.ceil(#list / GRID_COLS)
    dialog.bgChild:SetHeight(math.max(rows * (BG_CELL + ICON_PAD), 1))
end

local function ReadNumber(box, fallback)
    return AsNumber(box:GetSearchText()) or fallback
end

local function CancelPreviewTimer()
    if previewTimer then
        previewTimer:Cancel()
        previewTimer = nil
    end
end

--- Editor draft only. Does not write SavedVariables.
local function CollectLook()
    local icon = selectedIcon or DefaultIcon()
    local look = {
        icon        = { kind = icon.kind or "list", value = icon.value },
        effect      = nil,
        mapSize     = fields.mapSize,
        minimapSize = fields.minimapSize,
    }
    if bgEnabled and selectedBg then
        look.bg = {
            enabled = true,
            style = selectedBg,
            effect = fields.bgEffect or "none",
            scale = tonumber(fields.bgScale) or 1,
        }
    end
    return look
end

local function CollectDraft(look)
    local mapID = ReadNumber(fields.mapID, fields.mapIDValue)
    local x = ReadNumber(fields.x, fields.xValue)
    local y = ReadNumber(fields.y, fields.yValue)
    if not mapID or not x or not y then
        return nil
    end
    look = look or CollectLook()
    return {
        id          = editingID,
        title       = fields.title:GetSearchText(),
        description = fields.description:GetSearchText(),
        mapID       = mapID,
        x           = x,
        y           = y,
        icon        = look.icon,
        bg          = look.bg,
        effect      = look.effect,
        mapSize     = look.mapSize,
        minimapSize = look.minimapSize,
        storage     = fields.storageValue or "account",
        source      = fields.source or "manual",
        sourceKey   = fields.sourceKey,
        packId      = fields.packId,
        packPinId   = fields.packPinId,
        usePackLook = fields.packPin and fields.usePackLook,
        showOnList     = fields.showOnListCb:GetChecked() and true or false,
        showOnWorld    = fields.showOnWorldCb:GetChecked() and true or false,
        showOnMinimap  = fields.showOnMinimapCb:GetChecked() and true or false,
    }
end

local function ApplyPreviewDraft()
    previewTimer = nil
    if not previewReady or not dialog or not dialog.frame:IsShown() then
        return
    end
    local draft = CollectDraft()
    if not draft then
        ns.WayPinsMap:ClearPreviewDraft()
        return
    end
    if fields.packPin and fields.usePackLook and fields.packId then
        local pack = ns.WayPinPacks:GetPack(fields.packId)
        if pack then
            local packLook = ns.WayPinPacks:LookForPaint(pack)
            draft.icon = packLook.icon
            draft.bg = packLook.bg
            draft.effect = packLook.effect
            draft.mapSize = packLook.mapSize
            draft.minimapSize = packLook.minimapSize
        end
    end
    ns.WayPinsMap:SetPreviewDraft(draft)
end

SchedulePreview = function()
    if not previewReady then return end
    CancelPreviewTimer()
    previewTimer = C_Timer.NewTimer(PREVIEW_DELAY, ApplyPreviewDraft)
end

local function SaveFromDialog()
    ClearEditorFocus()
    local look = CollectLook()
    SyncUsePackLook()
    HonorPickedIcon(look)
    CancelPreviewTimer()
    ns.WayPinsMap:ClearPreviewDraft()
    if fields.packLook then
        if fields.packId then
            ns.WayPinPacks:SetLook(fields.packId, look)
        end
        dialog.frame:Hide()
        return
    end
    local payload = CollectDraft(look)
    if not payload then
        return
    end
    if editingID and ns.WayPins:GetPin(editingID) then
        local existing = ns.WayPins:GetPin(editingID)
        payload.created = existing.created
        payload.source = existing.source or payload.source
        payload.sourceKey = existing.sourceKey or payload.sourceKey
        ns.WayPins:Save(editingID, payload)
    elseif fields.packPin and fields.packId then
        local addFields = {
            title = payload.title,
            note  = payload.description,
            mapID = payload.mapID,
            x     = payload.x,
            y     = payload.y,
        }
        if not payload.usePackLook then
            addFields.icon        = payload.icon
            addFields.bg          = payload.bg
            addFields.effect      = payload.effect
            addFields.mapSize     = payload.mapSize
            addFields.minimapSize = payload.minimapSize
        end
        local newId = ns.WayPinPacks:AddPin(fields.packId, addFields)
        if newId then
            ns.UI.SelectWayPin(newId)
        end
    else
        ns.WayPins:Add(payload)
    end
    dialog.frame:Hide()
end

local function EnsureDialog()
    if dialog then return dialog end

    dialog = OneWoW_GUI:CreateDialog({
        name   = "OneWoW_NotesWayPinDialog",
        title  = L["WAYPINS_DIALOG_TITLE"],
        width  = DIALOG_WIDTH,
        height = 400,
        buttons = {
            { text = SAVE, onClick = function() SaveFromDialog() end },
            { text = CANCEL, onClick = function(f) f:Hide() end },
        },
        relayout = function()
            if LayoutDialog then LayoutDialog() end
        end,
    })

    local content = dialog.contentFrame

    local function Place(frame, x, y)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
    end

    local function PlaceWide(frame, y)
        Place(frame, DIALOG_PAD, y)
        frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", -DIALOG_PAD, y)
    end

    fields.nameLabel = OneWoW_GUI:CreateFS(content, 12)
    fields.nameLabel:SetText(NAME)
    fields.nameLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    fields.title = OneWoW_GUI:CreateEditBox(content, {
        placeholderText = L["WAYPINS_UNTITLED"],
        maxLetters = 80,
        onTextChanged = function()
            SchedulePreview()
        end,
    })

    fields.descLabel = OneWoW_GUI:CreateFS(content, 12)
    fields.descLabel:SetText(DESCRIPTION)
    fields.descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    fields.description = OneWoW_GUI:CreateEditBox(content, {
        maxLetters = 240,
        onTextChanged = function()
            SchedulePreview()
        end,
    })

    fields.coordLabel = OneWoW_GUI:CreateFS(content, 12)
    fields.coordLabel:SetText(L["WAYPINS_COORDS"])
    fields.coordLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    fields.mapID = OneWoW_GUI:CreateEditBox(content, {
        width = 90, maxLetters = 8, showClear = false,
        onTextChanged = function()
            local n = AsNumber(fields.mapID:GetSearchText())
            if n then
                fields.mapIDValue = n
            end
            SchedulePreview()
        end,
    })
    fields.mapID:SetNumeric(true)

    fields.x = OneWoW_GUI:CreateEditBox(content, {
        width = 90, maxLetters = 8, showClear = false,
        onTextChanged = function()
            local n = AsNumber(fields.x:GetSearchText())
            if n then
                fields.xValue = n
            end
            SchedulePreview()
        end,
    })

    fields.y = OneWoW_GUI:CreateEditBox(content, {
        width = 90, maxLetters = 8, showClear = false,
        onTextChanged = function()
            local n = AsNumber(fields.y:GetSearchText())
            if n then
                fields.yValue = n
            end
            SchedulePreview()
        end,
    })

    local storeDD = ns.UI.CreateThemedDropdown(content, L["LABEL_STORAGE"], 180, 24)
    storeDD:SetOptions({
        { text = L["UI_STORAGE_ACCOUNT"], value = "account" },
        { text = CHARACTER, value = "character" },
    })
    storeDD.onSelect = function(value)
        fields.storageValue = value
    end
    fields.storageDD = storeDD

    fields.showOnListCb = OneWoW_GUI:CreateCheckbox(content, {
        label = L["WAYPINS_SHOW_ON_LIST"],
        checked = true,
    })
    fields.showOnWorldCb = OneWoW_GUI:CreateCheckbox(content, {
        label = L["WAYPINS_SHOW_WORLD"],
        checked = true,
    })
    fields.showOnMinimapCb = OneWoW_GUI:CreateCheckbox(content, {
        label = L["WAYPINS_SHOW_MINIMAP"],
        checked = true,
    })

    fields.worldSizeLabel = OneWoW_GUI:CreateFS(content, 11)
    fields.worldSizeLabel:SetText(L["WAYPINS_SIZE_WORLD"])
    fields.worldSizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    fields.miniSizeLabel = OneWoW_GUI:CreateFS(content, 11)
    fields.miniSizeLabel:SetText(L["WAYPINS_SIZE_MINIMAP"])
    fields.miniSizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    fields.sizeSlider = OneWoW_GUI:CreateSlider(content, {
        minVal = 12,
        maxVal = ns.WayPinsVisual.WorldSizeMax(),
        step = 1,
        currentVal = ns.WayPinsVisual.WorldDefault(),
        width = 210,
        fmt = "%.0f",
        onChange = function(val)
            fields.mapSize = val
            MarkCustomLook()
            SchedulePreview()
        end,
    })

    fields.minimapSizeSlider = OneWoW_GUI:CreateSlider(content, {
        minVal = 10,
        maxVal = ns.WayPinsVisual.MinimapSizeMax(),
        step = 1,
        currentVal = ns.WayPinsVisual.MinimapDefault(),
        width = 190,
        fmt = "%.0f",
        onChange = function(val)
            fields.minimapSize = val
            MarkCustomLook()
            SchedulePreview()
        end,
    })

    fields.warn = OneWoW_GUI:CreateFS(content, 10)
    fields.warn:SetJustifyH("LEFT")
    fields.warn:SetWordWrap(true)
    fields.warn:SetText(L["WAYPINS_LAYERS_WARN"])
    fields.warn:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    fields.iconLabel = OneWoW_GUI:CreateFS(content, 12)
    fields.iconLabel:SetText(L["OVR_ICON_LABEL"])
    fields.iconLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local iconScroll, iconChild = OneWoW_GUI:CreateScrollFrame(content, {})
    dialog.iconScroll = iconScroll
    dialog.iconChild = iconChild

    fields.bgCheck = OneWoW_GUI:CreateCheckbox(content, {
        label = L["OVR_BG_ENABLE_LABEL"],
        checked = false,
        onClick = function(myself)
            bgEnabled = myself:GetChecked() and true or false
            if not bgEnabled then
                fields.effectDD:ClosePopup()
            end
            MarkCustomLook()
            LayoutDialog()
            SchedulePreview()
        end,
    })

    fields.usePackLookCb = OneWoW_GUI:CreateCheckbox(content, {
        label = L["WAYPINS_USE_PACK_LOOK"],
        checked = true,
        onClick = function(myself)
            fields.usePackLook = myself:GetChecked() and true or false
            LayoutDialog()
            SchedulePreview()
        end,
    })

    fields.effectDD = ns.UI.CreateThemedDropdown(content, L["OVR_EFFECT_LABEL"], 280, 24)
    fields.effectDD:SetOptions({
        { value = "none",     text = NONE },
        { value = "zooming",  text = L["OVR_EFFECT_ZOOMING"] },
        { value = "spinning", text = L["OVR_EFFECT_SPINNING"] },
        { value = "both",     text = L["OVR_EFFECT_BOTH"] },
    })
    fields.effectDD.onSelect = function(value)
        fields.bgEffect = value
        MarkCustomLook()
        SchedulePreview()
    end

    local bgScroll, bgChild = OneWoW_GUI:CreateScrollFrame(content, {})
    dialog.bgScroll = bgScroll
    dialog.bgChild = bgChild

    fields.bgScaleLabel = OneWoW_GUI:CreateFS(content, 11)
    fields.bgScaleLabel:SetText(L["OVR_BG_SCALE_LABEL"])
    fields.bgScaleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    fields.bgScaleSlider = OneWoW_GUI:CreateSlider(content, {
        minVal = 0.1,
        maxVal = 3.0,
        step = 0.1,
        currentVal = 1,
        width = 280,
        fmt = "%.1f",
        onChange = function(val)
            fields.bgScale = val
            MarkCustomLook()
            SchedulePreview()
        end,
    })

    fields.deleteBtn = OneWoW_GUI:CreateFitTextButton(content, { text = DELETE, height = 24 })
    fields.deleteBtn:Hide()
    fields.deleteBtn:SetScript("OnClick", function()
        CancelPreviewTimer()
        ns.WayPinsMap:ClearPreviewDraft()
        if editingID then
            local pin = ns.WayPins:GetPin(editingID)
            if pin and ns.WayPinPacks:IsPackPinId(editingID) then
                ns.WayPinsMap:ConfirmReturnFromPack(pin)
            else
                ns.WayPins:Remove(editingID)
            end
        end
        dialog.frame:Hide()
    end)

    LayoutDialog = function()
        local y = -10
        local packLook = fields.packLook
        local packPin = fields.packPin
        local showIdentity = not packLook
        local showVisuals = true

        fields.nameLabel:SetShown(showIdentity)
        fields.title:SetShown(showIdentity)
        fields.descLabel:SetShown(showIdentity)
        fields.description:SetShown(showIdentity)
        fields.coordLabel:SetShown(showIdentity)
        fields.mapID:SetShown(showIdentity)
        fields.x:SetShown(showIdentity)
        fields.y:SetShown(showIdentity)
        fields.storageDD:SetShown(showIdentity and not packPin)
        fields.usePackLookCb:SetShown(packPin)
        local showFlags = showIdentity
        fields.showOnListCb:SetShown(showFlags)
        fields.showOnWorldCb:SetShown(showFlags)
        fields.showOnMinimapCb:SetShown(showFlags)
        fields.worldSizeLabel:SetShown(showVisuals)
        fields.miniSizeLabel:SetShown(showVisuals)
        fields.sizeSlider:SetShown(showVisuals)
        fields.minimapSizeSlider:SetShown(showVisuals)
        fields.warn:SetShown(showVisuals)
        fields.iconLabel:SetShown(showVisuals)
        dialog.iconScroll:SetShown(showVisuals)
        fields.bgCheck:SetShown(showVisuals)

        if showIdentity then
            Place(fields.nameLabel, DIALOG_PAD, y)
            y = y - 16

            PlaceWide(fields.title, y)
            y = y - 30

            Place(fields.descLabel, DIALOG_PAD, y)
            y = y - 16

            PlaceWide(fields.description, y)
            y = y - 30

            Place(fields.coordLabel, DIALOG_PAD, y)
            y = y - 16

            Place(fields.mapID, DIALOG_PAD, y)
            fields.x:ClearAllPoints()
            fields.x:SetPoint("LEFT", fields.mapID, "RIGHT", 8, 0)
            fields.y:ClearAllPoints()
            fields.y:SetPoint("LEFT", fields.x, "RIGHT", 8, 0)
            y = y - 30

            if packPin then
                Place(fields.usePackLookCb, 10, y)
                y = y - 28
            else
                Place(fields.storageDD, DIALOG_PAD, y)
                y = y - 28
            end
            Place(fields.showOnListCb, 10, y)
            y = y - 24
            Place(fields.showOnWorldCb, 10, y)
            y = y - 24
            Place(fields.showOnMinimapCb, 10, y)
            y = y - 28
        end

        if showVisuals then
            Place(fields.worldSizeLabel, DIALOG_PAD, y)
            Place(fields.miniSizeLabel, 240, y)
            y = y - 16

            Place(fields.sizeSlider, DIALOG_PAD, y)
            Place(fields.minimapSizeSlider, 240, y)
            y = y - 40

            PlaceWide(fields.warn, y)
            fields.warn:SetWidth(DIALOG_WIDTH - DIALOG_PAD * 2)
            y = y - math.max(fields.warn:GetStringHeight(), 16) - 8

            Place(fields.iconLabel, DIALOG_PAD, y)
            y = y - 18

            dialog.iconScroll:ClearAllPoints()
            dialog.iconScroll:SetPoint("TOPLEFT", content, "TOPLEFT", DIALOG_PAD, y)
            dialog.iconScroll:SetPoint("TOPRIGHT", content, "TOPRIGHT", -DIALOG_PAD, y)
            dialog.iconScroll:SetHeight(ICON_SCROLL_H)
            y = y - ICON_SCROLL_H - 8

            Place(fields.bgCheck, 10, y)
            y = y - 26
        else
            fields.effectDD:Hide()
            dialog.bgScroll:Hide()
            fields.bgScaleLabel:Hide()
            fields.bgScaleSlider:Hide()
        end

        local showBg = showVisuals and bgEnabled
        fields.effectDD:SetShown(showBg)
        dialog.bgScroll:SetShown(showBg)
        fields.bgScaleLabel:SetShown(showBg)
        fields.bgScaleSlider:SetShown(showBg)

        if showBg then
            Place(fields.effectDD, DIALOG_PAD, y)
            y = y - 28

            dialog.bgScroll:ClearAllPoints()
            dialog.bgScroll:SetPoint("TOPLEFT", content, "TOPLEFT", DIALOG_PAD, y)
            dialog.bgScroll:SetPoint("TOPRIGHT", content, "TOPRIGHT", -DIALOG_PAD, y)
            dialog.bgScroll:SetHeight(BG_SCROLL_H)
            y = y - BG_SCROLL_H - 8

            Place(fields.bgScaleLabel, DIALOG_PAD, y)
            y = y - 16

            Place(fields.bgScaleSlider, DIALOG_PAD, y)
            y = y - 40
        end

        if fields.deleteBtn:IsShown() then
            Place(fields.deleteBtn, DIALOG_PAD, y)
            y = y - 32
        end

        local contentH = -y + 8
        local h = DIALOG_CHROME + contentH
        local maxH = math.floor(UIParent:GetHeight() * 0.9)
        if h > maxH then
            h = maxH
        end
        dialog.frame:SetHeight(h)
    end

    dialog.frame:HookScript("OnHide", function()
        previewReady = false
        CancelPreviewTimer()
        ns.WayPinsMap:ClearPreviewDraft()
        fields.effectDD:ClosePopup()
        fields.storageDD:ClosePopup()
    end)

    LayoutDialog()
    return dialog
end

--- Open the create/edit dialog. `seed` may be an existing pin or a coord draft.
---@param seed table|nil
function ns.UI.OpenWayPinDialog(seed)
    if not ns.WayPinsVisual.Enabled() then return end
    EnsureDialog()
    previewReady = false
    CancelPreviewTimer()
    ns.WayPinsMap:ClearPreviewDraft()
    seed = seed or {}
    seeding = true
    editingID = seed.packLook and nil or seed.id
    fields.packLook = seed.packLook == true
    fields.packPin = seed.packId ~= nil and not fields.packLook
    fields.packId = seed.packId
    fields.packPinId = seed.packPinId
    fields.usePackLook = fields.packPin and seed.usePackLook ~= false
    fields.source = seed.source
    fields.sourceKey = seed.sourceKey
    fields.storageValue = seed.storage == "character" and "character" or "account"
    fields.storageDD:SetSelected(fields.storageValue)
    selectedIcon = seed.icon and {
        kind = seed.icon.kind or "list",
        value = seed.icon.value,
    } or DefaultIcon()
    bgEnabled = seed.bg and seed.bg.enabled and true or false
    selectedBg = (seed.bg and seed.bg.style) or "Solid-Circle"
    fields.mapSize = seed.mapSize or ns.WayPinsVisual.WorldDefault()
    fields.minimapSize = seed.minimapSize or ns.WayPinsVisual.MinimapDefault()
    fields.mapIDValue = AsNumber(seed.mapID)
    fields.xValue = AsNumber(seed.x)
    fields.yValue = AsNumber(seed.y)
    local effect = (seed.bg and seed.bg.effect) or seed.effect or "none"
    if effect ~= "spinning" and effect ~= "zooming" and effect ~= "both" then
        effect = "none"
    end
    fields.bgEffect = effect
    fields.bgScale = (seed.bg and tonumber(seed.bg.scale)) or 1

    fields.title:SetText(seed.title or "")
    fields.description:SetText(seed.description or "")
    fields.mapID:SetText(fields.mapIDValue and tostring(fields.mapIDValue) or "")
    fields.x:SetText(fields.xValue and string.format("%.2f", fields.xValue) or "")
    fields.y:SetText(fields.yValue and string.format("%.2f", fields.yValue) or "")
    fields.sizeSlider.slider:SetValue(fields.mapSize)
    fields.minimapSizeSlider.slider:SetValue(fields.minimapSize)
    fields.bgScaleSlider.slider:SetValue(fields.bgScale)
    fields.effectDD:SetSelected(fields.bgEffect)
    fields.bgCheck:SetChecked(bgEnabled)
    fields.usePackLookCb:SetChecked(fields.usePackLook)
    fields.showOnListCb:SetChecked(seed.showOnList ~= false)
    fields.showOnWorldCb:SetChecked(seed.showOnWorld ~= false)
    fields.showOnMinimapCb:SetChecked(seed.showOnMinimap ~= false)
    seeding = false

    if fields.packLook then
        fields.deleteBtn:Hide()
        dialog.titleBar._titleText:SetText(L["WAYPINS_PACK_LOOK"])
    elseif editingID then
        fields.deleteBtn:Show()
        if fields.packPin then
            fields.deleteBtn:SetFitText(L["WAYPINS_REMOVE_FROM_PACK"])
        else
            fields.deleteBtn:SetFitText(DELETE)
        end
        dialog.titleBar._titleText:SetText(L["WAYPINS_DIALOG_EDIT"])
    else
        fields.deleteBtn:Hide()
        dialog.titleBar._titleText:SetText(L["WAYPINS_DIALOG_TITLE"])
    end

    RebuildIconGrid()
    RebuildBgGrid()
    LayoutDialog()
    dialog.frame:Show()
    dialog.frame:Raise()
    previewReady = true
end
