local OneWoW_GUI = OneWoW_GUI
local CreateFrame = CreateFrame
local math = math

local ALERT_ICON_SIZE = 16
local ALERT_ICON_GAP = 4
local ALERT_ROW_H = 18
local ALERT_SPLIT = " | "

local ALERT_SOURCE_DEFS = {
    { key = "shopping", icon = "Perks-ShoppingCart" },
    { key = "notes", icon = "icon-pin" },
    { key = "trackers", icon = "icon-flag" },
    { key = "farming", icon = "bags-icon-reagents" },
}

local function IconHasHits(btn)
    return btn.hits and #btn.hits > 0
end

local function PlaceMatchingIcons(row, x, wantHits)
    local placed = 0
    for i = 1, #ALERT_SOURCE_DEFS do
        local btn = row.icons[ALERT_SOURCE_DEFS[i].key]
        if IconHasHits(btn) == wantHits then
            if placed > 0 then
                x = x + ALERT_ICON_GAP
            end
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", row, "LEFT", x, 0)
            x = x + ALERT_ICON_SIZE
            placed = placed + 1
        end
    end
    return x
end

--- One-line Item Alert: count, hits left of |, idle icons (or Many) on the right.
---@param parent Frame
---@param options { interactive: boolean|nil, onClick: function|nil, manyLabel: string }
---@return Frame
function OneWoW_GUI:CreateItemAlertRow(parent, options)
    options = options or {}
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ALERT_ROW_H)
    row:EnableMouse(false)
    row.interactive = options.interactive == true
    row.onClick = options.onClick
    row._title = ""

    local label = OneWoW_GUI:CreateFS(row, 11)
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    row.label = label

    local noneText = OneWoW_GUI:CreateFS(row, 11)
    noneText:SetJustifyH("LEFT")
    noneText:SetWordWrap(false)
    noneText:SetText(options.noneLabel or NONE)
    row.noneText = noneText

    local sep = OneWoW_GUI:CreateFS(row, 11)
    sep:SetJustifyH("LEFT")
    sep:SetWordWrap(false)
    sep:SetText(ALERT_SPLIT)
    row.sep = sep

    local manyText = OneWoW_GUI:CreateFS(row, 11)
    manyText:SetJustifyH("LEFT")
    manyText:SetWordWrap(false)
    manyText:SetText(options.manyLabel)
    row.manyText = manyText

    row.icons = {}
    for i = 1, #ALERT_SOURCE_DEFS do
        local def = ALERT_SOURCE_DEFS[i]
        local btn = CreateFrame("Button", nil, row)
        btn:SetSize(ALERT_ICON_SIZE, ALERT_ICON_SIZE)
        btn.sourceKey = def.key
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        OneWoW.OverlayIcons:ApplyToTexture(tex, def.icon)
        btn.icon = tex
        btn:SetScript("OnClick", function(myself)
            if not row.interactive then
                return
            end
            if row.onClick then
                row.onClick(myself.sourceKey, myself.hits or {})
            end
        end)
        btn:EnableMouse(true)
        row.icons[def.key] = btn
    end

    function row:SetLabel(text)
        self._title = text
    end

    function row:SetHits(alerts)
        local hitCount = 0
        for i = 1, #ALERT_SOURCE_DEFS do
            local def = ALERT_SOURCE_DEFS[i]
            local btn = self.icons[def.key]
            local hits = alerts and alerts[def.key]
            btn.hits = hits
            if IconHasHits(btn) then
                hitCount = hitCount + 1
                btn.icon:SetAlpha(1)
                btn.icon:SetVertexColor(1, 1, 1)
            else
                btn.icon:SetAlpha(1)
                btn.icon:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
            btn:Show()
        end

        self.label:SetText(self._title .. ": (" .. hitCount .. ")")
        self.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        local labelW = math.ceil(self.label:GetStringWidth())
        self.label:SetWidth(labelW)

        self.noneText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        self.sep:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        self.manyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

        local showNone = hitCount == 0
        local showMany = hitCount == #ALERT_SOURCE_DEFS
        self.noneText:SetShown(showNone)
        self.manyText:SetShown(showMany)
        self.sep:Show()

        local x = labelW + 6
        if showNone then
            self.noneText:ClearAllPoints()
            self.noneText:SetPoint("LEFT", self, "LEFT", x, 0)
            x = x + math.ceil(self.noneText:GetStringWidth())
        else
            x = PlaceMatchingIcons(self, x, true)
        end

        self.sep:ClearAllPoints()
        self.sep:SetPoint("LEFT", self, "LEFT", x, 0)
        x = x + math.ceil(self.sep:GetStringWidth())

        if showMany then
            self.manyText:ClearAllPoints()
            self.manyText:SetPoint("LEFT", self, "LEFT", x, 0)
        else
            PlaceMatchingIcons(self, x, false)
        end

        self:Show()
        return ALERT_ROW_H
    end

    function row:ForEachIcon(fn)
        for i = 1, #ALERT_SOURCE_DEFS do
            fn(self.icons[ALERT_SOURCE_DEFS[i].key])
        end
    end

    return row
end
