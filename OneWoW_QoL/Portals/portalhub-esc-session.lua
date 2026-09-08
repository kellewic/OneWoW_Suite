local _, ns = ...

-- ============================================================================
-- ESC session tray + in-place Game Menu skin
-- ============================================================================
-- Keep GameMenuFrame and its button pool. Fade native art, overlay Suite
-- chrome, and wrap the visible columns in a mouse-disabled tray. Logout/Quit
-- stay on Blizzard widgets. Skin lives here (not OneWoW_GUI) this pass.
-- ============================================================================

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc

local C = OneWoW_GUI.Constants

ns.EscSession = ns.EscSession or {}
local Session = ns.EscSession

local TRAY_PAD = 16
local HEADER_H = 28
local COL_GAP = 6

local tray
local trayHeader
local trayTitle
local hookedMenu
local skinChrome = {}
local initialized = false
local settingsWired = false

local ART_KEYS = { "Border", "Header", "NineSlice", "Bg", "Background" }
local SLICE_KEYS = { "Left", "Center", "Right" }

local function MenuGap()
	return ns.EscPanels:GetMenuGap()
end

local function SkinEnabled(ph)
	return ph and ph.escSkinGameMenu ~= false
end

local function FadeMenuArt(menu, alpha)
	if not menu then
		return
	end
	for i = 1, #ART_KEYS do
		local piece = menu[ART_KEYS[i]]
		if piece and piece.SetAlpha then
			piece:SetAlpha(alpha)
		end
	end
end

local function FadeButtonSlices(button, alpha)
	for i = 1, #SLICE_KEYS do
		local tex = button[SLICE_KEYS[i]]
		if tex and tex.SetAlpha then
			tex:SetAlpha(alpha)
		end
	end
	local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
	if highlight and highlight.SetAlpha then
		highlight:SetAlpha(alpha)
	end
end

local function PaintChrome(chrome, state)
	if state == "hover" then
		chrome:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
		chrome:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
	elseif state == "pressed" then
		chrome:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED"))
		chrome:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
	else
		chrome:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
		chrome:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
	end
end

local function ApplyButtonFont(button)
	local fs = button.GetFontString and button:GetFontString()
	if not fs then
		return
	end
	OneWoW_GUI:SafeSetFont(fs, OneWoW_GUI:GetFont(), 14, "OUTLINE")
	if button:IsEnabled() then
		fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
	else
		fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
	end
end

local function UpdateChromeState(button, pushed)
	local chrome = skinChrome[button]
	if not chrome then
		return
	end
	local enabled = button:IsEnabled()
	local visible = button:IsVisible()
	local hovered = visible and enabled and button:IsMouseOver()
	if pushed == nil then
		pushed = button.GetButtonState and button:GetButtonState() == "PUSHED"
	end
	pushed = visible and enabled and pushed
	chrome:SetAlpha(enabled and 1 or 0.45)
	if pushed then
		PaintChrome(chrome, "pressed")
	elseif hovered then
		PaintChrome(chrome, "hover")
	else
		PaintChrome(chrome, "normal")
	end
	ApplyButtonFont(button)
end

local function EnsureButtonChrome(button)
	local chrome = skinChrome[button]
	if not chrome then
		chrome = CreateFrame("Frame", nil, button, "BackdropTemplate")
		chrome.ignoreInLayout = true
		chrome:EnableMouse(false)
		chrome:SetAllPoints(button)
		chrome:SetBackdrop(C.BACKDROP_INNER)
		skinChrome[button] = chrome

		local function refresh(myself)
			UpdateChromeState(myself)
		end
		button:HookScript("OnEnter", refresh)
		button:HookScript("OnLeave", function(myself)
			UpdateChromeState(myself, false)
		end)
		button:HookScript("OnMouseDown", function(myself)
			UpdateChromeState(myself, true)
		end)
		button:HookScript("OnMouseUp", function(myself)
			UpdateChromeState(myself, false)
		end)
		button:HookScript("OnEnable", refresh)
		button:HookScript("OnDisable", refresh)
		button:HookScript("OnShow", refresh)
		button:HookScript("OnHide", function(myself)
			UpdateChromeState(myself, false)
		end)
	end
	chrome:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
	chrome:Show()
	FadeButtonSlices(button, 0)
	UpdateChromeState(button)
end

local function ExpandBox(left, right, top, bottom, frame)
	if not frame or not frame.IsShown or not frame:IsShown() then
		return left, right, top, bottom
	end
	local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not l or not r or not t or not b then
		return left, right, top, bottom
	end
	if not left or l < left then left = l end
	if not right or r > right then right = r end
	if not top or t > top then top = t end
	if not bottom or b < bottom then bottom = b end
	return left, right, top, bottom
end

local function EnsureTray()
	if tray then
		return tray
	end

	tray = CreateFrame("Frame", "OneWoWEscSessionTray", UIParent, "BackdropTemplate")
	tray:SetFrameStrata("DIALOG")
	tray:SetFrameLevel(1)
	tray:EnableMouse(false)
	tray:SetBackdrop(C.BACKDROP_SOFT)
	tray:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
	tray:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

	trayHeader = tray:CreateTexture(nil, "ARTWORK")
	trayHeader:SetPoint("TOPLEFT", tray, "TOPLEFT", 4, -4)
	trayHeader:SetPoint("TOPRIGHT", tray, "TOPRIGHT", -4, -4)
	trayHeader:SetHeight(HEADER_H)
	trayHeader:SetColorTexture(OneWoW_GUI:GetThemeColor("TITLEBAR_BG"))

	trayTitle = OneWoW_GUI:CreateFS(tray, 14)
	trayTitle:SetPoint("TOP", tray, "TOP", 0, -10)
	trayTitle:SetText(MAINMENU_BUTTON)
	trayTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

	OneWoW_GUI:RegisterFontRoot(tray)
	return tray
end

local function PaintTray()
	if not tray then
		return
	end
	tray:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
	tray:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
	if trayHeader then
		trayHeader:SetColorTexture(OneWoW_GUI:GetThemeColor("TITLEBAR_BG"))
	end
	if trayTitle then
		trayTitle:SetText(MAINMENU_BUTTON)
		trayTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
	end
end

function Session:HideSession()
	if tray then
		tray:Hide()
	end
end

function Session:RestoreMenuArt()
	local menu = GameMenuFrame
	if not menu then
		return
	end
	FadeMenuArt(menu, 1)
	if menu.buttonPool and menu.buttonPool.EnumerateActive then
		for button in menu.buttonPool:EnumerateActive() do
			FadeButtonSlices(button, 1)
			local chrome = skinChrome[button]
			if chrome then
				chrome:Hide()
			end
		end
	end
end

function Session:RefreshMenuSkin()
	local menu = GameMenuFrame
	if not menu or not menu:IsShown() then
		return
	end
	local ph = OneWoW:GetPortalHub()
	if not SkinEnabled(ph) then
		self:RestoreMenuArt()
		return
	end
	if OneWoW.Restriction.IsProtectedActionBlocked() then
		return
	end

	FadeMenuArt(menu, 0)
	if menu.buttonPool and menu.buttonPool.EnumerateActive then
		for button in menu.buttonPool:EnumerateActive() do
			EnsureButtonChrome(button)
		end
	end
end

function Session:RequestSkinRefresh()
	OneWoW.Restriction.RunWhenUnrestricted("protected", "OneWoW_QoL.esc.menuskin", function()
		if not GameMenuFrame or not GameMenuFrame:IsShown() then
			return
		end
		Session:RefreshMenuSkin()
	end)
end

function Session:FitTray()
	local menu = GameMenuFrame
	if not menu or not menu:IsShown() then
		self:HideSession()
		return
	end

	local left, right, top, bottom = ExpandBox(nil, nil, nil, nil, menu)
	left, right, top, bottom = ExpandBox(left, right, top, bottom, ns.EscPanels:GetPanelsContainer())
	left, right, top, bottom = ExpandBox(left, right, top, bottom, ns.PortalHubEsc:GetTravelCard())
	if not left then
		self:HideSession()
		return
	end

	local host = EnsureTray()
	PaintTray()
	host:ClearAllPoints()
	host:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left - TRAY_PAD, bottom - TRAY_PAD)
	host:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right + TRAY_PAD, top + TRAY_PAD + HEADER_H)
	host:Show()
end

function Session:SyncLayout()
	local menu = GameMenuFrame
	if not menu or not menu:IsShown() then
		return
	end
	local ph = OneWoW:GetPortalHub()
	if not ph or not ph.escEnabled then
		return
	end

	local panelsSide = ph.escPanelsSide == "right" and "right" or "left"
	local portalsSide = ph.escPortalsSide == "left" and "left" or "right"
	local cardsOn = ns.EscPanels:HasVisiblePanelStack()
	local travel = ns.PortalHubEsc:GetTravelCard()
	local travelOn = travel and travel:IsShown()
	local sameSide = cardsOn and travelOn and (panelsSide == portalsSide)
	local gap = MenuGap()

	if cardsOn then
		ns.EscPanels:SyncPanelsContainerPosition(ph)
	end

	if travelOn then
		travel:ClearAllPoints()
		if sameSide then
			local pc = ns.EscPanels:GetPanelsContainer()
			if pc and pc:IsShown() then
				if panelsSide == "right" then
					travel:SetPoint("TOPLEFT", pc, "BOTTOMLEFT", 0, -COL_GAP)
				else
					travel:SetPoint("TOPRIGHT", pc, "BOTTOMRIGHT", 0, -COL_GAP)
				end
			elseif portalsSide == "right" then
				travel:SetPoint("TOPLEFT", menu, "TOPRIGHT", gap, 0)
			else
				travel:SetPoint("TOPRIGHT", menu, "TOPLEFT", -gap, 0)
			end
		elseif portalsSide == "right" then
			travel:SetPoint("TOPLEFT", menu, "TOPRIGHT", gap, 0)
		else
			travel:SetPoint("TOPRIGHT", menu, "TOPLEFT", -gap, 0)
		end
	end

	if SkinEnabled(ph) then
		self:FitTray()
		self:RequestSkinRefresh()
	else
		self:HideSession()
		self:RestoreMenuArt()
	end
end

function Session:ArmMenu()
	local menu = GameMenuFrame
	if not menu or hookedMenu == menu then
		return
	end
	hookedMenu = menu
	hooksecurefunc(menu, "InitButtons", function()
		Session:RequestSkinRefresh()
	end)
	if type(menu.AddButton) == "function" then
		hooksecurefunc(menu, "AddButton", function()
			Session:RequestSkinRefresh()
		end)
	end
	menu:HookScript("OnShow", function()
		Session:RequestSkinRefresh()
	end)
end

function Session:Initialize()
	if initialized then
		ns.PortalHubEsc:HookGameMenu()
		self:ArmMenu()
		return
	end
	initialized = true

	local function arm()
		ns.PortalHubEsc:HookGameMenu()
		Session:ArmMenu()
		if GameMenuFrame and GameMenuFrame:IsShown() then
			Session:RequestSkinRefresh()
		end
	end

	if GameMenuFrame then
		arm()
	end
	OneWoW:RegisterAddonLoadedWatcher("Blizzard_GameMenu", arm)

	if not settingsWired then
		settingsWired = true
		OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", Session, function()
			if GameMenuFrame and GameMenuFrame:IsShown() then
				Session:SyncLayout()
			end
		end)
	end
end
