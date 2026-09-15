local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local OverlayIcons = OneWoW.OverlayIcons
local format = string.format

-- ============================================================================
-- WayPinsVisual
-- ============================================================================
-- Paints a OneWay Pin button: icon and optional background. Backgrounds reuse
-- OverlayIcons atlas names. Extra layers cost frames; the edit dialog warns
-- about that. Minimap animation can be turned off in Notes settings.
-- ============================================================================

local Visual = {}
ns.WayPinsVisual = Visual

local DEFAULT_WORLD = 22
local DEFAULT_MINIMAP = 16
local BG_ZOOM = 1.8
-- Same halo as overlay backgrounds: scale 1 is a bit larger than the icon,
-- so a 22px list pin and a 96px map pin keep the same look.
local BG_SIZE_RATIO = 1.6

-- Glow, auction-house borders, artifact rings/FX, and power swirls are
-- backgrounds on OneWay Pins (not pin icons). OverlayIcons still lists
-- them for Overlays.
Visual.BG_STYLES = {
    "Solid-Circle",
    "Solid-Square",
    "Glow Pulse",
    "Spinning Orbs",
    "Portal Spiral",
    "bags-glow-white",
    "bags-glow-purple",
    "bags-glow-blue",
    "bags-glow-green",
    "bags-glow-orange",
    "bags-glow-artifact",
    "bags-glow-heirloom",
    "bags-newitem",
    "auctionhouse-itemicon-border-color",
    "auctionhouse-itemicon-border-blue",
    "auctionhouse-itemicon-border-green",
    "auctionhouse-itemicon-border-purple",
    "auctionhouse-itemicon-border-gray",
    "auctionhouse-itemicon-border-orange",
    "auctionhouse-itemicon-border-white",
    "auctionhouse-itemicon-border-account",
    "auctionhouse-itemicon-border-artifact",
    "Artifacts-ItemIconBorder",
    "Artifacts-PerkRing-GoldMedal",
    "Artifacts-PerkRing-MainProc",
    "Artifacts-PerkRing-Small",
    "Artifacts-PerkRing-Highlight",
    "ArtifactsFX-SpinningGlowys",
    "ArtifactsFX-StarBurst",
    "ArtifactsFX-YellowRing",
    "PowerSwirlAnimation-YellowRing",
    "PowerSwirlAnimation-BlueRing",
    "PowerSwirlAnimation-StarBurst",
    "PowerSwirlAnimation-WhiteStarBurst",
    "PowerSwirlAnimation-SpinningGlowys",
}

local bgStyleSet = {}
for _, name in ipairs(Visual.BG_STYLES) do
    bgStyleSet[name] = true
end

local WORLD_SIZE_MAX = 96
local MINIMAP_SIZE_MAX = 96

local function Clamp(n, lo, hi)
    n = tonumber(n)
    if not n then return nil end
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

function Visual.WorldDefault()
    return Clamp(ns.db.global.waypinWorldSize, 12, WORLD_SIZE_MAX) or DEFAULT_WORLD
end

function Visual.MinimapDefault()
    return Clamp(ns.db.global.waypinMinimapSize, 10, MINIMAP_SIZE_MAX) or DEFAULT_MINIMAP
end

function Visual.WorldSize(pin)
    if pin and pin.mapSize then
        return Clamp(pin.mapSize, 12, WORLD_SIZE_MAX)
    end
    return Visual.WorldDefault()
end

function Visual.WorldSizeMax()
    return WORLD_SIZE_MAX
end

function Visual.MinimapSizeMax()
    return MINIMAP_SIZE_MAX
end

--- True when this OverlayIcons list name is a pin icon (not a background).
---@param name string|nil
---@return boolean
function Visual.IsPinIconName(name)
    if type(name) ~= "string" or name == "" or name == "BLANK" then
        return false
    end
    if bgStyleSet[name] then
        return false
    end
    if name:find("^bags%-glow%-", 1) then
        return false
    end
    if name:find("^auctionhouse%-itemicon%-border", 1) then
        return false
    end
    if name:find("^Artifacts", 1) or name:find("^PowerSwirl", 1) then
        return false
    end
    return true
end

--- Paint a background style onto a texture (editor grid + pin).
---@param texture Texture
---@param style string|nil
function Visual.PaintStyle(texture, style)
    if not texture then return end
    texture:SetAlpha(1)
    texture:SetVertexColor(1, 1, 1)
    if not style or style == "" then
        texture:SetTexture(nil)
        texture:SetAlpha(0)
        return
    end
    if style == "Solid-Circle" then
        texture:SetTexture(nil)
        texture:SetAtlas("WhiteCircle-RaidBlips", false)
        return
    end
    if style == "Solid-Square" then
        texture:SetAtlas("")
        texture:SetTexture("Interface\\Buttons\\WHITE8x8")
        return
    end
    if style == "Glow Pulse" then
        texture:SetTexture(nil)
        texture:SetAtlas("bags-glow-white", false)
        return
    end
    if style == "Spinning Orbs" then
        texture:SetTexture(nil)
        texture:SetAtlas("ArtifactsFX-SpinningGlowys-Purple", false)
        return
    end
    if style == "Portal Spiral" then
        texture:SetTexture(nil)
        texture:SetAtlas("UI-Frame-jailerstower-Portrait-QualityEpic", false)
        return
    end
    if C_Texture.GetAtlasInfo(style) then
        texture:SetTexture(nil)
        texture:SetAtlas(style, false)
        return
    end
    OverlayIcons:ApplyToTexture(texture, style)
    texture:SetAlpha(1)
end

function Visual.MinimapSize(pin)
    if pin and pin.minimapSize then
        return Clamp(pin.minimapSize, 10, MINIMAP_SIZE_MAX)
    end
    return Visual.MinimapDefault()
end

function Visual.Enabled()
    return ns.db.global.waypinEnabled ~= false
end

function Visual.MapClickMenu()
    return ns.db.global.waypinMapClickEnabled ~= false
end

function Visual.MapClick()
    if ns.db.global.waypinMapClick == "right" then
        return "right"
    end
    return "ctrlRight"
end

function Visual.ShowWorld()
    return Visual.Enabled() and ns.db.global.waypinShowWorld ~= false
end

function Visual.ShowMinimap()
    return Visual.Enabled() and ns.db.global.waypinShowMinimap ~= false
end

function Visual.ShowZoneList()
    return Visual.Enabled() and ns.db.global.waypinShowZoneList ~= false
end

local SURFACE_KEYS = {
    list = "showOnList",
    world = "showOnWorld",
    minimap = "showOnMinimap",
}

--- True when this pin (and its pack, if any) should draw on a surface.
---@param pin table
---@param surface string "list"|"world"|"minimap"
---@return boolean
function Visual.PinShowsOn(pin, surface)
    local key = SURFACE_KEYS[surface]
    if not key or type(pin) ~= "table" then
        return true
    end
    if pin[key] == false then
        return false
    end
    local packId = pin.packId
    if packId and ns.WayPinPacks then
        local pack = ns.WayPinPacks:GetPack(packId)
        if pack and not ns.WayPinPacks:ShowsOn(pack, key) then
            return false
        end
    end
    return true
end

--- Hide the Pins list in places where it gets in the way.
---@return boolean
function Visual.HideListHere()
    local db = ns.db.global
    if db.waypinHideInPetBattles ~= false and C_PetBattles.IsInBattle() then
        return true
    end
    local inInstance, instanceType = IsInInstance()
    local inDelve = C_PartyInfo.IsDelveInProgress()
    if db.waypinHideInBattlegrounds ~= false then
        if instanceType == "pvp" or instanceType == "arena"
            or OneWoW.Restriction.IsTypeActive(Enum.AddOnRestrictionType.PvPMatch)
        then
            return true
        end
    end
    if db.waypinHideInDelves ~= false and inDelve then
        return true
    end
    if db.waypinHideInInstances ~= false and inInstance and not inDelve
        and instanceType ~= "pvp" and instanceType ~= "arena"
    then
        return true
    end
    return false
end

function Visual.MinimapAnimate()
    return Visual.Enabled() and ns.db.global.waypinMinimapAnimate == true
end

local function SetupBgAnim(look)
    if look.bgAnim then return end
    local ag = look.bgTex:CreateAnimationGroup()
    local spin1 = ag:CreateAnimation("Rotation")
    spin1:SetDuration(1.5)
    spin1:SetDegrees(-360)
    spin1:SetOrder(1)
    local scaleUp = ag:CreateAnimation("Scale")
    scaleUp:SetDuration(0.75)
    scaleUp:SetScale(BG_ZOOM, BG_ZOOM)
    scaleUp:SetOrder(1)
    local spin2 = ag:CreateAnimation("Rotation")
    spin2:SetDuration(1.5)
    spin2:SetDegrees(-360)
    spin2:SetOrder(2)
    local scaleDown = ag:CreateAnimation("Scale")
    scaleDown:SetDuration(0.75)
    scaleDown:SetScale(1 / BG_ZOOM, 1 / BG_ZOOM)
    scaleDown:SetOrder(2)
    ag:SetLooping("REPEAT")

    look.bgAnim = ag
    look.bgSpin1 = spin1
    look.bgSpin2 = spin2
    look.bgScaleUp = scaleUp
    look.bgScaleDown = scaleDown
end

local function ConfigureSpinZoom(spin1, spin2, scaleUp, scaleDown, effect, zoom)
    local hasSpin = (effect == "spinning" or effect == "both")
    local hasZoom = (effect == "zooming" or effect == "both")
    spin1:SetDegrees(hasSpin and -360 or 0)
    spin2:SetDegrees(hasSpin and -360 or 0)
    scaleUp:SetScale(hasZoom and zoom or 1, hasZoom and zoom or 1)
    scaleDown:SetScale(hasZoom and (1 / zoom) or 1, hasZoom and (1 / zoom) or 1)
end

local function StopAnims(look)
    if look.iconAnim then look.iconAnim:Stop() end
    if look.bgAnim then look.bgAnim:Stop() end
    if look.bgPulse then look.bgPulse:Stop() end
    if look.bgTex then
        look.bgTex:SetRotation(0)
        look.bgTex:SetScale(1)
        look.bgTex:SetAlpha(1)
    end
end

--- Spin / zoom / both from the pin editor. Style names do not animate on their own.
---@param bg table|nil
---@param pin table|nil
---@return string
local function ResolveBgEffect(bg, pin)
    local effect = bg and bg.effect
    if effect ~= "spinning" and effect ~= "zooming" and effect ~= "both" then
        effect = pin and pin.effect
    end
    if effect == "spinning" or effect == "zooming" or effect == "both" then
        return effect
    end
    return "none"
end

function Visual.Attach(btn)
    if btn._wayLook then return btn._wayLook end

    local bgFrame = CreateFrame("Frame", nil, btn)
    bgFrame:SetAllPoints()
    bgFrame:EnableMouse(false)
    local bgTex = bgFrame:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints()
    bgTex:SetTexelSnappingBias(0)
    bgTex:SetSnapToPixelGrid(false)

    local iconFrame = CreateFrame("Frame", nil, btn)
    iconFrame:SetAllPoints()
    iconFrame:EnableMouse(false)
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexelSnappingBias(0)
    icon:SetSnapToPixelGrid(false)

    local glow = btn:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("CENTER")
    glow:SetAtlas("UI-QuestPoiImportant-OuterGlow")
    glow:SetTexelSnappingBias(0)
    glow:SetSnapToPixelGrid(false)
    glow:Hide()

    local look = {
        bgFrame = bgFrame,
        bgTex = bgTex,
        iconFrame = iconFrame,
        icon = icon,
        glow = glow,
        bgMask = nil,
        bgMaskOn = false,
    }
    btn._wayLook = look
    btn.icon = icon
    btn.glow = glow
    return look
end

local function ApplyCircleMask(look)
    if not look.bgMask then
        local mask = look.bgFrame:CreateMaskTexture()
        mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(look.bgFrame)
        look.bgMask = mask
    end
    if not look.bgMaskOn then
        look.bgTex:AddMaskTexture(look.bgMask)
        look.bgMaskOn = true
    end
    look.bgMask:Show()
end

local function RemoveCircleMask(look)
    if look.bgMask and look.bgMaskOn then
        look.bgTex:RemoveMaskTexture(look.bgMask)
        look.bgMaskOn = false
        look.bgMask:Hide()
    end
end

local function ApplyBackground(look, bg, size, effect)
    if not bg or not bg.enabled then
        StopAnims(look)
        look.bgFrame:Hide()
        return
    end

    StopAnims(look)

    local style = bg.style or "Solid-Circle"
    local scale = tonumber(bg.scale) or 1
    local color = bg.color or { 1, 1, 1 }
    local bgSize = size * BG_SIZE_RATIO * scale
    look.bgFrame:ClearAllPoints()
    look.bgFrame:SetSize(bgSize, bgSize)
    look.bgFrame:SetPoint("CENTER")
    Visual.PaintStyle(look.bgTex, style)
    look.bgTex:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1)

    if style == "Solid-Circle" then
        ApplyCircleMask(look)
    else
        RemoveCircleMask(look)
    end

    if effect == "spinning" or effect == "zooming" or effect == "both" then
        SetupBgAnim(look)
        ConfigureSpinZoom(look.bgSpin1, look.bgSpin2, look.bgScaleUp, look.bgScaleDown, effect, BG_ZOOM)
        look.bgAnim:Play()
    end
    look.bgFrame:Show()
end

--- Fingerprint of painted look. Minimap pins skip Apply when this is unchanged.
---@param pin table|nil
---@param size number|nil
---@param animate boolean|nil
---@param tracked boolean|nil
---@return string
function Visual.PaintSignature(pin, size, animate, tracked)
    pin = pin or {}
    local icon = pin.icon
    local bg = pin.bg
    local tint = icon and icon.tint
    return format("%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s",
        icon and icon.kind or "",
        icon and icon.value or "",
        tint and tostring(tint[1]) or "",
        tint and tostring(tint[2]) or "",
        tint and tostring(tint[3]) or "",
        bg and tostring(bg.enabled) or "",
        bg and (bg.style or "") or "",
        bg and (bg.effect or "") or "",
        bg and tostring(bg.scale or "") or "",
        pin.effect or "",
        tostring(size or ""),
        tostring(animate),
        tostring(tracked))
end

--- Paint icon / background and size the button.
---@param btn Button
---@param pin table
---@param opts table|nil { size = number, tracked = boolean, animate = boolean|nil }
function Visual.Apply(btn, pin, opts)
    opts = opts or {}
    local look = Visual.Attach(btn)
    local size = opts.size or Visual.WorldSize(pin)
    local animate = opts.animate ~= false
    btn:SetSize(size, size)
    look.iconFrame:SetFrameLevel(btn:GetFrameLevel() + 2)
    look.bgFrame:SetFrameLevel(btn:GetFrameLevel())

    OverlayIcons:ApplyIconSpec(look.icon, pin.icon)
    if opts.tracked then
        look.icon:SetVertexColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
        look.glow:SetSize(size + 10, size + 10)
        look.glow:Show()
    else
        look.glow:Hide()
    end

    local effect = "none"
    if animate then
        effect = ResolveBgEffect(pin.bg, pin)
    end
    ApplyBackground(look, pin.bg, size, effect)
    if look.iconAnim then
        look.iconAnim:Stop()
    end
end

function Visual.Hide(btn)
    if not btn then return end
    if btn._wayLook then
        StopAnims(btn._wayLook)
    end
    btn:Hide()
end
