local _, ns = ...

local OneWoW = OneWoW

local Toasts = OneWoW.Toasts

local GRID_LABELS = {
    tmogs   = "TMogs",
    mounts  = "Mounts",
    pets    = "Pets",
    recipes = "Recipes",
    toys    = "Toys",
    quests  = "Quests",
    housing = "Housing",
}

local TOTAL_ONLY = {
    quests  = true,
    housing = true,
}

local EJ_INSTANCES = nil

local function InstanceEnabled()
    return OneWoW.SettingsFeatureRegistry:IsEnabled("toastalerts", "instances")
end

local function GetCatalogData()
    local api = OneWoW:GetCatalogPackAPI("journal")
    local place = OneWoW.StatusCards:LookupPlace(api)
    local instData = place and place.data
    if not instData then
        return nil
    end

    local keyMap = {
        TMog    = "tmogs",
        Mount   = "mounts",
        Pet     = "pets",
        Toy     = "toys",
        Recipe  = "recipes",
        Quest   = "quests",
        Housing = "housing",
    }
    local counts = {
        tmogs   = { current = 0, total = 0 },
        mounts  = { current = 0, total = 0 },
        pets    = { current = 0, total = 0 },
        recipes = { current = 0, total = 0 },
        toys    = { current = 0, total = 0 },
        quests  = { current = 0, total = 0 },
        housing = { current = 0, total = 0 },
    }

    local raw = place.api.CountPlaceCollectibles(instData)
    for special, row in pairs(raw) do
        local key = keyMap[special]
        if key then
            counts[key] = row
        end
    end

    return counts
end

local function BuildGrid(catalogData)
    if not catalogData then return nil end
    local grid = {}
    local order = {"tmogs", "mounts", "pets", "recipes", "toys", "housing", "quests"}
    for _, key in ipairs(order) do
        local entry = catalogData[key] or { current = 0, total = 0 }
        table.insert(grid, {
            label     = GRID_LABELS[key] or key,
            current   = entry.current or 0,
            total     = entry.total   or 0,
            totalOnly = TOTAL_ONLY[key] or false,
        })
    end
    return grid
end

-- Entering-world arming, registered by OneWoW_QoL.lua via
-- RegisterEnteringWorldHandler (the handler registry only exists once
-- OnAddonLoaded has run, so file-scope registration is not possible here).
ns.ToastInstance = {}
function ns.ToastInstance.OnEnteringWorld()
    if not InstanceEnabled() then return end

    local inInstance, instanceType = IsInInstance()
    if not inInstance then return end
    if instanceType == "pvp" or instanceType == "arena" then return end

    -- build cache of all encounter journal instances
    if not EJ_INSTANCES then
        EJ_INSTANCES = {}
        for tierIndex=1, EJ_GetNumTiers() do
            EJ_SelectTier(tierIndex)
            -- loop once for dungeons and once for raids
            local isRaid = false
            for _=1, 2 do
                local index = 1
                -- there is no API to get the number of instances per tier
                while true do
                    local _, instanceName, _, _, buttonImage1 = EJ_GetInstanceByIndex(index, isRaid)
                    if not instanceName then break end
                    EJ_INSTANCES[instanceName] = buttonImage1
                    index = index + 1
                end
                isRaid = not isRaid
            end
        end
    end
    -- failsafe in case something goes wrong when using the EJ_* APIs
    if not EJ_INSTANCES then return end

    C_Timer.After(3, function()
        if not InstanceEnabled() then return end
        local stillIn, stillType = IsInInstance()
        if not stillIn then return end
        if stillType == "pvp" or stillType == "arena" then return end

        local name, _, _, diffName, _, _, _, instanceID = GetInstanceInfo()
        if not name or name == "" then return end

        if stillType == "neighborhood" then
            diffName = C_HousingNeighborhood.GetNeighborhoodName()
        end

        local catalogData = GetCatalogData()
        local packHint
        if not catalogData and not OneWoW:AreWantedJournalPlacesLoaded() then
            packHint = OneWoW.L["STATUSCARD_ZONES_NOT_LOADED"]
        end

        Toasts.FireToast({
            toastType     = "instance",
            title         = name,
            subtitle      = diffName or "",
            icon          = EJ_INSTANCES[name],
            grid          = BuildGrid(catalogData),
            packHint      = packHint,
            instanceMapID = instanceID,
        })
    end)
end
