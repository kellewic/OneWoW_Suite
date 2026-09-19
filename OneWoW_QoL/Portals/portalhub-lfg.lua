local _, ns = ...

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI

local L = ns.L

ns.PortalHubLFG = ns.PortalHubLFG or {}
local LFG = ns.PortalHubLFG

-- LFG_LIST_JOINED_GROUP lifts browse-time secrecy, but a secret field still
-- throws if read. Resolve inside pcall and skip the prompt on any secret.
local events = CreateFrame("Frame")
local dialog
local secureBtn
local pendingSpellID
local pendingName
local enabled = false

local function IsPromptEnabled()
	return OneWoW:GetPortalHub().lfgTeleportPrompt == true
end

local function SavePosition()
	if not dialog then
		return
	end
	local p, _, rp, x, y = dialog.frame:GetPoint()
	if p then
		OneWoW:GetPortalHub().lfgPromptPosition = {p = p, rp = rp, x = x, y = y}
	end
end

local function ApplySavedPosition()
	if not dialog then
		return
	end
	local pos = OneWoW:GetPortalHub().lfgPromptPosition
	dialog.frame:ClearAllPoints()
	if pos and pos.p then
		dialog.frame:SetPoint(pos.p, UIParent, pos.rp or pos.p, pos.x or 0, pos.y or 0)
	else
		dialog.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
	end
end

local function UpdateButtonVisuals()
	if not secureBtn or not pendingSpellID then
		return
	end
	local info = C_Spell.GetSpellInfo(pendingSpellID)
	if info and info.iconID then
		secureBtn.icon:SetTexture(info.iconID)
	end
	local known = C_SpellBook.IsSpellKnown(pendingSpellID)
	secureBtn.icon:SetDesaturated(not known)
	secureBtn.icon:SetAlpha(known and 1 or 0.4)
	local r, g, b = OneWoW_GUI:GetThemeColor(known and "TEXT_PRIMARY" or "TEXT_MUTED")
	secureBtn.label:SetTextColor(r, g, b)
	if known then
		local cd = C_Spell.GetSpellCooldown(pendingSpellID)
		if cd and cd.duration and cd.duration > 0 then
			secureBtn.cooldown:SetCooldown(cd.startTime, cd.duration)
		else
			secureBtn.cooldown:Clear()
		end
	else
		secureBtn.cooldown:Clear()
	end
end

local function ApplySecureSpell()
	if not secureBtn or not pendingSpellID then
		return
	end
	if OneWoW.Restriction.IsProtectedActionBlocked() then
		OneWoW.Restriction.RunWhenUnrestricted("protected", "OneWoW_QoL.portalhub.lfgattr", ApplySecureSpell)
		return
	end
	secureBtn:SetAttribute("spell", pendingSpellID)
	UpdateButtonVisuals()
end

local function HidePrompt()
	if not dialog or not dialog.frame:IsShown() then
		return
	end
	if OneWoW.Restriction.IsProtectedActionBlocked() then
		OneWoW.Restriction.RunWhenUnrestricted("protected", "OneWoW_QoL.portalhub.lfghide", HidePrompt)
		return
	end
	dialog.frame:Hide()
end

local function ShowPrompt()
	if not enabled or not pendingSpellID or not dialog then
		return
	end
	if OneWoW.Restriction.IsInCombat() then
		OneWoW.Restriction.RunWhenUnrestricted("protected", "OneWoW_QoL.portalhub.lfgshow", ShowPrompt)
		return
	end
	if OneWoW.Restriction.IsProtectedActionBlocked() then
		OneWoW.Restriction.RunWhenUnrestricted("protected", "OneWoW_QoL.portalhub.lfgshow", ShowPrompt)
		return
	end
	dialog.nameFS:SetText(pendingName or "")
	local nameHeight = dialog.nameFS:GetStringHeight()
	if nameHeight < 16 then
		nameHeight = 16
	end
	dialog.nameHost:SetHeight(nameHeight)
	ApplySecureSpell()
	dialog.frame:Show()
end

local function ClearPending()
	pendingSpellID = nil
	pendingName = nil
	OneWoW.Restriction.CancelWhenUnrestricted("OneWoW_QoL.portalhub.lfgshow")
	OneWoW.Restriction.CancelWhenUnrestricted("OneWoW_QoL.portalhub.lfgattr")
end

local function BuildPopup()
	if dialog then
		return
	end
	if OneWoW.Restriction.IsProtectedActionBlocked() then
		OneWoW.Restriction.RunWhenUnrestricted("protected", "OneWoW_QoL.portalhub.lfgbuild", BuildPopup)
		return
	end

	dialog = OneWoW_GUI:CreateDialog({
		name = "OneWoW_PortalLFGPrompt",
		title = L["PORTAL_LFG_PROMPT_TITLE"],
		width = 240,
		height = 168,
		escClose = false,
		movable = true,
		onClose = function()
			ClearPending()
		end,
	})
	dialog.frame:HookScript("OnDragStop", SavePosition)
	if dialog.titleBar then
		dialog.titleBar:HookScript("OnDragStop", SavePosition)
	end

	local nameHost = CreateFrame("Frame", nil, dialog.contentFrame)
	nameHost:SetPoint("TOPLEFT", dialog.contentFrame, "TOPLEFT", 10, -8)
	nameHost:SetPoint("TOPRIGHT", dialog.contentFrame, "TOPRIGHT", -10, -8)
	nameHost:SetHeight(16)
	dialog.nameHost = nameHost

	local nameFS = OneWoW_GUI:CreateFS(nameHost, 13)
	nameFS:SetPoint("TOPLEFT")
	nameFS:SetPoint("TOPRIGHT")
	nameFS:SetJustifyH("CENTER")
	nameFS:SetWordWrap(true)
	dialog.nameFS = nameFS

	secureBtn = CreateFrame("Button", nil, dialog.contentFrame, "SecureActionButtonTemplate")
	-- SecureActionButton cannot SetPoint to a FontString (region).
	secureBtn:SetPoint("TOPLEFT", nameHost, "BOTTOMLEFT", 0, -8)
	secureBtn:SetPoint("TOPRIGHT", nameHost, "BOTTOMRIGHT", 0, -8)
	secureBtn:SetHeight(52)
	secureBtn:RegisterForClicks("AnyUp", "AnyDown")
	secureBtn:SetAttribute("type", "spell")

	local bg = secureBtn:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))

	local icon = secureBtn:CreateTexture(nil, "ARTWORK")
	icon:SetSize(36, 36)
	icon:SetPoint("LEFT", 8, 0)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	secureBtn.icon = icon

	local label = OneWoW_GUI:CreateFS(secureBtn, 12)
	label:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	label:SetPoint("RIGHT", -8, 0)
	label:SetJustifyH("LEFT")
	label:SetText(L["PORTAL_LFG_PROMPT_TELEPORT"])
	secureBtn.label = label

	local hover = secureBtn:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints()
	hover:SetColorTexture(1, 1, 1, 0.12)

	local cd = CreateFrame("Cooldown", nil, secureBtn, "CooldownFrameTemplate")
	cd:SetPoint("LEFT", secureBtn, "LEFT", 8, 0)
	cd:SetSize(36, 36)
	cd:SetHideCountdownNumbers(true)
	cd:SetDrawBling(false)
	cd:SetDrawEdge(false)
	secureBtn.cooldown = cd

	secureBtn:SetScript("OnEnter", function(myself)
		if not pendingSpellID then
			return
		end
		GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
		if not C_SpellBook.IsSpellKnown(pendingSpellID) then
			GameTooltip:SetText(L["PORTAL_LFG_PROMPT_NOT_LEARNED"], 1, 1, 1)
		else
			local cdInfo = C_Spell.GetSpellCooldown(pendingSpellID)
			if cdInfo and cdInfo.duration and cdInfo.duration > 0 then
				GameTooltip:SetText(L["PORTAL_LFG_PROMPT_ON_COOLDOWN"], 1, 1, 1)
			else
				GameTooltip:SetSpellByID(pendingSpellID)
			end
		end
		GameTooltip:Show()
	end)
	secureBtn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local turnOff = OneWoW_GUI:CreateFitTextButton(dialog.contentFrame, {
		text = L["PORTAL_LFG_PROMPT_TURN_OFF"],
		height = 22,
	})
	turnOff:SetPoint("BOTTOM", dialog.contentFrame, "BOTTOM", 0, 8)
	turnOff:SetScript("OnClick", function()
		OneWoW:GetPortalHub().lfgTeleportPrompt = false
		LFG:SetEnabled(false)
	end)

	ApplySavedPosition()
	dialog.frame:Hide()
end

local function ResolveJoinedDungeon(resultID)
	local spellID, displayName
	local ok = pcall(function()
		local info = C_LFGList.GetSearchResultInfo(resultID)
		if type(info) ~= "table" then
			return
		end
		local activityID = info.activityID
		if activityID == nil and info.activityIDs and not OneWoW.Restriction.IsSecret(info.activityIDs) then
			activityID = info.activityIDs[1]
		end
		if activityID == nil or OneWoW.Restriction.IsSecret(activityID) then
			return
		end
		local act = C_LFGList.GetActivityInfoTable(activityID)
		if type(act) ~= "table" then
			return
		end
		local fullName = act.fullName
		if type(fullName) ~= "string" or OneWoW.Restriction.IsSecret(fullName) then
			return
		end
		spellID = ns.PortalHubDetection:ResolvePathSpellByName(fullName)
		if spellID then
			displayName = fullName:gsub("%s*%b()%s*$", "")
		end
	end)
	if ok and spellID then
		pendingSpellID = spellID
		pendingName = displayName
	end
end

local function SyncEvents()
	if enabled then
		events:RegisterEvent("LFG_LIST_JOINED_GROUP")
		events:RegisterEvent("GROUP_ROSTER_UPDATE")
		events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	else
		events:UnregisterEvent("LFG_LIST_JOINED_GROUP")
		events:UnregisterEvent("GROUP_ROSTER_UPDATE")
		events:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
	end
end

function LFG:SetEnabled(wantEnabled)
	enabled = wantEnabled and true or false
	if enabled then
		BuildPopup()
		SyncEvents()
	else
		ClearPending()
		HidePrompt()
		SyncEvents()
		OneWoW.Restriction.CancelWhenUnrestricted("OneWoW_QoL.portalhub.lfgbuild")
		OneWoW.Restriction.CancelWhenUnrestricted("OneWoW_QoL.portalhub.lfghide")
	end
end

function LFG:Initialize()
	OneWoW_QoL:RegisterEnteringWorldHandler("portalhub-lfg", function()
		local inInstance, instanceType = IsInInstance()
		if inInstance and instanceType == "party" then
			ClearPending()
			HidePrompt()
		end
	end)
	self:SetEnabled(IsPromptEnabled())
end

events:SetScript("OnEvent", function(_, event, arg1)
	if not enabled then
		return
	end
	if event == "LFG_LIST_JOINED_GROUP" then
		ClearPending()
		ResolveJoinedDungeon(arg1)
		if pendingSpellID then
			if not dialog then
				BuildPopup()
			end
			ShowPrompt()
		end
	elseif event == "GROUP_ROSTER_UPDATE" then
		if not IsInGroup() then
			ClearPending()
			HidePrompt()
		end
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		local inInstance, instanceType = IsInInstance()
		if inInstance and instanceType == "party" then
			ClearPending()
			HidePrompt()
		end
	end
end)
