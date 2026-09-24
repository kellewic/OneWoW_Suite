-- ============================================================================
-- Font catalog, application, and font-root registry
-- ============================================================================
-- Loads after GUI/Settings.lua (needs RegisterSettingsCallback). Public API
-- stays on OneWoW_GUI (GetFont, SafeSetFont, CreateFS, RegisterFontRoot, …).
-- ============================================================================

local OneWoW_GUI = OneWoW_GUI
local Constants = OneWoW_GUI.Constants

local FONT_BASE = Constants.FONT_BASE

local FONTS = {
    { key = "default",                label = "WoW Default",          file = nil },
    { key = "actionman",              label = "Action Man",           file = FONT_BASE .. "ActionMan.ttf" },
    { key = "adventure",              label = "Adventure",            file = FONT_BASE .. "Adventure.ttf" },
    { key = "atkinsonhyperlegible",   label = "Atkinson Hyperlegible", file = FONT_BASE .. "AtkinsonHyperlegibleNext-Regular.otf" },
    { key = "bazooka",                label = "Bazooka",              file = FONT_BASE .. "Bazooka.ttf" },
    { key = "blackchancery",          label = "Black Chancery",       file = FONT_BASE .. "BlackChancery.ttf" },
    { key = "celestia",               label = "Celestia Medium Redux", file = FONT_BASE .. "CelestiaMediumRedux1.55.ttf" },
    { key = "continuum",              label = "Continuum Medium",     file = FONT_BASE .. "ContinuumMedium.ttf" },
    { key = "dejavusans",             label = "DejaVu Sans",          file = FONT_BASE .. "DejaVuLGCSans.ttf" },
    { key = "dejavuserif",            label = "DejaVu Serif",         file = FONT_BASE .. "DejaVuLGCSerif.ttf" },
    { key = "diabloheavy",            label = "Diablo Heavy",         file = FONT_BASE .. "DiabloHeavy.ttf" },
    { key = "diedidie",               label = "DieDieDie",            file = FONT_BASE .. "DieDieDie.ttf" },
    { key = "dorispp",                label = "DorisPP",              file = FONT_BASE .. "DorisPP.ttf" },
    { key = "expressway",             label = "Expressway",           file = FONT_BASE .. "Expressway.ttf" },
    { key = "fitzgerald",             label = "Fitzgerald",           file = FONT_BASE .. "Fitzgerald.ttf" },
    { key = "gentiumplus",            label = "Gentium Plus",         file = FONT_BASE .. "GentiumPlus-Regular.ttf" },
    { key = "hack",                   label = "Hack",                 file = FONT_BASE .. "Hack-Regular.ttf" },
    { key = "homespun",               label = "Homespun",             file = FONT_BASE .. "Homespun.ttf" },
    { key = "hookedup",               label = "All Hooked Up",        file = FONT_BASE .. "HookedUp.ttf" },
    { key = "lato",                   label = "Lato",                 file = FONT_BASE .. "Lato-Regular.ttf" },
    { key = "liberationmono",         label = "Liberation Mono",      file = FONT_BASE .. "LiberationMono-Regular.ttf" },
    { key = "liberationsans",         label = "Liberation Sans",      file = FONT_BASE .. "LiberationSans-Regular.ttf" },
    { key = "liberationserif",        label = "Liberation Serif",     file = FONT_BASE .. "LiberationSerif-Regular.ttf" },
    { key = "poppinssemibold",        label = "Poppins SemiBold",     file = FONT_BASE .. "Poppins-SemiBold.ttf" },
    { key = "ptsansnarrow",           label = "PT Sans Narrow",       file = FONT_BASE .. "PTSansNarrow.ttf" },
    { key = "robotocondensedbold",    label = "Roboto Condensed Bold", file = FONT_BASE .. "RobotoCondensed-Bold.ttf" },
    { key = "sfatarian",              label = "SF Atarian System",    file = FONT_BASE .. "SFAtarianSystem.ttf" },
    { key = "sfcovington",            label = "SF Covington",         file = FONT_BASE .. "SFCovington.ttf" },
    { key = "sfmovieposter",          label = "SF Movie Poster",      file = FONT_BASE .. "SFMoviePoster-Bold.ttf" },
    { key = "sfwondercomic",          label = "SF Wonder Comic",      file = FONT_BASE .. "SFWonderComic.ttf" },
    { key = "swfit",                  label = "SWF!T",                file = FONT_BASE .. "SWFIT.ttf" },
    { key = "texgyreadventor",        label = "TeX Gyre Adventor",    file = FONT_BASE .. "texgyreadventor-regular.otf" },
    { key = "texgyreadventorbold",    label = "TeX Gyre Adventor Bold", file = FONT_BASE .. "texgyreadventor-bold.otf" },
    { key = "wenquanyi",              label = "WenQuanYi Zen Hei",    file = FONT_BASE .. "wqy-zenhei.ttf" },
    { key = "yellowjacket",           label = "Yellowjacket",         file = FONT_BASE .. "yellow.ttf" },
}

local FONT_LOOKUP = {}
for _, f in ipairs(FONTS) do
    FONT_LOOKUP[f.key] = f
end

local LSM_NAME_TO_KEY = {
    ["Action Man"]             = "actionman",
    ["Adventure"]              = "adventure",
    ["All Hooked Up"]          = "hookedup",
    ["Atkinson Hyperlegible"]  = "atkinsonhyperlegible",
    ["Bazooka"]                = "bazooka",
    ["Black Chancery"]         = "blackchancery",
    ["Celestia Medium Redux"]  = "celestia",
    ["Continuum Medium"]       = "continuum",
    ["DejaVu Sans"]            = "dejavusans",
    ["DejaVu Serif"]           = "dejavuserif",
    ["Diablo Heavy"]           = "diabloheavy",
    ["DieDieDie"]              = "diedidie",
    ["DorisPP"]                = "dorispp",
    ["Enigmatic"]              = "enigmatic",
    ["Expressway"]             = "expressway",
    ["Fitzgerald"]             = "fitzgerald",
    ["Gentium Plus"]           = "gentiumplus",
    ["Hack"]                   = "hack",
    ["Homespun"]               = "homespun",
    ["Lato"]                   = "lato",
    ["Liberation Mono"]        = "liberationmono",
    ["Liberation Sans"]        = "liberationsans",
    ["Liberation Serif"]       = "liberationserif",
    ["Poppins SemiBold"]       = "poppinssemibold",
    ["PT Sans Narrow"]         = "ptsansnarrow",
    ["Roboto Condensed Bold"]  = "robotocondensedbold",
    ["SF Atarian System"]      = "sfatarian",
    ["SF Covington"]           = "sfcovington",
    ["SF Movie Poster"]        = "sfmovieposter",
    ["SF Wonder Comic"]        = "sfwondercomic",
    ["SWF!T"]                  = "swfit",
    ["TeX Gyre Adventor"]      = "texgyreadventor",
    ["TeX Gyre Adventor Bold"] = "texgyreadventorbold",
    ["WenQuanYi Zen Hei"]      = "wenquanyi",
    ["Yellowjacket"]           = "yellowjacket",
}

-- Resolves an LSM-registered font name to its file path. Returns nil (not the
-- LSM default) when the name isn't registered, so callers can distinguish
-- "unknown font" from "user picked the WoW default".
local function FetchLSMFont(name)
    if not name then return nil end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if not LSM then return nil end
    return LSM:Fetch("font", name, true)
end

function OneWoW_GUI:GetFont()
    local fontKey = self:GetSetting("font") or "default"
    local fontData = FONT_LOOKUP[fontKey]
    if fontData and fontData.file then
        return fontData.file
    end
    if fontKey ~= "default" then
        local path = FetchLSMFont(fontKey)
        if path then return path end
    end
    return nil
end

-- Returns the unified font list:
--   * "WoW Default" pinned at the top,
--   * then every other hardcoded OneWoW-shipped font + every LSM-registered
--     font that isn't already represented by a hardcoded entry (filtered via
--     LSM_NAME_TO_KEY), all sorted alphabetically by label.
-- LSM-only fonts use the LSM name as both `key` and `label`, so the same
-- string round-trips through dropdowns and SavedVariables.
function OneWoW_GUI:GetFontList()
    local list = {}
    local rest = {}
    for _, entry in ipairs(FONTS) do
        if entry.key == "default" then
            tinsert(list, entry)
        else
            tinsert(rest, entry)
        end
    end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        for _, name in ipairs(LSM:List("font") or {}) do
            if not LSM_NAME_TO_KEY[name] then
                local path = LSM:Fetch("font", name, true)
                if path then
                    tinsert(rest, { key = name, label = name, file = path })
                end
            end
        end
    end
    sort(rest, function(a, b) return a.label:lower() < b.label:lower() end)
    for _, entry in ipairs(rest) do
        tinsert(list, entry)
    end
    return list
end

function OneWoW_GUI:GetFontByKey(key)
    if not key or key == "default" then return nil end
    local fontData = FONT_LOOKUP[key]
    if fontData and fontData.file then return fontData.file end
    return FetchLSMFont(key)
end

-- Resolves any unified font key (hardcoded key or LSM name) into the same
-- { key, label, file } shape used by GetFontList. Returns nil for unknown
-- keys; "default" returns the WoW Default entry from FONT_LOOKUP.
function OneWoW_GUI:GetFontInfoByKey(key)
    if not key then return nil end
    local fontData = FONT_LOOKUP[key]
    if fontData then return fontData end
    local path = FetchLSMFont(key)
    if path then
        return { key = key, label = key, file = path }
    end
    return nil
end

function OneWoW_GUI:GetFontSizeOffset()
    return self._settingsDB and self._settingsDB.fontSizeOffset or 0
end

-- Safely apply a font file. Guarantees the fontstring ends with SOME valid font
-- set at the requested size, so callers can safely call SetText/SetFormattedText
-- afterwards without risking a "Font not set" error.
--
-- Mainline FontString:SetFont quirks we work around here:
--  1. SetFont's boolean return value is unreliable. Some valid custom TTFs
--     render correctly yet return false/nil. We cannot simply fall back to
--     SetFontObject(GameFontNormal) on a falsy return, because SetFontObject
--     forces BOTH font face AND size back to the object's baked defaults,
--     silently discarding the caller's size.
--  2. The first SetFont call with an uncached TTF can return nil or false while
--     only loading the file into WoW's font cache; the glyphs do not stick, so
--     button and label text stays blank until some later SetFont. A second
--     immediate call then succeeds. nil is not success here: some valid files
--     also report nil once they do render, so we retry once per file and only
--     treat an explicit false after that retry as unusable.
--  3. A font file may be genuinely missing / corrupt (FONTS entry whose file
--     is not on disk). To avoid leaving the fontstring with no font (which
--     crashes SetText later), we fall back to GameFontNormal's *path* applied
--     at the caller's size - keeping the size slider functional.
local STOCK_FONT_PATH
local function GetStockFontPath()
    if not STOCK_FONT_PATH then
        STOCK_FONT_PATH = select(1, GameFontNormal:GetFont())
    end
    return STOCK_FONT_PATH
end

local function TrySetFont(fontString, path, size, flags)
    local ok, success = pcall(fontString.SetFont, fontString, path, size, flags)
    return ok, success
end

-- Paths whose second SetFont was not an explicit failure. Later sets hit the
-- cache and only need one call. The fontstring that warms a path always gets
-- the second call itself, so its own text is not left blank.
local warmedFontPaths = {}

local function ApplyFontFile(fontString, path, size, flags)
    local ok, success = TrySetFont(fontString, path, size, flags)
    if not ok then
        return false
    end
    if not warmedFontPaths[path] then
        ok, success = TrySetFont(fontString, path, size, flags)
        if not ok then
            return false
        end
        if success ~= false then
            warmedFontPaths[path] = true
        end
    end
    return success ~= false
end

local fontMetadata = setmetatable({}, { __mode = "k" })

function OneWoW_GUI:SetFontBaseSize(fontObject, baseSize)
    if not fontObject then return nil end
    local metadata = fontMetadata[fontObject]
    if not metadata then
        metadata = {}
        fontMetadata[fontObject] = metadata
    end
    metadata.baseSize = baseSize
    return metadata
end

function OneWoW_GUI:SetFontCap(fontObject, baseSize, maxOffset)
    local metadata = self:SetFontBaseSize(fontObject, baseSize)
    if metadata then
        metadata.maxOffset = maxOffset
    end
    return metadata
end

function OneWoW_GUI:GetFontMetadata(fontObject)
    if not fontObject then return nil end
    return fontMetadata[fontObject]
end

function OneWoW_GUI:SafeSetFont(fontString, fontPath, size, flags)
    if not fontString then return end
    local offset = self._settingsDB and self._settingsDB.fontSizeOffset or 0
    local adjustedSize = math.max(6, (size or 12) + offset)
    local f = flags or ""
    local stockPath = GetStockFontPath()

    local target = fontPath or stockPath
    if target and ApplyFontFile(fontString, target, adjustedSize, f) then
        return
    end

    -- Target font is unusable (missing file, bad args, etc.). Apply the stock
    -- font at the caller's size so the fontstring is never left without a font.
    if stockPath and stockPath ~= target and ApplyFontFile(fontString, stockPath, adjustedSize, f) then
        return
    end
    fontString:SetFontObject(GameFontNormal)
end

-- Pre-warm every shipped font, plus the active face when it is an LSM path
-- outside that list. Hide() before SetFont skips the cache load, which is why
-- the old warm-up left the first real labels blank. The string stays shown at
-- alpha 0, gets the same two-call apply as live text, then is discarded.
function OneWoW_GUI:PrewarmFonts()
    local f = UIParent:CreateFontString(nil, "BACKGROUND")
    f:SetAlpha(0)
    local function warm(path)
        if not path or warmedFontPaths[path] then
            return
        end
        ApplyFontFile(f, path, 12, "")
        f:SetText("A")
        -- Alpha 0 can report a face as set when nothing rasterized. Leave the
        -- path unwarmed so the first visible label still gets the second call.
        if (f:GetStringWidth() or 0) <= 0 then
            warmedFontPaths[path] = nil
        end
    end
    for _, entry in ipairs(FONTS) do
        warm(entry.file)
    end
    warm(self:GetFont())
    f:SetText("")
    f:Hide()
    f:SetParent(nil)
end

function OneWoW_GUI:CreateFS(parent, size, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    self:SetFontBaseSize(fs, size or 12)
    self:SafeSetFont(fs, self:GetFont(), size or 12)
    return fs
end

function OneWoW_GUI:ApplyFont(fs, size)
    if not fs then return end
    local metadata = self:GetFontMetadata(fs)
    if size then
        metadata = self:SetFontBaseSize(fs, size)
    elseif not metadata and fs.GetFont then
        local _, currentSize = fs:GetFont()
        metadata = self:SetFontBaseSize(fs, currentSize or 13)
    end
    self:SafeSetFont(fs, self:GetFont(), (metadata and metadata.baseSize) or 13)
end

function OneWoW_GUI:ApplyFontCapped(fs, size, maxOffset)
    if not fs then return end
    self:SetFontCap(fs, size, maxOffset)
    local offset = self:GetFontSizeOffset() or 0
    local cappedSize = math.max(6, size + math.min(offset, maxOffset))
    local target = self:GetFont() or GetStockFontPath()
    if target then
        -- Same file + same flags: SetFont keeps the previous size. WoW Default
        -- has no file path, so fall through to the stock face at cappedSize
        -- instead of SetFontObject (that bakes GameFontNormal's size).
        if ApplyFontFile(fs, target, cappedSize, "OUTLINE") then
            ApplyFontFile(fs, target, cappedSize, "")
            return
        end
    end
    fs:SetFontObject(GameFontNormal)
end

function OneWoW_GUI:ApplyFontToFrame(frame)
    if not frame then return end
    local fontPath = self:GetFont()
    for _, region in ipairs({frame:GetRegions()}) do
        if region.GetFont and region.SetFont then
            local metadata = self:GetFontMetadata(region)
            if not metadata then
                local _, sz = region:GetFont()
                if sz and sz > 0 then
                    metadata = self:SetFontBaseSize(region, sz)
                end
            end
            if metadata and metadata.baseSize then
                if metadata.maxOffset then
                    self:ApplyFontCapped(region, metadata.baseSize, metadata.maxOffset)
                else
                    self:SafeSetFont(region, fontPath, metadata.baseSize)
                end
            end
        end
    end
    for _, child in ipairs({frame:GetChildren()}) do
        if child:GetObjectType() == "EditBox" and child.GetFont then
            local metadata = self:GetFontMetadata(child)
            if not metadata then
                local _, sz = child:GetFont()
                if sz and sz > 0 then
                    metadata = self:SetFontBaseSize(child, sz)
                end
            end
            if metadata and metadata.baseSize then
                local _, _, flags = child:GetFont()
                self:SafeSetFont(child, fontPath, metadata.baseSize, flags)
            end
        end
        if child.GetObjectType and child:GetObjectType() == "ScrollFrame" and child.GetScrollChild then
            local scrollChild = child:GetScrollChild()
            if scrollChild then
                self:ApplyFontToFrame(scrollChild)
            end
        end
        self:ApplyFontToFrame(child)
    end
end

-- ============================================================================
-- Font-root registry
-- ============================================================================
-- The main OneWoW window re-applies fonts by rebuilding itself on font change
-- (ResetGUIOnSettingChange -> UI:FullReset). Frames that live *outside* that
-- window — standalone dialogs, and panels docked to Blizzard frames (Auction
-- House, merchant, etc.) — are not caught by that rebuild, so their text keeps
-- the size it had at creation until the next /reload.
--
-- A font root is any such frame that opts in to automatic font handling. On a
-- font / font-size change the driver below re-applies fonts across the whole
-- subtree (ApplyFontToFrame) and runs an optional re-flow callback so a stack
-- that measures its text can re-space itself. CreateDialog registers every
-- dialog automatically; docked panels call RegisterFontRoot directly.
--
-- Keyed weakly so a frame that's abandoned (never a real concern for the shared
-- reused dialogs, but true for one-shot panels) drops out without leaking.
local fontRoots = setmetatable({}, { __mode = "k" })

--- Register a frame subtree for automatic font updates on font / font-size change.
--- Idempotent: re-registering the same frame just updates its relayout callback.
---@param frame Frame root frame whose subtree gets ApplyFontToFrame on font change
---@param relayout (fun())|nil optional re-flow callback run after fonts re-apply
function OneWoW_GUI:RegisterFontRoot(frame, relayout)
    if not frame then return end
    fontRoots[frame] = relayout or true
end

--- Stop tracking a frame. Rarely needed thanks to weak keys, but available for
--- panels that are explicitly torn down.
---@param frame Frame
function OneWoW_GUI:UnregisterFontRoot(frame)
    if frame then fontRoots[frame] = nil end
end

-- Re-apply fonts (and re-flow) across every registered root. One misbehaving
-- panel's relayout must not stop the others from updating, so relayouts are
-- isolated via pcall; the error still surfaces through the normal handler.
local function RefreshFontRoots()
    for frame, relayout in pairs(fontRoots) do
        OneWoW_GUI:ApplyFontToFrame(frame)
        if type(relayout) == "function" then
            local ok, err = pcall(relayout)
            if not ok then geterrorhandler()(err) end
        end
    end
end

-- Drive the registry off font changes. SetSetting fires OnFontChanged for both
-- a font swap and a size change (the fontSizeOffset branch fires it after
-- OnFontSizeChanged), so listening to OnFontChanged alone covers every case
-- without double-processing.
OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", OneWoW_GUI, RefreshFontRoots)

function OneWoW_GUI:MigrateLSMFontName(lsmName)
    if not lsmName then return nil end
    return LSM_NAME_TO_KEY[lsmName]
end
