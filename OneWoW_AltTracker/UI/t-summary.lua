local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local Location = OneWoW.Location

-- Hearth coordinates are stored as raw API fractions here, unlike the 0-100 the
-- rest of the suite keeps. The map opens even when no coordinates were captured.

ns.UI = ns.UI or {}

local currentSortColumn = nil
local currentSortAscending = true
local characterRows = {}

local summaryTabRef
local summaryRefreshPending = false
local summaryStorageSubscribed = false

local function ScheduleSummaryStorageRefresh()
    -- In-transit gold / mail icons; also keep bags column live when Storage writes.
    if summaryRefreshPending then
        return
    end
    summaryRefreshPending = true
    C_Timer.After(0.3, function()
        summaryRefreshPending = false
        local tab = summaryTabRef
        if tab and tab:IsVisible() and ns.UI.RefreshSummaryTab then
            ns.UI.RefreshSummaryTab(tab)
        end
    end)
end

--- Suite mail gold still in flight to this character (Storage in-transit).
local function GetInTransitGold(charKey)
    local API = OneWoW_AltTracker_Storage_API
    if not API or not API.GetInTransitShipments or not charKey then
        return 0
    end
    local total = 0
    for _, ship in ipairs(API.GetInTransitShipments(charKey) or {}) do
        total = total + (ship.money or 0)
    end
    return total
end

local function FormatGoldAmount(copper)
    local fmt = ns.AltTrackerFormatters
    if fmt and fmt.FormatGold then
        return fmt:FormatGold(copper or 0)
    end
    return tostring(copper or 0)
end

function ns.UI.CreateSummaryTab(parent)
    local overview = OneWoW_GUI:CreateOverviewPanel(parent, {
        height = 110,
        columns = 5,
        stats = {
            {label = L["ATTENTION"],            value = "0",    ttTitle = L["ATTENTION"],            ttDesc = L["TT_ATTENTION_DESC"]},
            {label = L["CHARACTERS"],           value = "0",    ttTitle = L["CHARACTERS"],           ttDesc = L["TT_CHARACTERS_DESC"]},
            {label = L["TOTAL_GOLD"],           value = "0g",   ttTitle = L["GOLD_TOTAL"],           ttDesc = L["TT_TOTAL_GOLD_DESC"]},
            {label = L["FACTIONS"],             value = "0/0",  ttTitle = L["FACTIONS"],             ttDesc = L["TT_FACTIONS_DESC"]},
            {label = L["RESTED"],               value = "0",    ttTitle = L["TT_RESTED"],               ttDesc = L["TT_RESTED_DESC"]},
            {label = L["PLAYTIME"],             value = "0h",   ttTitle = L["PLAYTIME"],             ttDesc = L["TT_PLAYTIME_DESC"]},
            {label = MOUNTS,               value = "0/0",  ttTitle = MOUNTS,               ttDesc = L["TT_MOUNTS_DESC"]},
            {label = PETS,                 value = "0/0",  ttTitle = PETS,                 ttDesc = L["TT_PETS_DESC"]},
            {label = L["PRIMARY_PROFESSIONS"],  value = "0/11", ttTitle = L["PRIMARY_PROFESSIONS"],  ttDesc = L["TT_PRIMARY_PROFESSIONS_DESC"]},
            {label = ACHIEVEMENTS,         value = "0",    ttTitle = ACHIEVEMENTS,         ttDesc = L["TT_ACHIEVEMENTS_DESC"]},
        },
    })

    local rosterPanel = CreateFrame("Frame", nil, parent)
    rosterPanel:SetPoint("TOPLEFT", overview.panel, "BOTTOMLEFT", 0, -8)
    rosterPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 30)

    local columns = {
        {key = "expand",    label = "",                  width = 25,  fixed = true,  align = "icon",   sortable = false, ttTitle = L["TT_COL_EXPAND"],     ttDesc = L["TT_COL_EXPAND_DESC"]},
        {key = "star",      label = "",                  width = 30,  fixed = true,  align = "icon",   sortable = false, ttTitle = L["TT_COL_STAR"],       ttDesc = L["TT_COL_STAR_DESC"]},
        {key = "faction",   label = L["COL_FACTION"],    width = 25,  fixed = true,  align = "center", sortable = false, ttTitle = FACTION,    ttDesc = L["TT_COL_FACTION_DESC"]},
        {key = "mail",      label = L["COL_MAIL"],       width = 35,  fixed = true,  align = "center", sortable = false, ttTitle = L["MAIL"],       ttDesc = L["TT_COL_MAIL_DESC"]},
        {key = "name",      label = CHARACTER,  width = 101, fixed = false, align = "left",                     ttTitle = CHARACTER,  ttDesc = L["TT_COL_CHARACTER_DESC"]},
        {key = "server",    label = L["COL_SERVER"],     width = 50,  fixed = false, align = "left",                     ttTitle = L["COL_SERVER"],     ttDesc = L["TT_COL_SERVER_DESC"]},
        {key = "level",     label = L["COL_LEVEL"],      width = 40,  fixed = true,  align = "center",                   ttTitle = LEVEL,      ttDesc = L["TT_COL_LEVEL_DESC"]},
        {key = "class",     label = CLASS,      width = 60,  fixed = false, align = "left",                     ttTitle = CLASS,      ttDesc = L["TT_COL_CLASS_DESC"]},
        {key = "spec",      label = L["COL_SPEC"],       width = 70,  fixed = false, align = "left",                     ttTitle = SPECIALIZATION,       ttDesc = L["TT_COL_SPEC_DESC"]},
        {key = "rested",    label = L["COL_RESTED_XP"],  width = 50,  fixed = true,  align = "center",                   ttTitle = L["TT_COL_RESTED_XP"],  ttDesc = L["TT_COL_RESTED_XP_DESC"]},
        {key = "itemLevel", label = L["COL_ITEM_LEVEL"], width = 50,  fixed = true,  align = "center",                   ttTitle = L["TT_COL_ITEM_LEVEL"], ttDesc = L["TT_COL_ITEM_LEVEL_DESC"]},
        {key = "bags",      label = L["COL_BAGS"],       width = 40,  fixed = true,  align = "center",                   ttTitle = L["TT_COL_BAGS"],       ttDesc = L["TT_COL_BAGS_DESC"]},
        {key = "money",     label = L["COL_GOLD"],       width = 102, fixed = false, align = "right",                    ttTitle = L["TT_COL_GOLD"],       ttDesc = L["TT_COL_GOLD_DESC"]},
        {key = "hearth",    label = L["COL_HEARTH"],     width = 80,  fixed = false, align = "left",                     ttTitle = L["TT_COL_HEARTH"],     ttDesc = L["TT_COL_HEARTH_DESC"]},
        {key = "lastSeen",  label = L["COL_LAST_SEEN"],  width = 80,  fixed = false, align = "left",                     ttTitle = L["COL_LAST_SEEN"],  ttDesc = L["TT_COL_LAST_SEEN_DESC"]},
    }

    local function onHeaderCreate(btn, col, _)
        if col.key == "expand" then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(14, 14)
            icon:SetPoint("CENTER")
            icon:SetAtlas("Gamepad_Rev_Plus_64")
            btn.icon = icon
            if btn.text then btn.text:SetText("") end
        elseif col.key == "mail" then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(12, 12)
            icon:SetPoint("CENTER")
            icon:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")
            btn.icon = icon
            if btn.text then btn.text:SetText("") end
        elseif col.key == "star" then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(12, 12)
            icon:SetPoint("CENTER")
            OneWoW_GUI:SetFavoriteAtlasTexture(icon)
            btn.icon = icon
            if btn.text then btn.text:SetText("") end
        end
    end

    local dt
    dt = OneWoW_GUI:CreateDataTable(rosterPanel, {
        columns = columns,
        headerHeight = 26,
        rowHeight = 32,
        onHeaderCreate = onHeaderCreate,
        onSort = function(sortColumn, sortAscending)
            currentSortColumn = sortColumn
            currentSortAscending = sortAscending
            ns.UI.RefreshSummaryTab(parent)
            C_Timer.After(0.1, function() dt.UpdateSortIndicators() end)
        end,
    })

    parent.dataTable = dt
    parent.columnsConfig = columns

    local status = OneWoW_GUI:CreateStatusBar(parent, rosterPanel, {
        text = string.format(L["CHARACTERS_TRACKED"], 1, ""),
    })

    parent.overviewPanel = overview.panel
    parent.statsContainer = overview.statsContainer
    parent.statBoxes = overview.statBoxes
    parent.rosterPanel = rosterPanel
    parent.headerRow = dt.headerRow
    parent.scrollContent = dt.scrollContent
    parent.statusBar = status.bar
    parent.statusText = status.text

    OneWoW_GUI:ApplyFontToFrame(parent)

    summaryTabRef = parent
    local function RefreshSummary()
        if ns.UI.RefreshSummaryTab then
            ns.UI.RefreshSummaryTab(parent)
        end
    end
    OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Character", RefreshSummary)
    OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Storage", function()
        if not summaryStorageSubscribed and OneWoW_AltTracker_Storage_API
            and OneWoW_AltTracker_Storage_API.RegisterStorageChanged then
            summaryStorageSubscribed = true
            OneWoW_AltTracker_Storage_API.RegisterStorageChanged(ScheduleSummaryStorageRefresh)
        end
        RefreshSummary()
    end)
    OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Collections", RefreshSummary)
    OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Professions", RefreshSummary)

    if ns.UI.RegisterRosterTabFrame then
        ns.UI.RegisterRosterTabFrame("summary", parent)
    end
end

function ns.UI.RefreshSummaryTab(summaryTab)
    if not summaryTab then
        return
    end

    if not OneWoW_AltTracker_Character_API then
        return
    end

    local currentCharKey = OneWoW_GUI:GetCharacterKey()
    local liveChar = OneWoW_AltTracker_Character_API.GetCharacterData(currentCharKey)
    if liveChar then
        if not liveChar.xp then liveChar.xp = {} end
        liveChar.xp.currentXP = UnitXP("player")
        liveChar.xp.maxXP = UnitXPMax("player")
        liveChar.xp.restedXP = GetXPExhaustion() or 0
        liveChar.xp.restState = GetRestState()
        liveChar.xp.isResting = IsResting()
        liveChar.xp.isXPDisabled = IsXPUserDisabled()
        liveChar.xp.lastUpdate = time()
    end

    local allChars = ns.UI.GetSortedCharacters(function(charKey, charData, col)
        if col == "name" then
            return charData.name or ""
        elseif col == "server" then
            return charData.realm or ""
        elseif col == "level" then
            return charData.level or 0
        elseif col == "class" then
            return charData.className or ""
        elseif col == "spec" then
            local spec = charData.stats and charData.stats.specName
            return type(spec) == "string" and spec or (type(spec) == "table" and (spec.name or "") or "")
        elseif col == "rested" then
            local Fmt = ns.AltTrackerFormatters
            if Fmt and charData.xp and charData.xp.maxXP and charData.xp.maxXP > 0 then
                return (Fmt:EstimateRestedXP(charData, charKey) / charData.xp.maxXP) * 100
            end
            return 0
        elseif col == "itemLevel" then
            return charData.itemLevel or 0
        elseif col == "bags" then
            local free = 0
            if OneWoW_AltTracker_Storage_API then
                local bags = OneWoW_AltTracker_Storage_API.GetBags(charKey)
                if bags then
                    for bagID = 0, 4 do
                        if bags[bagID] then
                            local numSlots = bags[bagID].numSlots or 0
                            local usedSlots = 0
                            if bags[bagID].slots then
                                for _, itemData in pairs(bags[bagID].slots) do
                                    if itemData then usedSlots = usedSlots + 1 end
                                end
                            end
                            free = free + (numSlots - usedSlots)
                        end
                    end
                end
            end
            return free
        elseif col == "money" then
            return (charData.money or 0) + GetInTransitGold(charKey)
        elseif col == "hearth" then
            return (charData.location and charData.location.bindLocation) or ""
        elseif col == "lastSeen" then
            return charData.lastLogin or 0
        end
        return charData.name or ""
    end, currentSortColumn, currentSortAscending)

    if #allChars == 0 then
        return
    end

    local scrollContent = summaryTab.scrollContent
    if not scrollContent then return end

    local dt = summaryTab.dataTable
    local columnsConfig = summaryTab.columnsConfig

    OneWoW_GUI:ClearDataRows(scrollContent)
    wipe(characterRows)
    if dt then dt:ClearRows() end

    local rowHeight = 32
    local rowGap = 2

    for _, charInfo in ipairs(allChars) do
        local charKey = charInfo.key
        local charData = charInfo.data

        local charRow = OneWoW_GUI:CreateDataRow(scrollContent, {
            rowHeight = rowHeight,
            expandedHeight = 100,
            rowGap = rowGap,
            data = { charKey = charKey, charData = charData },
            createDetails = function(ef, d)
                local cData = d.charData
                local cKey = d.charKey

                local grid = OneWoW_GUI:CreateExpandedPanelGrid(ef)

                local p1 = grid:AddPanel(L["EXPANDED_BASIC_INFO"])
                local playTimeColor = {OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")}
                local totalTime = (cData.playTime and cData.playTime.total) or 0
                grid:AddLine(p1, L["EXPANDED_TOTAL_PLAYTIME"], ns.UI.FormatPlaytimeCompact(totalTime), playTimeColor)

                if cData.playTime and cData.playTime.thisLevel ~= nil then
                    grid:AddLine(p1, L["EXPANDED_LEVEL_PLAYTIME"], ns.UI.FormatPlaytimeCompact(cData.playTime.thisLevel), playTimeColor)
                end

                local restedPercent = 0
                local eFmt = ns.AltTrackerFormatters
                if eFmt and cData.xp and cData.xp.maxXP and cData.xp.maxXP > 0 then
                    local estimatedRested = eFmt:EstimateRestedXP(cData, cKey)
                    restedPercent = math.floor((estimatedRested / cData.xp.maxXP) * 100)
                    local race = cData.race or cData.raceName or ""
                    local maxPercent = (race == "Pandaren") and 300 or 150
                    restedPercent = math.min(restedPercent, maxPercent)
                end
                local restedColor = {OneWoW_GUI:GetThemeColor("TEXT_WARNING")}
                if restedPercent >= 150 then restedColor = {OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED")}
                elseif restedPercent >= 60 then restedColor = {OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY")}
                elseif restedPercent >= 30 then restedColor = {OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")}
                end
                grid:AddLine(p1, L["TT_RESTED_AMOUNT"], restedPercent .. "%", restedColor)

                if cData.location and cData.location.bindLocation then
                    grid:AddLine(p1, L["EXPANDED_HEARTH"], cData.location.bindLocation)
                end

                if cData.location and cData.location.zone then
                    grid:AddLine(p1, L["EXPANDED_LAST_SEEN"], cData.location.zone, {OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")})
                end

                local p2 = grid:AddPanel(L["EXPANDED_COMMUNITY_INFO"])
                local guildName = L["EXPANDED_NO_GUILD"]
                local guildRank = ""
                if cData.guild and cData.guild.name then
                    guildName = cData.guild.name
                    guildRank = cData.guild.rank or ""
                end
                grid:AddLine(p2, L["GUILD"], guildName, {OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED")})
                if guildRank ~= "" then
                    grid:AddLine(p2, L["EXPANDED_GUILD_RANK"], guildRank, {OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")})
                end

                if cData.race or cData.raceName then
                    grid:AddLine(p2, L["RACE"], cData.race or cData.raceName, {OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")})
                end

                grid:Finish()
                OneWoW_GUI:ApplyFontToFrame(ef)
            end,
        })
        charRow.charKey = charKey

        if ns.UI.CreateFavoriteStarButton then
            table.insert(charRow.cells, 2, ns.UI.CreateFavoriteStarButton(charRow, charKey))
        end

        local factionCell = OneWoW_GUI:CreateFactionIcon(charRow, { faction = charData.faction })
        table.insert(charRow.cells, factionCell)

        local hasMail = ns.UI.GetHasMailForChar and ns.UI.GetHasMailForChar(charKey) or false
        local mailCell = OneWoW_GUI:CreateMailIcon(charRow, { hasMail = hasMail })
        table.insert(charRow.cells, mailCell)
        charRow.mailCell = mailCell
        if ns.UI.RegisterMailIconCell then
            ns.UI.RegisterMailIconCell(mailCell, charKey)
        end

        local nameText = OneWoW_GUI:CreateFS(charRow, 12)
        nameText:SetText(charData.name or charKey)
        local classColor = RAID_CLASS_COLORS[charData.class]
        if classColor then
            nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
        nameText:SetJustifyH("LEFT")

        local nameFrame = CreateFrame("Frame", nil, charRow)
        nameFrame:SetAllPoints(nameText)
        nameFrame:EnableMouse(true)
        nameFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(charData.name or charKey, 1, 1, 1)

            if charData.guid then
                GameTooltip:AddLine(L["TT_CHAR_GUID"] .. " " .. charData.guid, 0.7, 0.7, 0.7, true)
            end

            if charData.sex then
                if charData.sex == 2 then
                    GameTooltip:AddLine(L["TT_CHAR_GENDER_MALE"], 0.7, 0.7, 0.7)
                elseif charData.sex == 3 then
                    GameTooltip:AddLine(L["TT_CHAR_GENDER_FEMALE"], 0.7, 0.7, 0.7)
                end
            end

            if charData.title then
                GameTooltip:AddLine(L["TT_CHAR_TITLE"] .. " " .. charData.title, 0.7, 0.7, 0.7, true)
            else
                GameTooltip:AddLine(L["TT_CHAR_NO_TITLE"], 0.5, 0.5, 0.5)
            end

            GameTooltip:Show()
        end)
        nameFrame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        table.insert(charRow.cells, nameText)

        local realmText = OneWoW_GUI:CreateFS(charRow, 12)
        realmText:SetText(charData.realm or "")
        realmText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        realmText:SetJustifyH("LEFT")
        table.insert(charRow.cells, realmText)

        local levelContainer = CreateFrame("Frame", nil, charRow)
        levelContainer:SetSize(40, rowHeight)

        local level = charData.level or 0
        local isMaxLevel = (level >= 90)
        local xpDisabled = charData.xp and charData.xp.isXPDisabled

        if isMaxLevel then
            local levelText = OneWoW_GUI:CreateFS(levelContainer, 16)
            levelText:SetPoint("CENTER")
            levelText:SetText(L["LEVEL_MAX"])
            levelText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        else
            local iconTexture = levelContainer:CreateTexture(nil, "ARTWORK")
            iconTexture:SetSize(10, 10)
            iconTexture:SetPoint("LEFT", levelContainer, "LEFT", 3, 0)

            if xpDisabled then
                iconTexture:SetAtlas("transmog-icon-invalid")
                iconTexture:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            else
                iconTexture:SetAtlas("common-icon-checkmark")
                iconTexture:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            end

            local levelText = OneWoW_GUI:CreateFS(levelContainer, 12)
            levelText:SetPoint("LEFT", iconTexture, "RIGHT", 2, 0)
            levelText:SetText(tostring(level))
            levelText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        levelContainer:EnableMouse(true)
        levelContainer:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["COL_LEVEL"], 1, 1, 1)

            if isMaxLevel then
                GameTooltip:AddLine(L["TT_LEVEL_XP_ENABLED"], 0.5, 1, 0.5)
            elseif xpDisabled then
                GameTooltip:AddLine(L["TT_LEVEL_XP_DISABLED"], 1, 0.5, 0.5)
            else
                GameTooltip:AddLine(L["TT_LEVEL_XP_ENABLED"], 0.5, 1, 0.5)
            end

            GameTooltip:Show()
        end)
        levelContainer:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        table.insert(charRow.cells, levelContainer)

        local classText = OneWoW_GUI:CreateFS(charRow, 12)
        classText:SetText(ns.AltTrackerFormatters:GetCompactClassName(charData.class or charData.className or ""))
        classText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        classText:SetJustifyH("LEFT")
        table.insert(charRow.cells, classText)

        local specText = OneWoW_GUI:CreateFS(charRow, 12)
        local specName = (charData.stats and charData.stats.specName) or ""
        specText:SetText(tostring(specName or ""))
        specText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        specText:SetJustifyH("LEFT")

        local specFrame = CreateFrame("Frame", nil, charRow)
        specFrame:SetAllPoints(specText)
        specFrame:EnableMouse(true)
        specFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tostring(specName or ""), 1, 1, 1)

            if charData.stats and charData.stats.specRole then
                local roleText = charData.stats.specRole
                if roleText == "TANK" then
                    GameTooltip:AddLine(L["TT_SPEC_ROLE"] .. " " .. TANK, 0.5, 0.8, 1)
                elseif roleText == "HEALER" then
                    GameTooltip:AddLine(L["TT_SPEC_ROLE"] .. " " .. HEALER, 0.3, 1, 0.3)
                elseif roleText == "DAMAGER" then
                    GameTooltip:AddLine(L["TT_SPEC_ROLE"] .. " " .. L["TT_SPEC_ROLE_DAMAGER"], 1, 0.5, 0.5)
                end
            end

            if charData.stats and charData.stats.heroSpecName then
                GameTooltip:AddLine(L["TT_SPEC_HERO_SPEC"] .. " " .. charData.stats.heroSpecName, 0.9, 0.8, 0.5)
            else
                GameTooltip:AddLine(L["TT_SPEC_NO_HERO"], 0.5, 0.5, 0.5)
            end

            GameTooltip:Show()
        end)
        specFrame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        table.insert(charRow.cells, specText)

        local restedText = OneWoW_GUI:CreateFS(charRow, 12)
        local restedPercent = 0
        local Fmt = ns.AltTrackerFormatters
        if Fmt and charData.xp and charData.xp.maxXP and charData.xp.maxXP > 0 then
            local estimatedRested = Fmt:EstimateRestedXP(charData, charKey)
            restedPercent = math.floor((estimatedRested / charData.xp.maxXP) * 100)
            local race = charData.race or charData.raceName or ""
            local maxPercent = (race == "Pandaren") and 300 or 150
            restedPercent = math.min(restedPercent, maxPercent)
        end
        restedText:SetText(restedPercent .. "%")
        if restedPercent >= 150 then
            restedText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        elseif restedPercent >= 60 then
            restedText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
        elseif restedPercent >= 30 then
            restedText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        else
            restedText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
        end

        local restedFrame = CreateFrame("Frame", nil, charRow)
        restedFrame:SetAllPoints(restedText)
        restedFrame:EnableMouse(true)
        restedFrame:SetScript("OnEnter", function(self)
            local ttLevel = charData.level or 0
            local ttIsMaxLevel = (ttLevel >= 90)
            local ttFmt = ns.AltTrackerFormatters

            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["COL_RESTED_XP"], 1, 1, 1)

            if not ttIsMaxLevel and charData.xp and charData.xp.currentXP ~= nil and charData.xp.maxXP and charData.xp.maxXP > 0 then
                local currentXP = charData.xp.currentXP or 0
                local xpPercent = (currentXP / charData.xp.maxXP) * 100
                local xpNeeded = charData.xp.maxXP - currentXP
                GameTooltip:AddLine(L["TT_RESTED_XP_TO_LEVEL"] .. " " .. string.format("%.1f%%  (%s XP needed)", xpPercent, BreakUpLargeNumbers(xpNeeded)), 1, 1, 1)
            end

            if ttFmt and charData.xp and charData.xp.maxXP and charData.xp.maxXP > 0 then
                local estimatedRested = ttFmt:EstimateRestedXP(charData, charKey)
                local savedRested = charData.xp.restedXP or 0
                local race = charData.race or charData.raceName or ""
                local maxRestedXP = charData.xp.maxXP * ((race == "Pandaren") and 3 or 1.5)

                GameTooltip:AddLine(L["TT_RESTED_AMOUNT"] .. " " .. BreakUpLargeNumbers(math.floor(estimatedRested)) .. " / " .. BreakUpLargeNumbers(math.floor(maxRestedXP)), 0, 0.74, 0.83)

                if math.floor(estimatedRested) > math.floor(savedRested) then
                    local gained = math.floor(estimatedRested - savedRested)
                    GameTooltip:AddLine("+" .. BreakUpLargeNumbers(gained) .. " XP earned while offline", 0.5, 0.8, 1)
                end

                if estimatedRested >= maxRestedXP then
                    GameTooltip:AddLine("Fully Rested", 0.3, 1, 0.3)
                else
                    local xpRemaining = maxRestedXP - estimatedRested
                    local oneXPBubble = charData.xp.maxXP / 20
                    local bubblesNeeded = xpRemaining / oneXPBubble
                    local secondsRemaining
                    if charData.xp.isResting then
                        secondsRemaining = bubblesNeeded * 28800
                    else
                        secondsRemaining = bubblesNeeded * 28800 * 4
                    end
                    local daysLeft = math.floor(secondsRemaining / 86400)
                    local hoursLeft = math.floor((secondsRemaining % 86400) / 3600)
                    GameTooltip:AddLine("Fully rested in: " .. daysLeft .. "d " .. hoursLeft .. "h", 0.8, 0.8, 0.8)
                end
            elseif charData.xp and charData.xp.restedXP then
                GameTooltip:AddLine(L["TT_RESTED_AMOUNT"] .. " " .. tostring(charData.xp.restedXP), 0, 0.74, 0.83)
            end

            if charData.xp and charData.xp.restState then
                if charData.xp.restState == 1 then
                    GameTooltip:AddLine(L["TT_RESTED_STATE_RESTED"], 0.5, 1, 0.5)
                else
                    GameTooltip:AddLine(L["TT_RESTED_STATE_NORMAL"], 0.7, 0.7, 0.7)
                end
            end

            if charData.xp and charData.xp.isResting then
                GameTooltip:AddLine(L["TT_RESTED_IN_REST_AREA"], 0.5, 1, 0.5)
            else
                GameTooltip:AddLine(L["TT_RESTED_NOT_IN_REST_AREA"], 0.7, 0.7, 0.7)
            end

            GameTooltip:Show()
        end)
        restedFrame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        table.insert(charRow.cells, restedText)

        local ilvlText = OneWoW_GUI:CreateFS(charRow, 12)
        local ilvl = charData.itemLevel or 0
        ilvlText:SetText(tostring(ilvl))
        if charData.itemLevelColor then
            ilvlText:SetTextColor(charData.itemLevelColor.r, charData.itemLevelColor.g, charData.itemLevelColor.b)
        else
            ilvlText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
        table.insert(charRow.cells, ilvlText)

        local bagsText = OneWoW_GUI:CreateFS(charRow, 12)
        local bagsFree, bagsTotal = 0, 0
        if OneWoW_AltTracker_Storage_API then
            local bagsData = OneWoW_AltTracker_Storage_API.GetBags(charKey)
            if bagsData then
                for bagID = 0, 4 do
                    if bagsData[bagID] then
                        local numSlots = bagsData[bagID].numSlots or 0
                        bagsTotal = bagsTotal + numSlots

                        local usedSlots = 0
                        if bagsData[bagID].slots then
                            for _, itemData in pairs(bagsData[bagID].slots) do
                                if itemData then
                                    usedSlots = usedSlots + 1
                                end
                            end
                        end
                        bagsFree = bagsFree + (numSlots - usedSlots)
                    end
                end
            end
        end
        bagsText:SetText(bagsFree)
        bagsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        table.insert(charRow.cells, bagsText)

        local goldContainer = CreateFrame("Frame", nil, charRow)
        goldContainer:SetHeight(rowHeight)
        goldContainer:EnableMouse(true)

        local wallet = charData.money or 0
        local transit = GetInTransitGold(charKey)
        local virtual = wallet + transit

        local goldDot = goldContainer:CreateTexture(nil, "ARTWORK")
        goldDot:SetSize(6, 6)
        goldDot:SetPoint("RIGHT", goldContainer, "RIGHT", -1, 0)
        goldDot:SetTexture("Interface\\Buttons\\WHITE8x8")
        goldDot:SetVertexColor(1.00, 0.82, 0.10, 1)
        if transit > 0 then
            goldDot:Show()
        else
            goldDot:Hide()
        end

        local goldText = OneWoW_GUI:CreateFS(goldContainer, 12)
        OneWoW_GUI:ApplyFontCapped(goldText, 12, 2)
        goldText:SetText(FormatGoldAmount(wallet))
        goldText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        goldText:SetJustifyH("RIGHT")
        if transit > 0 then
            goldText:SetPoint("RIGHT", goldDot, "LEFT", -4, 0)
        else
            goldText:SetPoint("RIGHT", goldContainer, "RIGHT", -1, 0)
        end

        goldContainer:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["TT_COL_GOLD"], 1, 0.82, 0)
            GameTooltip:AddDoubleLine(L["TT_COL_GOLD_WALLET"], FormatGoldAmount(wallet), 0.8, 0.8, 0.8, 1, 0.82, 0)
            GameTooltip:AddDoubleLine(L["TT_COL_GOLD_IN_TRANSIT"], FormatGoldAmount(transit), 0.8, 0.8, 0.8, 1, 0.82, 0)
            GameTooltip:AddDoubleLine(L["TT_COL_GOLD_VIRTUAL"], FormatGoldAmount(virtual), 0.8, 0.8, 0.8, 1, 0.82, 0)
            GameTooltip:Show()
        end)
        goldContainer:SetScript("OnLeave", GameTooltip_Hide)

        table.insert(charRow.cells, goldContainer)

        local hearthContainer = CreateFrame("Frame", nil, charRow)
        hearthContainer:SetSize(80, rowHeight)

        local hearthText = OneWoW_GUI:CreateFS(hearthContainer, 12)
        hearthText:SetPoint("LEFT")
        hearthText:SetJustifyH("LEFT")
        local hearthLocation = (charData.location and charData.location.bindLocation) or ""
        hearthText:SetText(hearthLocation)

        local hearthMapID = charData.location and charData.location.hearthMapID
        if hearthMapID then
            hearthText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

            local hearthX = charData.location.hearthX
            local hearthY = charData.location.hearthY

            hearthContainer:EnableMouse(true)
            hearthContainer:SetScript("OnMouseUp", function()
                Location.SetWaypoint(hearthMapID, hearthX, hearthY, {
                    format = "fraction",
                    openMap = true,
                    title = hearthLocation,
                })
            end)
            hearthContainer:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(hearthLocation, OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                local mapInfo = C_Map.GetMapInfo(hearthMapID)
                if mapInfo then
                    GameTooltip:AddLine(mapInfo.name, OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                end
                GameTooltip:AddLine(L["TT_HEARTH_CLICK_MAP"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                GameTooltip:Show()
            end)
            hearthContainer:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        else
            hearthText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        table.insert(charRow.cells, hearthContainer)

        local lastSeenContainer = CreateFrame("Frame", nil, charRow)
        lastSeenContainer:SetSize(80, rowHeight)

        local lastSeenText = OneWoW_GUI:CreateFS(lastSeenContainer, 12)
        lastSeenText:SetPoint("CENTER")

        local lastLogin = charData.lastLogin or 0
        local currentTime = time()
        local timeDiff = currentTime - lastLogin
        local lastSeenFormatted = ""

        if charKey == currentCharKey then
            lastSeenFormatted = L["FMT_NOW"]
            lastSeenText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        elseif timeDiff < 60 then
            lastSeenFormatted = "1" .. L["FMT_MINUTE_SHORT"]
            lastSeenText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        elseif timeDiff < 3600 then
            local minutes = math.floor(timeDiff / 60)
            lastSeenFormatted = tostring(minutes) .. L["FMT_MINUTE_SHORT"]
            lastSeenText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            local years = math.floor(timeDiff / 31536000)
            local days = math.floor((timeDiff % 31536000) / 86400)
            local hours = math.floor((timeDiff % 86400) / 3600)
            local minutes = math.floor((timeDiff % 3600) / 60)

            if years > 0 then
                lastSeenFormatted = tostring(years) .. L["FMT_YEAR_SHORT"] .. " " .. tostring(days) .. L["FMT_DAY_SHORT"] .. " " .. tostring(hours) .. L["FMT_HOUR_SHORT"] .. " " .. tostring(minutes) .. L["FMT_MINUTE_SHORT"]
            else
                lastSeenFormatted = tostring(days) .. L["FMT_DAY_SHORT"] .. " " .. tostring(hours) .. L["FMT_HOUR_SHORT"] .. " " .. tostring(minutes) .. L["FMT_MINUTE_SHORT"]
            end
            lastSeenText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end

        lastSeenText:SetText(lastSeenFormatted)

        lastSeenContainer:EnableMouse(true)
        lastSeenContainer:SetScript("OnEnter", function(self)
            if lastLogin > 0 then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(date("%Y-%m-%d %H:%M", lastLogin), 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end
        end)
        lastSeenContainer:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        table.insert(charRow.cells, lastSeenContainer)

        if dt and dt.headerRow and dt.headerRow.columnButtons and columnsConfig then
            for i, cell in ipairs(charRow.cells) do
                local btn = dt.headerRow.columnButtons[i]
                if btn and btn.columnWidth and btn.columnX then
                    local width = btn.columnWidth
                    local x = btn.columnX
                    local col = columnsConfig[i]
                    cell:ClearAllPoints()
                    if col and col.align == "icon" then
                        cell:SetSize(width, rowHeight)
                        cell:SetPoint("LEFT", charRow, "LEFT", x, 0)
                    elseif col and col.align == "center" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("CENTER", charRow, "LEFT", x + width / 2, 0)
                    elseif col and col.align == "right" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("RIGHT", charRow, "LEFT", x + width - 3, 0)
                    else
                        cell:SetWidth(width - 6)
                        cell:SetPoint("LEFT", charRow, "LEFT", x + 3, 0)
                    end
                end
            end
        end

        table.insert(characterRows, charRow)
        if dt then dt:RegisterRow(charRow) end
    end

    OneWoW_GUI:LayoutDataRows(scrollContent, { rowHeight = rowHeight, rowGap = rowGap })

    -- First-open hint: auto-expand row 1 the first time this tab renders rows
    -- in the current session so users discover the per-character expand panel.
    -- Per-session only (flag lives on the tab frame, resets on /reload). After
    -- the user collapses or interacts with rows we leave their state alone.
    if not summaryTab._didInitialExpand and characterRows[1] then
        characterRows[1]:Expand()
        summaryTab._didInitialExpand = true
    end

    if summaryTab.statusText then
        summaryTab.statusText:SetText(string.format(L["CHARACTERS_TRACKED"], #allChars, ""))
    end

    ns.UI.RefreshSummaryStats(summaryTab)

    OneWoW_GUI:ApplyFontToFrame(summaryTab)

    C_Timer.After(0.1, function()
        if dt then dt.UpdateColumnLayout() end
    end)
end

function ns.UI.FormatPlaytimeCompact(seconds)
    seconds = tonumber(seconds) or 0
    local totalHours = math.floor(seconds / 3600)
    local days = math.floor(totalHours / 24)
    local years = math.floor(days / 365)
    local remDays = days % 365
    local remHours = totalHours % 24

    if years > 0 then
        return string.format("%dy %dd %dh", years, remDays, remHours)
    elseif days > 0 then
        return string.format("%dd %dh", days, remHours)
    else
        return string.format("%dh", totalHours)
    end
end

function ns.UI.ShowPlaytimeDialog(_)
    if not OneWoW_AltTracker_Character_API then
        return
    end

    local existingFrame = _G["OneWoWPlaytimeDialog"]
    if existingFrame and existingFrame:IsShown() then
        existingFrame:Hide()
        return
    end

    if existingFrame then
        OneWoW_GUI:ApplyFontToFrame(existingFrame)
        existingFrame:Show()
        return
    end

    local classTotals = {}
    local accountTotal = 0

    for _, charData in pairs(OneWoW_AltTracker_Character_API.GetAllCharacters()) do
        if charData.class and charData.playTime and charData.playTime.total then
            local class = charData.class
            classTotals[class] = (classTotals[class] or 0) + charData.playTime.total
            accountTotal = accountTotal + charData.playTime.total
        end
    end

    local sortedClasses = {}
    for class, time in pairs(classTotals) do
        table.insert(sortedClasses, {class = class, time = time})
    end
    table.sort(sortedClasses, function(a, b) return a.time > b.time end)

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoWPlaytimeDialog",
        showBrand = true,
        title = L["PLAYTIME_BY_CLASS"],
        width = 500,
        height = 400,
    })

    local cf = result.contentFrame

    local totalFrame = CreateFrame("Frame", nil, cf)
    totalFrame:SetPoint("BOTTOMLEFT", cf, "BOTTOMLEFT", 0, 0)
    totalFrame:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 0, 0)
    totalFrame:SetHeight(30)

    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(cf, { width = 480 })
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", cf, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -4, 30)

    local rowHeight = 24
    local highestTime = sortedClasses[1] and sortedClasses[1].time or 1

    local yOffset = 0
    for _, classInfo in ipairs(sortedClasses) do
        local classColor = RAID_CLASS_COLORS[classInfo.class] or {r = 1, g = 1, b = 1}
        local barPercent = classInfo.time / highestTime
        local accountPercent = classInfo.time / accountTotal

        local rowFrame = CreateFrame("Frame", nil, scrollContent)
        rowFrame:SetSize(scrollContent:GetWidth() - 20, rowHeight)
        rowFrame:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 10, yOffset)

        local classText = OneWoW_GUI:CreateFS(rowFrame, 12)
        classText:SetPoint("LEFT", 0, 0)
        classText:SetWidth(100)
        classText:SetText(ns.AltTrackerFormatters:GetCompactClassName(classInfo.class))
        classText:SetTextColor(classColor.r, classColor.g, classColor.b)
        classText:SetJustifyH("LEFT")

        local bar = OneWoW_GUI:CreateProgressBar(rowFrame, {
            min = 0,
            max = 1,
            value = barPercent,
            height = rowHeight - 6,
        })
        bar:SetPoint("LEFT", classText, "RIGHT", 8, 0)
        bar:SetPoint("RIGHT", rowFrame, "RIGHT", -160, 0)
        bar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
        bar._text:SetText("")

        local timeText = OneWoW_GUI:CreateFS(rowFrame, 12)
        timeText:SetPoint("LEFT", bar, "RIGHT", 8, 0)
        timeText:SetWidth(150)
        timeText:SetText(string.format("%5.1f%% - %s", accountPercent * 100, ns.UI.FormatPlaytimeCompact(classInfo.time)))
        timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        timeText:SetJustifyH("LEFT")

        rowFrame:EnableMouse(true)
        rowFrame:SetScript("OnEnter", function(self)
            local classChars = {}
            for _, charData in pairs(OneWoW_AltTracker_Character_API.GetAllCharacters()) do
                if charData.class == classInfo.class then
                    table.insert(classChars, charData)
                end
            end
            table.sort(classChars, function(a, b)
                local at = (a.playTime and a.playTime.total) or 0
                local bt = (b.playTime and b.playTime.total) or 0
                return at > bt
            end)
            local className = LOCALIZED_CLASS_NAMES_MALE[classInfo.class] or classInfo.class
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(className .. " - " .. #classChars, classColor.r, classColor.g, classColor.b)
            for rank, charData in ipairs(classChars) do
                local t = (charData.playTime and charData.playTime.total) or 0
                local timeStr = t > 0 and ns.UI.FormatPlaytimeCompact(t) or "-"
                local name = charData.name or charData.realm or "?"
                GameTooltip:AddDoubleLine("#" .. rank .. "  " .. name, timeStr, 1, 1, 1, 0.8, 0.8, 0.8)
            end
            GameTooltip:Show()
        end)
        rowFrame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        yOffset = yOffset - rowHeight
    end

    local totalHeight = math.abs(yOffset) + 10
    scrollContent:SetHeight(totalHeight)

    local totalText = OneWoW_GUI:CreateFS(totalFrame, 16)
    totalText:SetPoint("LEFT", totalFrame, "LEFT", 10, 0)
    totalText:SetText(TOTAL .. ": " .. ns.UI.FormatPlaytimeCompact(accountTotal))
    totalText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    OneWoW_GUI:ApplyFontToFrame(result.frame)

    result.frame:Show()
end

function ns.UI.RefreshSummaryStats(summaryTab)
    if not summaryTab or not summaryTab.statBoxes then return end
    if not OneWoW_AltTracker_Character_API then
        return
    end

    local stats = {
        attention = nil,
        characters = 0,
        totalGold = 0,
        walletGold = 0,
        transitGold = 0,
        factions = {Alliance = 0, Horde = 0},
        rested = 0,
        playtime = 0,
        mounts = 0,
        pets = 0,
        professions = 0,
        achievements = 0
    }

    local allChars = {}
    for charKey, charData in pairs(OneWoW_AltTracker_Character_API.GetAllCharacters()) do
        table.insert(allChars, {
            key = charKey,
            data = charData
        })
    end
    stats.characters = #allChars

    for _, charInfo in ipairs(allChars) do
        local charKey = charInfo.key
        local charData = charInfo.data

        local wallet = charData.money or 0
        local transit = GetInTransitGold(charKey)
        stats.walletGold = stats.walletGold + wallet
        stats.transitGold = stats.transitGold + transit
        stats.totalGold = stats.totalGold + wallet + transit

        if charData.faction then
            if charData.faction == "Alliance" then
                stats.factions.Alliance = stats.factions.Alliance + 1
            elseif charData.faction == "Horde" then
                stats.factions.Horde = stats.factions.Horde + 1
            end
        end

        local sFmt = ns.AltTrackerFormatters
        if sFmt and charData.xp and charData.xp.maxXP and charData.xp.maxXP > 0 then
            local estRested = sFmt:EstimateRestedXP(charData, charKey)
            if estRested > 0 then
                stats.rested = stats.rested + 1
            end
        elseif charData.xp and charData.xp.restedXP and charData.xp.restedXP > 0 then
            stats.rested = stats.rested + 1
        end

        if charData.playTime and charData.playTime.total then
            stats.playtime = stats.playtime + charData.playTime.total
        end
    end

    local uniquePets = {}
    local uniqueMounts = {}
    if OneWoW_AltTracker_Collections_API then
        for _, collData in pairs(OneWoW_AltTracker_Collections_API.GetAllCharacters()) do
            if collData.petsMounts then
                if collData.petsMounts.pets and collData.petsMounts.pets.collection then
                    for _, pet in ipairs(collData.petsMounts.pets.collection) do
                        if pet.petID then
                            uniquePets[pet.petID] = true
                        end
                    end
                end
                if collData.petsMounts.mounts and collData.petsMounts.mounts.collection then
                    for _, mount in ipairs(collData.petsMounts.mounts.collection) do
                        if mount.mountID then
                            uniqueMounts[mount.mountID] = true
                        end
                    end
                end
            end

            if collData.achievements and collData.achievements.totalPoints then
                stats.achievements = math.max(stats.achievements, collData.achievements.totalPoints)
            end
        end
    end

    for _ in pairs(uniquePets) do
        stats.pets = stats.pets + 1
    end
    for _ in pairs(uniqueMounts) do
        stats.mounts = stats.mounts + 1
    end

    if OneWoW_AltTracker_Professions_API then
        local uniquePrimaryProfs = {}
        for _, profData in pairs(OneWoW_AltTracker_Professions_API.GetAllCharacters()) do
            local profs = profData.professions
            if profs then
                if profs.Primary1 and profs.Primary1.name then
                    uniquePrimaryProfs[profs.Primary1.name] = true
                end
                if profs.Primary2 and profs.Primary2.name then
                    uniquePrimaryProfs[profs.Primary2.name] = true
                end
            end
        end
        for _ in pairs(uniquePrimaryProfs) do
            stats.professions = stats.professions + 1
        end
    end

    local statBoxes = summaryTab.statBoxes
    if statBoxes then
        if statBoxes[1] then statBoxes[1].value:SetText(stats.attention or "-") end
        if statBoxes[2] then statBoxes[2].value:SetText(tostring(stats.characters)) end
        if statBoxes[3] then
            local goldFormatted = FormatGoldAmount(stats.totalGold)
            statBoxes[3].value:SetText(goldFormatted)

            statBoxes[3]:SetScript("OnEnter", function(self)
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                local warbandGold = 0
                if OneWoW_AltTracker_Storage_API then
                    warbandGold = OneWoW_AltTracker_Storage_API.GetWarbandBankGold() or 0
                end
                local grandTotal = stats.totalGold + warbandGold
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["GOLD_TOTAL"] .. ": " .. FormatGoldAmount(grandTotal), 1, 0.82, 0)
                GameTooltip:AddLine("----------------------------", 0.4, 0.4, 0.4)
                GameTooltip:AddDoubleLine(L["TT_GOLD_CHARS_LABEL"], FormatGoldAmount(stats.walletGold), 0.8, 0.8, 0.8, 1, 0.82, 0)
                GameTooltip:AddDoubleLine(L["TT_GOLD_WARBAND_LABEL"], FormatGoldAmount(warbandGold), 0.8, 0.8, 0.8, 1, 0.82, 0)
                GameTooltip:AddDoubleLine(L["TT_GOLD_IN_TRANSIT_LABEL"], FormatGoldAmount(stats.transitGold), 0.8, 0.8, 0.8, 1, 0.82, 0)
                GameTooltip:Show()
            end)
            statBoxes[3]:SetScript("OnLeave", function(self)
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                GameTooltip:Hide()
            end)
        end
        if statBoxes[4] then
            local allianceTexture = ns.AltTrackerFormatters and ns.AltTrackerFormatters:GetFactionTexture("Alliance", 14) or ""
            local hordeTexture = ns.AltTrackerFormatters and ns.AltTrackerFormatters:GetFactionTexture("Horde", 14) or ""
            statBoxes[4].value:SetText(stats.factions.Alliance .. allianceTexture .. " - " .. hordeTexture .. stats.factions.Horde)
        end
        if statBoxes[5] then statBoxes[5].value:SetText(tostring(stats.rested)) end
        if statBoxes[6] then
            local playtimeFormatted = ns.UI.FormatPlaytimeCompact(stats.playtime)
            statBoxes[6].value:SetText(playtimeFormatted)
            statBoxes[6]:EnableMouse(true)
            statBoxes[6]:SetScript("OnEnter", function(self)
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["PLAYTIME"], 1, 1, 1)
                GameTooltip:AddLine(L["TT_PLAYTIME_DESC"], nil, nil, nil, true)
                GameTooltip:AddLine(L["TT_PLAYTIME_CLICK"], 0.5, 0.8, 1, true)
                GameTooltip:Show()
            end)
            statBoxes[6]:SetScript("OnLeave", function(self)
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                GameTooltip:Hide()
            end)
            statBoxes[6]:SetScript("OnMouseUp", function()
                if ns.UI.ShowPlaytimeDialog then
                    ns.UI.ShowPlaytimeDialog(stats)
                end
            end)
        end
        if statBoxes[7] then statBoxes[7].value:SetText(tostring(stats.mounts)) end
        if statBoxes[8] then statBoxes[8].value:SetText(tostring(stats.pets)) end
        if statBoxes[9] then
            local primaryTotal = (ns.ProfessionData and ns.ProfessionData.PRIMARY_PROFESSIONS and #ns.ProfessionData.PRIMARY_PROFESSIONS) or 11
            statBoxes[9].value:SetText(stats.professions .. "/" .. primaryTotal)
        end
        if statBoxes[10] then statBoxes[10].value:SetText(tostring(stats.achievements)) end
    end
end
