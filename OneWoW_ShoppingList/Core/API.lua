local _, ns = ...

-- Public, cross-addon read surface for the ShoppingList hub. ns stays private.
OneWoW_ShoppingList_API = {}

--- Toggle the Shopping List main window.
function OneWoW_ShoppingList_API.Toggle()
    if ns.MainWindow and ns.MainWindow.Toggle then
        ns.MainWindow:Toggle()
    end
end

--- Show the Shopping List main window.
function OneWoW_ShoppingList_API.Show()
    if ns.MainWindow and ns.MainWindow.Show then
        ns.MainWindow:Show()
    end
end

--- Show Shopping List, optionally selecting `listName`.
---@param listName string|nil
function OneWoW_ShoppingList_API.ShowList(listName)
    if listName and listName ~= "" then
        ns.ShoppingList:SetActiveList(listName)
    end
    OneWoW_ShoppingList_API.Show()
end

--- Hide the Shopping List main window.
function OneWoW_ShoppingList_API.Hide()
    if ns.MainWindow and ns.MainWindow.Hide then
        ns.MainWindow:Hide()
    end
end

--- Name of the list currently selected in Shopping List.
---@return string|nil
function OneWoW_ShoppingList_API.GetActiveListName()
    return ns.ShoppingList:GetActiveListName()
end

--- Parent (top-level) list names, favorites first.
---@return string[]
function OneWoW_ShoppingList_API.GetParentListNames()
    return ns.ShoppingList:GetParentLists()
end

--- Merge `{ itemID, quantity }` rows into a list. Quantities add if the item exists.
---@param listName string
---@param items { itemID: number, quantity: number }[]
---@return boolean
function OneWoW_ShoppingList_API.AddItems(listName, items)
    if not listName or type(items) ~= "table" then
        return false
    end
    local sl = ns.ShoppingList
    for i = 1, #items do
        local row = items[i]
        if row and row.itemID then
            sl:AddItemToList(listName, row.itemID, row.quantity or 1)
        end
    end
    return true
end

--- Create an empty named list. Returns false if the name is already used.
---@param name string
---@return boolean
function OneWoW_ShoppingList_API.CreateNamedList(name)
    if not name or name == "" then
        return false
    end
    local ok = ns.ShoppingList:CreateList(name)
    return ok == true
end

--- True when itemID is on any resolved shopping list.
---@param itemID number|string
---@return boolean onList
---@return string[] listNames
function OneWoW_ShoppingList_API.IsOnAnyList(itemID)
    return ns.ShoppingList:IsOnAnyList(itemID)
end

--- True when at least one list still has owned < needed for this itemID.
---@param itemID number|string
---@return boolean
function OneWoW_ShoppingList_API.IsStillNeeded(itemID)
    return ns.ShoppingList:IsStillNeeded(itemID)
end

--- Item IDs that are still short on at least one list (owned < needed).
---@return number[]
function OneWoW_ShoppingList_API.GetStillNeededItemIDs()
    return ns.ShoppingList:GetStillNeededItemIDs()
end

--- Add or update an item on the account-wide Farming List.
---@param itemID number|string
---@param style string|nil ignored; rows are stored as farming
---@param extras table|nil
---@return boolean
function OneWoW_ShoppingList_API.AddFarmItem(itemID, style, extras)
    return ns.FarmList:AddItem(itemID, style, extras)
end

--- Remove an item from the Farming List.
---@param itemID number|string
---@return boolean
function OneWoW_ShoppingList_API.RemoveFarmItem(itemID)
    return ns.FarmList:RemoveItem(itemID)
end

--- Kept for CompSync / older callers. Style is always farming.
---@param itemID number|string
---@param style string
---@return boolean
function OneWoW_ShoppingList_API.SetFarmStyle(itemID, style)
    return ns.FarmList:SetStyle(itemID, style)
end

--- All farm rows, name-sorted.
---@return table[]
function OneWoW_ShoppingList_API.GetFarmItems()
    return ns.FarmList:GetAll()
end

--- True when itemID is on the Farming List. Second return is the style.
---@param itemID number|string
---@return boolean
---@return string|nil style
function OneWoW_ShoppingList_API.IsOnFarmList(itemID)
    return ns.FarmList:IsOnFarmList(itemID)
end

--- Show the Shopping List window on the Farming tab.
function OneWoW_ShoppingList_API.ShowFarming()
    if ns.MainWindow and ns.MainWindow.SetWindowMode then
        ns.MainWindow:SetWindowMode("farming")
    end
    OneWoW_ShoppingList_API.Show()
end

--- Label for the shared Catalog List button.
---@return string
function OneWoW_ShoppingList_API.GetListButtonLabel()
    return ns.L["OWSL_BTN_LIST"]
end

--- Farm / Shopping picker for one item. Shopping opens a submenu of named lists.
---@param owner Frame
---@param itemID number|string
---@param extras table|nil
function OneWoW_ShoppingList_API.ShowAddToListMenu(owner, itemID, extras)
    itemID = tonumber(itemID)
    if not owner or not itemID or itemID <= 0 then
        return
    end
    extras = extras or {}
    local L = ns.L
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle(L["OWSL_BTN_LIST"])
        rootDescription:CreateButton(L["OWSL_MENU_FARM"], function()
            ns.FarmList:AddItem(itemID, "farming", extras)
        end)
        local shopMenu = rootDescription:CreateButton(L["OWSL_TAB_SHOPPING"])
        local names = ns.ShoppingList:GetParentLists()
        if not names or #names == 0 then
            shopMenu:CreateButton(L["OWSL_MAIN_LIST"], function()
                ns.ShoppingList:AddItemToList(ns.MAIN_LIST_KEY, itemID, extras.quantity or 1, extras.notes)
            end)
            return
        end
        for i = 1, #names do
            local listName = names[i]
            shopMenu:CreateButton(listName, function()
                ns.ShoppingList:AddItemToList(listName, itemID, extras.quantity or 1, extras.notes)
            end)
        end
    end)
end
