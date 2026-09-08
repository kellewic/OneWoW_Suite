local _, ns = ...

local OneWoW = OneWoW

local Toasts = OneWoW.Toasts
local Inventory = OneWoW.Inventory
local UpgradeDetection = OneWoW.UpgradeDetection

-- ============================================================================
-- Toast upgrades
-- ============================================================================
-- Fires when a new bag item is an upgrade for this character, using the same
-- UpgradeDetection answer as bag overlays, #upgrade, and gear tooltips.
-- Overlay Upgrade mode Off means no toast (detector returns false).
-- ============================================================================

local COLOR_UPGRADE = {0.20, 0.85, 0.35, 1.0}

local function UpgradesEnabled()
    return OneWoW.SettingsFeatureRegistry:IsEnabled("toastalerts", "upgrades")
end

local bagCache = {}
local bagReady = false

---@param info table
---@return string
local function GetItemCacheKey(info)
    if info.itemGUID and info.itemGUID ~= "" then
        return info.itemGUID
    end
    return "id_" .. info.itemID
end

local function BuildBagCache()
    bagCache = {}
    Inventory.ForEachSlot("player", function(_, _, info)
        if info and info.itemID then
            bagCache[GetItemCacheKey(info)] = info.itemID
        end
    end)
    bagReady = true
end

---@param bag number
---@param slot number
---@param info table
local function ConsiderNewUpgrade(bag, slot, info)
    local itemLink = info.hyperlink
    if not itemLink then return end

    local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not UpgradeDetection:CheckItemUpgrade(itemLink, itemLocation) then return end

    local name = C_Item.GetItemInfo(itemLink)
    local icon = info.iconFileID
    if not name or not icon then return end

    Toasts.FireToast({
        toastType = "upgrade",
        category  = "upgrade",
        title     = ns.L["TOAST_NEW_UPGRADE"],
        subtitle  = name,
        icon      = icon,
        color     = COLOR_UPGRADE,
    })
end

local function ScanBagsForUpgrades()
    if not bagReady then return end
    if not UpgradesEnabled() then return end

    local newCache = {}

    Inventory.ForEachSlot("player", function(bag, slot, info)
        if not (info and info.itemID) then return end
        local guid = GetItemCacheKey(info)
        newCache[guid] = info.itemID

        if not bagCache[guid] then
            ConsiderNewUpgrade(bag, slot, info)
        end
    end)

    bagCache = newCache
end

ns.ToastUpgrade = {}
function ns.ToastUpgrade.OnLogin()
    C_Timer.After(3, BuildBagCache)
end

OneWoW.Inventory.RegisterDelayedCallback("ToastUpgrade", function()
    ScanBagsForUpgrades()
end)
