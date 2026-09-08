local _, ns = ...

local OneWoW = OneWoW

local PE = OneWoW.PredicateEngine
local Toasts = OneWoW.Toasts
local Inventory = OneWoW.Inventory
local Collectibles = OneWoW.Collectibles

-- ============================================================================
-- Toast loot (New Collections)
-- ============================================================================
-- Fires when an uncollected collectible appears in bags, using the same
-- Collectibles.GetItemCollectionStatus path Catalog loot rows use.
-- NEW_MOUNT_ADDED / NEW_PET_ADDED / NEW_TOY_ADDED still toast when you learn
-- one that did not already toast from bags (direct grants, same-session use).
-- ============================================================================

local TYPE_COLORS = {
    mounts    = {1.00, 0.84, 0.00, 1.0},
    pets      = {0.20, 0.80, 0.80, 1.0},
    toys      = {0.70, 0.40, 1.00, 1.0},
    recipes   = {1.00, 0.60, 0.20, 1.0},
    tmogs     = {1.00, 0.40, 0.60, 1.0},
    housing   = {0.45, 0.85, 0.55, 1.0},
    heirlooms = {0.90, 0.80, 0.50, 1.0},
}

local TITLE_KEYS = {
    mounts    = "TOAST_NEW_MOUNT",
    pets      = "TOAST_NEW_PET",
    toys      = "TOAST_NEW_TOY",
    recipes   = "TOAST_NEW_RECIPE",
    tmogs     = "TOAST_NEW_TMOG",
    housing   = "TOAST_NEW_HOUSING",
    heirlooms = "TOAST_NEW_HEIRLOOM",
}

local COLLECTIBLE_CATEGORY = {
    mount      = "mounts",
    pet        = "pets",
    toy        = "toys",
    recipe     = "recipes",
    appearance = "tmogs",
    set        = "tmogs",
    decor      = "housing",
    heirloom   = "heirlooms",
}

local toastedKeys = {}

local function GetCfg()
    return OneWoW.SettingsFeatureRegistry:GetFeatureSettings("toastalerts", "detectiontypes")
end

local function LootEnabled()
    return OneWoW.SettingsFeatureRegistry:IsEnabled("toastalerts", "detectiontypes")
end

---@param category string
---@return boolean
local function CategoryEnabled(category)
    return GetCfg()[category] ~= false
end

---@param key string|nil
---@return boolean
local function AlreadyToasted(key)
    return key ~= nil and toastedKeys[key] == true
end

---@param key string|nil
local function RememberKey(key)
    if key then
        toastedKeys[key] = true
    end
end

---@param category string
---@param itemName string
---@param itemTexture number|string
---@param collectibleKey string|nil
local function FireLootToast(category, itemName, itemTexture, collectibleKey)
    if not LootEnabled() then return end
    if not CategoryEnabled(category) then return end
    if not itemName or itemName == "" then return end
    if AlreadyToasted(collectibleKey) then return end

    RememberKey(collectibleKey)
    Toasts.FireToast({
        toastType = "loot",
        category  = category,
        title     = ns.L[TITLE_KEYS[category]],
        subtitle  = itemName,
        icon      = itemTexture,
        color     = TYPE_COLORS[category],
    })
end

---@param mountID number
local function OnNewMount(mountID)
    if not LootEnabled() or not CategoryEnabled("mounts") then return end
    if not mountID or mountID <= 0 then return end

    local name, _, icon, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
    if not isCollected then return end
    if not name or not icon then return end

    FireLootToast("mounts", name, icon, Collectibles.BuildKey("mount", mountID))
end

---@param petGUID string
local function OnNewPet(petGUID)
    if not LootEnabled() or not CategoryEnabled("pets") then return end
    if not petGUID or petGUID == "" then return end

    local speciesID, _, _, _, _, _, _, name, icon = C_PetJournal.GetPetInfoByPetID(petGUID)
    speciesID = tonumber(speciesID)
    if not speciesID or speciesID <= 0 then return end
    if not name or not icon then return end

    FireLootToast("pets", name, icon, Collectibles.BuildKey("pet", speciesID))
end

---@param itemID number
local function OnNewToy(itemID)
    if not LootEnabled() or not CategoryEnabled("toys") then return end
    if not itemID or itemID <= 0 then return end

    local _, name, icon = C_ToyBox.GetToyInfo(itemID)
    if not name or not icon then return end
    if not PlayerHasToy(itemID) then return end

    FireLootToast("toys", name, icon, Collectibles.BuildKey("toy", itemID))
end

local bagCache  = {}
local bagReady  = false

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
---@param myProfsCompiled (fun(props: table): boolean)|nil
local function ConsiderNewCollectible(bag, slot, info, myProfsCompiled)
    local col = Collectibles.GetItemCollectionStatus(info.itemID, info.hyperlink, {
        bagID = bag,
        slotID = slot,
        hyperlink = info.hyperlink,
    })
    if not col or not col.applicable or col.collected then return end

    local category = COLLECTIBLE_CATEGORY[col.type]
    if not category or not CategoryEnabled(category) then return end

    if category == "recipes" and myProfsCompiled then
        local props = PE:BuildProps(info.itemID, bag, slot, info)
        if not PE:SafeEvaluate(myProfsCompiled, props) then return end
    end

    local name = C_Item.GetItemInfo(info.hyperlink or info.itemID)
    local icon = info.iconFileID
    if not name or not icon then return end

    FireLootToast(category, name, icon, col.key)
end

local function ScanBagsForCollectibles()
    if not bagReady then return end
    if not LootEnabled() then return end

    local myProfsCompiled = nil
    if CategoryEnabled("recipes") and GetCfg().recipesOnlyMyProfessions then
        myProfsCompiled = PE:Compile("#myprofs")
    end

    local newCache = {}

    Inventory.ForEachSlot("player", function(bag, slot, info)
        if not (info and info.itemID) then return end
        local guid = GetItemCacheKey(info)
        newCache[guid] = info.itemID

        if not bagCache[guid] then
            ConsiderNewCollectible(bag, slot, info, myProfsCompiled)
        end
    end)

    bagCache = newCache
end

-- ============================================================================
-- Blizzard native-alert suppression
-- ============================================================================
-- The Blizzard NewMount/NewPet/NewToy alert systems route through AlertFrame
-- (events registered on AlertFrame are dispatched to the matching subsystem).
-- Unregistering them here cleanly suppresses the native popups while leaving
-- our own lootFrame's handlers intact, so OneWoW's toast can still fire.
local NATIVE_ALERT_EVENTS = { "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "NEW_TOY_ADDED" }

local function ApplyBlizzardSuppression()
    local should = GetCfg().suppressBlizzardAlerts == true
    for _, ev in ipairs(NATIVE_ALERT_EVENTS) do
        if should then
            AlertFrame:UnregisterEvent(ev)
        else
            AlertFrame:RegisterEvent(ev)
        end
    end
end

Toasts.ApplyBlizzardSuppression = ApplyBlizzardSuppression

-- Login arming, registered by OneWoW_QoL.lua via RegisterLoginHandler (the
-- handler registry only exists once OnAddonLoaded has run, so file-scope
-- registration is not possible here).
ns.ToastLoot = {}
function ns.ToastLoot.OnLogin()
    C_Timer.After(3, BuildBagCache)
    ApplyBlizzardSuppression()
end

local lootFrame = CreateFrame("Frame")
lootFrame:RegisterEvent("NEW_MOUNT_ADDED")
lootFrame:RegisterEvent("NEW_PET_ADDED")
lootFrame:RegisterEvent("NEW_TOY_ADDED")
lootFrame:RegisterEvent("SKILL_LINES_CHANGED")

OneWoW.Inventory.RegisterDelayedCallback("ToastLoot", function()
    ScanBagsForCollectibles()
end)

lootFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "SKILL_LINES_CHANGED" then
        PE:InvalidateKnownProfessions()

    elseif event == "NEW_MOUNT_ADDED" then
        OnNewMount(tonumber(arg1))

    elseif event == "NEW_PET_ADDED" then
        OnNewPet(arg1)

    elseif event == "NEW_TOY_ADDED" then
        OnNewToy(tonumber(arg1))
    end
end)
