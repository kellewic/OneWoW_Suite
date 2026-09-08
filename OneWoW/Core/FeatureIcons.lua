local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

-- ============================================================================
-- FeatureIcons
-- ============================================================================
-- Single write site for suite feature faces (Home, Manage Features, Button
-- Collector enhanced row). Keyed by addon folder name, plus synthetic keys
-- for collector extras that are not load units (`settings`, `portals`).
-- Brand crest for Core stays on OneWoW_GUI:GetBrandIcon — not listed here.
-- Style (ring / ringless) comes from OneWoW_GUI:GetSetting("featureIcons.style").
-- DevTools session errors tint the face red (EventRegistry
-- OneWoW_DevTool.ErrorAlert) and send click through to the Errors tab.
-- ============================================================================

local MEDIA = OneWoW_GUI.Constants.MEDIA_BASE .. "Features\\"
local TEX_COORDS = { 0, 1, 0, 1 }
local DEVTOOL_ADDON = "OneWoW_Utility_DevTool"
local DEVTOOL_ERROR_ALERT = "OneWoW_DevTool.ErrorAlert"
local ALERT_RED = { 1, 0.18, 0.12, 1 }

--- Stem under Media/Features/<style>/
local FEATURE_FILES = {
    OneWoW_AltTracker = "alttracker",
    OneWoW_Catalog = "catalog",
    OneWoW_Notes = "notes",
    OneWoW_Trackers = "trackers",
    OneWoW_QoL = "qol",
    OneWoW_Bags = "bags",
    OneWoW_ShoppingList = "shoppinglist",
    OneWoW_DirectDeposit = "directdeposit",
    OneWoW_Mail = "mail",
    OneWoW_Utility_DevTool = "devtools",
    OneWoW_Notes_WayPins = "waypins",
    settings = "settings",
    portals = "portals",
}

local function FeatureIconStyle()
    if OneWoW_GUI:GetSetting("featureIcons.style") == "ringless" then
        return "ringless"
    end
    return "ring"
end

--- Resolve the suite feature face for a load unit or collector extra key.
---@param addonName string folder name (e.g. "OneWoW_Mail") or extra key ("settings", "portals")
---@return table|nil info { texture?, atlas?, texCoords?, plate? }
function ns:GetFeatureIcon(addonName)
    if type(addonName) ~= "string" or addonName == "" then
        return nil
    end
    local file = FEATURE_FILES[addonName]
    if not file then
        return nil
    end
    local style = FeatureIconStyle()
    return {
        texture = MEDIA .. style .. "\\" .. file .. ".png",
        texCoords = TEX_COORDS,
        plate = style ~= "ringless",
    }
end

--- Whether the feature face should use the error tint.
---@param addonName string
---@return boolean
function ns:FeatureIconHasAlert(addonName)
    if addonName ~= DEVTOOL_ADDON or not OneWoW_Utility_DevTool_API then
        return false
    end
    return OneWoW_Utility_DevTool_API.HasCurrentSessionErrors()
end

--- Gold face, or red when DevTools has a current-session error.
---@param texture Texture
---@param addonName string
function ns:ApplyFeatureIconAlert(texture, addonName)
    if ns:FeatureIconHasAlert(addonName) then
        texture:SetVertexColor(ALERT_RED[1], ALERT_RED[2], ALERT_RED[3], ALERT_RED[4])
        return
    end
    texture:SetVertexColor(1, 1, 1, 1)
end

--- Click opens the Errors tab while DevTools is alerting; otherwise `fallback`.
---@param addonName string
---@param fallback function|nil
---@return function|nil
function ns:ResolveFeatureIconClick(addonName, fallback)
    if ns:FeatureIconHasAlert(addonName) then
        return function()
            OneWoW_Utility_DevTool_API.OpenDevToolErrorsTab()
        end
    end
    return fallback
end

--- EventRegistry name fired when the DevTools error alert turns on or off.
---@return string
function ns:GetFeatureIconAlertEvent()
    return DEVTOOL_ERROR_ALERT
end
