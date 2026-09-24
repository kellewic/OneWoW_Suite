local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L
local Location = OneWoW.Location
local C_Timer = C_Timer

local collapsed = {}

local function PlaceDesc(content, text, width)
    local fs = OneWoW_GUI:CreateFS(content, 12)
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetSpacing(2)
    if width and width >= 1 then
        fs:SetWidth(width)
    else
        fs:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    end
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    return -((fs:GetStringHeight() or 14) + 10)
end

function ns.UI.CreateWaypointsTab(parent)
    local _, content = OneWoW_GUI:CreateScrollFrame(parent, { name = "OneWoW_QoL_WaypointsScroll" })

    local function Paint()
        OneWoW_GUI:ClearFrame(content)
        local stack = OneWoW_GUI:CreateCardStack(content, {
            getCollapsed = function(key) return collapsed[key] end,
            setCollapsed = function(key, on) collapsed[key] = on end,
        })

        stack:AddCard("arrow", L["WAYPOINT_ARROW"], function(cardContent, w)
            local y = PlaceDesc(cardContent, L["WAYPOINTS_CARD_DESC"], w)
            for _, provider in ipairs(Location.GetProviders()) do
                local opts = {
                    displayName = L[provider.nameKey],
                    isDetected = function()
                        return Location.IsProviderAvailable(provider.id)
                    end,
                    notDetectedText = L["OVR_INT_NOT_DETECTED"],
                    enabledText = L["FEATURE_ENABLED"],
                    disabledText = L["FEATURE_DISABLED"],
                    isEnabled = function()
                        return Location.GetActiveProvider() == provider.id
                    end,
                    onToggle = function(newState)
                        if newState then
                            Location.SetProvider(provider.id)
                        elseif provider.id ~= "blizzard" then
                            Location.SetProvider("blizzard")
                        end
                        C_Timer.After(0, Paint)
                    end,
                }
                local row = OneWoW_GUI:CreateIntegrationRow(cardContent, opts)
                row:SetPoint("TOPLEFT", cardContent, "TOPLEFT", 0, y)
                row:SetPoint("TOPRIGHT", cardContent, "TOPRIGHT", 0, y)
                y = y - 34
            end
            return math.abs(y)
        end)

        stack:Finish()
        local height = 0
        for _, frame in ipairs(stack.items) do
            height = height + (frame:GetHeight() or 0) + 8
        end
        content:SetHeight(math.max(height + 20, 120))
    end

    parent:HookScript("OnShow", Paint)
    Paint()
end
