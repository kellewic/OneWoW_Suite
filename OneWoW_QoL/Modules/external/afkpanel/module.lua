-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/afkpanel/module.lua
local ADDON_NAME, ns = ...

-- Module metadata + the single source of truth for this module's id. Loaded first in
-- the TOC block so the id/scope is available to the locale and code files (via
-- ns.ModuleRegistry:Current()). Define() registers it and caches its locale view.
ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "afkpanel",
    title       = "AFKPANEL_TITLE",
    category    = "INTERFACE",
    description = "AFKPANEL_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@onewow.net",
    link        = "https://www.onewow.net",
    tags        = { "afk", "info", "overlay" },
    toggles     = {
        { id = "camera_spin",  label = "AFKPANEL_CAMERA_SPIN", default = true },
        { id = "show_dock_bg", label = "AFKPANEL_SHOW_DOCK", description = "AFKPANEL_SHOW_DOCK_DESC", default = true },
    },
    preview        = true,
    defaultEnabled = true,
    isAFK       = false,
    _initialized = false,
    _eventFrame  = nil,
    _afkFrame    = nil,
    _model       = nil,
    _youPanel    = nil,
    _herePanel   = nil,
    _infoPanel   = nil,
    _timer       = nil,
    _animTimer   = nil,
    _startTime   = nil,
    _idleKind    = nil,
    _idleTipIndex = nil,
    _sizeQueued = nil,
})
