local _, ns = ...

-- Public, cross-addon read surface for the Catalog hub. ns stays private.
OneWoW_Catalog_API = {}

--- Returns Catalog's shared asynchronous item-data loader.
---@return table loader
function OneWoW_Catalog_API.GetItemDataLoader()
    return ns.GetItemDataLoader()
end

--- Look up a cached item name from Catalog's item cache.
---@param itemID number
---@return string|nil
function OneWoW_Catalog_API.GetCachedItemName(itemID)
    return ns.GetCachedItemName(itemID)
end

--- Record an item name into Catalog's item cache.
---@param itemID number
---@param itemName string
---@return boolean changed
function OneWoW_Catalog_API.RememberItemName(itemID, itemName)
    return ns.RememberItemName(itemID, itemName)
end

--- Toggle the Catalog module in the suite hub.
function OneWoW_Catalog_API.Toggle()
    OneWoW.UI:Toggle()
end

--- Open the item search tab, optionally focused on one item.
---@param itemID number|nil
---@param itemName string|nil
---@param retryCount number|nil
function OneWoW_Catalog_API.OpenItemSearch(itemID, itemName, retryCount)
    if ns.UI and ns.UI.OpenItemSearch then
        ns.UI.OpenItemSearch(itemID, itemName, retryCount)
    end
end

--- Open the quests tab focused on a quest.
---@param questID number
function OneWoW_Catalog_API.OpenQuest(questID)
    if ns.UI and ns.UI.OpenQuest then
        ns.UI.OpenQuest(questID)
    end
end

--- Open the quests tab with zone and/or NPC filters applied.
---@param opts { zoneName?: string, npcID?: number, npcName?: string }
function OneWoW_Catalog_API.OpenQuestsFiltered(opts)
    if ns.UI and ns.UI.OpenQuestsFiltered then
        ns.UI.OpenQuestsFiltered(opts)
    end
end

--- Open the NPCs tab focused on a creature. Creates the card when missing.
---@param npcID number
---@param npcInfo table|nil
function OneWoW_Catalog_API.OpenToVendor(npcID, npcInfo)
    if ns.UI and ns.UI.OpenToVendor then
        ns.UI.OpenToVendor(npcID, npcInfo)
    end
end

--- Open the NPCs tab for a zone or city card (Current Zone Only off).
---@param spec { zoneName?: string, uiMapID?: number, expansionID?: number }
function OneWoW_Catalog_API.OpenVendorsForZone(spec)
    if ns.UI and ns.UI.OpenVendorsForZone then
        ns.UI.OpenVendorsForZone(spec)
    end
end

--- Open the Zones (Journal) tab on a place. Number is mapID; table may carry
--- instanceID / placeKey / encounterID.
---@param spec number|table
function OneWoW_Catalog_API.OpenToInstance(spec)
    if ns.UI and ns.UI.OpenToInstance then
        ns.UI.OpenToInstance(spec)
    end
end

--- Refresh the quests list when the quests tab UI is loaded.
function OneWoW_Catalog_API.RefreshQuestsList()
    if ns.UI and ns.UI.RefreshQuestsList then
        ns.UI.RefreshQuestsList(true)
    end
end

--- Resolve a pack role or addon name to the CatDB addon Catalog will load.
---@param roleOrName string
---@return string|nil
function OneWoW_Catalog_API.ResolveCatalogPack(roleOrName)
    return OneWoW:ResolveCatalogPack(roleOrName)
end

--- Cross-unit API table for the resolved pack (`AddonName_API`).
---@param roleOrName string
---@return table|nil
function OneWoW_Catalog_API.GetCatalogPackAPI(roleOrName)
    return OneWoW:GetCatalogPackAPI(roleOrName)
end

--- EnsureLoaded the resolved pack. Explicit user actions only.
---@param roleOrName string
---@return string|nil
function OneWoW_Catalog_API.EnsureCatalogPack(roleOrName)
    return OneWoW:EnsureCatalogPack(roleOrName)
end

--- Shared List button: Farm / Want / Shopping via OneWoW_ShoppingList_API.
---@param parent Frame
---@param itemID number|string
---@param extras table|nil
---@return Button|nil
function ns.AttachListButton(parent, itemID, extras)
    itemID = tonumber(itemID)
    if not parent or not itemID or itemID <= 0 then
        return nil
    end
    extras = extras or {}
    local api = OneWoW_ShoppingList_API
    if not api or not api.ShowAddToListMenu then
        return nil
    end
    local btn = parent._listBtn
    if not btn then
        btn = OneWoW_GUI:CreateFitTextButton(parent, {
            text = api.GetListButtonLabel and api.GetListButtonLabel() or "",
            height = 18,
            minWidth = 36,
            paddingX = 8,
        })
        parent._listBtn = btn
        btn:SetScript("OnClick", function(self)
            if OneWoW_ShoppingList_API and OneWoW_ShoppingList_API.ShowAddToListMenu then
                OneWoW_ShoppingList_API.ShowAddToListMenu(self, self._itemID, self._extras)
            end
        end)
    elseif api.GetListButtonLabel then
        btn:SetFitText(api.GetListButtonLabel())
    end
    btn._itemID = itemID
    btn._extras = extras
    btn:ClearAllPoints()
    btn:SetPoint(extras.point or "RIGHT", extras.relativeTo or parent, extras.relativePoint or extras.point or "RIGHT", extras.x or -6, extras.y or 0)
    btn:Show()
    return btn
end
