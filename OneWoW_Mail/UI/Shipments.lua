local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

ns.ShipmentsUI = {}
local ShipmentsUI = ns.ShipmentsUI

local listChild
local detailFrame
local selectedId
local listRows = {} -- pooled list row buttons (WoW never GCs frames)
local dw -- detail widgets, built once per detailFrame (see EnsureDetailWidgets)
local newBtn
local renameBtn
local deleteBtn

local function AttachTooltip(frame, title, body)
    frame:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if body and body ~= "" then
            GameTooltip:AddLine(body, 0.85, 0.85, 0.85, true)
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", GameTooltip_Hide)
end

--- Thin coin-tinted border (same chrome as Compose money fields).
local function StyleMoneyBox(box, color)
    local r, g, b = color[1], color[2], color[3]
    local function applyIdle()
        box:SetBackdropBorderColor(r, g, b, 0.85)
    end
    local function applyFocus()
        box:SetBackdropBorderColor(math.min(1, r + 0.12), math.min(1, g + 0.12), math.min(1, b + 0.12), 1)
    end
    applyIdle()
    box:HookScript("OnEditFocusGained", applyFocus)
    box:HookScript("OnEditFocusLost", applyIdle)
end

local function SetWidgetEnabled(widget, on)
    if not widget then
        return
    end
    if on then
        widget:Enable()
        widget:SetAlpha(1)
    else
        widget:Disable()
        widget:SetAlpha(0.45)
    end
end

local function GetShipment(id)
    for _, s in ipairs(ns.db.global.mail.shipments) do
        if s.id == id then
            return s
        end
    end
end

local function GetShipmentIndex(id)
    for i, s in ipairs(ns.db.global.mail.shipments) do
        if s.id == id then
            return i
        end
    end
end

local function NewShipmentId()
    return "ship_" .. tostring(time()) .. "_" .. tostring(math.random(1000, 9999))
end

local function MakeShipment(name)
    return {
        id = NewShipmentId(),
        name = name,
        mode = "manual",
        frequency = "session",
        kind = "items",
        match = "",
        targetKind = "char",
        target = "",
        targetRoleId = "",
        roleDistribute = "fill_first",
        crossRealm = "send",
        keepQty = 0,
        maxQtyEnabled = false,
        maxQty = 0,
        restock = false,
        restockSources = ns:NewRestockSources(),
        exclusions = {},
        editedAt = time(),
        keepCopper = 0,
        maxCopperEnabled = false,
        maxCopper = 0,
        restockCopper = 0,
    }
end

local function CreateShipment(name)
    name = strtrim(name or "")
    if name == "" then
        return nil, "ERR_SHIPMENT_NAME_EMPTY"
    end
    local shipment = MakeShipment(name)
    tinsert(ns.db.global.mail.shipments, shipment)
    return shipment.id
end

local function TouchEdited(shipment)
    if shipment then
        shipment.editedAt = time()
    end
end

local function RenameShipment(id, name)
    name = strtrim(name or "")
    if name == "" then
        return false, "ERR_SHIPMENT_NAME_EMPTY"
    end
    local shipment = GetShipment(id)
    if not shipment then
        return false, "ERR_SHIPMENT_MISSING"
    end
    shipment.name = name
    TouchEdited(shipment)
    return true
end

local function DeleteShipment(id)
    local index = GetShipmentIndex(id)
    if not index then
        return false
    end
    tremove(ns.db.global.mail.shipments, index)
    return true
end

local function SyncCrudButtons()
    local has = selectedId and GetShipment(selectedId) and true or false
    SetWidgetEnabled(renameBtn, has)
    SetWidgetEnabled(deleteBtn, has)
end

-- Bags Category Manager pattern: StaticPopup name prompts + delete confirm.
StaticPopupDialogs["ONEWOW_MAIL_SHIPMENT_CREATE"] = {
    text = "",
    hasEditBox = true,
    button1 = L["CREATE"],
    button2 = CANCEL,
    OnShow = function(self)
        self.Text:SetText(L["SHIPMENT_CREATE_ENTER"])
        self.EditBox:SetText("")
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self)
        local name = strtrim(self.EditBox:GetText() or "")
        if name == "" then
            return
        end
        local id, err = CreateShipment(name)
        if not id then
            if err then
                UIErrorsFrame:AddMessage(L[err], 1, 0, 0)
            end
            C_Timer.After(0, function()
                local d = StaticPopup_Show("ONEWOW_MAIL_SHIPMENT_CREATE")
                if d and d.EditBox then
                    d.EditBox:SetText(name)
                    d.EditBox:SetFocus()
                end
            end)
            return
        end
        selectedId = id
        ShipmentsUI:Refresh()
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        StaticPopupDialogs["ONEWOW_MAIL_SHIPMENT_CREATE"].OnAccept(parent)
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["ONEWOW_MAIL_SHIPMENT_RENAME"] = {
    text = "",
    hasEditBox = true,
    button1 = L["RENAME"],
    button2 = CANCEL,
    OnShow = function(self, data)
        self.Text:SetText(L["SHIPMENT_RENAME_ENTER"])
        local shipment = data and GetShipment(data)
        if shipment then
            self.EditBox:SetText(shipment.name or "")
            self.EditBox:HighlightText()
        end
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self, data)
        local name = strtrim(self.EditBox:GetText() or "")
        if name == "" or not data then
            return
        end
        local ok, err = RenameShipment(data, name)
        if not ok then
            if err then
                UIErrorsFrame:AddMessage(L[err], 1, 0, 0)
            end
            C_Timer.After(0, function()
                local d = StaticPopup_Show("ONEWOW_MAIL_SHIPMENT_RENAME", nil, nil, data)
                if d and d.EditBox then
                    d.EditBox:SetText(name)
                    d.EditBox:SetFocus()
                end
            end)
            return
        end
        ShipmentsUI:Refresh()
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        StaticPopupDialogs["ONEWOW_MAIL_SHIPMENT_RENAME"].OnAccept(parent, parent.data)
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["ONEWOW_MAIL_SHIPMENT_DELETE"] = {
    text = "",
    button1 = DELETE,
    button2 = CANCEL,
    OnShow = function(self, data)
        local shipment = data and GetShipment(data)
        self.Text:SetText(string.format(L["SHIPMENT_DELETE_CONFIRM"], shipment and shipment.name or "?"))
    end,
    OnAccept = function(_, data)
        if not data then
            return
        end
        DeleteShipment(data)
        if selectedId == data then
            selectedId = nil
        end
        ShipmentsUI:Refresh()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- List rows are pooled: WoW never garbage-collects frames, so recreating them
-- on every refresh (each selection click) leaks frames and their scripts.
local function AcquireListRow()
    for _, row in ipairs(listRows) do
        if not row:IsShown() then
            row:Show()
            return row
        end
    end
    local row = CreateFrame("Button", nil, listChild, "BackdropTemplate")
    row:SetHeight(28)
    row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    row.label = OneWoW_GUI:CreateFS(row, 12)
    row.statusDot = row:CreateTexture(nil, "ARTWORK")
    row.statusDot:SetSize(7, 7)
    row.statusDot:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.label:SetPoint("LEFT", row.statusDot, "RIGHT", 6, 0)
    row:SetScript("OnClick", function(myself)
        selectedId = myself.shipmentId
        ShipmentsUI:Refresh()
    end)
    tinsert(listRows, row)
    return row
end

local function RefreshList()
    if not listChild then
        return
    end
    for _, row in ipairs(listRows) do
        row:Hide()
        row:ClearAllPoints()
    end
    local y = 0
    for _, s in ipairs(ns.db.global.mail.shipments) do
        local row = AcquireListRow()
        row.shipmentId = s.id
        row:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", listChild, "TOPRIGHT", 0, -y)
        if s.id == selectedId then
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        else
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        end
        -- Mode status: texture (not Unicode ●/○ — theme fonts like Poppins lack those glyphs).
        local mode = s.mode or "manual"
        if mode == "auto" then
            row.statusDot:SetColorTexture(0, 1, 0, 1)
        elseif mode == "auto_preview" then
            row.statusDot:SetColorTexture(1, 0.82, 0, 1)
        else
            row.statusDot:SetColorTexture(0.53, 0.53, 0.53, 1)
        end
        row.label:SetText(s.name or s.id)
        y = y + 30
    end
    listChild:SetHeight(math.max(1, y))
end

--- Resolve the currently selected shipment at call time. Detail widgets are
--- built once and outlive any particular shipment (reselect/rename/delete),
--- so their handlers must never capture a shipment table.
local function Current()
    return selectedId and GetShipment(selectedId)
end

-- Detail widgets: build-once/bind. WoW never garbage-collects frames, so the
-- old create-on-every-refresh pattern leaked widgets and their scripts on
-- each selection click.
local function EnsureDetailWidgets()
    if dw then
        return
    end
    dw = {}

    dw.empty = OneWoW_GUI:CreateFS(detailFrame, 12)
    dw.empty:SetPoint("TOPLEFT", detailFrame, "TOPLEFT", 8, -8)
    dw.empty:SetText(L["SHIPMENT_SELECT"])
    dw.empty:Hide()

    -- Sticky Preview/Send footer so actions stay inside the detail panel even when
    -- mode/frequency/kind push the form taller than the window.
    local FOOTER_H = 34
    local footer = CreateFrame("Frame", nil, detailFrame)
    footer:SetPoint("BOTTOMLEFT", detailFrame, "BOTTOMLEFT", 0, 4)
    footer:SetPoint("BOTTOMRIGHT", detailFrame, "BOTTOMRIGHT", 0, 4)
    footer:SetHeight(FOOTER_H)
    dw.footer = footer

    local detailScroll, content = OneWoW_GUI:CreateScrollFrame(detailFrame, {})
    detailScroll:ClearAllPoints()
    detailScroll:SetPoint("TOPLEFT", detailFrame, "TOPLEFT", 4, -4)
    detailScroll:SetPoint("BOTTOMRIGHT", detailFrame, "BOTTOMRIGHT", -4, FOOTER_H + 8)
    dw.detailScroll = detailScroll
    dw.content = content

    local SyncActionButtons -- forward: referenced by target commit/typing

    local y = -4
    local function nextY(delta)
        y = y - delta
        return y
    end

    -- Header: name, then auto-run mode (list dot mirrors the mode).
    dw.nameFs = OneWoW_GUI:CreateFS(content, 13)
    dw.nameFs:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.nameFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    nextY(20)

    dw.modeLabel = OneWoW_GUI:CreateFS(content, 11)
    dw.modeLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.modeLabel:SetText(L["SHIPMENT_MODE"] .. ":")
    nextY(16)

    -- Tri-state: three checkboxes acting as a radio group.
    dw.modeButtons = {}

    --- Check exactly the button for `mode`.
    function dw.SetModeChecked(mode)
        for key, cb in pairs(dw.modeButtons) do
            cb:SetChecked(key == mode)
        end
    end

    for _, def in ipairs({
        { key = "manual", label = L["MODE_MANUAL"], tt = L["TT_MODE_MANUAL"] },
        { key = "auto_preview", label = L["MODE_AUTO_PREVIEW"], tt = L["TT_MODE_AUTO_PREVIEW"] },
        { key = "auto", label = L["MODE_AUTO"], tt = L["TT_MODE_AUTO"] },
    }) do
        local cb = OneWoW_GUI:CreateCheckbox(content, { label = def.label })
        cb:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
        cb:SetScript("OnClick", function()
            local s = Current()
            if s then
                s.mode = def.key
                TouchEdited(s)
                if def.key == "manual" and ns.AutoRun then
                    ns.AutoRun:ClearSessionFlags(s.id)
                end
            end
            dw.SetModeChecked(def.key)
            if dw.SyncFrequencyEnabled then
                dw.SyncFrequencyEnabled()
            end
            RefreshList()
        end)
        AttachTooltip(cb, def.label, def.tt)
        dw.modeButtons[def.key] = cb
        nextY(24)
    end
    nextY(4)

    dw.freqLabel = OneWoW_GUI:CreateFS(content, 11)
    dw.freqLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.freqLabel:SetText(L["SHIPMENT_FREQUENCY"] .. ":")
    nextY(16)

    dw.freqButtons = {}
    function dw.SetFrequencyChecked(freq)
        for key, cb in pairs(dw.freqButtons) do
            cb:SetChecked(key == freq)
        end
    end
    for _, def in ipairs({
        { key = "session", label = L["FREQ_SESSION"], tt = L["TT_FREQ_SESSION"] },
        { key = "visit", label = L["FREQ_VISIT"], tt = L["TT_FREQ_VISIT"] },
    }) do
        local cb = OneWoW_GUI:CreateCheckbox(content, { label = def.label })
        cb:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
        cb:SetScript("OnClick", function()
            local s = Current()
            if s then
                s.frequency = def.key
                TouchEdited(s)
            end
            dw.SetFrequencyChecked(def.key)
        end)
        AttachTooltip(cb, def.label, def.tt)
        dw.freqButtons[def.key] = cb
        nextY(24)
    end
    nextY(4)

    dw.kindLabel = OneWoW_GUI:CreateFS(content, 11)
    dw.kindLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.kindLabel:SetText(L["SHIPMENT_KIND"] .. ":")
    nextY(16)

    dw.kindButtons = {}
    function dw.SetKindChecked(kind)
        for key, cb in pairs(dw.kindButtons) do
            cb:SetChecked(key == kind)
        end
    end
    do
        local prev
        for _, def in ipairs({
            { key = "items", label = L["KIND_ITEMS"], tt = L["TT_KIND_ITEMS"] },
            { key = "gold", label = L["KIND_GOLD"], tt = L["TT_KIND_GOLD"] },
        }) do
            local cb = OneWoW_GUI:CreateCheckbox(content, { label = def.label })
            if prev then
                cb:SetPoint("LEFT", prev, "LEFT", (prev:GetMeasuredWidth() or 80) + 20, 0)
            else
                cb:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
            end
            cb:SetScript("OnClick", function()
                local s = Current()
                if s then
                    s.kind = def.key
                    TouchEdited(s)
                end
                dw.SetKindChecked(def.key)
                if dw.SyncKindPanels then
                    dw.SyncKindPanels()
                end
            end)
            AttachTooltip(cb, def.label, def.tt)
            dw.kindButtons[def.key] = cb
            prev = cb
        end
        nextY(24)
    end
    nextY(6)

    -- Shared target (both kinds): Character name or Alt role.
    dw.targetLabel = OneWoW_GUI:CreateFS(content, 11)
    dw.targetLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.targetLabel:SetText(TARGET .. ":")
    AttachTooltip(dw.targetLabel, TARGET, L["TT_SHIPMENT_TARGET"])
    nextY(16)

    dw.targetKindButtons = {}
    function dw.SetTargetKindChecked(kind)
        for key, cb in pairs(dw.targetKindButtons) do
            cb:SetChecked(key == kind)
        end
    end
    do
        local prev
        for _, def in ipairs({
            { key = "char", label = CHARACTER, tt = L["TT_TARGET_KIND_CHAR"] },
            { key = "role", label = ROLE, tt = L["TT_TARGET_KIND_ROLE"] },
        }) do
            local cb = OneWoW_GUI:CreateCheckbox(content, { label = def.label })
            if prev then
                cb:SetPoint("LEFT", prev, "LEFT", (prev:GetMeasuredWidth() or 80) + 20, 0)
            else
                cb:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
            end
            cb:SetScript("OnClick", function()
                local s = Current()
                if s then
                    s.targetKind = def.key
                    TouchEdited(s)
                end
                dw.SetTargetKindChecked(def.key)
                if dw.SyncTargetKind then
                    dw.SyncTargetKind()
                end
                if SyncActionButtons then
                    SyncActionButtons()
                end
            end)
            AttachTooltip(cb, def.label, def.tt)
            dw.targetKindButtons[def.key] = cb
            prev = cb
        end
        nextY(24)
    end
    nextY(4)

    dw.targetBox = OneWoW_GUI:CreateEditBox(content, {
        width = 280,
        height = 24,
        placeholderText = "",
        showClear = true,
    })
    dw.targetBox:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.targetSuggest = ns.AddressSuggest:Attach(dw.targetBox, {
        onCommit = function(text)
            local s = Current()
            if s then
                s.target = text
                TouchEdited(s)
            end
            if SyncActionButtons then
                SyncActionButtons()
            end
        end,
    })
    dw.targetBox:HookScript("OnTextChanged", function(_, userInput)
        if userInput and SyncActionButtons then
            SyncActionButtons()
        end
    end)
    AttachTooltip(dw.targetBox, TARGET, L["TT_SHIPMENT_TARGET"])

    local DISTRIBUTE_LABELS = {
        fill_first = L["ROLE_DIST_FILL"],
        round_robin = L["ROLE_DIST_RR"],
        equal_split = L["ROLE_DIST_EQUAL"],
    }
    local CROSS_LABELS = {
        send = L["CROSS_REALM_SEND"],
        cancel = L["CROSS_REALM_CANCEL"],
        warbound = L["CROSS_REALM_WARBAND"],
    }

    dw.roleDropdown = OneWoW_GUI:CreateDropdown(content, {
        width = 200,
        height = 24,
        text = L["TARGET_ROLE_PICK"],
    })
    dw.roleDropdown:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    OneWoW_GUI:AttachFilterMenu(dw.roleDropdown, {
        searchable = false,
        menuHeight = 200,
        buildItems = function()
            local items = {}
            for _, role in ipairs(OneWoW.AltScope:GetRolesSorted()) do
                tinsert(items, {
                    text = role.name or role.id,
                    value = role.id,
                })
            end
            if #items == 0 then
                tinsert(items, { text = L["TARGET_ROLE_NONE"], value = "" })
            end
            return items
        end,
        onSelect = function(value, text)
            local s = Current()
            if s then
                s.targetRoleId = value or ""
                TouchEdited(s)
            end
            dw.roleDropdown._text:SetText(text)
            dw.roleDropdown._activeValue = value
            if SyncActionButtons then
                SyncActionButtons()
            end
        end,
        getActiveValue = function()
            local s = Current()
            return s and s.targetRoleId or nil
        end,
    })
    AttachTooltip(dw.roleDropdown, ROLE, L["TT_TARGET_KIND_ROLE"])

    nextY(28)

    dw.crossLabel = OneWoW_GUI:CreateFS(content, 11)
    dw.crossLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.crossLabel:SetText(L["CROSS_REALM"] .. ":")
    AttachTooltip(dw.crossLabel, L["CROSS_REALM"], L["TT_CROSS_REALM"])
    nextY(16)

    dw.crossDropdown = OneWoW_GUI:CreateDropdown(content, {
        width = 220,
        height = 24,
        text = CROSS_LABELS.send,
    })
    dw.crossDropdown:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    OneWoW_GUI:AttachFilterMenu(dw.crossDropdown, {
        searchable = false,
        menuHeight = 100,
        buildItems = function()
            return {
                { text = CROSS_LABELS.send, value = "send", tooltip = L["TT_CROSS_REALM_SEND"] },
                { text = CROSS_LABELS.cancel, value = "cancel", tooltip = L["TT_CROSS_REALM_CANCEL"] },
                { text = CROSS_LABELS.warbound, value = "warbound", tooltip = L["TT_CROSS_REALM_WARBAND"] },
            }
        end,
        onSelect = function(value, text)
            local s = Current()
            if s then
                s.crossRealm = value
                TouchEdited(s)
            end
            dw.crossDropdown._text:SetText(text)
            dw.crossDropdown._activeValue = value
        end,
        getActiveValue = function()
            local s = Current()
            return (s and s.crossRealm) or "send"
        end,
    })
    AttachTooltip(dw.crossDropdown, L["CROSS_REALM"], L["TT_CROSS_REALM"])
    nextY(36)

    local rulesTopChar = y

    dw.distLabel = OneWoW_GUI:CreateFS(content, 11)
    dw.distLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.distLabel:SetText(L["ROLE_DISTRIBUTE"] .. ":")
    AttachTooltip(dw.distLabel, L["ROLE_DISTRIBUTE"], L["TT_ROLE_DISTRIBUTE"])
    nextY(16)

    dw.distDropdown = OneWoW_GUI:CreateDropdown(content, {
        width = 220,
        height = 24,
        text = DISTRIBUTE_LABELS.fill_first,
    })
    dw.distDropdown:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    OneWoW_GUI:AttachFilterMenu(dw.distDropdown, {
        searchable = false,
        menuHeight = 100,
        buildItems = function()
            return {
                { text = DISTRIBUTE_LABELS.fill_first, value = "fill_first", tooltip = L["TT_ROLE_DIST_FILL"] },
                { text = DISTRIBUTE_LABELS.round_robin, value = "round_robin", tooltip = L["TT_ROLE_DIST_RR"] },
                { text = DISTRIBUTE_LABELS.equal_split, value = "equal_split", tooltip = L["TT_ROLE_DIST_EQUAL"] },
            }
        end,
        onSelect = function(value, text)
            local s = Current()
            if s then
                s.roleDistribute = value
                TouchEdited(s)
            end
            dw.distDropdown._text:SetText(text)
            dw.distDropdown._activeValue = value
        end,
        getActiveValue = function()
            local s = Current()
            return (s and s.roleDistribute) or "fill_first"
        end,
    })
    AttachTooltip(dw.distDropdown, L["ROLE_DISTRIBUTE"], L["TT_ROLE_DISTRIBUTE"])
    nextY(36)

    local rulesTopRole = y
    dw.rulesTop = rulesTopChar

    local function AnchorRules()
        local top = dw.rulesTop
        if dw.itemPanel then
            dw.itemPanel:ClearAllPoints()
            dw.itemPanel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
            dw.itemPanel:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, top)
        end
        if dw.goldPanel then
            dw.goldPanel:ClearAllPoints()
            dw.goldPanel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
            dw.goldPanel:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, top)
        end
        if dw.LayoutPreviewUnderRules then
            dw.LayoutPreviewUnderRules()
        end
    end

    function dw.SyncTargetKind()
        local s = Current()
        local kind = (s and s.targetKind) or "char"
        if kind == "role" then
            dw.targetBox:Hide()
            if dw.targetSuggest and dw.targetSuggest.chevron then
                dw.targetSuggest.chevron:Hide()
            end
            if dw.targetSuggest then
                dw.targetSuggest:Hide()
            end
            dw.roleDropdown:Show()
            dw.distLabel:Show()
            dw.distDropdown:Show()
            dw.rulesTop = rulesTopRole
        else
            dw.targetBox:Show()
            if dw.targetSuggest and dw.targetSuggest.chevron then
                dw.targetSuggest.chevron:Show()
            end
            dw.roleDropdown:Hide()
            dw.distLabel:Hide()
            dw.distDropdown:Hide()
            dw.rulesTop = rulesTopChar
        end
        AnchorRules()
    end

    -- Item-specific panel.
    dw.itemPanel = CreateFrame("Frame", nil, content)
    dw.itemPanel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, rulesTopRole)
    dw.itemPanel:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, rulesTopRole)

    local iy = 0
    local function nextIY(delta)
        iy = iy - delta
        return iy
    end

    dw.matchLabel = OneWoW_GUI:CreateFS(dw.itemPanel, 11)
    dw.matchLabel:SetPoint("TOPLEFT", dw.itemPanel, "TOPLEFT", 8, iy)
    dw.matchLabel:SetText(L["SHIPMENT_MATCH"] .. ":")
    AttachTooltip(dw.matchLabel, L["SHIPMENT_MATCH"], L["TT_SHIPMENT_MATCH"])
    nextIY(16)

    dw.matchBox = OneWoW_GUI:CreateEditBox(dw.itemPanel, {
        width = 360,
        height = 24,
        placeholderText = "",
    })
    dw.matchBox:SetPoint("TOPLEFT", dw.itemPanel, "TOPLEFT", 8, iy)
    dw.matchBox:HookScript("OnEnterPressed", function(myself)
        local s = Current()
        if s then
            s.match = myself:GetSearchText()
            TouchEdited(s)
        end
        myself:ClearFocus()
    end)
    dw.matchBox:HookScript("OnEditFocusLost", function(myself)
        local s = Current()
        if s then
            s.match = myself:GetSearchText()
            TouchEdited(s)
        end
    end)
    AttachTooltip(dw.matchBox, L["SHIPMENT_MATCH"], L["TT_SHIPMENT_MATCH"])
    nextIY(32)

    dw.rulesHeader = OneWoW_GUI:CreateFS(dw.itemPanel, 12)
    dw.rulesHeader:SetPoint("TOPLEFT", dw.itemPanel, "TOPLEFT", 8, iy)
    dw.rulesHeader:SetText(L["SHIPMENT_RULES"])
    dw.rulesHeader:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    nextIY(22)

    dw.keepLabel = OneWoW_GUI:CreateFS(dw.itemPanel, 12)
    dw.keepLabel:SetPoint("TOPLEFT", dw.itemPanel, "TOPLEFT", 8, iy - 2)
    dw.keepLabel:SetText(L["SHIPMENT_KEEP"] .. ":")
    AttachTooltip(dw.keepLabel, L["SHIPMENT_KEEP"], L["TT_SHIPMENT_KEEP"])

    dw.keepBox = OneWoW_GUI:CreateEditBox(dw.itemPanel, {
        width = 56,
        height = 22,
        placeholderText = "0",
    })
    dw.keepBox:SetPoint("LEFT", dw.keepLabel, "RIGHT", 8, 0)
    dw.keepBox:SetNumeric(true)
    dw.keepBox:HookScript("OnEditFocusLost", function(myself)
        local s = Current()
        if s then
            s.keepQty = tonumber(myself:GetSearchText()) or 0
            TouchEdited(s)
        end
    end)
    dw.keepBox:HookScript("OnTextChanged", function(myself, userInput)
        local s = Current()
        if userInput and s then
            s.keepQty = tonumber(myself:GetSearchText()) or 0
            TouchEdited(s)
        end
    end)
    AttachTooltip(dw.keepBox, L["SHIPMENT_KEEP"], L["TT_SHIPMENT_KEEP"])
    nextIY(30)

    dw.maxEnable = OneWoW_GUI:CreateCheckbox(dw.itemPanel, {
        label = L["SHIPMENT_MAX"] .. ":",
    })
    dw.maxEnable:SetPoint("TOPLEFT", dw.itemPanel, "TOPLEFT", 4, iy)
    AttachTooltip(dw.maxEnable, L["SHIPMENT_MAX"], L["TT_SHIPMENT_MAX"])

    dw.maxBox = OneWoW_GUI:CreateEditBox(dw.itemPanel, {
        width = 56,
        height = 22,
        placeholderText = "0",
    })
    dw.maxBox:SetPoint("LEFT", dw.maxEnable.label, "RIGHT", 8, 0)
    dw.maxBox:SetNumeric(true)
    dw.maxBox:HookScript("OnEditFocusLost", function(myself)
        local s = Current()
        if s then
            s.maxQty = tonumber(myself:GetSearchText()) or 0
            TouchEdited(s)
        end
    end)
    dw.maxBox:HookScript("OnTextChanged", function(myself, userInput)
        local s = Current()
        if userInput and s then
            s.maxQty = tonumber(myself:GetSearchText()) or 0
            TouchEdited(s)
        end
    end)
    AttachTooltip(dw.maxBox, L["SHIPMENT_MAX"], L["TT_SHIPMENT_MAX"])
    nextIY(30)

    dw.restock = OneWoW_GUI:CreateCheckbox(dw.itemPanel, {
        label = L["SHIPMENT_RESTOCK"],
    })
    dw.restock:SetPoint("TOPLEFT", dw.itemPanel, "TOPLEFT", 4, iy)
    dw.restock:SetScript("OnClick", function(myself)
        local s = Current()
        if s then
            s.restock = myself:GetChecked() and true or false
            TouchEdited(s)
        end
        if dw.SyncRestockSourcesEnabled then
            dw.SyncRestockSourcesEnabled()
        end
    end)
    AttachTooltip(dw.restock, L["SHIPMENT_RESTOCK"], L["TT_SHIPMENT_RESTOCK"])
    nextIY(26)

    dw.restockSourcesLabel = OneWoW_GUI:CreateFS(dw.itemPanel, 11)
    dw.restockSourcesLabel:SetPoint("TOPLEFT", dw.itemPanel, "TOPLEFT", 8, iy)
    dw.restockSourcesLabel:SetText(L["SHIPMENT_RESTOCK_SOURCES"] .. ":")
    AttachTooltip(dw.restockSourcesLabel, L["SHIPMENT_RESTOCK_SOURCES"], L["TT_SHIPMENT_RESTOCK_SOURCES"])
    nextIY(16)

    dw.restockSourceButtons = {}
    for _, def in ipairs({
        { key = "bags", label = HUD_EDIT_MODE_BAGS_LABEL },
        { key = "bank", label = BANK },
        { key = "warband", label = ACCOUNT_BANK_PANEL_TITLE },
        { key = "guild", label = GUILD_BANK },
    }) do
        local cb = OneWoW_GUI:CreateCheckbox(dw.itemPanel, { label = def.label })
        cb:SetPoint("TOPLEFT", dw.itemPanel, "TOPLEFT", 16, iy)
        cb:SetScript("OnClick", function(myself)
            local s = Current()
            if not s then
                return
            end
            s.restockSources = ns:NormalizeRestockSources(s.restockSources)
            s.restockSources[def.key] = myself:GetChecked() and true or false
            TouchEdited(s)
        end)
        AttachTooltip(cb, def.label, L["TT_SHIPMENT_RESTOCK_SOURCES"])
        dw.restockSourceButtons[def.key] = cb
        nextIY(24)
    end
    nextIY(4)
    local itemRulesH = -iy
    dw.itemPanel:SetHeight(itemRulesH)

    -- Gold-specific panel (same vertical slot as item panel).
    dw.goldPanel = CreateFrame("Frame", nil, content)
    dw.goldPanel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, rulesTopRole)
    dw.goldPanel:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, rulesTopRole)
    dw.goldPanel:Hide()

    local gy = 0
    local function nextGY(delta)
        gy = gy - delta
        return gy
    end

    dw.goldRulesHeader = OneWoW_GUI:CreateFS(dw.goldPanel, 12)
    dw.goldRulesHeader:SetPoint("TOPLEFT", dw.goldPanel, "TOPLEFT", 8, gy)
    dw.goldRulesHeader:SetText(L["SHIPMENT_GOLD_RULES"])
    dw.goldRulesHeader:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    nextGY(22)

    dw.goldKeepLabel = OneWoW_GUI:CreateFS(dw.goldPanel, 12)
    dw.goldKeepLabel:SetPoint("TOPLEFT", dw.goldPanel, "TOPLEFT", 8, gy - 2)
    dw.goldKeepLabel:SetText(L["SHIPMENT_GOLD_KEEP"] .. ":")
    AttachTooltip(dw.goldKeepLabel, L["SHIPMENT_GOLD_KEEP"], L["TT_SHIPMENT_GOLD_KEEP"])

    dw.goldKeepBox = OneWoW_GUI:CreateEditBox(dw.goldPanel, {
        width = 80,
        height = 22,
        placeholderText = GOLD_AMOUNT_SYMBOL,
    })
    dw.goldKeepBox:SetPoint("LEFT", dw.goldKeepLabel, "RIGHT", 8, 0)
    dw.goldKeepBox:SetNumeric(true)
    StyleMoneyBox(dw.goldKeepBox, ns.Constants.MONEY_COLORS.GOLD)
    local function CommitGoldKeep()
        local s = Current()
        if s then
            local gold = tonumber(dw.goldKeepBox:GetSearchText()) or 0
            s.keepCopper = gold * 10000
            TouchEdited(s)
        end
    end
    dw.goldKeepBox:HookScript("OnEditFocusLost", CommitGoldKeep)
    dw.goldKeepBox:HookScript("OnTextChanged", function(_, userInput)
        if userInput then CommitGoldKeep() end
    end)
    AttachTooltip(dw.goldKeepBox, L["SHIPMENT_GOLD_KEEP"], L["TT_SHIPMENT_GOLD_KEEP"])
    nextGY(30)

    dw.goldMaxEnable = OneWoW_GUI:CreateCheckbox(dw.goldPanel, {
        label = L["SHIPMENT_GOLD_MAX"] .. ":",
    })
    dw.goldMaxEnable:SetPoint("TOPLEFT", dw.goldPanel, "TOPLEFT", 4, gy)
    AttachTooltip(dw.goldMaxEnable, L["SHIPMENT_GOLD_MAX"], L["TT_SHIPMENT_GOLD_MAX"])

    dw.goldMaxBox = OneWoW_GUI:CreateEditBox(dw.goldPanel, {
        width = 80,
        height = 22,
        placeholderText = GOLD_AMOUNT_SYMBOL,
    })
    dw.goldMaxBox:SetPoint("LEFT", dw.goldMaxEnable.label, "RIGHT", 8, 0)
    dw.goldMaxBox:SetNumeric(true)
    StyleMoneyBox(dw.goldMaxBox, ns.Constants.MONEY_COLORS.GOLD)
    local function CommitGoldMax()
        local s = Current()
        if s then
            local gold = tonumber(dw.goldMaxBox:GetSearchText()) or 0
            s.maxCopper = gold * 10000
            TouchEdited(s)
        end
    end
    dw.goldMaxBox:HookScript("OnEditFocusLost", CommitGoldMax)
    dw.goldMaxBox:HookScript("OnTextChanged", function(_, userInput)
        if userInput then CommitGoldMax() end
    end)
    AttachTooltip(dw.goldMaxBox, L["SHIPMENT_GOLD_MAX"], L["TT_SHIPMENT_GOLD_MAX"])
    nextGY(30)

    dw.goldRestock = OneWoW_GUI:CreateCheckbox(dw.goldPanel, {
        label = L["SHIPMENT_GOLD_RESTOCK"] .. ":",
    })
    dw.goldRestock:SetPoint("TOPLEFT", dw.goldPanel, "TOPLEFT", 4, gy)
    AttachTooltip(dw.goldRestock, L["SHIPMENT_GOLD_RESTOCK"], L["TT_SHIPMENT_GOLD_RESTOCK"])

    dw.goldRestockBox = OneWoW_GUI:CreateEditBox(dw.goldPanel, {
        width = 80,
        height = 22,
        placeholderText = GOLD_AMOUNT_SYMBOL,
    })
    dw.goldRestockBox:SetPoint("LEFT", dw.goldRestock.label, "RIGHT", 8, 0)
    dw.goldRestockBox:SetNumeric(true)
    StyleMoneyBox(dw.goldRestockBox, ns.Constants.MONEY_COLORS.GOLD)
    local function CommitGoldRestock()
        local s = Current()
        if s then
            local gold = tonumber(dw.goldRestockBox:GetSearchText()) or 0
            s.restockCopper = gold * 10000
            TouchEdited(s)
        end
    end
    dw.goldRestockBox:HookScript("OnEditFocusLost", CommitGoldRestock)
    dw.goldRestockBox:HookScript("OnTextChanged", function(_, userInput)
        if userInput then CommitGoldRestock() end
    end)
    AttachTooltip(dw.goldRestockBox, L["SHIPMENT_GOLD_RESTOCK"], L["TT_SHIPMENT_GOLD_RESTOCK"])
    dw.goldRestock:SetScript("OnClick", function(myself)
        local s = Current()
        if s then
            s.restock = myself:GetChecked() and true or false
            TouchEdited(s)
            if s.restock and (s.restockCopper or 0) == 0 and (s.maxCopper or 0) > 0 then
                s.restockCopper = s.maxCopper
                dw.goldRestockBox:SetText(tostring(math.floor(s.restockCopper / 10000)))
            end
        end
        if dw.SyncGoldCapDependent then
            dw.SyncGoldCapDependent()
        end
    end)
    nextGY(28)
    local goldRulesH = -gy
    dw.goldPanel:SetHeight(goldRulesH)

    -- Preview sits just under whichever rules panel is showing (item panel is taller).
    local PREVIEW_H = 180
    local PREVIEW_LINE_H = 18
    local PREVIEW_SCROLL_W = ns.Constants.GUI.SCROLLBAR_CONTENT_GUTTER
    dw.previewLines = {}

    local function HidePreviewLines()
        for _, fs in ipairs(dw.previewLines) do
            fs:Hide()
            fs:ClearAllPoints()
            fs._tipTitle = nil
            fs._tipBody = nil
            if fs._hit then
                fs._hit:Hide()
            end
        end
    end

    local function AcquirePreviewLine()
        for _, fs in ipairs(dw.previewLines) do
            if not fs:IsShown() then
                fs:Show()
                return fs
            end
        end
        local fs = OneWoW_GUI:CreateFS(dw.previewChild, 11)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        local hit = CreateFrame("Frame", nil, dw.previewChild)
        hit:SetHeight(PREVIEW_LINE_H)
        hit:EnableMouse(true)
        hit:SetScript("OnEnter", function()
            if not fs._tipTitle then
                return
            end
            GameTooltip:SetOwner(hit, "ANCHOR_RIGHT")
            GameTooltip:SetText(fs._tipTitle, 1, 1, 1)
            if fs._tipBody and fs._tipBody ~= "" then
                GameTooltip:AddLine(fs._tipBody, 0.85, 0.85, 0.85, true)
            end
            GameTooltip:Show()
        end)
        hit:SetScript("OnLeave", GameTooltip_Hide)
        fs._hit = hit
        tinsert(dw.previewLines, fs)
        return fs
    end

    local function SetPreviewRows(rows)
        HidePreviewLines()
        local width = math.max(100, (dw.previewScroll:GetWidth() or 400) - PREVIEW_SCROLL_W)
        dw.previewChild:SetWidth(width)
        local rowY = 0
        for _, row in ipairs(rows) do
            local fs = AcquirePreviewLine()
            fs:SetText(row.text or "")
            if row.warning then
                fs:SetTextColor(1, 0.53, 0, 1)
            else
                fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", dw.previewChild, "TOPLEFT", 0, -rowY)
            fs:SetPoint("TOPRIGHT", dw.previewChild, "TOPRIGHT", -4, -rowY)
            fs._tipTitle = row.tipTitle
            fs._tipBody = row.tipBody
            if fs._hit then
                fs._hit:ClearAllPoints()
                fs._hit:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
                fs._hit:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 0, 0)
                if row.tipTitle then
                    fs._hit:Show()
                else
                    fs._hit:Hide()
                end
            end
            rowY = rowY + PREVIEW_LINE_H
        end
        dw.previewChild:SetHeight(math.max(1, rowY))
        dw.previewScroll:SetVerticalScroll(0)
    end
    dw.SetPreviewRows = SetPreviewRows

    local function LayoutPreviewUnderRules()
        local panel = dw.goldPanel:IsShown() and dw.goldPanel or dw.itemPanel
        local rulesH = panel:GetHeight()
        dw.previewScroll:ClearAllPoints()
        dw.previewScroll:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 8, -10)
        dw.previewScroll:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", -8, -10)
        dw.previewScroll:SetHeight(PREVIEW_H)
        content:SetHeight(math.max(1, -(dw.rulesTop - rulesH - 10) + PREVIEW_H + 10))
        local width = math.max(100, (dw.previewScroll:GetWidth() or 400) - PREVIEW_SCROLL_W)
        dw.previewChild:SetWidth(width)
    end
    dw.LayoutPreviewUnderRules = LayoutPreviewUnderRules

    local SKIP_SHORT = {
        ["restock-met"] = "PREVIEW_SKIP_RESTOCK_MET",
        ["keep-holds"] = "PREVIEW_SKIP_KEEP_HOLDS",
        ["underfunded"] = "PREVIEW_SKIP_UNDERFUNDED",
        ["cap-zero"] = "PREVIEW_SKIP_CAP_ZERO",
        ["no-match"] = "PREVIEW_SKIP_NO_MATCH",
        ["nothing"] = "PREVIEW_SKIP_NOTHING",
        ["cross-realm-cancel"] = "PREVIEW_SKIP_CROSS_REALM_CANCEL",
        ["cross-realm-warbound"] = "PREVIEW_SKIP_CROSS_REALM_WARBAND",
        ["cross-realm-gold"] = "PREVIEW_SKIP_CROSS_REALM_GOLD",
        ["cross-realm-other"] = "PREVIEW_SKIP_CROSS_REALM_OTHER",
    }
    local SKIP_FULL = {
        ["restock-met"] = "LOG_SKIP_RESTOCK_MET",
        ["keep-holds"] = "LOG_SKIP_KEEP_HOLDS",
        ["underfunded"] = "LOG_SKIP_UNDERFUNDED",
        ["cap-zero"] = "LOG_SKIP_CAP_ZERO",
        ["no-match"] = "LOG_SKIP_NO_MATCH",
        ["nothing"] = "LOG_SKIP_NOTHING",
        ["cross-realm-cancel"] = "LOG_SKIP_CROSS_REALM_CANCEL",
        ["cross-realm-warbound"] = "LOG_SKIP_CROSS_REALM_WARBAND",
        ["cross-realm-gold"] = "LOG_SKIP_CROSS_REALM_GOLD",
        ["cross-realm-other"] = "LOG_SKIP_CROSS_REALM_OTHER",
    }

    local function CommitDetailFields()
        local s = Current()
        if not s then
            return
        end
        s.targetKind = (dw.targetKindButtons.role:GetChecked() and "role") or "char"
        if s.targetKind == "role" then
            s.targetRoleId = dw.roleDropdown._activeValue or s.targetRoleId or ""
            s.roleDistribute = dw.distDropdown._activeValue or s.roleDistribute or "fill_first"
        else
            s.target = dw.targetSuggest:GetText()
        end
        s.crossRealm = dw.crossDropdown._activeValue or s.crossRealm or "send"
        s.kind = (dw.kindButtons.gold:GetChecked() and "gold") or "items"
        s.frequency = (dw.freqButtons.visit:GetChecked() and "visit") or "session"
        if s.kind == "gold" then
            s.keepCopper = (tonumber(dw.goldKeepBox:GetSearchText()) or 0) * 10000
            s.maxCopper = (tonumber(dw.goldMaxBox:GetSearchText()) or 0) * 10000
            s.maxCopperEnabled = dw.goldMaxEnable:GetChecked() and true or false
            s.restock = dw.goldRestock:GetChecked() and true or false
            s.restockCopper = (tonumber(dw.goldRestockBox:GetSearchText()) or 0) * 10000
            dw.goldKeepBox:ClearFocus()
            dw.goldMaxBox:ClearFocus()
            dw.goldRestockBox:ClearFocus()
        else
            s.match = dw.matchBox:GetSearchText()
            s.keepQty = tonumber(dw.keepBox:GetSearchText()) or 0
            s.maxQty = tonumber(dw.maxBox:GetSearchText()) or 0
            s.maxQtyEnabled = dw.maxEnable:GetChecked() and true or false
            s.restock = dw.restock:GetChecked() and true or false
            s.restockSources = ns:NormalizeRestockSources(s.restockSources)
            for key, cb in pairs(dw.restockSourceButtons) do
                s.restockSources[key] = cb:GetChecked() and true or false
            end
            dw.keepBox:ClearFocus()
            dw.maxBox:ClearFocus()
            dw.matchBox:ClearFocus()
        end
        TouchEdited(s)
        dw.targetBox:ClearFocus()
    end

    dw.previewBtn = OneWoW_GUI:CreateFitTextButton(footer, { text = PREVIEW, height = 26 })
    dw.previewBtn:SetPoint("LEFT", footer, "LEFT", 8, 0)

    local function RenderShipmentPreview(shipment, allowRetry)
        local result = ns.ShipmentEvaluator:Preview(shipment.id)
        local rows = {}
        local needsRetry = false
        local roleLabel = nil
        if (shipment.targetKind or "char") == "role" and shipment.targetRoleId and shipment.targetRoleId ~= "" then
            local role = OneWoW.AltScope:GetRole(shipment.targetRoleId)
            roleLabel = (role and role.name) or shipment.targetRoleId
        end
        local function TargetLabel(target)
            local name = target or "?"
            local short = strsplit("-", name, 2)
            if roleLabel then
                return string.format("%s >> %s", roleLabel, short or name)
            end
            return short or name
        end
        for _, plan in ipairs(result.plans) do
            local who = TargetLabel(plan.target)
            local hadEntry = false
            for _, entry in ipairs(plan.entries or {}) do
                hadEntry = true
                if entry.money then
                    local amount = OneWoW.Format.FormatGold(entry.money)
                    tinsert(rows, {
                        text = string.format("%s  |  %s", who, amount),
                        tipTitle = who,
                        tipBody = amount,
                    })
                else
                    local link = entry.slots and entry.slots[1] and entry.slots[1].link
                    local name, resolved = ns.ItemLabel.ResolveName(entry.itemID, link)
                    ns.ItemLabel.RequestLoadIfNeeded(entry.itemID, link)
                    if not resolved then
                        needsRetry = true
                    end
                    local quality = C_Item.GetItemQualityByID(entry.itemID)
                    local r, g, b = OneWoW_GUI:GetItemQualityColor(quality)
                    local colored = string.format(
                        "|cff%02x%02x%02x%s|r",
                        math.floor(r * 255 + 0.5),
                        math.floor(g * 255 + 0.5),
                        math.floor(b * 255 + 0.5),
                        name
                    )
                    local amount = string.format("%s x%d", colored, entry.quantity)
                    tinsert(rows, {
                        text = string.format("%s  |  %s", who, amount),
                        tipTitle = who,
                        tipBody = string.format("%s x%d", name, entry.quantity),
                    })
                end
            end
            if not hadEntry and not plan.error and plan.skipReason then
                local shortKey = SKIP_SHORT[plan.skipReason] or "PREVIEW_SKIP_NOTHING"
                local fullKey = SKIP_FULL[plan.skipReason] or "LOG_SKIP_NOTHING"
                local tipBody = L[fullKey]
                if plan.skipDetail then
                    tipBody = tipBody .. "\n" .. plan.skipDetail
                end
                tinsert(rows, {
                    text = string.format("%s  |  %s", who, L[shortKey]),
                    tipTitle = who,
                    tipBody = tipBody,
                })
            elseif plan.omitDetail then
                tinsert(rows, {
                    text = string.format("%s  |  %s", who, L["PREVIEW_SKIP_CROSS_REALM_WARBAND"]),
                    tipTitle = who,
                    tipBody = plan.omitDetail,
                })
            end
        end
        for _, err in ipairs(result.errors) do
            tinsert(rows, { text = err, warning = true, tipTitle = err })
        end
        local jobCount = #(result.jobs or {})
        if jobCount > 0 then
            local postage = (GetSendMailPrice() or 30) * jobCount
            local postageText = SEND_MAIL_COST .. " " .. OneWoW.Format.FormatGold(postage)
            tinsert(rows, { text = postageText, tipTitle = postageText })
        end
        if #rows == 0 then
            tinsert(rows, { text = L["PREVIEW_EMPTY"] })
        end
        SetPreviewRows(rows)
        C_Timer.After(0, function()
            if dw.detailScroll then
                dw.detailScroll:SetVerticalScroll(dw.detailScroll:GetVerticalScrollRange())
            end
        end)
        if needsRetry and allowRetry then
            C_Timer.After(0.25, function()
                if Current() ~= shipment then
                    return
                end
                RenderShipmentPreview(shipment, false)
            end)
        end
    end

    dw.previewBtn:SetScript("OnClick", function()
        local s = Current()
        if not s then
            return
        end
        CommitDetailFields()
        RenderShipmentPreview(s, true)
    end)

    dw.sendBtn = OneWoW_GUI:CreateFitTextButton(footer, { text = L["BTN_SEND_SHIPMENT"], height = 26 })
    dw.sendBtn:SetPoint("LEFT", dw.previewBtn, "RIGHT", 6, 0)
    dw.sendBtn:SetScript("OnClick", function()
        local s = Current()
        if not s then
            return
        end
        CommitDetailFields()
        local to = s.target or ""
        if (s.targetKind or "char") == "role" then
            if not s.targetRoleId or s.targetRoleId == "" then
                print(L["ADDON_CHAT_PREFIX"] .. " " .. L["ERR_NO_TARGET"])
                return
            end
        elseif to == "" then
            print(L["ADDON_CHAT_PREFIX"] .. " " .. L["ERR_NO_TARGET"])
            return
        else
            local isAlt = ns.AddressBook:IsSuiteAlt(to)
            if not isAlt then
                print(L["ADDON_CHAT_PREFIX"] .. " " .. L["WARN_NON_ROSTER"])
            end
        end
        ns.ShipmentEvaluator:Run({ shipmentId = s.id }, function(ok, _, summary)
            if ok then
                print(L["ADDON_CHAT_PREFIX"] .. " " .. string.format(L["SEND_DONE"], summary.sent))
            end
        end)
    end)

    dw.previewScroll, dw.previewChild = OneWoW_GUI:CreateScrollFrame(content, {})
    dw.previewScroll:SetHeight(PREVIEW_H)
    LayoutPreviewUnderRules()
    SetPreviewRows({})

    SyncActionButtons = function()
        local s = Current()
        local hasTarget = false
        if s and (s.targetKind or "char") == "role" then
            hasTarget = s.targetRoleId and s.targetRoleId ~= ""
        else
            hasTarget = strtrim(dw.targetSuggest:GetText() or "") ~= ""
        end
        SetWidgetEnabled(dw.previewBtn, hasTarget)
        SetWidgetEnabled(dw.sendBtn, hasTarget)
    end
    dw.SyncActionButtons = SyncActionButtons

    local function SyncRestockSourcesEnabled()
        local on = dw.maxEnable:GetChecked() and dw.restock:GetChecked()
        for _, cb in pairs(dw.restockSourceButtons) do
            SetWidgetEnabled(cb, on)
        end
        if dw.restockSourcesLabel then
            dw.restockSourcesLabel:SetAlpha(on and 1 or 0.45)
        end
    end
    dw.SyncRestockSourcesEnabled = SyncRestockSourcesEnabled

    local function SyncCapDependent()
        local s = Current()
        local capOn = dw.maxEnable:GetChecked() and true or false
        if s and (s.kind or "items") ~= "gold" then
            s.maxQtyEnabled = capOn
        end
        if capOn then
            SetWidgetEnabled(dw.maxBox, true)
            SetWidgetEnabled(dw.restock, true)
        else
            SetWidgetEnabled(dw.maxBox, false)
            dw.restock:SetChecked(false)
            if s and (s.kind or "items") ~= "gold" then
                s.restock = false
            end
            SetWidgetEnabled(dw.restock, false)
        end
        SyncRestockSourcesEnabled()
    end
    dw.SyncCapDependent = SyncCapDependent

    local function SyncGoldCapDependent()
        local s = Current()
        local capOn = dw.goldMaxEnable:GetChecked() and true or false
        if s and (s.kind or "items") == "gold" then
            s.maxCopperEnabled = capOn
        end
        if capOn then
            SetWidgetEnabled(dw.goldMaxBox, true)
            SetWidgetEnabled(dw.goldRestock, true)
        else
            SetWidgetEnabled(dw.goldMaxBox, false)
            dw.goldRestock:SetChecked(false)
            if s and (s.kind or "items") == "gold" then
                s.restock = false
            end
            SetWidgetEnabled(dw.goldRestock, false)
        end
        local restockOn = capOn and dw.goldRestock:GetChecked()
        SetWidgetEnabled(dw.goldRestockBox, restockOn)
    end
    dw.SyncGoldCapDependent = SyncGoldCapDependent

    local function SyncFrequencyEnabled()
        local mode = "manual"
        for key, cb in pairs(dw.modeButtons) do
            if cb:GetChecked() then
                mode = key
                break
            end
        end
        local on = mode ~= "manual"
        for _, cb in pairs(dw.freqButtons) do
            SetWidgetEnabled(cb, on)
        end
        if dw.freqLabel then
            dw.freqLabel:SetAlpha(on and 1 or 0.45)
        end
    end
    dw.SyncFrequencyEnabled = SyncFrequencyEnabled

    local function SyncKindPanels()
        local kind = dw.kindButtons.gold:GetChecked() and "gold" or "items"
        if kind == "gold" then
            dw.itemPanel:Hide()
            dw.goldPanel:Show()
            SyncGoldCapDependent()
        else
            dw.goldPanel:Hide()
            dw.itemPanel:Show()
            SyncCapDependent()
        end
        LayoutPreviewUnderRules()
    end
    dw.SyncKindPanels = SyncKindPanels

    dw.maxEnable:SetScript("OnClick", function()
        local s = Current()
        if s then
            TouchEdited(s)
        end
        SyncCapDependent()
    end)
    dw.goldMaxEnable:SetScript("OnClick", function()
        local s = Current()
        if s then
            TouchEdited(s)
        end
        SyncGoldCapDependent()
    end)
end

--- Bind the selected shipment's values into the (already built) widgets.
local function RefreshDetail()
    if not detailFrame then
        return
    end
    EnsureDetailWidgets()
    local s = Current()
    if not s then
        dw.detailScroll:Hide()
        dw.footer:Hide()
        dw.empty:Show()
        return
    end
    dw.empty:Hide()
    dw.detailScroll:Show()
    dw.footer:Show()

    dw.nameFs:SetText(NAME .. ": " .. (s.name or ""))
    dw.SetModeChecked(s.mode or "manual")
    dw.SetFrequencyChecked(s.frequency or "session")
    dw.SetKindChecked(s.kind or "items")
    dw.SetTargetKindChecked(s.targetKind or "char")
    dw.targetSuggest:SetText(s.target or "")
    local roleId = s.targetRoleId or ""
    dw.roleDropdown._activeValue = roleId
    if roleId ~= "" then
        local role = OneWoW.AltScope:GetRole(roleId)
        dw.roleDropdown._text:SetText((role and role.name) or roleId)
    else
        dw.roleDropdown._text:SetText(L["TARGET_ROLE_PICK"])
    end
    local dist = s.roleDistribute or "fill_first"
    dw.distDropdown._activeValue = dist
    local distLabels = {
        fill_first = L["ROLE_DIST_FILL"],
        round_robin = L["ROLE_DIST_RR"],
        equal_split = L["ROLE_DIST_EQUAL"],
    }
    dw.distDropdown._text:SetText(distLabels[dist] or distLabels.fill_first)
    local cross = s.crossRealm or "send"
    if cross ~= "send" and cross ~= "cancel" and cross ~= "warbound" then
        cross = "send"
    end
    local crossLabels = {
        send = L["CROSS_REALM_SEND"],
        cancel = L["CROSS_REALM_CANCEL"],
        warbound = L["CROSS_REALM_WARBAND"],
    }
    dw.crossDropdown._activeValue = cross
    dw.crossDropdown._text:SetText(crossLabels[cross] or crossLabels.send)
    dw.SyncTargetKind()
    dw.matchBox:SetText(s.match or "")
    dw.matchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    dw.keepBox:SetText(tostring(s.keepQty or 0))
    dw.keepBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    dw.maxEnable:SetChecked(s.maxQtyEnabled and true or false)
    dw.maxBox:SetText(tostring(s.maxQty or 0))
    dw.maxBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    dw.restock:SetChecked(s.restock and true or false)
    local sources = ns:NormalizeRestockSources(s.restockSources)
    s.restockSources = sources
    for key, cb in pairs(dw.restockSourceButtons) do
        cb:SetChecked(sources[key] and true or false)
    end

    local keepGold = math.floor((s.keepCopper or 0) / 10000)
    dw.goldKeepBox:SetText(tostring(keepGold))
    dw.goldKeepBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    dw.goldMaxEnable:SetChecked(s.maxCopperEnabled and true or false)
    local maxGold = math.floor((s.maxCopper or 0) / 10000)
    dw.goldMaxBox:SetText(tostring(maxGold))
    dw.goldMaxBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    dw.goldRestock:SetChecked(s.restock and (s.kind or "items") == "gold")
    local restockGold = math.floor((s.restockCopper or 0) / 10000)
    dw.goldRestockBox:SetText(tostring(restockGold))
    dw.goldRestockBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    dw.SetPreviewRows({})
    dw.SyncFrequencyEnabled()
    dw.SyncKindPanels()
    dw.SyncActionButtons()
    dw.detailScroll:SetVerticalScroll(0)
end

function ShipmentsUI:Reset()
    listChild = nil
    detailFrame = nil
    wipe(listRows)
    dw = nil
    newBtn = nil
    renameBtn = nil
    deleteBtn = nil
end

function ShipmentsUI:Create(parent)
    local listWidth = ns.Constants.GUI.LEFT_PANEL_WIDTH
    local actionH = 30
    local btnH = ns.Constants.GUI.BUTTON_HEIGHT
    local listScroll
    listScroll, listChild = OneWoW_GUI:CreateScrollFrame(parent, { width = listWidth })
    listScroll:ClearAllPoints()
    listScroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    listScroll:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, actionH)
    listScroll:SetWidth(listWidth)

    -- Buttons only — no full-width backdrop (FitText widths vary by locale).
    newBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = NEW, height = btnH })
    newBtn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 2)
    newBtn:SetScript("OnClick", function()
        StaticPopup_Show("ONEWOW_MAIL_SHIPMENT_CREATE")
    end)

    renameBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = L["RENAME"], height = btnH })
    renameBtn:SetPoint("LEFT", newBtn, "RIGHT", 4, 0)
    renameBtn:SetScript("OnClick", function()
        if not selectedId or not GetShipment(selectedId) then
            return
        end
        StaticPopup_Show("ONEWOW_MAIL_SHIPMENT_RENAME", nil, nil, selectedId)
    end)

    deleteBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = DELETE, height = btnH })
    deleteBtn:SetPoint("LEFT", renameBtn, "RIGHT", 4, 0)
    deleteBtn:SetScript("OnClick", function()
        if not selectedId or not GetShipment(selectedId) then
            return
        end
        StaticPopup_Show("ONEWOW_MAIL_SHIPMENT_DELETE", nil, nil, selectedId)
    end)

    detailFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    detailFrame:SetPoint("TOPLEFT", listScroll, "TOPRIGHT", 16, 0)
    detailFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    detailFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    detailFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    detailFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
end

function ShipmentsUI:Refresh()
    if selectedId and not GetShipment(selectedId) then
        selectedId = nil
    end
    if not selectedId and ns.db.global.mail.shipments[1] then
        selectedId = ns.db.global.mail.shipments[1].id
    end
    RefreshList()
    RefreshDetail()
    SyncCrudButtons()
end
