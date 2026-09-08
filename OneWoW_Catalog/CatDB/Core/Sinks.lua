local _, ns = ...

local CatalogData = OneWoW.CatalogData

local function InvalidatePlaceLookups()
    OneWoW_CatDB_ZoneDB_API.InvalidateDataLookups()
end

local function PlacePayload(payload)
    if type(payload) ~= "table" then
        return
    end
    if payload.places then
        ns:RegisterPlaceData(payload.places)
    end
    if payload.encounters then
        ns:RegisterEncounterData(payload.encounters)
    end
    InvalidatePlaceLookups()
end

CatalogData:SetSink("hubs", PlacePayload)
CatalogData:SetSink("zone", PlacePayload)
CatalogData:SetSink("zone_extra", function(payload)
    if type(payload) == "table" then
        if payload.encounters then
            ns:RegisterEncounterData(payload.encounters)
        else
            ns:RegisterEncounterData(payload)
        end
        InvalidatePlaceLookups()
    end
end)
CatalogData:SetSink("npc", function(payload)
    ns:RegisterNpcData(payload)
end)
CatalogData:SetSink("quest", function(payload)
    ns:RegisterQuestData(payload)
end)
CatalogData:SetSink("item", function(payload)
    ns:RegisterItemData(payload)
end)
CatalogData:SetSink("achievement", function(payload)
    if type(payload) == "table" then
        ns:RegisterItemAchievementData(payload)
    end
end)
CatalogData:SetSink("mappin", function(payload, addon)
    local pins = payload
    if type(payload) == "table" and payload.pins then
        pins = payload.pins
    end
    CatalogData.shippedPins[addon] = pins or {}
end)
