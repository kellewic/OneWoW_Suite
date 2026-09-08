local _, ns = ...

local UI = ns.UI

local OneWoW_GUI = OneWoW_GUI

local Constants = OneWoW_GUI.Constants
local RESERVED_DEFAULT = "Default"

-- ============================================================
-- Utilities
-- ============================================================

local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = type(v) == "table" and DeepCopy(v) or v
    end
    return dst
end

local function DeepMerge(dst, src)
    if type(src) ~= "table" then return end
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            DeepMerge(dst[k], v)
        else
            dst[k] = v
        end
    end
end

local function SyncSettingToChildAddons(settingType, _)
    local integratedAddons = {
        "OneWoW_AltTracker", "OneWoW_Notes", "OneWoW_QoL",
        "OneWoW_Catalog", "OneWoW_DirectDeposit", "OneWoW_Bags",
        "OneWoW_ShoppingList", "OneWoW_Trackers", "OneWoW_Utility_DevTool",
    }
    -- Themes are applied per child addon (each owns its theme). Language is NOT looped
    -- here: it lives in one central scope-folded view, so the caller applies it once via
    -- ns.Locale:SetLanguage(). (settingType is always "theme" now.)
    for _, globalName in ipairs(integratedAddons) do
        local addon = _G[globalName]
        if addon and settingType == "theme" and addon.ApplyTheme then
            addon:ApplyTheme()
        end
    end
end

-- ============================================================
-- Backend
-- ============================================================

ns.Profiles = {}

function ns.Profiles.CaptureSettings()
    local snapshot = {}

    local g = ns.db.global
    snapshot.core = {
        language  = g.language,
        theme     = g.theme,
        minimap   = DeepCopy(g.minimap),
        featureIcons = DeepCopy(g.featureIcons),
        settings  = DeepCopy(g.settings),
        portalHub = DeepCopy(g.portalHub),
        searchCatalog = DeepCopy(g.searchCatalog),
    }

    if OneWoW_QoL_API then
        snapshot.qol = OneWoW_QoL_API.CaptureProfileSettings()
    end

    snapshot.cvars = {}
    if OneWoW_QoL_API and OneWoW_QoL_API.GetCVarList then
        local cvarList = OneWoW_QoL_API.GetCVarList()
        if cvarList then
            for _, entry in ipairs(cvarList) do
                local val = C_CVar.GetCVar(entry.cvar)
                if val then snapshot.cvars[entry.cvar] = val end
            end
        end
    end

    return snapshot
end

function ns.Profiles.ApplySettings(snapshot, profileName)
    if not snapshot then return end

    if snapshot.core then
        local g = ns.db.global
        if snapshot.core.language then g.language = snapshot.core.language end
        if snapshot.core.theme    then g.theme    = snapshot.core.theme    end
        if snapshot.core.minimap then
            if snapshot.core.minimap.hide  ~= nil then g.minimap.hide  = snapshot.core.minimap.hide  end
            if snapshot.core.minimap.theme       then g.minimap.theme  = snapshot.core.minimap.theme end
        end
        if snapshot.core.featureIcons and snapshot.core.featureIcons.style then
            g.featureIcons.style = snapshot.core.featureIcons.style
        end
        if snapshot.core.settings then DeepMerge(g.settings,  snapshot.core.settings)  end
        if snapshot.core.portalHub then DeepMerge(g.portalHub, snapshot.core.portalHub) end
        if snapshot.core.searchCatalog then
            g.searchCatalog = DeepCopy(snapshot.core.searchCatalog)
            OneWoW.SearchCatalog:InvalidateAll()
        end
    end

    if snapshot.qol and OneWoW_QoL_API then
        OneWoW_QoL_API.ApplyProfileSettings(snapshot.qol)
    end

    if snapshot.cvars then
        for cvarName, value in pairs(snapshot.cvars) do
            C_CVar.SetCVar(cvarName, value)
        end
    end

    if snapshot.core and snapshot.core.theme    then SyncSettingToChildAddons("theme", snapshot.core.theme) end
    if snapshot.core and snapshot.core.language then ns.Locale:SetLanguage(snapshot.core.language) end

    if profileName then
        ns.db.global.activeProfile = profileName
    end

    UI:FullReset()
    C_Timer.After(0.1, function()
        UI:Show()
        UI:SelectSubTab("settings", "profiles")
    end)
end

function ns.Profiles.AutoSaveDefault()
    local snap = ns.Profiles.CaptureSettings()
    snap._isDefault = true
    snap._updatedAt = time()
    ns.db.global.profiles[RESERVED_DEFAULT] = snap
    ns.db.global.defaultProfile = RESERVED_DEFAULT
end

-- ============================================================
-- Serialization
-- ============================================================

function ns.Profiles.SerializeProfile(profileName, profile)
    local exportable = {}
    for k, v in pairs(profile) do
        if k ~= "_isDefault" and k ~= "_updatedAt" then
            exportable[k] = v
        end
    end
    exportable._exportName = profileName
    local body = UI.SerializeVal(exportable, 0)
    if not body then return nil end
    return "-- OneWoW Settings Profile\n-- Version: 1\n" .. body
end

function ns.Profiles.DeserializeProfile(str)
    if not str or str == "" then return nil, "Empty input" end
    local cleaned = str:gsub("%-%-[^\n]*\n?", "")
    local func = loadstring("return " .. cleaned)
    if not func then return nil, "Parse error" end
    local ok, data = pcall(func)
    if not ok then return nil, "Execution error" end
    if type(data) ~= "table" then return nil, "Invalid format" end
    return data, nil
end

function ns.Profiles.ImportProfile(str)
    local data, err = ns.Profiles.DeserializeProfile(str)
    if not data then return false, err end
    local profiles = ns.db.global.profiles
    local name = data._exportName or "Imported"
    if name == RESERVED_DEFAULT then name = "Imported Default" end
    data._exportName = nil
    if profiles[name] then
        local base, i = name, 2
        while profiles[name] do name = base .. " (" .. i .. ")"; i = i + 1 end
    end
    profiles[name] = data
    return true, name
end

-- ============================================================
-- Auto-save hooks
-- ============================================================

ns:RegisterCoreLoginHandler("profiles.AutoSaveDefault", function()
    if ns.Profiles and ns.Profiles.AutoSaveDefault then
        ns.Profiles.AutoSaveDefault()
    end
end)

local _autoSaveFrame = CreateFrame("Frame")
_autoSaveFrame:RegisterEvent("PLAYER_LOGOUT")
_autoSaveFrame:SetScript("OnEvent", function()
    if ns.Profiles and ns.Profiles.AutoSaveDefault then
        ns.Profiles.AutoSaveDefault()
    end
end)

-- ============================================================
-- Export / Import Dialogs
-- ============================================================

function UI:ShowSettingsProfileExportDialog(profileName, serializedStr)
    local eb
    local result = OneWoW_GUI:CreateDialog({
        name   = "OneWoW_SettingsProfileExportDialog",
        title  = "Export Profile: |cFFFFD100" .. profileName .. "|r",
        width  = 620,
        height = 500,
        strata = "FULLSCREEN_DIALOG",
        showBrand = true,
        buttons = {
            { text = "Select All", onClick = function() eb:SetFocus(); eb:HighlightText() end },
            { text = "Close",      onClick = function(d) d:Hide() end },
        },
    })

    local cf = result.contentFrame

    local hint = OneWoW_GUI:CreateFS(cf, 10)
    hint:SetPoint("TOPLEFT", cf, "TOPLEFT", 10, -8)
    hint:SetText("Select all and copy (Ctrl+A, Ctrl+C) to share this profile:")
    hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local textBG = OneWoW_GUI:CreateFrame(cf, { width = 600, height = 420, backdrop = Constants.BACKDROP_SOFT })
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

function UI:ShowSettingsProfileImportDialog(onImported)
    local eb
    local result = OneWoW_GUI:CreateDialog({
        name   = "OneWoW_SettingsProfileImportDialog",
        title  = "Import UI & Addon Settings Profile",
        width  = 620,
        height = 460,
        strata = "FULLSCREEN_DIALOG",
        showBrand = true,
        buttons = {
            { text = "Import", onClick = function(d)
                local text = eb:GetText()
                local ok, res = ns.Profiles.ImportProfile(text)
                if ok then
                    print(string.format("|cFFFFD100OneWoW:|r Settings profile imported: %s", res))
                    d:Hide()
                    if onImported then onImported() end
                else
                    print(string.format("|cFFFFD100OneWoW:|r Import failed: %s", res or "unknown error"))
                end
            end },
            { text = "Cancel", onClick = function(d) d:Hide() end },
        },
    })

    local cf = result.contentFrame

    local hint = OneWoW_GUI:CreateFS(cf, 10)
    hint:SetPoint("TOPLEFT", cf, "TOPLEFT", 10, -8)
    hint:SetText("Paste exported profile data below, then click Import:")
    hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local textBG = OneWoW_GUI:CreateFrame(cf, { width = 600, height = 380, backdrop = Constants.BACKDROP_SOFT })
    textBG:ClearAllPoints()
    textBG:SetPoint("TOPLEFT",     cf, "TOPLEFT",     10, -28)
    textBG:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -10, 4)

    eb = UI.CreateScrollableEditBox(textBG, function() result.frame:Hide() end)
    eb:SetAutoFocus(true)

    result.frame:Show()
end

-- ============================================================
-- Delete Confirmation Dialog (reusable)
-- ============================================================

local _deleteConfirmDialog

local function ShowDeleteConfirm(profileName, onConfirm)
    if _deleteConfirmDialog then
        _deleteConfirmDialog.frame:Hide()
    end
    _deleteConfirmDialog = OneWoW_GUI:CreateConfirmDialog({
        name    = "OneWoW_SettingsProfileDeleteConfirm",
        title   = "Delete Profile",
        message = "Delete settings profile: |cFFFFD100" .. profileName .. "|r?\nThis cannot be undone.",
        width   = 400,
        buttons = {
            { text = "Delete", color = { 0.7, 0.15, 0.15 }, onClick = function(d)
                d:Hide()
                if onConfirm then onConfirm() end
            end },
            { text = "Cancel", onClick = function(d) d:Hide() end },
        },
    })
    _deleteConfirmDialog.frame:Show()
end

-- ============================================================
-- Profiles Tab
-- ============================================================

function UI:CreateProfilesTab(parent)
    local _, content = OneWoW_GUI:CreateScrollFrame(parent, { name = "OneWoW_ProfilesScroll" })

    local settingsHost = CreateFrame("Frame", nil, content)
    settingsHost:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    settingsHost:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    settingsHost:SetHeight(200)

    local charHost = CreateFrame("Frame", nil, content)
    charHost:SetPoint("TOPLEFT", settingsHost, "BOTTOMLEFT", 0, -8)
    charHost:SetPoint("TOPRIGHT", settingsHost, "BOTTOMRIGHT", 0, -8)
    charHost:SetHeight(200)

    local function RecalcContentHeight()
        local sh = settingsHost:GetHeight() or 0
        local ch = charHost:GetHeight() or 0
        content:SetHeight(sh + 8 + ch + 20)
    end

    -- ── UI & Addon Settings ───────────────────────────────────
    local yOffset = -10

    local settingsHeader = OneWoW_GUI:CreateSectionHeader(settingsHost, {
        title = "UI & Addon Settings",
        yOffset = yOffset,
        fontSize = 14,
    })
    yOffset = settingsHeader.bottomY - 8

    local descText = OneWoW_GUI:CreateFS(settingsHost, 12)
    descText:SetPoint("TOPLEFT",  settingsHost, "TOPLEFT",  10, yOffset)
    descText:SetPoint("TOPRIGHT", settingsHost, "TOPRIGHT", -10, yOffset)
    descText:SetJustifyH("LEFT")
    descText:SetWordWrap(true)
    descText:SetSpacing(2)
    descText:SetText("Saves your OneWoW theme, language, overlays, portal settings, and all QoL feature toggles. Export to share your setup or import from another player.")
    descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    yOffset = yOffset - 36

    local saveSection = OneWoW_GUI:CreateSectionHeader(settingsHost, { title = "Save New Profile", yOffset = yOffset })
    yOffset = saveSection.bottomY - 8

    local nameInput = OneWoW_GUI:CreateEditBox(settingsHost, { name = "OneWoW_ProfileNameInput", width = 280, height = 26 })
    nameInput:SetPoint("TOPLEFT", settingsHost, "TOPLEFT", 10, yOffset)
    nameInput:SetAutoFocus(false)

    local saveBtn = OneWoW_GUI:CreateFitTextButton(settingsHost, { text = "Save Profile", height = 26 })
    saveBtn:SetPoint("LEFT", nameInput, "RIGHT", 8, 0)

    yOffset = yOffset - 40

    local listHeaderSection = OneWoW_GUI:CreateSectionHeader(settingsHost, { title = "Saved Profiles", yOffset = yOffset })
    yOffset = listHeaderSection.bottomY - 8

    local importBtn = OneWoW_GUI:CreateFitTextButton(settingsHost, { text = "Import Profile", height = 24 })
    importBtn:SetPoint("TOPRIGHT", settingsHost, "TOPRIGHT", -10, yOffset + 32)

    local listContainer = CreateFrame("Frame", nil, settingsHost)
    listContainer:SetPoint("TOPLEFT",  settingsHost, "TOPLEFT",  10, yOffset)
    listContainer:SetPoint("TOPRIGHT", settingsHost, "TOPRIGHT", -10, yOffset)
    listContainer:SetHeight(20)

    local function RefreshListing()
        OneWoW_GUI:ClearFrame(listContainer)

        local profiles = ns.db.global.profiles
        if not profiles then profiles = {} end

        local activeProfile = ns.db.global.activeProfile

        local sorted = {}
        if profiles[RESERVED_DEFAULT] then
            table.insert(sorted, { name = RESERVED_DEFAULT, data = profiles[RESERVED_DEFAULT] })
        end
        for name, data in pairs(profiles) do
            if name ~= RESERVED_DEFAULT and type(data) == "table" then
                table.insert(sorted, { name = name, data = data })
            end
        end
        table.sort(sorted, function(a, b)
            if a.name == RESERVED_DEFAULT then return true end
            if b.name == RESERVED_DEFAULT then return false end
            return a.name:lower() < b.name:lower()
        end)

        if #sorted == 0 then
            local empty = OneWoW_GUI:CreateFS(listContainer, 12)
            empty:SetPoint("TOPLEFT", 10, -14)
            empty:SetText("No profiles saved yet. Save one above.")
            empty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            listContainer:SetHeight(40)
            settingsHost:SetHeight(math.abs(yOffset) + listContainer:GetHeight() + 20)
            RecalcContentHeight()
            return
        end

        local CARD_H = 76
        local CARD_GAP = 6
        local yOff = 0

        for _, entry in ipairs(sorted) do
            local name = entry.name
            local data = entry.data
            local isDefault = (name == RESERVED_DEFAULT)
            local isActive  = (activeProfile == name)

            local card = OneWoW_GUI:CreateFrame(listContainer, { width = 100, height = CARD_H, backdrop = Constants.BACKDROP_SOFT })
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT",  listContainer, "TOPLEFT",  0, yOff)
            card:SetPoint("TOPRIGHT", listContainer, "TOPRIGHT", 0, yOff)
            card:SetHeight(CARD_H)

            local nameText = OneWoW_GUI:CreateFS(card, 12)
            nameText:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
            nameText:SetText(isDefault and ("|cFFFFD100" .. name .. "|r") or name)
            if isActive then
                nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            else
                nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end

            if isDefault then
                local badge = OneWoW_GUI:CreateFS(card, 10)
                badge:SetPoint("LEFT", nameText, "RIGHT", 8, 0)
                badge:SetText("Account Default - Auto-Updates")
                badge:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
            end

            if isActive and not isDefault then
                local activeBadge = OneWoW_GUI:CreateFS(card, 10)
                activeBadge:SetPoint("LEFT", nameText, "RIGHT", 8, 0)
                activeBadge:SetText("Active")
                activeBadge:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end

            local dateText = OneWoW_GUI:CreateFS(card, 10)
            dateText:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -26)
            local ts = data._updatedAt or 0
            local dateLabel = isDefault and "Updated: " or "Saved: "
            dateText:SetText(dateLabel .. (ts > 0 and date("%Y-%m-%d %H:%M", ts) or "Unknown"))
            dateText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

            local tags = {}
            if data.core then
                local parts = {}
                if data.core.theme    then table.insert(parts, data.core.theme)    end
                if data.core.language then table.insert(parts, data.core.language) end
                table.insert(tags, "Core" .. (#parts > 0 and (" (" .. table.concat(parts, ", ") .. ")") or ""))
            end
            if data.qol then
                local mc = 0
                if data.qol.modules then for _ in pairs(data.qol.modules) do mc = mc + 1 end end
                table.insert(tags, string.format("QoL (%d modules)", mc))
            end
            if data.cvars then
                local cc = 0
                for _ in pairs(data.cvars) do cc = cc + 1 end
                if cc > 0 then table.insert(tags, string.format("%d CVars", cc)) end
            end

            local tagsText = OneWoW_GUI:CreateFS(card, 10)
            tagsText:SetPoint("TOPLEFT",  card, "TOPLEFT",  10, -44)
            tagsText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -280, -44)
            tagsText:SetJustifyH("LEFT")
            tagsText:SetText(#tags > 0 and table.concat(tags, "  |cFF444444/|r  ") or "")
            tagsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

            local btnY = 6

            if not isDefault then
                local delBtn = OneWoW_GUI:CreateFitTextButton(card, { text = "Delete", height = 26, danger = true })
                delBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, btnY)
                local capturedName = name
                delBtn:SetScript("OnClick", function()
                    ShowDeleteConfirm(capturedName, function()
                        ns.db.global.profiles[capturedName] = nil
                        if ns.db.global.activeProfile == capturedName then
                            ns.db.global.activeProfile = nil
                        end
                        RefreshListing()
                    end)
                end)

                local exportBtn = OneWoW_GUI:CreateFitTextButton(card, { text = "Export", height = 26 })
                exportBtn:SetPoint("RIGHT", delBtn, "LEFT", -6, 0)
                exportBtn:SetScript("OnClick", function()
                    local serialized = ns.Profiles.SerializeProfile(capturedName, data)
                    if serialized then UI:ShowSettingsProfileExportDialog(capturedName, serialized) end
                end)

                local loadBtn = OneWoW_GUI:CreateFitTextButton(card, { text = "Load", height = 26 })
                loadBtn:SetPoint("RIGHT", exportBtn, "LEFT", -6, 0)
                loadBtn:SetScript("OnClick", function()
                    ns.Profiles.ApplySettings(data, capturedName)
                end)
            else
                local exportBtn = OneWoW_GUI:CreateFitTextButton(card, { text = "Export", height = 26 })
                exportBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, btnY)
                exportBtn:SetScript("OnClick", function()
                    local serialized = ns.Profiles.SerializeProfile(RESERVED_DEFAULT, data)
                    if serialized then UI:ShowSettingsProfileExportDialog(RESERVED_DEFAULT, serialized) end
                end)

                local restoreBtn = OneWoW_GUI:CreateFitTextButton(card, { text = "Restore Now", height = 26 })
                restoreBtn:SetPoint("RIGHT", exportBtn, "LEFT", -6, 0)
                restoreBtn:SetScript("OnClick", function()
                    ns.Profiles.ApplySettings(data, RESERVED_DEFAULT)
                end)
            end

            yOff = yOff - (CARD_H + CARD_GAP)
        end

        listContainer:SetHeight(math.abs(yOff) + CARD_GAP)
        settingsHost:SetHeight(math.abs(yOffset) + listContainer:GetHeight() + 20)
        RecalcContentHeight()
    end

    saveBtn:SetScript("OnClick", function()
        local name = nameInput:GetText():trim()
        if name == "" then
            print("|cFFFFD100OneWoW:|r Profile name cannot be empty.")
            return
        end
        if name == RESERVED_DEFAULT then
            print("|cFFFFD100OneWoW:|r Cannot use the name 'Default' - it is reserved.")
            return
        end
        local snap = ns.Profiles.CaptureSettings()
        snap._updatedAt = time()
        ns.db.global.profiles[name] = snap
        ns.db.global.activeProfile  = name
        nameInput:SetText("")
        print(string.format("|cFFFFD100OneWoW:|r Settings profile saved: %s", name))
        RefreshListing()
    end)

    importBtn:SetScript("OnClick", function()
        UI:ShowSettingsProfileImportDialog(RefreshListing)
    end)

    -- ── Character Backup ──────────────────────────────────────
    local charHeader = OneWoW_GUI:CreateSectionHeader(charHost, {
        title = "Character Backup",
        yOffset = -10,
        fontSize = 14,
    })
    local charBodyY = charHeader.bottomY - 8

    if UI.CreateCharProfilesPanel then
        UI:CreateCharProfilesPanel(parent, {
            content = charHost,
            yOffset = charBodyY,
            onHeightChanged = function(height)
                charHost:SetHeight(height)
                RecalcContentHeight()
            end,
        })
    end

    C_Timer.After(0.05, function()
        ns.Profiles.AutoSaveDefault()
        RefreshListing()
        OneWoW_GUI:ApplyFontToFrame(parent)
        RecalcContentHeight()
    end)
end
