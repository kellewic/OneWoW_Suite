-- ============================================================================
-- SearchRegistry
-- ============================================================================
-- Hub title-bar search index. Features register here (or via RegisterModule /
-- SettingsFeatureRegistry / QoL Define hooks) so the catalog stays aligned
-- with live tabs and settings.
--
-- Design decisions:
--   - Entries store locale keys / display functions, not frozen English paths
--   - Haystacks are built lazily and wiped on language change
--   - Registration is load-time data only; never index widgets (lazy UI)
--   - Query is a linear scan of a few hundred rows; no frame walk
--
-- What feeds the index (automatic):
--   RegisterModule, RegisterSettingsPanel, SettingsFeatureRegistry:Register,
--   QoL Define, overlay presets, CVar rows, CoreEntries (Home / Display /
--   standalone windows)
-- Leftover settings/windows not in those hooks: OneWoW.Search:Register in that
-- addon's Search.lua, with English tags for player phrasing.
--
-- Player phrasing lives in this file only:
--   STOPWORDS = dropped  |  INTENT = boost only, never required
-- ============================================================================

local _, ns = ...

local ipairs, pairs, type = ipairs, pairs, type
local tinsert, tremove, sort = tinsert, tremove, sort
local strlower, strfind = strlower, strfind
local tostring, concat = tostring, table.concat

ns.SearchRegistry = {}
local reg = ns.SearchRegistry

local entries = {}
local byId = {}

local PATH_SEP = " > "

-- Quoted keys: do, for, in, and, or are Lua reserved words.
local STOPWORDS = {
    ["how"] = true, ["do"] = true, ["i"] = true, ["the"] = true, ["a"] = true, ["an"] = true,
    ["for"] = true, ["to"] = true, ["my"] = true, ["me"] = true, ["please"] = true, ["can"] = true,
    ["you"] = true, ["what"] = true, ["where"] = true, ["is"] = true, ["in"] = true, ["of"] = true,
    ["and"] = true, ["or"] = true, ["it"] = true, ["this"] = true, ["that"] = true, ["with"] = true,
}

-- Action verbs: extra score if they appear, never required to match.
-- "how do I change map pins" must still find pins after "change" is stripped.
local INTENT = {
    ["stop"] = true, ["hide"] = true, ["disable"] = true, ["enable"] = true,
    ["turn"] = true, ["off"] = true, ["on"] = true, ["show"] = true,
    ["find"] = true, ["open"] = true, ["change"] = true, ["set"] = true,
    ["adjust"] = true, ["edit"] = true, ["modify"] = true, ["update"] = true,
    ["make"] = true, ["use"] = true,
}

local TAB_EXTRA_TAGS = {
    waypins = { "pins", "pin", "oneway", "map pin", "map pins", "minimap pin" },
    collectibles = { "mount", "pet", "toy", "transmog" },
    toastalerts = { "popup", "pop-up", "notification", "alert", "toast", "upgrade", "collection", "loot" },
    overlays = { "overlay", "bag overlay", "bag icon" },
    tooltips = { "tooltip", "hover" },
    quests = { "quest", "quest log" },
    features = { "qol", "module", "toggle" },
    toggles = { "cvar", "gameplay", "interface" },
}

local FEATURE_TAB_TAGS = {
    toastalerts = { "toast", "popup", "pop-up", "notification", "alert", "upgrade", "collection", "loot" },
    overlays = { "overlay", "overlays", "bag overlay" },
    tooltips = { "tooltip", "tooltips", "hover" },
}

local PRESET_EXTRA_TAGS = {
    junk = { "grey", "gray", "vendor junk", "sell junk" },
    boe = { "bind on equip", "boe" },
    soulbound = { "bop", "bound" },
    warbound = { "warband" },
    wue = { "warbound until equipped" },
}

---@param v any
---@param scope string|nil
---@return string
local function ResolveText(v, scope)
    if type(v) == "function" then
        local result = v()
        if result == nil then
            return ""
        end
        return tostring(result)
    end
    if type(v) ~= "string" or v == "" then
        return ""
    end
    if scope then
        return ns.Locale:GetTable(scope)[v]
    end
    return ns.L[v]
end

---@param crumbs table|nil
---@return string
local function ResolvePath(crumbs)
    if type(crumbs) ~= "table" then
        return ""
    end
    local parts = {}
    for i = 1, #crumbs do
        local text = ResolveText(crumbs[i], nil)
        if text ~= "" then
            tinsert(parts, text)
        end
    end
    return concat(parts, PATH_SEP)
end

---@param tags table|nil
---@return string[]
local function NormalizeTags(tags)
    local out = {}
    if type(tags) ~= "table" then
        return out
    end
    for i = 1, #tags do
        local t = tags[i]
        if type(t) == "string" and t ~= "" then
            tinsert(out, strlower(t))
        end
    end
    return out
end

---@param a string[]
---@param b string[]|nil
---@return string[]
local function MergeTags(a, b)
    if not b then
        return a
    end
    local seen = {}
    local out = {}
    for i = 1, #a do
        local t = a[i]
        if not seen[t] then
            seen[t] = true
            tinsert(out, t)
        end
    end
    for i = 1, #b do
        local t = b[i]
        if type(t) == "string" and t ~= "" then
            t = strlower(t)
            if not seen[t] then
                seen[t] = true
                tinsert(out, t)
            end
        end
    end
    return out
end

--- Hub section label, resolved live (RegisterModule may land after this file).
---@param moduleName string
---@return fun(): string
function reg.ModuleLabel(moduleName)
    return function()
        if moduleName == "home" then
            return ns.L["HOME_TAB"]
        end
        if moduleName == "settings" then
            return SETTINGS
        end
        local m = ns.ModuleRegistry:GetModule(moduleName)
        if m and m.displayName then
            local n = m.displayName
            if type(n) == "function" then
                return n() or moduleName
            end
            return n
        end
        return moduleName
    end
end

--- Hub or Settings sub-tab label, resolved live.
---@param moduleName string
---@param tabName string
---@return fun(): string
function reg.TabLabel(moduleName, tabName)
    return function()
        if moduleName == "settings" then
            if tabName == "settings" then
                return DISPLAY
            end
            local coreKeys = {
                rolesandalts = "ROLES_ALTS_SUBTAB",
                searchshortcuts = "SEARCH_SHORTCUTS_SUBTAB",
                profiles = "PROFILES_SUBTAB",
                managefeatures = "MANAGE_FEATURES_SUBTAB",
            }
            local key = coreKeys[tabName]
            if key then
                return ns.L[key]
            end
            for _, panel in ipairs(ns.ModuleRegistry:GetSettingsPanels()) do
                if panel.name == tabName then
                    local n = panel.displayName
                    if type(n) == "function" then
                        return n() or tabName
                    end
                    return n
                end
            end
        end
        local m = ns.ModuleRegistry:GetModule(moduleName)
        if m and m.tabs then
            for _, tab in ipairs(m.tabs) do
                if tab.name == tabName then
                    local n = tab.displayName
                    if type(n) == "function" then
                        return n() or tabName
                    end
                    return n
                end
            end
        end
        return tabName
    end
end

---@param addonKey string|nil
---@return boolean
local function IsInstalled(addonKey)
    if not addonKey then
        return true
    end
    return C_AddOns.DoesAddOnExist(addonKey) and C_AddOns.GetAddOnEnableState(addonKey) ~= 0
end

---@param entry table
local function BuildHaystack(entry)
    local title = ResolveText(entry.title, entry.scope)
    local desc = ResolveText(entry.description, entry.scope)
    local path = ResolvePath(entry.path)
    local parts = { title, desc, path }
    local tags = entry.tags
    if tags then
        for i = 1, #tags do
            tinsert(parts, tags[i])
        end
    end
    entry._title = title
    entry._desc = desc
    entry._path = path
    entry._haystack = strlower(concat(parts, " "))
end

---@param entry table
local function EnsureHaystack(entry)
    if not entry._haystack then
        BuildHaystack(entry)
    end
    return entry._haystack
end

--- Add or replace a search entry. `id` is required and idempotent.
---@param entry table
function reg:Register(entry)
    if type(entry) ~= "table" or type(entry.id) ~= "string" or entry.id == "" then
        return
    end
    entry.tags = NormalizeTags(entry.tags)
    entry._haystack = nil
    entry._title = nil
    entry._desc = nil
    entry._path = nil
    local existing = byId[entry.id]
    if existing then
        for k in pairs(existing) do
            existing[k] = nil
        end
        for k, v in pairs(entry) do
            existing[k] = v
        end
        return
    end
    byId[entry.id] = entry
    tinsert(entries, entry)
end

---@param id string
function reg:Unregister(id)
    local existing = byId[id]
    if not existing then
        return
    end
    byId[id] = nil
    for i = 1, #entries do
        if entries[i] == existing then
            tremove(entries, i)
            return
        end
    end
end

function reg:InvalidateHaystacks()
    for i = 1, #entries do
        local e = entries[i]
        e._haystack = nil
        e._title = nil
        e._desc = nil
        e._path = nil
    end
end

---@return table[]
function reg:GetAll()
    return entries
end

--- Feed one hub module (all of its tabs). Called from ModuleRegistry:RegisterModule.
---@param moduleInfo table
function reg:RegisterHubModule(moduleInfo)
    if type(moduleInfo) ~= "table" or not moduleInfo.name then
        return
    end
    local tabs = moduleInfo.tabs
    if type(tabs) ~= "table" then
        return
    end
    local addonKey = moduleInfo.addonName
    if addonKey == "" then
        addonKey = nil
    end
    for i = 1, #tabs do
        local tab = tabs[i]
        if tab and tab.name then
            local tags = MergeTags({ tab.name, moduleInfo.name }, TAB_EXTRA_TAGS[tab.name])
            self:Register({
                id = "hub:" .. moduleInfo.name .. ":" .. tab.name,
                title = tab.displayName,
                tags = tags,
                addonKey = addonKey,
                path = { self.ModuleLabel(moduleInfo.name), self.TabLabel(moduleInfo.name, tab.name) },
                nav = { module = moduleInfo.name, subtab = tab.name },
            })
        end
    end
end

--- Feed one Settings row-2 panel. Called from RegisterSettingsPanel.
---@param panelInfo table
function reg:RegisterSettingsPanelEntry(panelInfo)
    if type(panelInfo) ~= "table" or not panelInfo.name then
        return
    end
    self:Register({
        id = "settings-panel:" .. panelInfo.name,
        title = panelInfo.displayName,
        tags = { panelInfo.name, "settings" },
        path = { self.ModuleLabel("settings"), self.TabLabel("settings", panelInfo.name) },
        nav = { module = "settings", subtab = panelInfo.name },
    })
end

--- Feed a SettingsFeatureRegistry row (tooltips / overlays / toasts).
---@param tabName string
---@param featureData table
function reg:RegisterFeature(tabName, featureData)
    if type(featureData) ~= "table" or not featureData.id then
        return
    end
    local tags = MergeTags({ featureData.id, tabName }, FEATURE_TAB_TAGS[tabName])
    self:Register({
        id = "feature:" .. tabName .. ":" .. featureData.id,
        title = featureData.title,
        description = featureData.description,
        scope = "OneWoW_QoL",
        tags = tags,
        addonKey = "OneWoW_QoL",
        path = {
            self.ModuleLabel("qol"),
            self.TabLabel("qol", tabName),
            function()
                return ResolveText(featureData.title, "OneWoW_QoL")
            end,
        },
        nav = { module = "qol", subtab = tabName },
    })
end

--- Factory so Lua 5.1 does not reuse the for-loop local across toggle closures.
---@param def table
---@param toggle table
---@param qolL fun(): table
---@param scope string|nil
---@return table
local function MakeQoLToggleEntry(def, toggle, qolL, scope)
    return {
        id = "qol-mod:" .. def.id .. ":toggle:" .. toggle.id,
        title = toggle.label,
        description = toggle.description,
        scope = scope,
        tags = { toggle.id, def.id },
        addonKey = "OneWoW_QoL",
        path = {
            reg.ModuleLabel("qol"),
            function() return qolL()["TAB_FEATURES"] end,
            function() return ResolveText(def.title, scope) end,
            function() return ResolveText(toggle.label, scope) end,
        },
        nav = { module = "qol", subtab = "features" },
    }
end

--- Feed a QoL external module and its toggles. Called from ModuleRegistry:Define.
---@param def table
function reg:RegisterQoLModule(def)
    if type(def) ~= "table" or not def.id then
        return
    end
    local scope = def._scope
    local qolL = function()
        return ns.Locale:GetTable("OneWoW_QoL")
    end
    local tags = MergeTags({ def.id, "qol", def.category and strlower(def.category) or "utility" }, def.tags)
    self:Register({
        id = "qol-mod:" .. def.id,
        title = def.title,
        description = def.description,
        scope = scope,
        tags = tags,
        addonKey = "OneWoW_QoL",
        path = {
            self.ModuleLabel("qol"),
            function() return qolL()["TAB_FEATURES"] end,
            function() return ResolveText(def.title, scope) end,
        },
        nav = { module = "qol", subtab = "features" },
    })
    local toggles = def.toggles
    if type(toggles) ~= "table" then
        return
    end
    for i = 1, #toggles do
        local t = toggles[i]
        if t and t.id then
            self:Register(MakeQoLToggleEntry(def, t, qolL, scope))
        end
    end
end

---@param preset table
---@return table
local function MakeOverlayPresetEntry(preset)
    local tags = MergeTags({ preset.id, "overlay", "overlays" }, PRESET_EXTRA_TAGS[preset.id])
    return {
        id = "overlay-preset:" .. preset.id,
        title = preset.title,
        description = preset.description,
        scope = "OneWoW_QoL",
        tags = tags,
        addonKey = "OneWoW_QoL",
        path = {
            reg.ModuleLabel("qol"),
            reg.TabLabel("qol", "overlays"),
            function() return ResolveText(preset.title, "OneWoW_QoL") end,
        },
        nav = { module = "qol", subtab = "overlays" },
    }
end

--- Overlay 2.0 preset names. Called once from CoreEntries after definitions load.
function reg:RegisterOverlayPresets()
    local presets = ns.Overlays2Defs:GetPresets()
    for i = 1, #presets do
        self:Register(MakeOverlayPresetEntry(presets[i]))
    end
end

--- One QoL CVar / gameplay toggle row.
---@param row table
function reg:RegisterCVarRow(row)
    if type(row) ~= "table" or not row.cvar then
        return
    end
    local cat = row.cat or "GAMEPLAY"
    local qolL = function()
        return ns.Locale:GetTable("OneWoW_QoL")
    end
    self:Register({
        id = "cvar:" .. row.cvar,
        title = function()
            if row.nameGlobal then
                return _G[row.nameGlobal] or row.nameGlobal
            end
            return ResolveText(row.name, "OneWoW_QoL")
        end,
        description = row.desc,
        scope = "OneWoW_QoL",
        tags = { row.cvar, strlower(cat) },
        addonKey = "OneWoW_QoL",
        path = {
            self.ModuleLabel("qol"),
            function() return qolL()["TAB_TOGGLES"] end,
            function() return qolL()["TOGGLE_CAT_" .. cat] end,
            function()
                if row.nameGlobal then
                    return _G[row.nameGlobal] or row.nameGlobal
                end
                return ResolveText(row.name, "OneWoW_QoL")
            end,
        },
        nav = { module = "qol", subtab = "toggles" },
    })
end

---@param query string
---@return string[] content
---@return string[] intent
local function Tokenize(query)
    query = strlower(query):match("^%s*(.-)%s*$") or ""
    local raw = {}
    for word in query:gmatch("[%a%d]+") do
        if #word >= 2 and not STOPWORDS[word] then
            tinsert(raw, word)
        end
    end
    -- CJK / spaced non-ASCII: [%a%d] found nothing, so split on whitespace.
    if #raw == 0 then
        for word in query:gmatch("%S+") do
            if #word >= 1 and not STOPWORDS[word] then
                tinsert(raw, word)
            end
        end
    end
    if #raw == 0 and #query >= 2 then
        tinsert(raw, query)
    end
    local content, intent = {}, {}
    for i = 1, #raw do
        local tok = raw[i]
        if INTENT[tok] then
            tinsert(intent, tok)
        else
            tinsert(content, tok)
        end
    end
    if #content == 0 then
        return intent, {}
    end
    return content, intent
end

---@param haystack string
---@param tok string
---@return number
local function TokenScore(haystack, tok)
    if haystack == tok then
        return 100
    end
    if haystack:sub(1, #tok) == tok then
        return 80
    end
    if strfind(haystack, " " .. tok, 1, true) then
        return 80
    end
    if strfind(haystack, tok, 1, true) then
        return 50
    end
    return 0
end

--- Ranked hits for a player query. Empty when nothing matches.
---@param query string
---@param limit number|nil
---@return table[]
function reg:Query(query, limit)
    limit = limit or 8
    local content, intent = Tokenize(query)
    if #content == 0 then
        return {}
    end

    local hits = {}
    for i = 1, #entries do
        local entry = entries[i]
        local hay = EnsureHaystack(entry)
        local score = 0
        local miss = false
        for t = 1, #content do
            local s = TokenScore(hay, content[t])
            if s == 0 then
                miss = true
                break
            end
            score = score + s
        end
        if not miss then
            for t = 1, #intent do
                if TokenScore(hay, intent[t]) > 0 then
                    score = score + 10
                end
            end
            tinsert(hits, {
                entry = entry,
                score = score,
                installed = IsInstalled(entry.addonKey),
                path = entry._path,
                desc = entry._desc,
                title = entry._title,
            })
        end
    end

    sort(hits, function(a, b)
        if a.installed ~= b.installed then
            return a.installed
        end
        if a.score ~= b.score then
            return a.score > b.score
        end
        return a.path < b.path
    end)

    if #hits <= limit then
        return hits
    end
    local out = {}
    for i = 1, limit do
        out[i] = hits[i]
    end
    return out
end

ns.Locale:OnApply(function()
    reg:InvalidateHaystacks()
end)
