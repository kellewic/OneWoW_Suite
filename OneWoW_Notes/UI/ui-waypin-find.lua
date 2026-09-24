local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local Location = OneWoW.Location
local C = OneWoW_GUI.Constants
local C_Timer = C_Timer
local C_Item = C_Item
local C_Map = C_Map
local ipairs, pairs, next, tinsert, sort = ipairs, pairs, next, tinsert, sort

-- ============================================================================
-- Find Location
-- ============================================================================
-- Search Catalog vendor NPCs and Notes NPC records. Filter tokens are
-- AND-matched against name, ID, type, notes, tooltips, custom category, and
-- items a vendor sells. A leading ! excludes. Zone accepts a name or map ID.
-- Typing waits one second so a few characters can land before search.
-- ============================================================================

ns.UI = ns.UI or {}

local MAX_RESULTS = 80
local ROW_H = 36
local SEARCH_DELAY = 1
local COSMIC_MAP = 946

local dialog
local fields = {}
local resultRows = {}
local findPackId
local resultChild
local resultStatus
local searchTimer

local function ParseTokens(text)
    local include, exclude = {}, {}
    if type(text) ~= "string" then
        return include, exclude
    end
    for token in text:gmatch("%S+") do
        token = token:gsub(",", "")
        if token ~= "" then
            if token:sub(1, 1) == "!" then
                local t = token:sub(2):lower()
                if t ~= "" then
                    tinsert(exclude, t)
                end
            else
                tinsert(include, token:lower())
            end
        end
    end
    return include, exclude
end

local function HayMatches(hay, include, exclude)
    for _, token in ipairs(include) do
        if not hay:find(token, 1, true) then
            return false
        end
    end
    for _, token in ipairs(exclude) do
        if hay:find(token, 1, true) then
            return false
        end
    end
    return true
end

local function BuildHay(name, subtitle, category, roles, zone, subzone, extra)
    local parts = {
        name or "",
        subtitle or "",
        category or "",
        zone or "",
        subzone or "",
        extra or "",
    }
    if type(roles) == "table" then
        for _, role in ipairs(roles) do
            tinsert(parts, tostring(role))
        end
    end
    return table.concat(parts, " "):lower()
end

local function ZoneNeedleParts(needle)
    local parenID = tonumber(needle:match("%((%d+)%)%s*$"))
    local asID = tonumber(needle)
    local namePart = needle:gsub("%s*%(%d+%)%s*$", "")
    return asID or parenID, namePart
end

local function ZoneHit(loc, mapID, needle, currentMapID)
    mapID = tonumber(mapID)
    if needle == "" then
        return mapID == currentMapID
    end
    local wantID, namePart = ZoneNeedleParts(needle)
    if wantID and wantID == mapID then
        return true
    end
    if namePart ~= "" then
        if loc.zone and loc.zone:lower():find(namePart, 1, true) then
            return true
        end
        if loc.subzone and loc.subzone:lower():find(namePart, 1, true) then
            return true
        end
        local info = mapID and C_Map.GetMapInfo(mapID)
        if info and info.name and info.name:lower():find(namePart, 1, true) then
            return true
        end
    end
    return false
end

local function ResolveZone(text)
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return nil
    end
    local parenID = tonumber(text:match("%((%d+)%)%s*$"))
    if parenID then
        local info = C_Map.GetMapInfo(parenID)
        if info then
            return parenID, info.name
        end
    end
    local asID = tonumber(text)
    if asID then
        local info = C_Map.GetMapInfo(asID)
        if info then
            return asID, info.name
        end
    end
    local needle = text:gsub("%s*%(%d+%)%s*$", ""):lower()
    if needle == "" then
        return nil
    end
    local current = Location.GetPlayerMapID()
    if current then
        local info = C_Map.GetMapInfo(current)
        if info and info.name and info.name:lower() == needle then
            return current, info.name
        end
    end
    local children = C_Map.GetMapChildrenInfo(COSMIC_MAP, nil, true)
    local fuzzyID, fuzzyName
    if children then
        for _, info in ipairs(children) do
            if info.name and info.name:lower() == needle then
                return info.mapID, info.name
            end
            if not fuzzyID and info.name and info.name:lower():find(needle, 1, true) then
                fuzzyID, fuzzyName = info.mapID, info.name
            end
        end
    end
    return fuzzyID, fuzzyName
end

local function EnsureVendorsAPI()
    OneWoW:EnsureCatalogPack("vendors")
    return OneWoW:GetCatalogPackAPI("vendors")
end

local function VendorItemsMatch(vendor, include, exclude)
    if type(vendor.items) ~= "table" or not next(vendor.items) then
        return false
    end
    if #include == 0 then
        return false
    end
    for itemID in pairs(vendor.items) do
        local name = C_Item.GetItemNameByID(itemID) or ""
        local hay = (tostring(itemID) .. " " .. name):lower()
        if HayMatches(hay, include, exclude) then
            return true
        end
    end
    return false
end

local function TooltipExtra(record)
    local extra = record.content or ""
    if type(record.tooltipLines) == "table" then
        for i = 1, #record.tooltipLines do
            extra = extra .. " " .. (record.tooltipLines[i] or "")
        end
    end
    return extra
end

local function CollectResults(zoneText, filterText)
    local out = {}
    local seen = {}
    local currentMapID = Location.GetPlayerMapID()
    local zoneNeedle = (zoneText or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local include, exclude = ParseTokens(filterText)

    local api = EnsureVendorsAPI()
    if api then
        for npcID, vendor in pairs(api.GetAllVendors()) do
            if type(vendor) == "table" and vendor.locations then
                for mapID, loc in pairs(vendor.locations) do
                    if type(loc) == "table" and loc.x and loc.y and ZoneHit(loc, mapID, zoneNeedle, currentMapID) then
                        local extra = tostring(npcID)
                        if vendor.items and next(vendor.items) then
                            extra = extra .. " sells vendor"
                        end
                        local cat = vendor.category or ""
                        if cat:find("profession", 1, true) then
                            extra = extra .. " professions profession"
                        end
                        if cat == "repair" then
                            extra = extra .. " repair"
                        end
                        if cat == "banker" then
                            extra = extra .. " banker bank"
                        end
                        extra = extra .. " " .. TooltipExtra(vendor)
                        local hay = BuildHay(
                            vendor.name,
                            vendor.subtitle,
                            vendor.category,
                            vendor.roles,
                            loc.zone,
                            loc.subzone,
                            extra
                        )
                        local matched = HayMatches(hay, include, exclude)
                        if not matched then
                            matched = VendorItemsMatch(vendor, include, exclude)
                        end
                        if matched then
                            local key = tostring(npcID) .. ":" .. tostring(mapID)
                            if not seen[key] then
                                seen[key] = true
                                tinsert(out, {
                                    title = vendor.name or tostring(npcID),
                                    sub = vendor.subtitle or vendor.category or "",
                                    mapID = tonumber(mapID),
                                    x = loc.x,
                                    y = loc.y,
                                    source = "vendor",
                                    sourceKey = npcID,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    for npcID, npc in pairs(ns.NPCs:GetAllNPCs()) do
        if type(npc) == "table" and npc.mapID and npc.coords then
            local loc = {
                zone = npc.zone,
                subzone = npc.subzone,
                x = npc.coords.x,
                y = npc.coords.y,
            }
            if loc.x and loc.y and ZoneHit(loc, npc.mapID, zoneNeedle, currentMapID) then
                local key = tostring(npcID) .. ":" .. tostring(npc.mapID)
                if not seen[key] then
                    local extra = tostring(npcID) .. " npc " .. TooltipExtra(npc)
                    local hay = BuildHay(npc.name, npc.category, npc.category, nil, npc.zone, npc.subzone, extra)
                    if HayMatches(hay, include, exclude) then
                        seen[key] = true
                        tinsert(out, {
                            title = npc.name or tostring(npcID),
                            sub = npc.category or "",
                            mapID = tonumber(npc.mapID),
                            x = npc.coords.x,
                            y = npc.coords.y,
                            source = "npc",
                            sourceKey = npcID,
                        })
                    end
                end
            end
        end
    end

    sort(out, function(a, b)
        if a.title == b.title then
            return (a.mapID or 0) < (b.mapID or 0)
        end
        return a.title < b.title
    end)

    if #out > MAX_RESULTS then
        local trimmed = {}
        for i = 1, MAX_RESULTS do
            trimmed[i] = out[i]
        end
        return trimmed, api ~= nil, #out
    end
    return out, api ~= nil, #out
end

local function PaintResults(list, catalogOk, total)
    for _, row in ipairs(resultRows) do
        row:Hide()
    end
    local y = 0
    for i, hit in ipairs(list) do
        local row = resultRows[i]
        if not row then
            row = CreateFrame("Button", nil, resultChild, "BackdropTemplate")
            row:SetHeight(ROW_H)
            row:SetBackdrop(C.BACKDROP_INNER_NO_INSETS)

            local title = OneWoW_GUI:CreateFS(row, 12)
            title:SetPoint("TOPLEFT", 8, -4)
            title:SetPoint("RIGHT", -88, 0)
            title:SetJustifyH("LEFT")
            title:SetWordWrap(false)
            row.title = title

            local sub = OneWoW_GUI:CreateFS(row, 10)
            sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
            sub:SetPoint("RIGHT", -88, 0)
            sub:SetJustifyH("LEFT")
            sub:SetWordWrap(false)
            row.sub = sub

            local goBtn = OneWoW_GUI:CreateFitTextButton(row, { text = L["WAYPINS_GO"], height = 22, minWidth = 36 })
            goBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            goBtn:SetScript("OnClick", function(myself)
                local data = myself:GetParent().hit
                if data then
                    Location.SetWaypoint(data.mapID, data.x, data.y, {
                        format = "percent",
                        title = data.title,
                    })
                end
            end)
            row.goBtn = goBtn

            local addBtn = OneWoW_GUI:CreateFitTextButton(row, { text = ADD, height = 22, minWidth = 40 })
            addBtn:SetPoint("RIGHT", goBtn, "LEFT", -4, 0)
            addBtn:SetScript("OnClick", function(myself)
                local data = myself:GetParent().hit
                if not data then return end
                local pinID
                if findPackId then
                    pinID = ns.WayPinPacks:AddPin(findPackId, {
                        title = data.title,
                        mapID = data.mapID,
                        x = data.x,
                        y = data.y,
                    })
                else
                    pinID = ns.WayPins:Add({
                        title = data.title,
                        mapID = data.mapID,
                        x = data.x,
                        y = data.y,
                        source = data.source,
                        sourceKey = data.sourceKey,
                    })
                end
                local pin = pinID and ns.WayPins:GetPin(pinID)
                if pin then
                    ns.UI.OpenWayPinDialog(pin)
                end
            end)
            row.addBtn = addBtn

            resultRows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", resultChild, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", resultChild, "TOPRIGHT", 0, -y)
        row.hit = hit
        row.title:SetText(hit.title)
        row.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        local zoneName = ns.WayPins:MapDisplayName(hit.mapID)
        local extra = hit.sub ~= "" and (hit.sub .. "  ") or ""
        row.sub:SetText(string.format("%s%s (%d)  %.1f, %.1f", extra, zoneName, hit.mapID or 0, hit.x or 0, hit.y or 0))
        row.sub:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        row:Show()
        y = y + ROW_H + 2
    end
    resultChild:SetHeight(math.max(y, 1))

    if #list == 0 then
        if not catalogOk then
            resultStatus:SetText(L["WAYPINS_FIND_NEED_CATALOG"])
        else
            resultStatus:SetText(L["WAYPINS_FIND_EMPTY"])
        end
    else
        resultStatus:SetText(string.format(L["UI_COUNT_FORMAT"], L["WAYPINS_FIND_LOCATION"], total or #list))
    end
end

local function CancelSearchTimer()
    if searchTimer then
        searchTimer:Cancel()
        searchTimer = nil
    end
end

local function RunSearch()
    CancelSearchTimer()
    local zoneText = fields.zone:GetSearchText()
    local filterText = fields.filters:GetSearchText()
    local list, catalogOk, total = CollectResults(zoneText, filterText)
    PaintResults(list, catalogOk, total)
end

local function ScheduleSearch()
    CancelSearchTimer()
    searchTimer = C_Timer.NewTimer(SEARCH_DELAY, function()
        searchTimer = nil
        RunSearch()
    end)
end

local function FillCurrentZone()
    local mapID = Location.GetPlayerMapID()
    local info = mapID and C_Map.GetMapInfo(mapID)
    if info then
        fields.zone:SetText(string.format("%s (%d)", info.name, mapID))
        fields.zone:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    else
        fields.zone:SetText("")
    end
end

local function VerifyZone()
    local mapID, name = ResolveZone(fields.zone:GetSearchText())
    if mapID and name then
        fields.zone:SetText(string.format("%s (%d)", name, mapID))
        fields.zone:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        resultStatus:SetText(string.format("%s (%d)", name, mapID))
        RunSearch()
        return
    end
    resultStatus:SetText(L["WAYPINS_FIND_ZONE_FAIL"])
end

local function AttachFieldTooltip(box, text)
    box:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    box:HookScript("OnLeave", GameTooltip_Hide)
end

local function EnsureDialog()
    if dialog then return dialog end

    dialog = OneWoW_GUI:CreateDialog({
        name   = "OneWoW_NotesWayPinFindDialog",
        title  = L["WAYPINS_FIND_LOCATION"],
        width  = 560,
        height = 560,
        buttons = {
            { text = SEARCH, onClick = function() RunSearch() end },
            { text = CANCEL, onClick = function(f) f:Hide() end },
        },
    })

    local content = dialog.contentFrame
    local y = -12

    local zoneLabel = OneWoW_GUI:CreateFS(content, 12)
    zoneLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    zoneLabel:SetText(ZONE)
    zoneLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    y = y - 18

    local currentBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["WAYPINS_FIND_CURRENT"], height = 24 })
    currentBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, y)
    currentBtn:SetScript("OnClick", function()
        FillCurrentZone()
        RunSearch()
    end)
    currentBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:SetText(L["WAYPINS_FIND_ZONE_TT"], 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    currentBtn:HookScript("OnLeave", GameTooltip_Hide)

    local verifyBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["WAYPINS_FIND_VERIFY"], height = 24 })
    verifyBtn:SetPoint("RIGHT", currentBtn, "LEFT", -4, 0)
    verifyBtn:SetScript("OnClick", VerifyZone)
    verifyBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:SetText(L["WAYPINS_FIND_ZONE_TT"], 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    verifyBtn:HookScript("OnLeave", GameTooltip_Hide)

    fields.zone = OneWoW_GUI:CreateEditBox(content, {
        placeholderText = ZONE,
        maxLetters = 80,
        onTextChanged = function()
            ScheduleSearch()
        end,
    })
    fields.zone:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    fields.zone:SetPoint("RIGHT", verifyBtn, "LEFT", -8, 0)
    AttachFieldTooltip(fields.zone, L["WAYPINS_FIND_ZONE_TT"])
    y = y - 32

    local filterLabel = OneWoW_GUI:CreateFS(content, 12)
    filterLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    filterLabel:SetText(SEARCH)
    filterLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    y = y - 18

    fields.filters = OneWoW_GUI:CreateEditBox(content, {
        placeholderText = L["WAYPINS_FIND_FILTERS_PH"],
        maxLetters = 120,
        onTextChanged = function()
            ScheduleSearch()
        end,
    })
    fields.filters:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    fields.filters:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, y)
    fields.filters:HookScript("OnEnterPressed", RunSearch)
    fields.zone:HookScript("OnEnterPressed", RunSearch)
    AttachFieldTooltip(fields.filters, L["WAYPINS_FIND_SEARCH_TT"])
    y = y - 32

    local hint = OneWoW_GUI:CreateFS(content, 10)
    hint:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    hint:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, y)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(L["WAYPINS_FIND_HINT"])
    hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    y = y - 48

    resultStatus = OneWoW_GUI:CreateFS(content, 11)
    resultStatus:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    resultStatus:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    y = y - 20

    local scroll, child = OneWoW_GUI:CreateScrollFrame(content, {})
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    scroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -14, 8)
    resultChild = child

    return dialog
end

---@param packId string|nil
function ns.UI.OpenWayPinFindDialog(packId)
    if not ns.WayPinsVisual.Enabled() then return end
    findPackId = packId
    EnsureDialog()
    FillCurrentZone()
    fields.filters:SetText("")
    RunSearch()
    dialog.frame:Show()
    dialog.frame:Raise()
end
