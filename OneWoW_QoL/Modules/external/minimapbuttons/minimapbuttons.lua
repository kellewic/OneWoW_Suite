local _, ns = ...

local MinimapButtonsModule, L = ns.ModuleRegistry:Current()
if not MinimapButtonsModule then return end

local OneWoW_GUI = OneWoW_GUI

-- ─── Raw UIParent methods (bypass noop overrides when positioning buttons) ──

local RawClearAllPoints      = UIParent.ClearAllPoints
local RawSetPoint            = UIParent.SetPoint
local RawSetScale            = UIParent.SetScale
local RawSetParent           = UIParent.SetParent
local RawSetAlpha            = UIParent.SetAlpha
local RawSetFrameStrata      = UIParent.SetFrameStrata
local RawSetFrameLevel       = UIParent.SetFrameLevel
local RawSetFixedFrameStrata = UIParent.SetFixedFrameStrata
local RawSetFixedFrameLevel  = UIParent.SetFixedFrameLevel

local IS_RETAIL = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

-- ─── Constants ──────────────────────────────────────────────────────────────

local CONTAINER_STRATA = "MEDIUM"
local CONTAINER_LEVEL  = 7

-- ─── State ──────────────────────────────────────────────────────────────────

local hubButton        = nil
local containerFrame   = nil
local hiddenContainer  = nil          -- parent for buttons whose pref is "hide"
local collectedButtons = {}
local collectedNames   = {}
local collectedMap     = {}
local hiddenButtons    = {}           -- [frame] = true for currently-hidden buttons
-- Dual-display ("Also Show on Minimap"): when on, real buttons stay on the
-- minimap and the panel shows these lightweight proxy icons that forward clicks.
local proxyButtons     = {}           -- array of proxy frames shown in the panel
local proxyByName      = {}           -- [frameName] = proxy frame
local enhancedRow      = {}
local enhancedBuiltCount = 0          -- #_loadedComponents the row was last built from
local searchBox        = nil
local searchFilter     = ""
local autoCloseTimer   = nil
local _layouting       = false
local _relayoutTimer   = nil
local _compartmentHooksRegistered = false
local _minimapFadeHooks = false

-- ─── Blizzard frames that must never be collected ───────────────────────────

local BLIZZARD_SKIP = {
    MiniMapMailFrame                    = true,
    MinimapZoomIn                       = true,
    MinimapZoomOut                      = true,
    MiniMapTracking                     = true,
    MinimapBackdrop                     = true,
    GameTimeFrame                       = true,
    TimeManagerClockButton              = true,
    GarrisonLandingPageMinimapButton    = true,
    QueueStatusMinimapButton            = true,
    MinimapZoneTextButton               = true,
    AddonCompartmentFrame               = true,
    ExpansionLandingPageMinimapButton   = true,
    MinimapCluster                      = true,
    MinimapCompassTexture               = true,
}

local OWN_BUTTON_NAME = "OneWoW_QoL_MMBtnCollector"

-- ─── Helpers ────────────────────────────────────────────────────────────────

local noop = function(...) end

local function ScheduleRelayout()
    if _relayoutTimer then
        _relayoutTimer:Cancel()
    end
    _relayoutTimer = C_Timer.NewTimer(0.15, function()
        _relayoutTimer = nil
        if containerFrame and containerFrame:IsShown() then
            MinimapButtonsModule:LayoutContainer()
        end
    end)
end

local function GetSettings()
    local s = ns.ModuleRegistry:GetModuleBucket("minimapbuttons")
    if s.closeMode       == nil then s.closeMode       = "autoclose" end
    if s.autoCloseDelay  == nil then s.autoCloseDelay  = 3           end
    if s.enhancedMenu    == nil then s.enhancedMenu    = false       end
    if s.enhancedMail     == nil then s.enhancedMail     = true        end
    if s.enhancedSettings == nil then s.enhancedSettings = true        end
    if s.enhancedPortals  == nil then s.enhancedPortals  = true        end
    -- Exclusive per-icon list for the OneWoW launcher row. Missing ids default
    -- to shown. First load copies the old Mail / Settings / Portals checkboxes.
    if not s.enhancedTiles then
        s.enhancedTiles = {
            settings = s.enhancedSettings ~= false,
            portals = s.enhancedPortals ~= false,
            OneWoW_Mail = s.enhancedMail ~= false,
        }
    end
    if s.maxColumns      == nil then s.maxColumns      = 6           end
    if s.maxRows         == nil then s.maxRows         = 0           end
    if s.buttonSize      == nil then s.buttonSize      = 34          end
    if s.buttonSpacing   == nil then s.buttonSpacing   = 2           end
    if s.buttonScale     == nil then s.buttonScale     = 10          end
    if s.locked          == nil then s.locked          = false       end
    if s.growDirection   == nil then s.growDirection    = "down"      end
    if s.alsoShowOnMinimap == nil then s.alsoShowOnMinimap = false    end
    if s.proxyPos        == nil then s.proxyPos        = {}          end
    if s.showTooltips    == nil then s.showTooltips    = true        end

    -- The old text-input whitelist / blacklist never worked reliably (see the
    -- bug report that triggered this rewrite). Drop them on first load so
    -- users don't carry around stale entries.
    s.whitelist        = nil
    s.blacklist        = nil
    s.mbbWhitelistSeed = nil

    -- Unified per-button preference model with three states:
    --
    --   "mini" — collected into the OneWoW panel (default for new entries)
    --   "map"  — left on the minimap (button stays where the addon put it)
    --   "hide" — hidden entirely (reparented to an offscreen hidden frame)
    --
    -- The DB remembers the user's choice across sessions so addons being
    -- temporarily disabled don't reset their preference.
    --
    --   s.buttons[frameName] = {
    --       pref        = "mini" | "map" | "hide",
    --       seen        = boolean,
    --       displayName = string,
    --   }
    if not s.buttons then s.buttons = {} end

    -- One-shot schema upgrade. v1 was the binary "show" / "hide" pair shipped
    -- briefly between this and the previous rewrite; map it onto the ternary
    -- "mini" / "map" / "hide" so "hide" doesn't silently change meaning.
    if (s.buttonsSchema or 1) < 2 then
        for _, info in pairs(s.buttons) do
            if info.pref == "show" then
                info.pref = "mini"
            elseif info.pref == "hide" then
                info.pref = "map"
            end
        end
        s.buttonsSchema = 2
    end

    return s
end

MinimapButtonsModule.GetSettings = GetSettings

-- Disabling tears down hooks/parenting; LibDBIcon + square minimap need a full UI reload to behave (same class of issue as Leatrix/minimap shape).
local function ShowDisableReloadDialog()
    local d = StaticPopupDialogs["ONEWOW_MMBTNS_RELOAD"]
    if not d then
        StaticPopupDialogs["ONEWOW_MMBTNS_RELOAD"] = {
            text = "",
            button1 = ACCEPT,
            button2 = CANCEL,
            OnAccept = ReloadUI,
            OnCancel = function()
                print("|cFFFFD100OneWoW QoL:|r " .. (L["MMBTNS_DISABLE_RELOAD_CHAT"]))
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        d = StaticPopupDialogs["ONEWOW_MMBTNS_RELOAD"]
    end
    d.text = L["MMBTNS_DISABLE_RELOAD_TEXT"]
        or "Disabling this feature requires a UI reload to restore minimap buttons.\n\nReload now?"
    d.button1 = L["MMBTNS_DISABLE_RELOAD_BTN"]
    StaticPopup_Show("ONEWOW_MMBTNS_RELOAD")
end

-- ─── Per-button preference model ────────────────────────────────────────────

-- Derive a friendly UI label from a raw frame name. LibDBIcon frames follow
-- "LibDBIcon10_<Addon>" so the addon name shows up cleanly in the settings
-- list. Anything else falls back to the raw frame name.
local function MakeDisplayName(frameName, hint)
    if type(hint) == "string" and hint ~= "" and not hint:find("^LibDBIcon10_") then
        return hint
    end
    if type(frameName) ~= "string" then return tostring(frameName or "?") end
    local addonName = frameName:match("^LibDBIcon10_(.+)$")
    if addonName then return addonName end
    return frameName
end

local VALID_PREFS = { mini = true, map = true, hide = true }

local function RegisterDetectedButton(frameName, hint)
    if not frameName or frameName == "" then return end
    if BLIZZARD_SKIP[frameName] or frameName == OWN_BUTTON_NAME then return end
    local s = GetSettings()
    local info = s.buttons[frameName]
    if not info then
        info = { pref = "mini", seen = true, displayName = MakeDisplayName(frameName, hint) }
        s.buttons[frameName] = info
    else
        info.seen = true
        if not VALID_PREFS[info.pref] then info.pref = "mini" end
        -- Refresh displayName if it was previously missing or if the new hint
        -- is more user-friendly than what we had.
        local better = MakeDisplayName(frameName, hint)
        if not info.displayName or info.displayName == "" or info.displayName == frameName then
            info.displayName = better
        end
    end
end

local function GetButtonPref(frameName)
    if not frameName then return "mini" end
    local s = GetSettings()
    local info = s.buttons[frameName]
    if info and VALID_PREFS[info.pref] then return info.pref end
    return "mini"
end

local function SetButtonPref(frameName, pref)
    if not frameName or not VALID_PREFS[pref] then return end
    local s = GetSettings()
    local info = s.buttons[frameName]
    if not info then
        info = { pref = pref, seen = false, displayName = MakeDisplayName(frameName) }
        s.buttons[frameName] = info
    else
        info.pref = pref
    end
end

local function RemoveKnownButton(frameName)
    if not frameName then return end
    local s = GetSettings()
    s.buttons[frameName] = nil
end

local function ResetAllSeenFlags()
    local s = GetSettings()
    for _, info in pairs(s.buttons) do
        info.seen = false
    end
end

MinimapButtonsModule.MakeDisplayName       = MakeDisplayName
MinimapButtonsModule.RegisterDetectedButton = RegisterDetectedButton
MinimapButtonsModule.GetButtonPref          = GetButtonPref
MinimapButtonsModule.SetButtonPref          = SetButtonPref
MinimapButtonsModule.RemoveKnownButton      = RemoveKnownButton

local function GetCurrentIcon()
    return OneWoW_GUI:GetBrandIcon(OneWoW_GUI:GetSetting("minimap.theme"))
end

-- ─── Hub button position (free-floating on UIParent) ────────────────────────

local function SaveHubPosition()
    if not hubButton then return end
    local s = GetSettings()
    local point, _, relPoint, x, y = hubButton:GetPoint()
    if point then
        s.hubPosition = { point = point, relativePoint = relPoint, x = x, y = y }
    end
end

local function RestoreHubPosition()
    if not hubButton then return end
    local s = GetSettings()
    if s.hubPosition then
        hubButton:ClearAllPoints()
        hubButton:SetPoint(s.hubPosition.point, UIParent, s.hubPosition.relativePoint,
            s.hubPosition.x, s.hubPosition.y)
    else
        hubButton:ClearAllPoints()
        hubButton:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -200)
    end
end

-- ─── Button Detection (aligned with MinimapButtonButton Logic/Main.lua) ─────

local function isValidFrame(frame)
    return type(frame) == "table" and frame.IsObjectType and frame:IsObjectType("Frame")
end

local function isTomCatsButton(frameName)
    return frameName:match("^TomCats%-") ~= nil
end

local function nameEndsWithNumber(frameName)
    return frameName:match("%d$") ~= nil
end

local function nameMatchesButtonPattern(frameName)
    local patterns = {
        "^LibDBIcon10_",
        "MinimapButton",
        "MinimapFrame",
        "MinimapIcon",
        "[-_]Minimap[-_]",
        "Minimap$",
    }
    for _, pattern in ipairs(patterns) do
        if frameName:match(pattern) then return true end
    end
    return false
end

local function isMinimapButton(frame)
    local frameName = frame and frame.GetName and frame:GetName()
    if not frameName then return false end

    if issecurevariable and _G[frameName] and issecurevariable(_G, frameName) then
        return false
    end

    if isTomCatsButton(frameName) then return true end
    if nameEndsWithNumber(frameName) then return false end

    return nameMatchesButtonPattern(frameName)
end

local function updateLayoutIfVisibilityChanged(frame)
    if not frame or not frame._OneWoWMBBCollected then return end
    -- During LayoutContainer we Hide() every collected button; hooksecurefunc would
    -- set collectedMap to false and FilteredButtons() would drop all icons (empty panel).
    if _layouting then return end
    local visibility = frame:IsShown()
    if collectedMap[frame] ~= visibility then
        collectedMap[frame] = visibility
        ScheduleRelayout()
    end
end

-- Parent hide (e.g. closing the collector) can fire Hide on children and poison
-- collectedMap; reset when reopening or after addon compartment toggles.
local function ResetCollectedVisibilityMap()
    for _, btn in ipairs(collectedButtons) do
        if btn and btn._OneWoWMBBCollected then
            collectedMap[btn] = true
        end
    end
end

-- Match Leatrix Plus / LibDBIcon: square minimap uses a small radius; round uses full orbit.
local function SyncLibDBIconRadiusToMinimapShape()
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if not lib or not lib.SetButtonRadius then return end
    local shape = "ROUND"
    if GetMinimapShape then
        shape = GetMinimapShape() or "ROUND"
    end
    if type(shape) == "string" and strupper(shape) == "SQUARE" then
        lib:SetButtonRadius(0.165)
    else
        lib:SetButtonRadius(1)
    end
end

local function LibDBIconNotifyRestored(frame)
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if not lib or not frame then return end
    local list = lib.GetButtonList and lib:GetButtonList()
    if not list then return end
    for _, n in ipairs(list) do
        if type(n) == "string" then
            local btn = lib.GetMinimapButton and lib:GetMinimapButton(n)
            if btn == frame then
                if type(lib.Show) == "function" then
                    pcall(lib.Show, lib, n)
                end
                break
            end
        end
    end
end

local function RefreshAllLibDBIcons()
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if not lib or not lib.GetButtonList or not lib.Show then return end
    SyncLibDBIconRadiusToMinimapShape()
    local list = lib:GetButtonList()
    if not list then return end
    for _, n in ipairs(list) do
        pcall(lib.Show, lib, n)
    end
end

-- ─── Button Collection (MBB-style: reparent, raw scale, hooksecurefunc Show/Hide)

local function ApplyCollectedButtonScale(frame)
    local s = GetSettings()
    local scale = (s.buttonScale or 10) / 10
    if scale > 0 then
        RawSetScale(frame, scale)
    end
end

function MinimapButtonsModule:ApplyButtonScale()
    for _, frame in ipairs(collectedButtons) do
        if frame and frame._OneWoWMBBCollected then
            ApplyCollectedButtonScale(frame)
        end
    end
    self:LayoutContainer()
end

-- LibDBIcon ShowOnEnter (and Mini Tools "Hide Addon Icons") plays a C-side
-- Alpha animation (fadeOut) when the mouse leaves the minimap or any LDB
-- button. SetAlpha = noop does not stop that, so collected icons appeared
-- then faded out. Clear the mouseover flag and stop the group while collected.
---@param frame table
local function SuppressLibDBIconMouseoverFade(frame)
    if frame.showOnMouseover then
        frame._OneWoWMBBStashedShowOnMouseover = true
        frame.showOnMouseover = false
    end
    if frame.fadeOut and frame.fadeOut.Stop then
        frame.fadeOut:Stop()
    end
end

local function RestoreLibDBIconMouseoverFade(frame)
    if frame._OneWoWMBBStashedShowOnMouseover then
        frame.showOnMouseover = true
        frame._OneWoWMBBStashedShowOnMouseover = nil
    end
end

-- LibDBIcon OnEnter/OnLeave fades every showOnMouseover button, not just
-- the one under the cursor. Re-pin the whole collected set after those run.
local function PinAllCollectedLibDBIconFades()
    for _, btn in ipairs(collectedButtons) do
        if btn and btn._OneWoWMBBCollected then
            SuppressLibDBIconMouseoverFade(btn)
            RawSetAlpha(btn, 1)
        end
    end
end

-- Mini Tools reapplies ShowOnEnter from its hide-addon-icons toggle. Call after
-- collect / uncollect so map-pref buttons pick up that fade again and panel
-- buttons stay excluded.
local function SyncMiniToolsHideAddonIcons()
    if not ns.ModuleRegistry:IsEnabled("map_mini_tools") then return end
    local mtm = ns.ModuleRegistry:GetById("map_mini_tools")
    if mtm then
        mtm:ApplyHideAddonIcons()
    end
end

-- Force a collected button's stacking + visibility to our panel's values via the
-- Raw* UIParent methods, bypassing both any fixed-frame locks a rival collector
-- set and our own noop'd instance methods. Clears the SetFixedFrame* locks first
-- (otherwise strata/level assignments are silently dropped), then pins the button
-- above the container backdrop at full alpha.
---@param frame table
local function PinCollectedStacking(frame)
    RawSetFixedFrameStrata(frame, false)
    RawSetFixedFrameLevel(frame, false)
    RawSetFrameStrata(frame, CONTAINER_STRATA)
    RawSetFrameLevel(frame, CONTAINER_LEVEL + 2)
    SuppressLibDBIconMouseoverFade(frame)
    RawSetAlpha(frame, 1)
end

local function CollectButton(frame)
    local name = frame:GetName()
    if not name or collectedNames[name] then return end

    local origEnter = frame:GetScript("OnEnter")
    local origLeave = frame:GetScript("OnLeave")

    collectedNames[name] = true
    frame._OneWoWMBBCollected = true

    frame:SetParent(containerFrame)
    PinCollectedStacking(frame)
    -- Stash the button's own drag handlers so Map / uncollect can restore them;
    -- otherwise the icon is stuck undraggable once it has been collected.
    frame._OneWoWMBBOrigDragStart = frame:GetScript("OnDragStart")
    frame._OneWoWMBBOrigDragStop  = frame:GetScript("OnDragStop")
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
    if frame.SetIgnoreParentScale then
        frame:SetIgnoreParentScale(false)
    end
    ApplyCollectedButtonScale(frame)

    -- Seize every mutator a rival collector uses to fight us. We already blocked
    -- position (Parent/Point/Scale); the visibility + stacking group closes the
    -- rest. EllesmereUI's minimap flyout, for example, hard-locks strata/level
    -- via SetFixedFrame* and forces SetAlpha(0) on buttons it sweeps — which left
    -- our collected icons transparent-but-clickable. With the instance methods
    -- noop'd, no addon can override our layout while the button is collected; we
    -- drive the real values through the Raw* UIParent methods. Show/Hide stay
    -- hooked (not blocked) so genuine visibility changes still reflow the panel.
    frame.ClearAllPoints      = noop
    frame.SetPoint            = noop
    frame.SetParent           = noop
    frame.SetScale            = noop
    frame.SetAlpha            = noop
    frame.SetFrameStrata      = noop
    frame.SetFrameLevel       = noop
    frame.SetFixedFrameStrata = noop
    frame.SetFixedFrameLevel  = noop

    if not frame._OneWoWMBBShowHooked then
        hooksecurefunc(frame, "Show", function()
            updateLayoutIfVisibilityChanged(frame)
        end)
        hooksecurefunc(frame, "Hide", function()
            updateLayoutIfVisibilityChanged(frame)
        end)
        frame._OneWoWMBBShowHooked = true
    end

    frame._OneWoWMBBOrigEnter = origEnter
    frame._OneWoWMBBOrigLeave = origLeave
    frame:SetScript("OnEnter", function(self)
        if frame._OneWoWMBBOrigEnter then frame._OneWoWMBBOrigEnter(self) end
        PinAllCollectedLibDBIconFades()
        if not GetSettings().showTooltips then
            GameTooltip:Hide()
        end
    end)
    frame:SetScript("OnLeave", function(self)
        if frame._OneWoWMBBOrigLeave then frame._OneWoWMBBOrigLeave(self) end
        PinAllCollectedLibDBIconFades()
        if not GetSettings().showTooltips then
            GameTooltip:Hide()
        end
    end)

    table.insert(collectedButtons, frame)
    collectedMap[frame] = frame:IsShown()
end

local function UncollectButton(frame)
    frame._OneWoWMBBCollected = false
    local n = frame:GetName()
    if n then
        collectedNames[n] = nil
    end
    collectedMap[frame] = nil

    -- Release every mutator we seized in CollectButton (revert to the metatable
    -- method), then reset the values we forced so the button behaves normally
    -- back on the minimap.
    frame.ClearAllPoints      = nil
    frame.SetPoint            = nil
    frame.SetParent           = nil
    frame.SetScale            = nil
    frame.SetAlpha            = nil
    frame.SetFrameStrata      = nil
    frame.SetFrameLevel       = nil
    frame.SetFixedFrameStrata = nil
    frame.SetFixedFrameLevel  = nil
    RawSetScale(frame, 1)
    RawSetAlpha(frame, 1)
    RestoreLibDBIconMouseoverFade(frame)

    frame:SetScript("OnEnter", frame._OneWoWMBBOrigEnter)
    frame:SetScript("OnLeave", frame._OneWoWMBBOrigLeave)
    frame._OneWoWMBBOrigEnter = nil
    frame._OneWoWMBBOrigLeave = nil

    -- Restore the button's own drag handlers so it can be repositioned on the
    -- minimap again (LibDBIcon and most addons drive dragging through these).
    frame:SetScript("OnDragStart", frame._OneWoWMBBOrigDragStart)
    frame:SetScript("OnDragStop", frame._OneWoWMBBOrigDragStop)
    frame._OneWoWMBBOrigDragStart = nil
    frame._OneWoWMBBOrigDragStop = nil

    -- Drop layout anchors from the collector grid; otherwise icons stay where the panel was.
    RawClearAllPoints(frame)
    frame:SetParent(Minimap)
    if frame.Show then frame:Show() end
    LibDBIconNotifyRestored(frame)
end

-- Locate frame for `frameName` regardless of whether we're already holding
-- it. Walks our own collected/hidden tables first (fastest), then falls back
-- to LibDBIcon, LibMapButton, Minimap children, and finally _G.
local function FindButtonFrame(frameName)
    if not frameName then return nil end

    for _, btn in ipairs(collectedButtons) do
        if btn and btn.GetName and btn:GetName() == frameName then
            return btn
        end
    end
    for btn in pairs(hiddenButtons) do
        if btn and btn.GetName and btn:GetName() == frameName then
            return btn
        end
    end

    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib and lib.GetButtonList then
        local list = lib:GetButtonList()
        if list then
            for _, n in ipairs(list) do
                if type(n) == "string" then
                    local btn = lib.GetMinimapButton and lib:GetMinimapButton(n)
                    if btn and btn.GetName and btn:GetName() == frameName then
                        return btn
                    end
                end
            end
        end
    end

    local libMap = LibStub and LibStub("LibMapButton-1.1", true)
    if libMap and libMap.buttons then
        for _, btn in pairs(libMap.buttons) do
            if btn and btn.GetName and btn:GetName() == frameName then
                return btn
            end
        end
    end

    local parents = { Minimap, MinimapBackdrop, MinimapCluster }
    for _, parent in ipairs(parents) do
        if parent and parent.GetChildren then
            for _, child in ipairs({ parent:GetChildren() }) do
                if child and child.GetName and child:GetName() == frameName then
                    return child
                end
            end
        end
    end

    local g = _G[frameName]
    if type(g) == "table" and g.GetObjectType then
        return g
    end
    return nil
end

local function UncollectByName(frameName)
    for i = #collectedButtons, 1, -1 do
        local btn = collectedButtons[i]
        if btn and btn.GetName and btn:GetName() == frameName then
            tremove(collectedButtons, i)
            UncollectButton(btn)
            return btn
        end
    end
    return nil
end

-- Hidden buttons live as children of an offscreen, permanently :Hide()-ed
-- frame. Children of a hidden parent never render even if their own :Show()
-- has been called, so we don't need to fight the owning addon every frame.
local function EnsureHiddenContainer()
    if hiddenContainer then return hiddenContainer end
    hiddenContainer = CreateFrame("Frame", "OneWoW_QoL_MMBtnHidden", UIParent)
    hiddenContainer:SetSize(1, 1)
    hiddenContainer:Hide()
    return hiddenContainer
end

local function HideButton(frame)
    if not frame or hiddenButtons[frame] then return end
    EnsureHiddenContainer()

    -- Stash originals so we can put them back when the user switches pref.
    -- _OneWoWMBBOrigShow is unused right now (the hidden parent is enough)
    -- but kept as a marker for future swap-back logic.
    frame._OneWoWMBBHidden = true

    -- The addon may still call SetParent on its own button; noop it so we
    -- don't lose the hidden parent. Restored in UnhideButton.
    frame.SetParent = noop
    frame.ClearAllPoints = noop
    frame.SetPoint = noop

    RawClearAllPoints(frame)
    RawSetParent(frame, hiddenContainer)
    if frame.Hide then frame:Hide() end

    hiddenButtons[frame] = true
end

local function UnhideButton(frame)
    if not frame or not hiddenButtons[frame] then return end

    frame.SetParent = nil
    frame.ClearAllPoints = nil
    frame.SetPoint = nil
    frame._OneWoWMBBHidden = nil

    RawClearAllPoints(frame)
    frame:SetParent(Minimap)
    if frame.Show then frame:Show() end

    hiddenButtons[frame] = nil
    LibDBIconNotifyRestored(frame)
end

-- ─── Dual-display proxies (Also Show on Minimap) ────────────────────────────
--
-- The real button is collected into the panel as normal (100% the same look,
-- tooltip, and clicks there). When "Also Show on Minimap" is on we additionally
-- place a lightweight proxy back on the minimap edge that mirrors the icon and
-- forwards clicks/tooltips to the collected real.

local PROXY_SIZE = 31

-- Best-effort icon lookup for an arbitrary minimap button: LibDBIcon exposes
-- `.icon`; otherwise grab the first textured layer; fall back to a placeholder.
local function ExtractButtonIcon(frame)
    if frame.icon and frame.icon.GetTexture then
        local t = frame.icon:GetTexture()
        if t then return t end
    end
    if frame.GetRegions then
        for _, r in ipairs({ frame:GetRegions() }) do
            if r and r.GetObjectType and r:GetObjectType() == "Texture" then
                local t = r:GetTexture()
                if t then return t end
            end
        end
    end
    return "Interface\\ICONS\\INV_Misc_QuestionMark"
end

local function RemoveProxy(frameName)
    local proxy = proxyByName[frameName]
    if not proxy then return end
    proxyByName[frameName] = nil
    for i = #proxyButtons, 1, -1 do
        if proxyButtons[i] == proxy then
            tremove(proxyButtons, i)
            break
        end
    end
    proxy:Hide()
    proxy:SetParent(nil)
end

local function ProxyRadius()
    return (Minimap:GetWidth() or 140) / 2 + 6
end

local function PositionProxyAtAngle(proxy, angleDeg)
    local a = math.rad(angleDeg)
    local r = ProxyRadius()
    proxy:ClearAllPoints()
    proxy:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
    proxy._angle = angleDeg
end

-- Save a proxy's hand-placed angle so it persists across reloads / re-collects.
local function SaveProxyAngle(frameName, angleDeg)
    if not frameName then return end
    local s = GetSettings()
    s.proxyPos = s.proxyPos or {}
    s.proxyPos[frameName] = angleDeg
end

-- Create (or refresh) the minimap proxy for a collected button. The proxy lives
-- on the minimap edge and forwards clicks/tooltip to the real (collected) frame.
local function EnsureProxy(frameName)
    local real = FindButtonFrame(frameName)
    if not real then return nil end

    local proxy = proxyByName[frameName]
    if not proxy then
        proxy = CreateFrame("Button", nil, Minimap)
        proxy:SetSize(PROXY_SIZE, PROXY_SIZE)
        proxy:SetFrameStrata("MEDIUM")
        proxy:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
        proxy:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        -- Standard LibDBIcon-style minimap button look: background, cropped icon,
        -- round tracking-border ring, and the minimap zoom-button highlight.
        local bg = proxy:CreateTexture(nil, "BACKGROUND")
        bg:SetSize(20, 20)
        bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        bg:SetPoint("TOPLEFT", 7, -5)

        local icon = proxy:CreateTexture(nil, "ARTWORK")
        icon:SetSize(17, 17)
        icon:SetPoint("TOPLEFT", 7, -6)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        proxy.icon = icon

        local border = proxy:CreateTexture(nil, "OVERLAY")
        border:SetSize(53, 53)
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetPoint("TOPLEFT")

        proxy:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

        proxy:SetScript("OnClick", function(_, button)
            local target = FindButtonFrame(proxy._realName)
            if target and target.Click then pcall(target.Click, target, button) end
        end)
        proxy:SetScript("OnEnter", function(myself)
            if not GetSettings().showTooltips then return end
            local target = FindButtonFrame(proxy._realName)
            local onEnter = target and target:GetScript("OnEnter")
            if onEnter then
                pcall(onEnter, target)
            else
                GameTooltip:SetOwner(myself, "ANCHOR_LEFT")
                GameTooltip:AddLine(myself._realName or "", 1, 0.82, 0)
                GameTooltip:Show()
            end
        end)
        proxy:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Draggable around the minimap edge (LibDBIcon-style angle), unless the
        -- collector position is locked. A plain left-click still triggers OnClick.
        proxy:RegisterForDrag("LeftButton")
        proxy:SetScript("OnDragStart", function(myself)
            if GetSettings().locked then return end
            myself:SetScript("OnUpdate", function(s2)
                local mx, my = Minimap:GetCenter()
                if not mx then return end
                local scale = Minimap:GetEffectiveScale() or 1
                local cx, cy = GetCursorPosition()
                cx, cy = cx / scale, cy / scale
                PositionProxyAtAngle(s2, math.deg(math.atan2(cy - my, cx - mx)))
            end)
        end)
        proxy:SetScript("OnDragStop", function(myself)
            myself:SetScript("OnUpdate", nil)
            SaveProxyAngle(myself._realName, myself._angle)
        end)

        proxyByName[frameName] = proxy
        table.insert(proxyButtons, proxy)
    end

    proxy._realName = frameName
    proxy.icon:SetTexture(ExtractButtonIcon(real))
    return proxy
end

local function ClearProxies()
    for _, proxy in ipairs(proxyButtons) do
        proxy:Hide()
        proxy:SetParent(nil)
    end
    wipe(proxyButtons)
    wipe(proxyByName)
end

local function SortProxies()
    table.sort(proxyButtons, function(a, b)
        return (a._realName or "") < (b._realName or "")
    end)
end

-- Position proxies around the minimap edge: each uses its saved angle if the
-- user has dragged it, otherwise a default clockwise arc slot (which is saved so
-- it stays put afterwards).
local function LayoutMinimapProxies()
    if #proxyButtons == 0 then return end
    local s = GetSettings()
    s.proxyPos = s.proxyPos or {}
    local step = 30  -- degrees between proxies on the default arc
    for i, proxy in ipairs(proxyButtons) do
        local name = proxy._realName
        local angle = name and s.proxyPos[name]
        if not angle then
            angle = 90 - (i - 1) * step
            if name then s.proxyPos[name] = angle end
        end
        PositionProxyAtAngle(proxy, angle)
        proxy:Show()
    end
end

MinimapButtonsModule.LayoutMinimapProxies = LayoutMinimapProxies

-- Move a single button to the state implied by `pref`. Idempotent — calling
-- twice with the same pref is a no-op. Caller is responsible for triggering
-- LayoutContainer / UpdateBadge afterwards if it's batching multiple updates.
local function ApplyPrefImmediate(frameName, pref)
    if not VALID_PREFS[pref] then return end
    local frame = FindButtonFrame(frameName)
    if not frame then return end

    local isCollected = collectedNames[frameName] == true
    local isHidden    = hiddenButtons[frame] == true

    if pref == "mini" then
        if isHidden then UnhideButton(frame) end
        if not isCollected and containerFrame then
            CollectButton(frame)
        end
        -- Dual-display: also mirror the collected button onto the minimap edge.
        if GetSettings().alsoShowOnMinimap then
            EnsureProxy(frameName)
        else
            RemoveProxy(frameName)
        end
    elseif pref == "map" then
        RemoveProxy(frameName)
        if isCollected then UncollectByName(frameName) end
        if isHidden then UnhideButton(frame) end
    elseif pref == "hide" then
        RemoveProxy(frameName)
        if isCollected then UncollectByName(frameName) end
        if not isHidden then HideButton(frame) end
    end
end

-- Discovery + collection are decoupled: ConsiderButton always registers the
-- button (so the settings UI can list it even when the collector is off),
-- then delegates the "where should this live?" decision to ApplyPrefImmediate
-- so the same logic is shared between scans and direct UI clicks.
local function ConsiderButton(frame, hint)
    if not frame or not frame.GetName then return end
    local frameName = frame:GetName()
    if not frameName
        or BLIZZARD_SKIP[frameName]
        or frameName == OWN_BUTTON_NAME then
        return
    end
    RegisterDetectedButton(frameName, hint)

    if not containerFrame then return end
    ApplyPrefImmediate(frameName, GetButtonPref(frameName))
end

-- Some addons parent their button to MinimapBackdrop or MinimapCluster instead
-- of Minimap directly; walk all three so they're picked up.
local function ScanMinimapChildren()
    local parents = { Minimap, MinimapBackdrop, MinimapCluster }
    for _, parent in ipairs(parents) do
        if parent and parent.GetChildren then
            for _, child in ipairs({ parent:GetChildren() }) do
                if (child:IsObjectType("Button") or child:IsObjectType("Frame"))
                    and isValidFrame(child) and isMinimapButton(child) then
                    ConsiderButton(child)
                end
            end
        end
    end
end

local function ScanLibDBIcon()
    local libDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if not libDBIcon then return end

    local list = libDBIcon:GetButtonList()
    if not list then return end
    for _, name in ipairs(list) do
        if type(name) == "string" then
            local btn = libDBIcon:GetMinimapButton(name)
            ConsiderButton(btn, name)
        end
    end
end

local function ScanLibMapButton()
    local libMap = LibStub and LibStub("LibMapButton-1.1", true)
    if not libMap or not libMap.buttons then return end
    for _, btn in pairs(libMap.buttons) do
        ConsiderButton(btn)
    end
end

-- Lightweight discovery-only pass: refreshes seen flags and the s.buttons
-- map without touching collection state. Used by the settings UI before
-- listing rows so "Enabled/Disabled" status is always current.
function MinimapButtonsModule:DiscoverButtons()
    ResetAllSeenFlags()
    ScanLibDBIcon()
    ScanLibMapButton()
    ScanMinimapChildren()

    -- Buttons we're already holding (collected into the panel or stashed in
    -- the hidden container) are no longer children of Minimap, so the scans
    -- above can't see them. Mark them seen explicitly — by definition the
    -- owning addon is loaded if we still have the frame reference.
    for _, btn in ipairs(collectedButtons) do
        local n = btn and btn.GetName and btn:GetName()
        if n then RegisterDetectedButton(n) end
    end
    for btn in pairs(hiddenButtons) do
        local n = btn and btn.GetName and btn:GetName()
        if n then RegisterDetectedButton(n) end
    end
end

local function SortCollected()
    table.sort(collectedButtons, function(a, b)
        return (a:GetName() or "") < (b:GetName() or "")
    end)
end

-- Returns a sorted array of { name, displayName, pref, seen } for the UI.
function MinimapButtonsModule:GetKnownButtons()
    local s = GetSettings()
    local out = {}
    for name, info in pairs(s.buttons) do
        out[#out + 1] = {
            name        = name,
            displayName = info.displayName or MakeDisplayName(name),
            pref        = info.pref or "show",
            seen        = info.seen == true,
        }
    end
    table.sort(out, function(a, b)
        local ad = (a.displayName or ""):lower()
        local bd = (b.displayName or ""):lower()
        if ad == bd then return (a.name or "") < (b.name or "") end
        return ad < bd
    end)
    return out
end

-- Called by the UI when the user picks Mini / Map / Hide on a row. Applies
-- the change immediately via the shared ApplyPrefImmediate helper so the
-- click-driven path goes through exactly the same state machine as scans.
function MinimapButtonsModule:ApplyButtonPref(frameName, pref)
    if not frameName or not VALID_PREFS[pref] then return end
    SetButtonPref(frameName, pref)
    ApplyPrefImmediate(frameName, pref)
    self:LayoutContainer()
    self:UpdateBadge()
    SyncMiniToolsHideAddonIcons()
end

function MinimapButtonsModule:CollectAll()
    local s = GetSettings()

    -- If dual-display was just turned off, drop any minimap proxies first.
    if not s.alsoShowOnMinimap then
        ClearProxies()
    end

    -- Discovery refreshes seen flags and, via ConsiderButton -> ApplyPrefImmediate,
    -- collects / leaves-on-map / hides each button per its stored pref (and mirrors
    -- "mini" buttons to a minimap proxy when dual-display is on).
    self:DiscoverButtons()

    -- Reconcile any buttons we're still holding that no longer have a
    -- matching pref (e.g. user toggled MAP or HIDE on a collected button
    -- when the settings panel was closed and the discovery scan can't undo
    -- that on its own).
    for i = #collectedButtons, 1, -1 do
        local btn = collectedButtons[i]
        local n = btn and btn.GetName and btn:GetName()
        if n then
            local pref = GetButtonPref(n)
            if pref ~= "mini" then
                tremove(collectedButtons, i)
                RemoveProxy(n)
                UncollectButton(btn)
                if pref == "hide" then HideButton(btn) end
            end
        end
    end

    SortCollected()

    if s.alsoShowOnMinimap then
        SortProxies()
        LayoutMinimapProxies()
    end

    self:LayoutContainer()
    self:UpdateBadge()
    SyncMiniToolsHideAddonIcons()
end

-- ─── Enhanced OneWoW Row ────────────────────────────────────────────────────

-- Resolves a loaded component to the open action the owning addon registered
-- via OneWoW:RegisterMinimap (callback, or hub tabKey -> GUI:Show). Match by
-- addon folder name stored on the load component.
---@param addonName string|nil
---@return (fun())|nil
local function FindMinimapEntryAction(addonName)
    if not addonName then return nil end
    local entries = OneWoW:GetMinimapEntries()
    if not entries then return nil end
    for _, entry in ipairs(entries) do
        if entry.addon == addonName then
            if entry.callback then
                return entry.callback
            elseif entry.tabKey then
                local tabKey = entry.tabKey
                return function()
                    OneWoW.UI:Show(tabKey)
                end
            end
            return nil
        end
    end
    return nil
end

local function GetCompanionAction(comp)
    if not comp then return nil end
    -- Core and GUI both ultimately just toggle the main OneWoW window.
    -- Skip the slash dispatch (pairs(SlashCmdList) iteration order can
    -- mis-resolve "/1w" on some clients, leaving the Core tile dead).
    if comp.name == "Core" or comp.name == "GUI" then
        return function()
            OneWoW.UI:Toggle()
        end
    end
    local entryAction = FindMinimapEntryAction(comp.addon)
    if entryAction then
        return entryAction
    end
    if comp.cmd then
        return function()
            local cmd = comp.cmd:gsub("^/", "")
            local slashKey
            for k, _ in pairs(SlashCmdList) do
                for i = 1, 10 do
                    local s = _G["SLASH_" .. k .. i]
                    if s and s:lower() == ("/" .. cmd):lower() then
                        slashKey = k
                        break
                    end
                end
                if slashKey then break end
            end
            if slashKey then
                SlashCmdList[slashKey]("")
            end
        end
    end
    return nil
end

local function ApplyCompanionIcon(tex, comp)
    local brand = OneWoW_GUI:GetBrandIcon(OneWoW_GUI:GetSetting("minimap.theme"))
    if comp.name == "Core" or not comp.addon then
        tex:SetTexture(brand)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        return
    end
    local info = OneWoW:GetFeatureIcon(comp.addon)
    if info and info.atlas then
        tex:SetAtlas(info.atlas, false)
    else
        tex:SetTexture((info and info.texture) or brand)
    end
    if info and info.texCoords then
        tex:SetTexCoord(unpack(info.texCoords))
    else
        tex:SetTexCoord(0, 1, 0, 1)
    end
end

local function AddEnhancedButton(comp, action)
    action = action or GetCompanionAction(comp)

    local btn = CreateFrame("Button", nil, containerFrame)
    btn:SetSize(28, 28)

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    ApplyCompanionIcon(tex, comp)

    local info = OneWoW:GetFeatureIcon(comp.addon)
    local skin = { preset = "clean", trimIcon = false }
    if info and info.plate == false then
        skin.bgAlpha = 0
        skin.borderSize = 0
    end
    OneWoW_GUI:SkinIconFrame(btn, skin)
    btn._addon = comp.addon
    local face = btn._skinnedIcon or tex
    OneWoW:ApplyFeatureIconAlert(face, comp.addon)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(comp.name, 1, 0.82, 0, true)
        if comp.ver and comp.ver ~= "" then
            GameTooltip:AddLine("v" .. comp.ver, 0.7, 0.7, 0.7)
        end
        if comp.cmd then
            GameTooltip:AddLine(comp.cmd, 0.5, 0.5, 0.6)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function()
        local click = OneWoW:ResolveFeatureIconClick(comp.addon, action)
        if click then
            click()
        else
            OneWoW.UI:Toggle()
        end
    end)

    table.insert(enhancedRow, btn)
end

local function OpenPortalHub()
    local global = OneWoW:GetCoreGlobal()
    global.lastSubTabs.qol = "portals"
    OneWoW.UI:Show("qol")
end

local ENHANCED_TILE_SETTINGS = "settings"
local ENHANCED_TILE_PORTALS  = "portals"

local function EnhancedTileId(comp)
    if not comp then return nil end
    if comp.addon == ENHANCED_TILE_SETTINGS or comp.addon == ENHANCED_TILE_PORTALS then
        return comp.addon
    end
    return comp.addon or comp.name
end

local function IsEnhancedTileShown(id)
    if not id then return false end
    local v = GetSettings().enhancedTiles[id]
    if v == nil then return true end
    return v == true
end

function MinimapButtonsModule:IsEnhancedTileShown(id)
    return IsEnhancedTileShown(id)
end

function MinimapButtonsModule:SetEnhancedTileShown(id, shown)
    if not id then return end
    GetSettings().enhancedTiles[id] = shown and true or false
    self:Refresh()
end

-- Exclusive catalog: Core + every manifest load unit + Settings + Portals,
-- plus any loaded component that is not already on that list (except GUI).
function MinimapButtonsModule:GetEnhancedTileCatalog()
    local seen = {}
    local out = {}

    local function add(id, label, available)
        if not id or seen[id] then return end
        seen[id] = true
        out[#out + 1] = {
            id = id,
            label = label,
            available = available == true,
            shown = IsEnhancedTileShown(id),
        }
    end

    add("OneWoW", "Core", C_AddOns.IsAddOnLoaded("OneWoW"))

    for _, entry in ipairs(OneWoW.ModuleManifest) do
        local label = entry.display
        if entry.addon == "OneWoW_Mail" then
            label = MAIL_LABEL
        end
        add(entry.addon, label, C_AddOns.IsAddOnLoaded(entry.addon))
    end

    for _, comp in ipairs(OneWoW:GetLoadedComponents()) do
        if comp.name ~= "GUI" then
            add(EnhancedTileId(comp), comp.name, true)
        end
    end

    add(ENHANCED_TILE_SETTINGS, SETTINGS, true)
    add(ENHANCED_TILE_PORTALS, ns.L["PORTALS_SUBTAB"], C_AddOns.IsAddOnLoaded("OneWoW_QoL"))

    return out
end

local function AppendHubLaunchers()
    if IsEnhancedTileShown(ENHANCED_TILE_SETTINGS) then
        AddEnhancedButton({
            name  = SETTINGS,
            addon = ENHANCED_TILE_SETTINGS,
        }, function()
            OneWoW.UI:Show("settings")
        end)
    end
    if IsEnhancedTileShown(ENHANCED_TILE_PORTALS) then
        AddEnhancedButton({
            name  = ns.L["PORTALS_SUBTAB"],
            addon = ENHANCED_TILE_PORTALS,
        }, OpenPortalHub)
    end
end

local function BuildEnhancedRow()
    if not containerFrame then return end
    for _, btn in ipairs(enhancedRow) do
        btn:Hide()
        btn:SetParent(nil)
    end
    wipe(enhancedRow)

    local companions = OneWoW:GetLoadedComponents()
    if not companions then return end

    enhancedBuiltCount = #companions

    for _, comp in ipairs(companions) do
        -- GUI only opens the main OneWoW window, identical to the Core tile.
        if comp.name ~= "GUI" and IsEnhancedTileShown(EnhancedTileId(comp)) then
            AddEnhancedButton(comp)
        end
    end

    AppendHubLaunchers()
end

-- ─── Container Layout ───────────────────────────────────────────────────────

local function FilteredButtons()
    local filtered = {}
    local lower = searchFilter ~= "" and searchFilter:lower() or nil
    for _, btn in ipairs(collectedButtons) do
        if collectedMap[btn] ~= false then
            if not lower then
                table.insert(filtered, btn)
            else
                local name = btn:GetName() or ""
                if name:lower():find(lower, 1, true) then
                    table.insert(filtered, btn)
                end
            end
        end
    end
    return filtered
end

function MinimapButtonsModule:LayoutContainer()
    if not containerFrame then return end
    _layouting = true
    local s = GetSettings()
    local btnSize = s.buttonSize
    local spacing = s.buttonSpacing
    local maxCols = s.maxColumns
    local maxRows = s.maxRows

    for _, btn in ipairs(collectedButtons) do
        btn:Hide()
    end

    local visibleButtons = FilteredButtons()
    local totalCount = #visibleButtons + (s.enhancedMenu and #enhancedRow or 0)

    if maxRows == 1 and maxCols == 1 and totalCount > 1 then
        s.maxRows = 0
        maxRows = 0
        print("|cFFFFD100OneWoW QoL:|r " .. (L["MMBTNS_1X1_WARNING"]))
    end

    local yOff = 0
    local maxW = 0

    if s.enhancedMenu and #enhancedRow > 0 then
        -- Same cell size and column count as the collected grid so Max Columns
        -- applies to the OneWoW row. A fixed 28px pitch left an empty last
        -- column once the panel grew to the collected-button width.
        local owSize = btnSize
        local owSpacing = spacing
        local owCols = math.min(#enhancedRow, maxCols)
        local owRows = math.ceil(#enhancedRow / owCols)

        for i, btn in ipairs(enhancedRow) do
            local row = math.floor((i - 1) / owCols)
            local col = (i - 1) % owCols
            btn:ClearAllPoints()
            btn:SetSize(owSize, owSize)
            btn:SetPoint("TOPLEFT", containerFrame, "TOPLEFT",
                4 + col * (owSize + owSpacing),
                -(4 + yOff + row * (owSize + owSpacing)))
            btn:Show()
        end

        local owWidth = owCols * (owSize + owSpacing) - owSpacing + 8
        if owWidth > maxW then maxW = owWidth end
        yOff = yOff + owRows * (owSize + owSpacing) + 2

        if not containerFrame._divider then
            containerFrame._divider = containerFrame:CreateTexture(nil, "ARTWORK")
            containerFrame._divider:SetHeight(1)
        end
        local div = containerFrame._divider
        div:ClearAllPoints()
        div:SetPoint("TOPLEFT", containerFrame, "TOPLEFT", 4, -(4 + yOff))
        div:SetPoint("TOPRIGHT", containerFrame, "TOPRIGHT", -4, -(4 + yOff))
        div:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        div:Show()
        yOff = yOff + 4
    else
        for _, btn in ipairs(enhancedRow) do btn:Hide() end
        if containerFrame._divider then containerFrame._divider:Hide() end
    end

    local showSearch = #collectedButtons > 12 or searchFilter ~= ""
    if showSearch then
        if not searchBox then
            searchBox = CreateFrame("EditBox", nil, containerFrame, "BackdropTemplate")
            searchBox:SetSize(120, 20)
            searchBox:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
            searchBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            searchBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            searchBox:SetFontObject(GameFontHighlightSmall)
            searchBox:SetTextInsets(4, 4, 0, 0)
            searchBox:SetAutoFocus(false)
            searchBox:SetMaxLetters(30)
            searchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            searchBox._placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            searchBox._placeholder:SetPoint("LEFT", 6, 0)
            searchBox._placeholder:SetText(L["SEARCH"])

            searchBox:SetScript("OnTextChanged", function(myself)
                local text = myself:GetText() or ""
                searchFilter = text
                if myself._placeholder then
                    myself._placeholder:SetShown(text == "")
                end
                MinimapButtonsModule:LayoutContainer()
            end)
            searchBox:SetScript("OnEscapePressed", function(myself)
                myself:SetText("")
                myself:ClearFocus()
            end)
        end

        searchBox:ClearAllPoints()
        searchBox:SetPoint("TOPLEFT", containerFrame, "TOPLEFT", 4, -(4 + yOff))
        searchBox:SetPoint("TOPRIGHT", containerFrame, "TOPRIGHT", -4, -(4 + yOff))
        searchBox:Show()
        yOff = yOff + 24
    else
        if searchBox then
            searchBox:Hide()
            searchFilter = ""
        end
    end

    local cols = math.min(#visibleButtons, maxCols)
    if cols < 1 then cols = 1 end
    local rows = math.ceil(#visibleButtons / cols)
    if maxRows > 0 and rows > maxRows then rows = maxRows end
    local maxVisible = cols * rows

    for i, btn in ipairs(visibleButtons) do
        if i <= maxVisible then
            local row = math.floor((i - 1) / cols)
            local col = (i - 1) % cols

            RawClearAllPoints(btn)

            local bSize = btnSize
            btn:SetSize(bSize, bSize)

            RawSetPoint(btn, "TOPLEFT", containerFrame, "TOPLEFT",
                4 + col * (bSize + spacing),
                -(4 + yOff + row * (bSize + spacing)))

            -- Re-assert stacking + alpha every layout as belt-and-suspenders:
            -- CollectButton already noop'd these mutators, but a button collected
            -- before that seizure (or via a future path) still gets pinned here.
            PinCollectedStacking(btn)

            btn:Show()
        end
    end

    local gridW = cols * (btnSize + spacing) - spacing + 8
    if gridW > maxW then maxW = gridW end
    local gridH = rows * (btnSize + spacing) - spacing

    local totalH = yOff + gridH + 8
    if totalH < 20 then totalH = 20 end
    if maxW < 40 then maxW = 40 end

    containerFrame:SetSize(maxW, totalH)
    _layouting = false
end

-- ─── Container Frame ────────────────────────────────────────────────────────

local function CreateContainer()
    if containerFrame then return end

    containerFrame = CreateFrame("Frame", "OneWoW_QoL_MMBtnContainer", UIParent,
        BackdropTemplateMixin and "BackdropTemplate")
    containerFrame:SetFrameStrata(CONTAINER_STRATA)
    containerFrame:SetFrameLevel(CONTAINER_LEVEL)
    containerFrame:SetClampedToScreen(true)
    containerFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SOFT)
    containerFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    containerFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    containerFrame:SetSize(100, 100)
    containerFrame:Hide()
end

local function PositionContainer()
    if not containerFrame or not hubButton then return end
    local s = GetSettings()
    containerFrame:ClearAllPoints()
    local dir = s.growDirection or "down"
    if dir == "up" then
        containerFrame:SetPoint("BOTTOMLEFT", hubButton, "TOPLEFT", 0, 4)
    elseif dir == "left" then
        containerFrame:SetPoint("TOPRIGHT", hubButton, "TOPLEFT", -4, 0)
    elseif dir == "right" then
        containerFrame:SetPoint("TOPLEFT", hubButton, "TOPRIGHT", 4, 0)
    else
        containerFrame:SetPoint("TOPLEFT", hubButton, "BOTTOMLEFT", 0, -4)
    end
end

local function ShowContainer()
    if not containerFrame then return end
    -- The enhanced row is first built at OnEnable, when OneWoW companions may
    -- not all have registered yet (load-order race) — leaving tiles missing or
    -- wired to stale actions until a /reload. Rebuild here when the loaded
    -- component count has changed since the last build, so opening the panel
    -- always reflects the fully-populated, correctly-wired set.
    local companions = OneWoW:GetLoadedComponents()
    if GetSettings().enhancedMenu and companions
        and enhancedBuiltCount ~= #companions then
        BuildEnhancedRow()
    end
    ResetCollectedVisibilityMap()
    MinimapButtonsModule:CollectAll()
    PositionContainer()
    containerFrame:Show()
    MinimapButtonsModule:StartAutoCloseTimer()
end

local function HideContainer()
    if not containerFrame then return end
    MinimapButtonsModule:CancelAutoCloseTimer()
    containerFrame:Hide()
end

local function ToggleContainer()
    if not containerFrame then return end
    if containerFrame:IsShown() then
        HideContainer()
    else
        ShowContainer()
    end
end

-- ─── Auto-close ─────────────────────────────────────────────────────────────

function MinimapButtonsModule:StartAutoCloseTimer()
    self:CancelAutoCloseTimer()
    local s = GetSettings()
    if s.closeMode ~= "autoclose" then return end

    local delay = s.autoCloseDelay or 3
    autoCloseTimer = C_Timer.NewTimer(delay, function()
        if containerFrame and containerFrame:IsShown() then
            if not containerFrame:IsMouseOver() and not (hubButton and hubButton:IsMouseOver()) then
                HideContainer()
            else
                MinimapButtonsModule:StartAutoCloseTimer()
            end
        end
    end)
end

function MinimapButtonsModule:CancelAutoCloseTimer()
    if autoCloseTimer then
        autoCloseTimer:Cancel()
        autoCloseTimer = nil
    end
end

-- ─── Hub Button ─────────────────────────────────────────────────────────────

local function CreateHubButton()
    if hubButton then return end

    hubButton = CreateFrame("Button", OWN_BUTTON_NAME, UIParent)
    hubButton:SetSize(36, 36)
    hubButton:SetFrameStrata(CONTAINER_STRATA)
    hubButton:SetFrameLevel(CONTAINER_LEVEL)
    hubButton:SetMovable(true)
    hubButton:SetClampedToScreen(true)
    hubButton:EnableMouse(true)
    hubButton:RegisterForDrag("LeftButton")
    hubButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local tex = hubButton:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(GetCurrentIcon())
    tex:SetAllPoints()
    hubButton.icon = tex

    local badge = hubButton:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    badge:SetPoint("BOTTOMRIGHT", 2, -2)
    badge:SetText("")
    hubButton.badge = badge

    hubButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L["MMBTNS_TOOLTIP_LINE1"], 1, 0.82, 0)
        local count = #collectedButtons
        GameTooltip:AddLine(string.format(L["MMBTNS_TOOLTIP_BUTTONS"], count), 0.7, 0.7, 0.8)
        GameTooltip:AddLine(L["MMBTNS_TOOLTIP_HINT"], 0.5, 0.5, 0.6)
        GameTooltip:AddLine(L["MMBTNS_TOOLTIP_HINT_RIGHT"], 0.5, 0.5, 0.6)
        if not GetSettings().locked then
            GameTooltip:AddLine(L["MMBTNS_TOOLTIP_DRAG"], 0.5, 0.5, 0.6)
        end
        GameTooltip:Show()
    end)
    hubButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    hubButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            ToggleContainer()
        elseif button == "RightButton" then
            MinimapButtonsModule:ShowContextMenu(self)
        end
    end)

    hubButton:SetScript("OnDragStart", function(self)
        if GetSettings().locked then return end
        self:StartMoving()
    end)
    hubButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveHubPosition()
    end)

    RestoreHubPosition()
    hubButton:Show()
end

function MinimapButtonsModule:UpdateIcon()
    if hubButton and hubButton.icon then
        hubButton.icon:SetTexture(GetCurrentIcon())
    end
end

function MinimapButtonsModule:UpdateBadge()
    if not hubButton or not hubButton.badge then return end
    local count = #collectedButtons
    if count > 0 then
        hubButton.badge:SetText(tostring(count))
    else
        hubButton.badge:SetText("")
    end
end

-- ─── Context Menu ───────────────────────────────────────────────────────────

function MinimapButtonsModule:ShowContextMenu(anchor)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(_, rootDescription)
            local s = GetSettings()
            rootDescription:CreateTitle(L["MMBTNS_TITLE"])
            local lockLabel = s.locked
                and (L["UNLOCK_POSITION"])
                or  (L["MMBTNS_CONTEXT_LOCK"])
            rootDescription:CreateButton(lockLabel, function()
                s.locked = not s.locked
            end)
            rootDescription:CreateButton(L["MMBTNS_CONTEXT_REFRESH"], function()
                MinimapButtonsModule:CollectAll()
            end)
            rootDescription:CreateButton(L["OPEN_SETTINGS"], function()
                MinimapButtonsModule:OpenSettings()
            end)
        end)
    end
end

function MinimapButtonsModule:OpenSettings()
    if ns.UI and ns.UI.SelectFeature then
        ns.UI.SelectFeature("minimapbuttons")
    end
end

-- ─── Theme Update ───────────────────────────────────────────────────────────

function MinimapButtonsModule:ApplyTheme()
    if containerFrame and OneWoW_GUI then
        containerFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        containerFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    end
    if containerFrame and containerFrame._divider and OneWoW_GUI then
        containerFrame._divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end
    if searchBox and OneWoW_GUI then
        searchBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        searchBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        searchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
end

-- LibDBIcon hooks Minimap OnEnter/OnLeave to fade showOnMouseover buttons.
-- Register after that library so we run last and re-pin collected icons.
local function RegisterMinimapFadeHooks()
    if _minimapFadeHooks then return end
    _minimapFadeHooks = true
    Minimap:HookScript("OnEnter", PinAllCollectedLibDBIconFades)
    Minimap:HookScript("OnLeave", PinAllCollectedLibDBIconFades)
end

-- ─── Lifecycle ──────────────────────────────────────────────────────────────

function MinimapButtonsModule:OnEnable()
    CreateContainer()
    CreateHubButton()

    if GetSettings().enhancedMenu then
        BuildEnhancedRow()
    end

    self:RegisterEvents()
    RegisterMinimapFadeHooks()

    C_Timer.After(0, function() self:CollectAll() end)
    C_Timer.After(1, function() self:CollectAll() end)
    C_Timer.After(3, function() self:CollectAll() end)

    local libDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if libDBIcon and libDBIcon.RegisterCallback then
        libDBIcon.RegisterCallback(self, "LibDBIcon_IconCreated", function()
            C_Timer.After(0.2, function() self:CollectAll() end)
        end)
    end

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function()
        MinimapButtonsModule:ApplyTheme()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", self, function()
        MinimapButtonsModule:UpdateIcon()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFeatureIconStyleChanged", self, function()
        MinimapButtonsModule:Refresh()
    end)

    local alertEvent = OneWoW:GetFeatureIconAlertEvent()
    EventRegistry:UnregisterCallback(alertEvent, self)
    EventRegistry:RegisterCallback(alertEvent, function()
        for _, btn in ipairs(enhancedRow) do
            local face = btn._skinnedIcon
            if face and btn._addon then
                OneWoW:ApplyFeatureIconAlert(face, btn._addon)
            end
        end
    end, self)
end

function MinimapButtonsModule:OnDisable()
    EventRegistry:UnregisterCallback(OneWoW:GetFeatureIconAlertEvent(), self)
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
    end

    SyncLibDBIconRadiusToMinimapShape()
    ClearProxies()
    for _, btn in ipairs(collectedButtons) do
        UncollectButton(btn)
    end
    wipe(collectedButtons)
    wipe(collectedNames)
    wipe(collectedMap)

    -- Disabling the feature must release every button we were hiding —
    -- otherwise icons stay invisible until the user notices and re-enables.
    local hiddenCopy = {}
    for btn in pairs(hiddenButtons) do
        hiddenCopy[#hiddenCopy + 1] = btn
    end
    for _, btn in ipairs(hiddenCopy) do
        UnhideButton(btn)
    end

    RefreshAllLibDBIcons()
    SyncMiniToolsHideAddonIcons()
    C_Timer.After(0, function()
        SyncLibDBIconRadiusToMinimapShape()
        RefreshAllLibDBIcons()
        SyncMiniToolsHideAddonIcons()
    end)

    if containerFrame then
        containerFrame:Hide()
    end
    if hubButton then
        hubButton:Hide()
    end

    C_Timer.After(0, ShowDisableReloadDialog)
end

function MinimapButtonsModule:OnToggle()
end

function MinimapButtonsModule:RegisterAddonCompartmentHooks()
    if _compartmentHooksRegistered then return end
    local f = AddonCompartmentFrame
    if not f or not f.HookScript then return end
    _compartmentHooksRegistered = true
    local function onCompartmentVisibility()
        if not containerFrame or not containerFrame:IsShown() then return end
        ResetCollectedVisibilityMap()
        ScheduleRelayout()
    end
    f:HookScript("OnShow", onCompartmentVisibility)
    f:HookScript("OnHide", onCompartmentVisibility)
end

function MinimapButtonsModule:RegisterEvents()
    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame", "OneWoW_QoL_MMBtnEvents")
    end
    self._eventFrame:UnregisterAllEvents()
    if IS_RETAIL then
        self._eventFrame:RegisterEvent("PET_BATTLE_OPENING_START")
        self._eventFrame:RegisterEvent("PET_BATTLE_CLOSE")
    end

    self._eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PET_BATTLE_OPENING_START" then
            if hubButton then hubButton:Hide() end
        elseif event == "PET_BATTLE_CLOSE" then
            if hubButton then hubButton:Show() end
        end
    end)

    self:RegisterAddonCompartmentHooks()
end

function MinimapButtonsModule:Refresh()
    if GetSettings().enhancedMenu then
        BuildEnhancedRow()
    end
    self:CollectAll()
end

function MinimapButtonsModule:ApplyMinimapShapeToLibDBIcons()
    SyncLibDBIconRadiusToMinimapShape()
    RefreshAllLibDBIcons()
    C_Timer.After(0, function()
        SyncLibDBIconRadiusToMinimapShape()
        RefreshAllLibDBIcons()
    end)
end
