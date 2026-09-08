local _, ns = ...

-- Public, cross-addon read surface for the DevTool hub. ns stays private.
OneWoW_Utility_DevTool_API = {}

--- Toggle the DevTool main window.
function OneWoW_Utility_DevTool_API.Toggle()
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    elseif ns.ToggleMainWindow then
        ns:ToggleMainWindow()
    end
end

--- Show the DevTool main window.
function OneWoW_Utility_DevTool_API.Show()
    if ns.UI and ns.UI.Show then
        ns.UI:Show()
    end
end

--- Hide the DevTool main window.
function OneWoW_Utility_DevTool_API.Hide()
    if ns.UI and ns.UI.Hide then
        ns.UI:Hide()
    end
end

--- Open DevTool focused on the Errors tab (keybinding target).
function OneWoW_Utility_DevTool_API.OpenDevToolErrorsTab()
    if ns.OpenDevToolErrorsTab then
        ns:OpenDevToolErrorsTab()
    end
end

--- Whether the error logger has errors in the current session (feature-icon tint).
---@return boolean
function OneWoW_Utility_DevTool_API.HasCurrentSessionErrors()
    if ns.ErrorLogger and ns.ErrorLogger.HasCurrentSessionErrors then
        return ns.ErrorLogger:HasCurrentSessionErrors()
    end
    return false
end
