local _, ns = ...
local OneWoW_GUI = OneWoW_GUI

local QuestToolsModule, L = ns.ModuleRegistry:Current()
if not QuestToolsModule then return end

local collapsedCards = {}

local MODIFIER_FNS = {
    SHIFT = IsShiftKeyDown,
    CTRL = IsControlKeyDown,
    ALT = IsAltKeyDown,
}

local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("questtools", id)
end

local function GetModifierKey()
    local key = ns.ModuleRegistry:GetModuleBucket("questtools").modifierKey
    if key == "SHIFT" or key == "CTRL" or key == "ALT" then
        return key
    end
    return "SHIFT"
end

local function SetModifierKey(key)
    if key ~= "SHIFT" and key ~= "CTRL" and key ~= "ALT" then return end
    ns.ModuleRegistry:GetModuleBucket("questtools").modifierKey = key
end

local function ModifierLabel(key)
    if key == "CTRL" then return CTRL_KEY_TEXT end
    if key == "ALT" then return ALT_KEY_TEXT end
    return SHIFT_KEY_TEXT
end

local function ModifierHeld()
    local fn = MODIFIER_FNS[GetModifierKey()] or IsShiftKeyDown
    return fn()
end

local function ShouldAutomate()
    local held = ModifierHeld()
    if GetToggle("require_modifier") then
        return held
    end
    return not held
end

local function GetDisplayedTextFromGossipButton(btn)
    if not btn then return nil end
    if btn.GetText then
        local t = btn:GetText()
        if type(t) == "string" and t ~= "" then return t end
    end
    local regions = { btn:GetRegions() }
    for _, rr in ipairs(regions) do
        if rr.GetText and rr:GetObjectType() == "FontString" then
            local t = rr:GetText()
            if type(t) == "string" and t ~= "" then return t end
        end
    end
    return nil
end

function QuestToolsModule:GetGossipDisplayedButtonTexts()
    local out = {}
    local gf = GossipFrame
    if not gf or not gf:IsShown() then return out end
    local scrollTarget = gf.GreetingPanel and gf.GreetingPanel.ScrollBox and gf.GreetingPanel.ScrollBox.ScrollTarget
    if not scrollTarget then return out end
    local children = { scrollTarget:GetChildren() }
    for _, child in ipairs(children) do
        if child and child.GetObjectType and child:GetObjectType() == "Button" then
            local t = GetDisplayedTextFromGossipButton(child)
            if t then
                out[#out + 1] = t
            end
        end
    end
    return out
end

function QuestToolsModule:DebugPrintGossipApiVsUi()
    print("|cff00ff00[OneWoW_QoL QuestTools]|r Gossip: API name vs. UI button text")

    local opts = C_GossipInfo.GetOptions()
    if opts then
        for _, o in pairs(opts) do
            print("  API", "order", tostring(o.orderIndex), "name", tostring(o.name), "icon", tostring(o.icon))
        end
    else
        print("  API: (nil)")
    end

    print("  UI (GossipFrame scroll buttons):")
    local lines = self:GetGossipDisplayedButtonTexts()
    if #lines == 0 then
        print("    (none — is GossipFrame open?)")
    else
        for i, line in ipairs(lines) do
            print("   ", i, line)
        end
    end
end

local function NormalizeGossipTextForMatch(text)
    if not text then return "" end
    local s = text
    s = s:gsub("|H[^|]+|h([^|]*)|h", "%1")
    for _ = 1, 12 do
        local before = s
        s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        if s == before then break end
    end
    s = s:gsub("|T[^|]+|t", "")
    s = s:gsub("^%s+", "")
    return s
end

local function HasQuestGossipMarker(name)
    if not name or name == "" then return false end
    local plain = "(quest)"
    if string.find(name:lower(), plain, 1, true) then return true end
    local s = NormalizeGossipTextForMatch(name)
    return string.find(s:lower(), plain, 1, true) ~= nil
end

function QuestToolsModule:IsGossipOptionChoosable(opt)
    if not opt then return false end
    if opt.status ~= nil then
        local S = Enum.GossipOptionStatus
        if opt.status == S.Locked or opt.status == S.Unavailable then
            return false
        end
    end
    return true
end

local function HasQuestLabelPrependFlag(opt)
    if not opt or opt.flags == nil then return false end
    return FlagsUtil.IsSet(opt.flags, Enum.GossipOptionRecFlags.QuestLabelPrepend)
end

local function ResolveIndexedGossipHits(hits, texts, byOrder)
    if #hits == 0 then return nil end
    if #hits == 1 then return hits[1].opt end
    local withDisplayQuest = {}
    for _, hit in ipairs(hits) do
        local t = texts[hit.index]
        if t and HasQuestGossipMarker(t) then
            withDisplayQuest[#withDisplayQuest + 1] = hit.opt
        end
    end
    if #withDisplayQuest == 1 then return withDisplayQuest[1] end
    if #withDisplayQuest > 1 then
        table.sort(withDisplayQuest, byOrder)
        return withDisplayQuest[1]
    end
    table.sort(hits, function(a, b)
        return (a.opt.orderIndex or math.huge) < (b.opt.orderIndex or math.huge)
    end)
    return hits[1].opt
end

function QuestToolsModule:PickQuestGossipOption()
    local options = C_GossipInfo.GetOptions()
    if not options then return nil end
    local list = {}
    for _, o in pairs(options) do
        list[#list + 1] = o
    end
    table.sort(list, function(a, b)
        return (a.orderIndex or math.huge) < (b.orderIndex or math.huge)
    end)
    local texts = self:GetGossipDisplayedButtonTexts()
    local byOrder = function(a, b)
        return (a.orderIndex or math.huge) < (b.orderIndex or math.huge)
    end
    local flagHits = {}
    for i, opt in ipairs(list) do
        if self:IsGossipOptionChoosable(opt) and HasQuestLabelPrependFlag(opt) then
            flagHits[#flagHits + 1] = { index = i, opt = opt }
        end
    end
    if #flagHits == 0 then return nil end
    return ResolveIndexedGossipHits(flagHits, texts, byOrder)
end

function QuestToolsModule:TryAutoGossip()
    if not ns.ModuleRegistry:IsEnabled("questtools") or not GetToggle("auto_gossip") then return false end
    if not ShouldAutomate() then return false end
    local gf = GossipFrame
    if gf and not gf:IsShown() then return false end

    local opt = self:PickQuestGossipOption()
    if not opt then return false end
    local name = opt.name or opt.title
    if opt.gossipOptionID ~= nil then
        local id = opt.gossipOptionID
        local ok = pcall(C_GossipInfo.SelectOption, id, name)
        if not ok then
            ok = pcall(C_GossipInfo.SelectOption, id)
        end
        return ok
    elseif opt.orderIndex ~= nil then
        local idx = opt.orderIndex
        local ok = pcall(C_GossipInfo.SelectOptionByIndex, idx, name)
        if not ok then
            ok = pcall(C_GossipInfo.SelectOptionByIndex, idx)
        end
        return ok
    end
    return false
end

function QuestToolsModule:ScheduleGossipRetries()
    if not ns.ModuleRegistry:IsEnabled("questtools") or not GetToggle("auto_gossip") then return end
    if not ShouldAutomate() then return end

    self._gossipRetryToken = (self._gossipRetryToken or 0) + 1
    local token = self._gossipRetryToken
    local attempt = 0
    local maxAttempts = 24

    local function step()
        if token ~= self._gossipRetryToken then return end
        if not GetToggle("auto_gossip") then return end
        if not ShouldAutomate() then return end
        local gf = GossipFrame
        if gf and not gf:IsShown() then return end
        attempt = attempt + 1
        if self:TryAutoGossip() then return end
        if attempt < maxAttempts then
            C_Timer.After(0.05, step)
        end
    end

    C_Timer.After(0, step)
end

function QuestToolsModule:OnGossipOpen()
    if not ns.ModuleRegistry:IsEnabled("questtools") or not GetToggle("auto_gossip") then return end
    if not ShouldAutomate() then return end
    self:HookGossipFrameShow()
    self:ScheduleGossipRetries()
end

function QuestToolsModule:HookGossipFrameShow()
    if self._gossipHooked then return end
    local gf = GossipFrame
    if not gf or not gf.HookScript then return end
    self._gossipHooked = true
    gf:HookScript("OnShow", function()
        QuestToolsModule:OnGossipOpen()
    end)
end

function QuestToolsModule:InitGossip()
    if self._gossipFrame then return end
    self._gossipFrame = CreateFrame("Frame", "OneWoW_QoL_QuestGossip")
    self._gossipFrame:SetScript("OnEvent", function(_, event)
        if event == "GOSSIP_SHOW" then
            self:OnGossipOpen()
        end
    end)
    self:HookGossipFrameShow()
end

function QuestToolsModule:RegisterGossipEvents()
    if not self._gossipFrame then return end
    self._gossipFrame:RegisterEvent("GOSSIP_SHOW")
end

function QuestToolsModule:UnregisterGossipEvents()
    if not self._gossipFrame then return end
    self._gossipFrame:UnregisterEvent("GOSSIP_SHOW")
end

function QuestToolsModule:InitAccept()
    if self._acceptFrame then return end
    self._acceptFrame = CreateFrame("Frame", "OneWoW_QoL_QuestAccept")
    self._acceptFrame:SetScript("OnEvent", function(_, event)
        if event == "QUEST_DETAIL" then
            if not GetToggle("auto_accept") then return end
            if not ShouldAutomate() then return end
            if QuestGetAutoAccept() then return end
            AcceptQuest()
        elseif event == "QUEST_GREETING" then
            if not GetToggle("auto_accept") then return end
            if not ShouldAutomate() then return end
            local numActive = C_GossipInfo.GetNumActiveQuests()
            for i = 1, numActive do C_GossipInfo.SelectActiveQuest(i) end
            local numAvail = C_GossipInfo.GetNumAvailableQuests()
            for i = 1, numAvail do C_GossipInfo.SelectAvailableQuest(i) end
        end
    end)
end

function QuestToolsModule:InitTurnin()
    if self._turninFrame then return end
    self._turninFrame = CreateFrame("Frame", "OneWoW_QoL_QuestTurnin")
    self._turninFrame:SetScript("OnEvent", function(_, event)
        if event == "QUEST_PROGRESS" then
            if not GetToggle("auto_turnin") then return end
            if not ShouldAutomate() then return end
            if IsQuestCompletable() then CompleteQuest() end
        elseif event == "QUEST_COMPLETE" then
            if not GetToggle("auto_turnin") then return end
            if not ShouldAutomate() then return end
            local numChoices = GetNumQuestChoices()
            if numChoices <= 1 then GetQuestReward(1) end
        end
    end)
end

function QuestToolsModule:InitRewardPicker()
    if self._goldIcon then return end

    self._goldIcon = CreateFrame("Frame", "OneWoW_QoL_QuestRewardPicker", QuestInfoRewardsFrame)
    self._goldIcon:SetSize(20, 20)
    self._goldIcon:SetFrameStrata("DIALOG")
    self._goldIcon:SetFrameLevel(501)
    self._goldIcon:Hide()

    local texture = self._goldIcon:CreateTexture(nil, "OVERLAY")
    texture:SetSize(20, 20)
    texture:SetPoint("CENTER")
    texture:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    texture:SetDrawLayer("OVERLAY", 7)
    self._goldIcon.texture = texture

    hooksecurefunc(QuestInfoRewardsFrame, "Show", function()
        C_Timer.After(0.1, function() self:EvaluateRewards() end)
    end)

    if MapQuestInfoRewardsFrame then
        hooksecurefunc(MapQuestInfoRewardsFrame, "Show", function()
            C_Timer.After(0.1, function() self:EvaluateRewards() end)
        end)
    end
end

function QuestToolsModule:EvaluateRewards()
    if not ns.ModuleRegistry:IsEnabled("questtools") or not GetToggle("reward_picker") then
        if self._goldIcon then self._goldIcon:Hide() end
        return
    end

    if self._goldIcon then self._goldIcon:Hide() end

    local choices = {}
    local count = 0

    if QuestFrame and QuestFrame:IsShown() and QuestInfoRewardsFrame:IsShown() then
        local questItemName = "QuestInfoRewardsFrameQuestInfoItem"
        for i = 1, 50 do
            local button = _G[questItemName .. i]
            if button and button:IsShown() and button.type == "choice" then
                local itemLink = GetQuestItemLink("choice", button:GetID())
                if itemLink then
                    count = count + 1
                    choices[count] = {link = itemLink, button = button}
                end
            end
        end
    end

    if WorldMapFrame and WorldMapFrame:IsShown() and QuestMapFrame and QuestMapFrame:IsShown() and MapQuestInfoRewardsFrame and MapQuestInfoRewardsFrame:IsShown() then
        local questItemName = "MapQuestInfoRewardsFrameQuestInfoItem"
        for i = 1, 50 do
            local button = _G[questItemName .. i]
            if button and button:IsShown() and button.type == "choice" then
                local itemLink = GetQuestLogItemLink("choice", button:GetID())
                if itemLink then
                    count = count + 1
                    choices[count] = {link = itemLink, button = button}
                end
            end
        end
    end

    if count <= 1 then return end

    local allCached = true
    for i = 1, count do
        if choices[i] and choices[i].link then
            if not C_Item.GetItemInfo(choices[i].link) then
                allCached = false
                local itemID = GetItemInfoFromHyperlink(choices[i].link)
                if itemID then C_Item.RequestLoadItemDataByID(itemID) end
            end
        end
    end

    if not allCached then
        C_Timer.After(0.3, function() self:EvaluateRewards() end)
        return
    end

    local highestValue = 0
    local highestChoice = nil
    for i = 1, count do
        local choice = choices[i]
        if choice and choice.link then
            local vendorPrice = select(11, C_Item.GetItemInfo(choice.link))
            if vendorPrice and vendorPrice > highestValue then
                highestValue = vendorPrice
                highestChoice = choice
            end
        end
    end

    if highestChoice and highestValue > 0 and highestChoice.button and self._goldIcon then
        self._goldIcon:SetParent(highestChoice.button)
        self._goldIcon:ClearAllPoints()
        self._goldIcon:SetPoint("TOPLEFT", highestChoice.button, "TOPLEFT", -1, 1)
        self._goldIcon:Show()
    end
end

function QuestToolsModule:OnEnable()
    self:InitAccept()
    self:InitTurnin()
    self:InitGossip()
    self:InitRewardPicker()

    C_Timer.After(0, function()
        QuestToolsModule:HookGossipFrameShow()
    end)

    self._acceptFrame:RegisterEvent("QUEST_DETAIL")
    self._acceptFrame:RegisterEvent("QUEST_GREETING")
    self._turninFrame:RegisterEvent("QUEST_PROGRESS")
    self._turninFrame:RegisterEvent("QUEST_COMPLETE")
    if GetToggle("auto_gossip") then
        self:RegisterGossipEvents()
    end
end

function QuestToolsModule:OnDisable()
    if self._acceptFrame then self._acceptFrame:UnregisterAllEvents() end
    if self._turninFrame then self._turninFrame:UnregisterAllEvents() end
    self:UnregisterGossipEvents()
    if self._goldIcon then self._goldIcon:Hide() end
end

function QuestToolsModule:OnToggle(toggleId, value)
    if toggleId == "auto_accept" then
        if self._acceptFrame then
            if value then
                self._acceptFrame:RegisterEvent("QUEST_DETAIL")
                self._acceptFrame:RegisterEvent("QUEST_GREETING")
            else
                self._acceptFrame:UnregisterAllEvents()
            end
        end
    elseif toggleId == "auto_turnin" then
        if self._turninFrame then
            if value then
                self._turninFrame:RegisterEvent("QUEST_PROGRESS")
                self._turninFrame:RegisterEvent("QUEST_COMPLETE")
            else
                self._turninFrame:UnregisterAllEvents()
            end
        end
    elseif toggleId == "reward_picker" then
        if not value and self._goldIcon then
            self._goldIcon:Hide()
        end
    elseif toggleId == "auto_gossip" then
        if value then
            self:RegisterGossipEvents()
        else
            self:UnregisterGossipEvents()
        end
    end
end

OneWoW_QoL_DebugGossipDisplayed = function()
    QuestToolsModule:DebugPrintGossipApiVsUi()
end

function QuestToolsModule:CreateCustomDetail(detailScrollChild, yOffset, isEnabled, registerRefresh)
    local cardsHost = CreateFrame("Frame", nil, detailScrollChild)
    cardsHost:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
    cardsHost:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)

    local stack = OneWoW_GUI:CreateCardStack(cardsHost, {
        getCollapsed = function(key) return collapsedCards[key] end,
        setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    })

    local function applyHostHeight()
        local h = math.max(1, cardsHost:GetHeight())
        if detailScrollChild.UpdateDetailHeight then
            detailScrollChild:SetHeight(h)
            detailScrollChild.UpdateDetailHeight()
        else
            detailScrollChild:SetHeight(math.abs(yOffset) + h + 20)
            if detailScrollChild.updateThumb then
                detailScrollChild.updateThumb()
            end
        end
    end
    stack.OnRelayout = applyHostHeight

    local automationRefresh

    stack:AddCard("questtools:automation", L["QUESTTOOLS_AUTOMATION_HEADER"], function(content, contentWidth)
        local w = tonumber(contentWidth) or 0
        if w < 1 then
            w = content:GetWidth() or 0
        end

        local requireCb = OneWoW_GUI:CreateCheckbox(content, {
            label = L["QUESTTOOLS_REQUIRE_MODIFIER"],
            checked = GetToggle("require_modifier"),
            labelMaxWidth = (w > 40) and (w - 32) or nil,
            wrap = true,
            onClick = function(myself)
                ns.ModuleRegistry:SetToggleValue("questtools", "require_modifier", myself:GetChecked() and true or false)
            end,
        })
        requireCb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

        local requireDesc = OneWoW_GUI:CreateFS(content, 11)
        requireDesc:SetPoint("TOPLEFT", requireCb, "BOTTOMLEFT", 0, -4)
        requireDesc:SetJustifyH("LEFT")
        requireDesc:SetWordWrap(true)
        requireDesc:SetSpacing(2)
        if w >= 1 then
            requireDesc:SetWidth(w)
        else
            requireDesc:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        end
        requireDesc:SetText(L["QUESTTOOLS_REQUIRE_MODIFIER_DESC"])
        requireDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local keyLabel = OneWoW_GUI:CreateFS(content, 12)
        keyLabel:SetPoint("TOPLEFT", requireDesc, "BOTTOMLEFT", 0, -12)
        keyLabel:SetText(L["QUESTTOOLS_MODIFIER_KEY"])
        keyLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local keyDesc = OneWoW_GUI:CreateFS(content, 11)
        keyDesc:SetPoint("TOPLEFT", keyLabel, "BOTTOMLEFT", 0, -4)
        keyDesc:SetJustifyH("LEFT")
        keyDesc:SetWordWrap(true)
        keyDesc:SetSpacing(2)
        if w >= 1 then
            keyDesc:SetWidth(w)
        else
            keyDesc:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        end
        keyDesc:SetText(L["QUESTTOOLS_MODIFIER_KEY_DESC"])
        keyDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local modifierDD, modifierDDText = OneWoW_GUI:CreateDropdown(content, {
            width = 220,
            text = ModifierLabel(GetModifierKey()),
        })
        OneWoW_GUI:AttachFilterMenu(modifierDD, {
            searchable = false,
            buildItems = function()
                return {
                    { text = SHIFT_KEY_TEXT, value = "SHIFT" },
                    { text = CTRL_KEY_TEXT, value = "CTRL" },
                    { text = ALT_KEY_TEXT, value = "ALT" },
                }
            end,
            onSelect = function(value, text)
                modifierDDText:SetText(text)
                SetModifierKey(value)
            end,
            getActiveValue = function()
                return GetModifierKey()
            end,
        })
        modifierDD:SetPoint("TOPLEFT", keyDesc, "BOTTOMLEFT", 0, -4)

        local function ApplyEnabled(enabled)
            if enabled then
                requireCb:Enable()
            else
                requireCb:Disable()
            end
            requireCb.label:SetTextColor(OneWoW_GUI:GetThemeColor(enabled and "TEXT_PRIMARY" or "TEXT_MUTED"))
            keyLabel:SetTextColor(OneWoW_GUI:GetThemeColor(enabled and "TEXT_PRIMARY" or "TEXT_MUTED"))
            modifierDD:EnableMouse(enabled)
            modifierDD:SetAlpha(enabled and 1 or 0.45)
        end

        automationRefresh = function()
            requireCb:SetChecked(GetToggle("require_modifier") and true or false)
            modifierDDText:SetText(ModifierLabel(GetModifierKey()))
            ApplyEnabled(ns.ModuleRegistry:IsEnabled("questtools"))
        end
        ApplyEnabled(isEnabled)

        local cbH = requireCb:GetMeasuredHeight()
        local requireDescH = requireDesc:GetStringHeight() or 14
        local keyLabelH = keyLabel:GetStringHeight() or 14
        local keyDescH = keyDesc:GetStringHeight() or 14
        local dropH = modifierDD:GetHeight() or 26
        return math.max(1, cbH + 4 + requireDescH + 12 + keyLabelH + 4 + keyDescH + 4 + dropH)
    end)

    stack:Finish()
    applyHostHeight()

    if registerRefresh then
        registerRefresh(function()
            if automationRefresh then
                automationRefresh()
            end
        end)
    end

    return yOffset - cardsHost:GetHeight()
end
