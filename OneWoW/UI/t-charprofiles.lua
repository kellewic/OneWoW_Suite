local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local MAX_ACCOUNT_MACROS = Constants.MacroConsts.MAX_ACCOUNT_MACROS
local MAX_CHARACTER_MACROS = Constants.MacroConsts.MAX_CHARACTER_MACROS

local UI = ns.UI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local function GetCharProfiles()
    return ns.db.global.charProfiles
end

-- ============================================================
-- Backend
-- ============================================================

ns.CharProfiles = {}
local Module = ns.CharProfiles

function Module:CaptureKeybinds()
    local bindings = {}
    for i = 1, GetNumBindings() do
        local command, _, key1, key2 = GetBinding(i)
        if command and (key1 or key2) then
            table.insert(bindings, { command = command, key1 = key1, key2 = key2 })
        end
    end
    return { bindings = bindings, count = #bindings, capturedAt = time() }
end

function Module:CaptureMacros()
    local account = {}
    local accountCount = 0
    for i = 1, MAX_ACCOUNT_MACROS do
        local name, iconTexture, body = GetMacroInfo(i)
        if name then
            local macroIcon
            if type(iconTexture) == "number" then
                macroIcon = iconTexture
            elseif type(iconTexture) == "string" then
                macroIcon = iconTexture:gsub("^Interface\\Icons\\", "")
            else
                macroIcon = "INV_Misc_QuestionMark"
            end
            account[i] = { id = i, name = name, icon = macroIcon, body = body }
            accountCount = accountCount + 1
        end
    end

    local character = {}
    local charCount = 0
    for i = MAX_ACCOUNT_MACROS + 1, MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS do
        local name, iconTexture, body = GetMacroInfo(i)
        if name then
            local macroIcon
            if type(iconTexture) == "number" then
                macroIcon = iconTexture
            elseif type(iconTexture) == "string" then
                macroIcon = iconTexture:gsub("^Interface\\Icons\\", "")
            else
                macroIcon = "INV_Misc_QuestionMark"
            end
            character[i] = { id = i, name = name, icon = macroIcon, body = body }
            charCount = charCount + 1
        end
    end

    return {
        account = account,
        character = character,
        accountCount = accountCount,
        charCount = charCount,
        capturedAt = time(),
    }
end

function Module:CaptureGameSettings()
    if not ConsoleGetAllCommands or not GetCVar then return nil end
    local commands = ConsoleGetAllCommands()
    if not commands then return nil end
    local cvars = {}
    local count = 0
    for _, cmdInfo in ipairs(commands) do
        if cmdInfo.commandType == 0 and cmdInfo.command then
            local value = GetCVar(cmdInfo.command)
            if value ~= nil then
                cvars[cmdInfo.command] = value
                count = count + 1
            end
        end
    end
    if count == 0 then return nil end
    return { cvars = cvars, count = count, capturedAt = time() }
end

function Module:CaptureAddonSet()
    if not C_AddOns then return nil end
    local addons = {}
    local total = C_AddOns.GetNumAddOns()
    local charName = UnitName("player")
    for i = 1, total do
        local name, title = C_AddOns.GetAddOnInfo(i)
        if name then
            local state = C_AddOns.GetAddOnEnableState(name, charName)
            table.insert(addons, { name = name, title = title or name, enabled = (state == 2) })
        end
    end
    return { addons = addons, count = #addons, capturedAt = time() }
end

local ADDON_SETTINGS_MAP = {
    {
        dbName = "OneWoW_DB",
        displayName = "OneWoW",
        globalWrap = true,
        keys = {"language", "theme", "minimap", "mainFrameSize", "mainFramePosition", "portalHub", "settings", "searchCatalog"},
    },
    {
        dbName = "OneWoW_AltTracker_DB",
        displayName = "AltTracker",
        acedb = true,
        keys = {"language", "theme", "minimap", "mainFrameSize", "mainFramePosition", "altTrackerSettings", "overrides", "favorites", "seasonChecklist"},
    },
    {
        dbName = "OneWoW_QoL_DB",
        displayName = "QoL",
        acedb = true,
        keys = {"language", "theme", "lastTab", "minimap", "modules"},
    },
    {
        dbName = "OneWoW_Notes_DB",
        displayName = "Notes",
        acedb = true,
        keys = {"language", "theme", "minimap", "lastTab", "mainFrameSize", "mainFramePosition", "sortCompletedTasks", "zoneAlertsEnabled", "npcScanEnabled", "playerScanEnabled", "pinnedScale"},
    },
    {
        dbName = "OneWoW_Catalog_DB",
        displayName = "Catalog",
        acedb = true,
        keys = {"language", "theme", "lastTab", "minimap", "mainFrameSize", "mainFramePosition"},
    },
    {
        dbName = "OneWoW_Bags_DB",
        displayName = "Bags",
        keys = {"language", "theme", "minimap", "viewMode", "columns", "bagScale", "bankScale", "warbandBankScale", "guildBankScale", "iconSize", "autoOpen", "autoClose", "locked", "showBagsBar", "showNewItems", "recentItemDuration", "categorySort", "showEmptySlots"},
    },
    {
        dbName = "OneWoW_DirectDeposit_DB",
        displayName = "DirectDeposit",
        keys = {"language", "theme", "minimap", "directDeposit"},
    },
    {
        dbName = "OneWoW_ShoppingList_DB",
        displayName = "ShoppingList",
        globalWrap = true,
        keys = {"settings", "minimap"},
    },
    {
        dbName = "OneWoW_AltTracker_Character_DB",
        displayName = "AltTracker Character",
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_AltTracker_Accounting_DB",
        displayName = "AltTracker Accounting",
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_AltTracker_Auctions_DB",
        displayName = "AltTracker Auctions",
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_AltTracker_Professions_DB",
        displayName = "AltTracker Professions",
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_AltTracker_Collections_DB",
        displayName = "AltTracker Collections",
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_AltTracker_Endgame_DB",
        displayName = "AltTracker Endgame",
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_AltTracker_Storage_DB",
        displayName = "AltTracker Storage",
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_CatDB_ZoneDB_DB",
        displayName = "CatDB Places",
        acedb = true,
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_CatDB_TradeSkillDB_DB",
        displayName = "CatDB TradeSkillDB",
        acedb = true,
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_CatDB_NPCDB_DB",
        displayName = "CatDB NPCs",
        acedb = true,
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_CatDB_QuestDBCurrent_DB",
        displayName = "CatDB Quests",
        acedb = true,
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_CatDB_ItemDB_DB",
        displayName = "CatDB Items",
        acedb = true,
        keys = {"settings"},
    },
}

local SETTINGS_MAP_BY_DBNAME = {}
for _, entry in ipairs(ADDON_SETTINGS_MAP) do
    SETTINGS_MAP_BY_DBNAME[entry.dbName] = entry
end

function Module:CaptureAddonSettings()
    local captured = {}
    local count = 0
    for _, entry in ipairs(ADDON_SETTINGS_MAP) do
        local db = _G[entry.dbName]
        if db then
            local source = db
            if (entry.acedb or entry.globalWrap) and type(db.global) == "table" then
                source = db.global
            end
            local settings = {}
            local hasData = false
            for _, key in ipairs(entry.keys) do
                if source[key] ~= nil then
                    if type(source[key]) == "table" then
                        settings[key] = CopyTable(source[key])
                    else
                        settings[key] = source[key]
                    end
                    hasData = true
                end
            end
            if hasData then
                captured[entry.dbName] = {
                    displayName = entry.displayName,
                    acedb = entry.acedb or false,
                    globalWrap = entry.globalWrap or false,
                    settings = settings,
                }
                count = count + 1
            end
        end
    end
    return { addons = captured, count = count, capturedAt = time() }
end

function Module:RestoreKeybinds(keybindData)
    if not keybindData or not keybindData.bindings then return 0 end
    LoadBindings(2)
    local count = 0
    for _, bindData in ipairs(keybindData.bindings) do
        if bindData.key1 then
            local ctx = C_KeyBindings.GetBindingContextForAction(bindData.command) or 1
            SetBinding(bindData.key1, bindData.command, ctx)
        end
        if bindData.key2 then
            local ctx = C_KeyBindings.GetBindingContextForAction(bindData.command) or 1
            SetBinding(bindData.key2, bindData.command, ctx)
        end
        count = count + 1
    end
    SaveBindings(2)
    return count
end

function Module:RestoreMacros(macroData, doAccount, doCharacter)
    if not macroData then return 0 end
    local count = 0

    local function FindOrCreate(macroInfo, isChar)
        if not macroInfo or not macroInfo.name then return end
        local existing = GetMacroIndexByName(macroInfo.name)
        if existing and existing > 0 then
            count = count + 1
            return
        end
        local numGlobal, numPerChar = GetNumMacros()
        local canCreate = isChar and (numPerChar < MAX_CHARACTER_MACROS) or (numGlobal < MAX_ACCOUNT_MACROS)
        if canCreate then
            local icon = macroInfo.icon or "INV_Misc_QuestionMark"
            local newId = CreateMacro(macroInfo.name, icon, macroInfo.body or "", isChar)
            if newId then count = count + 1 end
        else
            print(string.format("|cFFFFD100OneWoW:|r Macro limit reached, skipped: %s", macroInfo.name))
        end
    end

    if doAccount and macroData.account then
        for _, macroInfo in pairs(macroData.account) do
            FindOrCreate(macroInfo, false)
        end
    end
    if doCharacter and macroData.character then
        for _, macroInfo in pairs(macroData.character) do
            FindOrCreate(macroInfo, true)
        end
    end
    return count
end

function Module:RestoreGameSettings(gameData)
    if not gameData or not gameData.cvars or not SetCVar then return 0 end
    local count = 0
    for cvarName, value in pairs(gameData.cvars) do
        SetCVar(cvarName, value)
        count = count + 1
    end
    return count
end

function Module:RestoreAddonSet(addonData)
    if not addonData or not addonData.addons or not C_AddOns then return 0 end
    local charName = UnitName("player")
    local count = 0
    for _, addonInfo in ipairs(addonData.addons) do
        if C_AddOns.GetAddOnInfo(addonInfo.name) then
            local currentState = C_AddOns.GetAddOnEnableState(addonInfo.name, charName)
            local isEnabled = (currentState == 2)
            if addonInfo.enabled ~= isEnabled then
                if addonInfo.enabled then
                    C_AddOns.EnableAddOn(addonInfo.name, charName)
                else
                    C_AddOns.DisableAddOn(addonInfo.name, charName)
                end
                count = count + 1
            end
        end
    end
    return count
end

function Module:RestoreAddonSettings(addonData)
    if not addonData or not addonData.addons then return 0 end
    local count = 0
    for dbName, entry in pairs(addonData.addons) do
        local db = _G[dbName]
        if db then
            -- Resolve the wrap flags from the current map, not the snapshot:
            -- a profile captured before a DB changed shape (e.g. a flat root
            -- later gaining a .global subtable) must restore into the DB's
            -- current layout. Snapshot flags only cover dbNames that have
            -- since left the map.
            local mapEntry = SETTINGS_MAP_BY_DBNAME[dbName] or entry
            local target = db
            if (mapEntry.acedb or mapEntry.globalWrap) and type(db.global) == "table" then
                target = db.global
            end
            for key, value in pairs(entry.settings) do
                if type(value) == "table" then
                    target[key] = CopyTable(value)
                else
                    target[key] = value
                end
            end
            count = count + 1
        end
    end
    return count
end

function Module:SaveProfile(name, options)
    if not name or name == "" then
        print("|cFFFFD100OneWoW:|r Profile name cannot be empty.")
        return false
    end

    local profile = { name = name, timestamp = time(), savedBy = OneWoW_GUI:BuildCharKey() }

    if options.keybinds then
        profile.keybinds = self:CaptureKeybinds()
    end
    if options.accountMacros or options.characterMacros then
        local macros = self:CaptureMacros()
        if options.accountMacros then
            profile.accountMacros = { data = macros.account, count = macros.accountCount, capturedAt = macros.capturedAt }
        end
        if options.characterMacros then
            profile.characterMacros = { data = macros.character, count = macros.charCount, capturedAt = macros.capturedAt }
        end
    end
    if options.gameSettings then
        profile.gameSettings = self:CaptureGameSettings()
    end
    if options.addonSet then
        profile.addonSet = self:CaptureAddonSet()
    end
    if options.addonSettings then
        profile.addonSettings = self:CaptureAddonSettings()
    end

    GetCharProfiles()[name] = profile
    print("|cFFFFD100OneWoW:|r Character profile saved: " .. name)
    return true
end

function Module:DeleteProfile(name)
    local profiles = GetCharProfiles()
    if not profiles[name] then return false end
    profiles[name] = nil
    print("|cFFFFD100OneWoW:|r Character profile deleted: " .. name)
    return true
end

function Module:GetProfilesList()
    local profiles = GetCharProfiles()
    local list = {}
    for name, data in pairs(profiles) do
        if type(data) == "table" and data.name and data.timestamp then
            table.insert(list, { name = name, data = data })
        end
    end
    table.sort(list, function(a, b)
        return (a.data.timestamp or 0) > (b.data.timestamp or 0)
    end)
    return list
end

function Module:GetCurrentCounts()
    local counts = {}
    local bindCount = 0
    for i = 1, GetNumBindings() do
        local cmd, _, k1, k2 = GetBinding(i)
        if cmd and (k1 or k2) then bindCount = bindCount + 1 end
    end
    counts.keybinds = bindCount
    local numGlobal, numPerChar = GetNumMacros()
    counts.accountMacros = numGlobal or 0
    counts.characterMacros = numPerChar or 0
    counts.addonSet = C_AddOns.GetNumAddOns() or 0
    return counts
end

function Module:SerializeProfile(profile)
    local body = UI.SerializeVal(profile, 0)
    if not body then return nil end
    return "-- OneWoW Character Profile\n-- Version: 1\n" .. body
end

function Module:DeserializeProfile(str)
    if not str or str == "" then return nil, "Empty input" end
    local cleaned = str:gsub("%-%-[^\n]*\n?", "")
    local func = loadstring("return " .. cleaned)
    if not func then return nil, "Parse error" end
    local ok, data = pcall(func)
    if not ok then return nil, "Execution error" end
    if type(data) ~= "table" then return nil, "Invalid format" end
    if type(data.name) ~= "string" or data.name == "" then return nil, "Missing profile name" end
    return data, nil
end

function Module:ImportProfile(str)
    local data, err = self:DeserializeProfile(str)
    if not data then return false, err end
    local profiles = GetCharProfiles()
    local name = data.name
    if profiles[name] then
        local base = name
        local i = 2
        while profiles[name] do
            name = base .. " (" .. i .. ")"
            i = i + 1
        end
        data.name = name
    end
    data.timestamp = data.timestamp or time()
    profiles[name] = data
    return true, name
end

-- ============================================================
-- Dialogs
-- ============================================================

function UI:ShowCharProfileRestoreDialog(profileName, profile, onRestored)
    local restoreChecks = {}
    local yOff = -10

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_CharProfileRestoreDialog",
        title = "Restore Profile: |cFFFFD100" .. profileName .. "|r",
        width = 480,
        height = 360,
        strata = "FULLSCREEN_DIALOG",
        showBrand = true,
        buttons = {
            { text = "Restore Profile", onClick = function(dialog)
                local M = ns.CharProfiles
                local results = {}
                local reloadNeeded = false

                if restoreChecks.keybinds and restoreChecks.keybinds:GetChecked() then
                    local n = M:RestoreKeybinds(profile.keybinds)
                    table.insert(results, string.format("%d Keybinds", n))
                end

                if restoreChecks.accountMacros and restoreChecks.accountMacros:GetChecked() then
                    local n = M:RestoreMacros(
                        { account = type(profile.accountMacros) == "table" and profile.accountMacros.data or {} },
                        true, false)
                    table.insert(results, string.format("%d Account Macros", n))
                end

                if restoreChecks.characterMacros and restoreChecks.characterMacros:GetChecked() then
                    local n = M:RestoreMacros(
                        { character = type(profile.characterMacros) == "table" and profile.characterMacros.data or {} },
                        false, true)
                    table.insert(results, string.format("%d Character Macros", n))
                end

                if restoreChecks.gameSettings and restoreChecks.gameSettings:GetChecked() then
                    local n = M:RestoreGameSettings(profile.gameSettings)
                    table.insert(results, string.format("%d Game Settings", n))
                    reloadNeeded = true
                end

                if restoreChecks.addonSet and restoreChecks.addonSet:GetChecked() then
                    local n = M:RestoreAddonSet(profile.addonSet)
                    table.insert(results, string.format("%d changes to Addon Set", n))
                    reloadNeeded = true
                end

                if restoreChecks.addonSettings and restoreChecks.addonSettings:GetChecked() then
                    local n = M:RestoreAddonSettings(profile.addonSettings)
                    table.insert(results, string.format("%d Addon Settings", n))
                    reloadNeeded = true
                end

                dialog:Hide()

                print(string.format("|cFFFFD100OneWoW:|r Character profile restored: %s", profileName))
                for _, line in ipairs(results) do
                    print("  |cFFFFD100-|r " .. line)
                end

                if reloadNeeded then
                    print("|cFFFFD100OneWoW:|r A UI reload is required to apply changes.")
                    C_Timer.After(1.5, function()
                        local reloadDialog = OneWoW_GUI:CreateConfirmDialog({
                            name    = "OneWoW_CharProfileReloadConfirm",
                            title   = "Reload Required",
                            message = "A UI reload is required to apply restored settings. Reload now?",
                            width   = 420,
                            buttons = {
                                { text = "Reload Now", onClick = function(d) d:Hide(); ReloadUI() end },
                                { text = "Later",      onClick = function(d) d:Hide() end },
                            },
                        })
                        reloadDialog.frame:Show()
                    end)
                end

                if onRestored then onRestored() end
            end },
            { text = "Cancel", onClick = function(dialog) dialog:Hide() end },
        },
    })

    local cf = result.contentFrame

    local savedDate = OneWoW_GUI:CreateFS(cf, 10)
    savedDate:SetPoint("TOPLEFT", cf, "TOPLEFT", 10, yOff)
    savedDate:SetText("Saved: " .. date("%Y-%m-%d %H:%M", profile.timestamp or 0))
    savedDate:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOff = yOff - 18

    if profile.savedBy then
        local savedByFS = OneWoW_GUI:CreateFS(cf, 10)
        savedByFS:SetPoint("TOPLEFT", savedDate, "BOTTOMLEFT", 0, -4)
        savedByFS:SetText("Saved by: |cFFFFD100" .. profile.savedBy .. "|r")
        savedByFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        yOff = yOff - 18
    end

    local selectLabel = OneWoW_GUI:CreateFS(cf, 12)
    selectLabel:SetPoint("TOPLEFT", cf, "TOPLEFT", 10, yOff - 10)
    selectLabel:SetText("Select what to restore:")
    selectLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOff = yOff - 28

    local function AddRestoreRow(key, labelText, count, available)
        if not available then return end
        local cb = OneWoW_GUI:CreateCheckbox(cf, { label = "" })
        cb:SetPoint("TOPLEFT", cf, "TOPLEFT", 10, yOff)
        cb:SetChecked(true)
        local display = count and count > 0
            and (labelText .. " |cFF888888(" .. count .. ")|r")
            or labelText
        if cb.label then cb.label:SetText(display) end
        restoreChecks[key] = cb
        yOff = yOff - 30
    end

    AddRestoreRow("keybinds",
        "Keybinds",
        type(profile.keybinds) == "table" and profile.keybinds.count or 0,
        type(profile.keybinds) == "table")

    AddRestoreRow("accountMacros",
        "Account Macros",
        type(profile.accountMacros) == "table" and profile.accountMacros.count or 0,
        type(profile.accountMacros) == "table")

    AddRestoreRow("characterMacros",
        "Character Macros",
        type(profile.characterMacros) == "table" and profile.characterMacros.count or 0,
        type(profile.characterMacros) == "table")

    AddRestoreRow("gameSettings",
        "WoW Game Settings",
        type(profile.gameSettings) == "table" and profile.gameSettings.count or 0,
        type(profile.gameSettings) == "table")

    AddRestoreRow("addonSet",
        "Addon Set",
        type(profile.addonSet) == "table" and profile.addonSet.count or 0,
        type(profile.addonSet) == "table")

    AddRestoreRow("addonSettings",
        "Addon Settings",
        type(profile.addonSettings) == "table" and profile.addonSettings.count or 0,
        type(profile.addonSettings) == "table")

    result.frame:SetHeight(math.abs(yOff) + 28 + 10 + 10 + 28 + 10)
    result.frame:Show()
end

function UI:ShowCharProfileExportDialog(profileName, serializedStr)
    local eb

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_CharProfileExportDialog",
        title = "Export Profile: |cFFFFD100" .. profileName .. "|r",
        width = 620,
        height = 500,
        strata = "FULLSCREEN_DIALOG",
        showBrand = true,
        buttons = {
            { text = "Select All", onClick = function()
                eb:SetFocus()
                eb:HighlightText()
            end },
            { text = "Close", onClick = function(dialog) dialog:Hide() end },
        },
    })

    local cf = result.contentFrame

    local hint = OneWoW_GUI:CreateFS(cf, 10)
    hint:SetPoint("TOPLEFT", cf, "TOPLEFT", 10, -8)
    hint:SetText("Select all text and copy (Ctrl+A, Ctrl+C) to share this profile:")
    hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local textBG = OneWoW_GUI:CreateFrame(cf, { width = 600, height = 420, backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT })
    textBG:ClearAllPoints()
    textBG:SetPoint("TOPLEFT",     cf, "TOPLEFT",     10, -28)
    textBG:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -10, 4)

    eb = UI.CreateScrollableEditBox(textBG, function() result.frame:Hide() end)
    eb:SetAutoFocus(true)

    result.frame:Show()
    C_Timer.After(0, function()
        eb:SetText(serializedStr or "")
        eb:SetCursorPosition(0)
    end)
end

function UI:ShowCharProfileImportDialog(onImported)
    local eb

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_CharProfileImportDialog",
        title = "Import Character Profile",
        width = 620,
        height = 460,
        strata = "FULLSCREEN_DIALOG",
        showBrand = true,
        buttons = {
            { text = "Import", onClick = function(dialog)
                local text = eb:GetText()
                local ok, res = ns.CharProfiles:ImportProfile(text)
                if ok then
                    print(string.format("|cFFFFD100OneWoW:|r Character profile imported: %s", res))
                    dialog:Hide()
                    if onImported then onImported() end
                else
                    print(string.format("|cFFFFD100OneWoW:|r Import failed: %s", res or "unknown error"))
                end
            end },
            { text = "Cancel", onClick = function(dialog) dialog:Hide() end },
        },
    })

    local cf = result.contentFrame

    local hint = OneWoW_GUI:CreateFS(cf, 10)
    hint:SetPoint("TOPLEFT", cf, "TOPLEFT", 10, -8)
    hint:SetText("Paste exported profile data below, then click Import:")
    hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local textBG = OneWoW_GUI:CreateFrame(cf, { width = 600, height = 380, backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT })
    textBG:ClearAllPoints()
    textBG:SetPoint("TOPLEFT",     cf, "TOPLEFT",     10, -28)
    textBG:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -10, 4)

    eb = UI.CreateScrollableEditBox(textBG, function() result.frame:Hide() end)
    eb:SetAutoFocus(true)

    result.frame:Show()
end

-- ============================================================
-- Section UI Builder
-- ============================================================

function UI:CreateCharProfilesPanel(parent, opts)
    opts = opts or {}
    local M = ns.CharProfiles

    local content = opts.content
    local yOffset = opts.yOffset
    if not content then
        _, content = OneWoW_GUI:CreateScrollFrame(parent, { name = "OneWoW_CharProfilesScroll" })
        yOffset = -10
    end

    local descText = OneWoW_GUI:CreateFS(content, 12)
    descText:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    descText:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    descText:SetJustifyH("LEFT")
    descText:SetWordWrap(true)
    descText:SetSpacing(2)
    descText:SetText("Backs up your character's complete setup: keybinds, macros, game settings, enabled addons, and all OneWoW addon data. Export to restore on alts or share with others.")
    descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    yOffset = yOffset - 40

    local newProfileContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    newProfileContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    newProfileContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    newProfileContainer:SetHeight(165)
    newProfileContainer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    newProfileContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    newProfileContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local newTitle = OneWoW_GUI:CreateFS(newProfileContainer, 12)
    newTitle:SetPoint("TOPLEFT", newProfileContainer, "TOPLEFT", 15, -12)
    newTitle:SetText("New Character Profile")
    newTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local nameLabel = OneWoW_GUI:CreateFS(newProfileContainer, 10)
    nameLabel:SetPoint("TOPLEFT", newProfileContainer, "TOPLEFT", 15, -40)
    nameLabel:SetText("Profile Name:")
    nameLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local nameEdit = OneWoW_GUI:CreateEditBox(newProfileContainer, { width = 300, height = 26 })
    nameEdit:SetPoint("TOPLEFT", newProfileContainer, "TOPLEFT", 15, -58)
    nameEdit:SetMaxLetters(64)
    nameEdit:SetAutoFocus(false)

    local counts = M:GetCurrentCounts()

    local COL1_X = 15
    local COL2_X = 230
    local COL3_X = 445

    local function MakeCheckbox(labelText, count, xPos, yPos)
        local cb = OneWoW_GUI:CreateCheckbox(newProfileContainer, { label = "" })
        cb:SetPoint("TOPLEFT", newProfileContainer, "TOPLEFT", xPos, yPos)
        cb:SetChecked(false)
        local display = (count and count > 0) and (labelText .. " (" .. count .. ")") or labelText
        if cb.label then cb.label:SetText(display) end
        return cb
    end

    local cbKeybinds   = MakeCheckbox("Keybinds",         counts.keybinds,        COL1_X, -98)
    local cbAccMacros  = MakeCheckbox("Account Macros",   counts.accountMacros,   COL2_X, -98)
    local cbAddonSet   = MakeCheckbox("Addon Set",         counts.addonSet,        COL3_X, -98)
    local cbGameSet    = MakeCheckbox("Game Settings",     nil,                    COL1_X, -124)
    local cbCharMacro  = MakeCheckbox("Character Macros", counts.characterMacros, COL2_X, -124)
    local cbAddonSett  = MakeCheckbox("Addon Settings",   nil,                    COL3_X, -124)

    local saveBtn = OneWoW_GUI:CreateFitTextButton(newProfileContainer, { text = "Save Profile", height = 28 })
    saveBtn:SetPoint("TOPRIGHT", newProfileContainer, "TOPRIGHT", -15, -55)

    local listContainer = CreateFrame("Frame", nil, content)
    listContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset - 185)
    listContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset - 185)
    listContainer:SetHeight(20)

    local function UpdateScrollHeight()
        local listH = listContainer:GetHeight() or 0
        local height = math.abs(yOffset) + listH + 40
        if opts.onHeightChanged then
            opts.onHeightChanged(height)
        else
            content:SetHeight(height)
        end
    end

    local function RefreshListing()
        for _, child in ipairs({ listContainer:GetChildren() }) do
            child:Hide()
            child:SetParent(nil)
        end
        for _, r in ipairs({ listContainer:GetRegions() }) do r:Hide() end

        local profilesList = M:GetProfilesList()

        if #profilesList == 0 then
            local empty = OneWoW_GUI:CreateFS(listContainer, 12)
            empty:SetPoint("TOPLEFT", 15, -14)
            empty:SetText("No character profiles saved yet")
            empty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            listContainer:SetHeight(40)
            UpdateScrollHeight()
            return
        end

        local CARD_H = 68
        local CARD_GAP = 6
        local yOff = 0

        for _, entry in ipairs(profilesList) do
            local name = entry.name
            local data = entry.data

            local card = CreateFrame("Frame", nil, listContainer, "BackdropTemplate")
            card:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, yOff)
            card:SetPoint("TOPRIGHT", listContainer, "TOPRIGHT", 0, yOff)
            card:SetHeight(CARD_H)
            card:SetBackdrop(BACKDROP_INNER_NO_INSETS)
            card:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

            local nameText = OneWoW_GUI:CreateFS(card, 12)
            nameText:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
            nameText:SetText(name)
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            local dateText = OneWoW_GUI:CreateFS(card, 10)
            dateText:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -26)
            local dateStr = "Saved: " .. date("%Y-%m-%d %H:%M", data.timestamp or 0)
            if data.savedBy then
                dateStr = dateStr .. "  |cFF888888by " .. data.savedBy .. "|r"
            end
            dateText:SetText(dateStr)
            dateText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

            local tags = {}
            if type(data.keybinds) == "table" then
                table.insert(tags, string.format("Keybinds (%d)", data.keybinds.count or 0))
            end
            if type(data.accountMacros) == "table" then
                table.insert(tags, string.format("Acct Macros (%d)", data.accountMacros.count or 0))
            end
            if type(data.characterMacros) == "table" then
                table.insert(tags, string.format("Char Macros (%d)", data.characterMacros.count or 0))
            end
            if type(data.gameSettings) == "table" then
                table.insert(tags, string.format("CVars (%d)", data.gameSettings.count or 0))
            end
            if type(data.addonSet) == "table" then
                table.insert(tags, string.format("Addons (%d)", data.addonSet.count or 0))
            end
            if type(data.addonSettings) == "table" then
                table.insert(tags, string.format("Addon Settings (%d)", data.addonSettings.count or 0))
            end

            local tagsText = OneWoW_GUI:CreateFS(card, 10)
            tagsText:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -44)
            tagsText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -278, -44)
            tagsText:SetText(#tags > 0 and table.concat(tags, "  |cFF444444/|r  ") or "")
            tagsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            tagsText:SetJustifyH("LEFT")

            local exportBtn = OneWoW_GUI:CreateFitTextButton(card, { text = "Export", height = 26 })
            exportBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -192, 6)
            exportBtn:SetScript("OnClick", function()
                local exportData = {}
                for k, v in pairs(data) do
                    if k ~= "gameSettings" and k ~= "addonSettings" then
                        exportData[k] = v
                    end
                end
                local serialized = ns.CharProfiles:SerializeProfile(exportData)
                if serialized then
                    UI:ShowCharProfileExportDialog(name, serialized)
                end
            end)

            local restoreBtn = OneWoW_GUI:CreateFitTextButton(card, { text = "Restore", height = 26 })
            restoreBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -96, 6)
            restoreBtn:SetScript("OnClick", function()
                UI:ShowCharProfileRestoreDialog(name, data, RefreshListing)
            end)

            local capturedName = name
            local deleteBtn = OneWoW_GUI:CreateFitTextButton(card, { text = "Delete", height = 26, danger = true })
            deleteBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, 6)
            deleteBtn:SetScript("OnClick", function()
                local dlg = OneWoW_GUI:CreateConfirmDialog({
                    name    = "OneWoW_CharProfileDeleteConfirm",
                    title   = "Delete Character Profile",
                    message = "Delete character profile: |cFFFFD100" .. capturedName .. "|r?\nThis cannot be undone.",
                    width   = 420,
                    buttons = {
                        { text = "Delete", color = { 0.7, 0.15, 0.15 }, onClick = function(d)
                            d:Hide()
                            M:DeleteProfile(capturedName)
                            RefreshListing()
                        end },
                        { text = "Cancel", onClick = function(d) d:Hide() end },
                    },
                })
                dlg.frame:Show()
            end)

            yOff = yOff - (CARD_H + CARD_GAP)
        end

        listContainer:SetHeight(math.abs(yOff) + CARD_GAP)
        UpdateScrollHeight()
    end

    saveBtn:SetScript("OnClick", function()
        local name = nameEdit:GetText():trim()
        local saveOpts = {
            keybinds        = cbKeybinds:GetChecked()  and true or false,
            accountMacros   = cbAccMacros:GetChecked() and true or false,
            characterMacros = cbCharMacro:GetChecked() and true or false,
            gameSettings    = cbGameSet:GetChecked()   and true or false,
            addonSet        = cbAddonSet:GetChecked()  and true or false,
            addonSettings   = cbAddonSett:GetChecked() and true or false,
        }
        if M:SaveProfile(name, saveOpts) then
            nameEdit:SetText("")
            cbKeybinds:SetChecked(false)
            cbAccMacros:SetChecked(false)
            cbCharMacro:SetChecked(false)
            cbGameSet:SetChecked(false)
            cbAddonSet:SetChecked(false)
            cbAddonSett:SetChecked(false)
            RefreshListing()
        end
    end)

    local savedProfilesHeader = OneWoW_GUI:CreateFS(content, 12)
    savedProfilesHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset - 190)
    savedProfilesHeader:SetText("Saved Character Profiles")
    savedProfilesHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local importBtn = OneWoW_GUI:CreateFitTextButton(content, { text = "Import Profile", height = 24 })
    importBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset - 187)
    importBtn:SetScript("OnClick", function()
        UI:ShowCharProfileImportDialog(RefreshListing)
    end)

    yOffset = yOffset - 230

    listContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    listContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)

    C_Timer.After(0.05, function()
        RefreshListing()
        OneWoW_GUI:ApplyFontToFrame(parent)
        UpdateScrollHeight()
    end)
end
