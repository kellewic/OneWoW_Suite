local _, ns = ...

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI

local L = ns.L

-- Session-only collapse memory for Toast settings cards (cleared on /reload).
local collapsedToastCards = {}

local SOUND_OPTIONS = {
    { labelKey = "TOAST_SOUND_NONE",      id = 0 },
    { labelKey = "TOAST_SOUND_RAIDALERT", id = SOUNDKIT.READY_CHECK },
    { labelKey = "TOAST_SOUND_CHIME",     id = SOUNDKIT.ACHIEVEMENT_MENU_OPEN },
}

local function GetSoundLabel(soundId)
    for _, opt in ipairs(SOUND_OPTIONS) do
        if opt.id == soundId then
            return L[opt.labelKey]
        end
    end
    return L["TOAST_SOUND_NONE"]
end

--- Sound dropdown + play button inside a card content frame. Returns new yOffset.
local function CreateSoundDropdown(content, featureId, yOffset)
    local reg = OneWoW.SettingsFeatureRegistry

    local dropBtn = OneWoW_GUI:CreateDropdown(content, {
        width = 200,
        text = GetSoundLabel(reg:GetSetting("toastalerts", featureId, "sound")),
    })
    dropBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)

    OneWoW_GUI:AttachFilterMenu(dropBtn, {
        searchable = false,
        buildItems = function()
            local items = {}
            for _, opt in ipairs(SOUND_OPTIONS) do
                tinsert(items, { text = L[opt.labelKey], value = opt.id })
            end
            return items
        end,
        onSelect = function(value, text)
            reg:SetSetting("toastalerts", featureId, "sound", value)
            dropBtn._text:SetText(text)
        end,
        getActiveValue = function() return reg:GetSetting("toastalerts", featureId, "sound") end,
    })

    local playBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["TOAST_SOUND_PLAY_BTN"], height = 26 })
    playBtn:SetPoint("LEFT", dropBtn, "RIGHT", 6, 0)
    playBtn:SetScript("OnClick", function()
        local soundId = reg:GetSetting("toastalerts", featureId, "sound") or 0
        if soundId > 0 then
            PlaySound(soundId, "Master")
        end
    end)

    return yOffset - 30 - 10
end

local function AddGeneralCards(stack)
    stack:AddCard("toast:general:anchor", "Anchor Position", function(content, _)
        local infoText = OneWoW_GUI:CreateFS(content, 12)
        infoText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        infoText:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
        infoText:SetJustifyH("LEFT")
        infoText:SetWordWrap(true)
        infoText:SetText(L["TOAST_ANCHOR_INFO"])
        infoText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local showAnchorBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["TOAST_ANCHOR_SHOW_BTN"], height = 28 })
        showAnchorBtn:SetPoint("TOPLEFT", infoText, "BOTTOMLEFT", 0, -10)
        showAnchorBtn:SetScript("OnClick", function(self)
            local Toasts = OneWoW.Toasts
            if Toasts.anchorVisible then
                Toasts.HideAnchor()
                self.text:SetText(L["TOAST_ANCHOR_SHOW_BTN"])
            else
                Toasts.ShowAnchor()
                self.text:SetText(L["TOAST_ANCHOR_HIDE_BTN"])
            end
        end)

        return math.max(1, infoText:GetStringHeight() + 10 + 28 + 10)
    end)
end

local function AddDetectionCards(stack)
    local reg = OneWoW.SettingsFeatureRegistry
    local cfg = reg:GetFeatureSettings("toastalerts", "detectiontypes")

    stack:AddCard("toast:detection:types", L["TOAST_LOOT_TYPES_HEADER"], function(content, _)
        local y = 0
        local types = {
            { key = "mounts",    label = L["TOAST_LOOT_MOUNTS"] },
            { key = "pets",      label = L["TOAST_LOOT_PETS"] },
            { key = "toys",      label = L["TOAST_LOOT_TOYS"] },
            { key = "recipes",   label = L["TOAST_LOOT_RECIPES"] },
            { key = "tmogs",     label = L["TOAST_LOOT_TMOGS"] },
            { key = "housing",   label = HOUSING_SETTINGS_LABEL },
            { key = "heirlooms", label = HEIRLOOMS },
        }

        for _, entry in ipairs(types) do
            local capturedKey = entry.key
            local cb = OneWoW_GUI:CreateCheckbox(content, { label = entry.label })
            cb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            cb:SetChecked(cfg[capturedKey] ~= false)

            local recipesOnlyCb = nil
            if capturedKey == "recipes" then
                y = y - 32
                recipesOnlyCb = OneWoW_GUI:CreateCheckbox(content, {
                    label = L["TOAST_LOOT_RECIPES_ONLY_MY_PROFESSIONS"],
                })
                recipesOnlyCb:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
                recipesOnlyCb:SetChecked(cfg.recipesOnlyMyProfessions == true)
                recipesOnlyCb:SetEnabled(cfg.recipes ~= false)
                recipesOnlyCb:SetScript("OnClick", function(self)
                    reg:SetSetting("toastalerts", "detectiontypes", "recipesOnlyMyProfessions", self:GetChecked())
                end)
            end

            cb:SetScript("OnClick", function(self)
                reg:SetSetting("toastalerts", "detectiontypes", capturedKey, self:GetChecked())
                if recipesOnlyCb then
                    recipesOnlyCb:SetEnabled(self:GetChecked())
                end
            end)

            y = y - 32
        end

        return math.max(1, math.abs(y))
    end)

    stack:AddCard("toast:detection:suppress", L["TOAST_LOOT_SUPPRESS_BLIZZARD_HEADER"], function(content, _)
        local y = 0
        local suppressCb = OneWoW_GUI:CreateCheckbox(content, {
            label = L["TOAST_LOOT_SUPPRESS_BLIZZARD"],
        })
        suppressCb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        suppressCb:SetChecked(cfg.suppressBlizzardAlerts == true)
        suppressCb:SetScript("OnClick", function(self)
            reg:SetSetting("toastalerts", "detectiontypes", "suppressBlizzardAlerts", self:GetChecked())
            OneWoW.Toasts.ApplyBlizzardSuppression()
        end)
        y = y - 32
        return math.max(1, math.abs(y))
    end)

    stack:AddCard("toast:detection:sound", L["TOAST_SOUND_HEADER"], function(content, _)
        local y = CreateSoundDropdown(content, "detectiontypes", 0)
        return math.max(1, math.abs(y))
    end)
end

local function AddItemAlertsCards(stack)
    local reg = OneWoW.SettingsFeatureRegistry
    local cfg = reg:GetFeatureSettings("toastalerts", "notealerts")

    stack:AddCard("toast:notes:types", L["TOAST_NOTES_TYPES_HEADER"], function(content, _)
        local y = 0
        local types = {
            { key = "npcs",    label = L["TOAST_NOTES_NPCS"] },
            { key = "players", label = L["TOAST_NOTES_PLAYERS"] },
            { key = "zones",   label = L["TOAST_NOTES_ZONES"] },
            { key = "items",   label = L["TOAST_NOTES_ITEMS"] },
        }

        for _, entry in ipairs(types) do
            local capturedKey = entry.key
            local cb = OneWoW_GUI:CreateCheckbox(content, { label = entry.label })
            cb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            cb:SetChecked(cfg[capturedKey] ~= false)
            cb:SetScript("OnClick", function(self)
                reg:SetSetting("toastalerts", "notealerts", capturedKey, self:GetChecked())
            end)
            y = y - 32
        end

        return math.max(1, math.abs(y))
    end)

    stack:AddCard("toast:notes:sound", L["TOAST_SOUND_HEADER"], function(content, _)
        local y = CreateSoundDropdown(content, "notealerts", 0)
        return math.max(1, math.abs(y))
    end)
end

local function AddUpgradeCards(stack)
    stack:AddCard("toast:upgrades:note", L["TOAST_UPGRADES_TITLE"], function(content, _)
        local infoText = OneWoW_GUI:CreateFS(content, 12)
        infoText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        infoText:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
        infoText:SetJustifyH("LEFT")
        infoText:SetWordWrap(true)
        infoText:SetText(L["TOAST_UPGRADES_NOTE"])
        infoText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        return math.max(1, infoText:GetStringHeight() + 10)
    end)

    stack:AddCard("toast:upgrades:sound", L["TOAST_SOUND_HEADER"], function(content, _)
        local y = CreateSoundDropdown(content, "upgrades", 0)
        return math.max(1, math.abs(y))
    end)
end

--- Instance feature has no CreateSection chrome — keep a free note under the header.
local function AddInstanceNote(dsc, yOffset)
    local infoText = OneWoW_GUI:CreateFS(dsc, 12)
    infoText:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    infoText:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    infoText:SetJustifyH("LEFT")
    infoText:SetWordWrap(true)
    infoText:SetText(L["TOAST_INSTANCE_DELAY_INFO"] or
        "Shown 3 seconds after entering an instance. Requires Catalog data modules for completion data.")
    infoText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    return yOffset - infoText:GetStringHeight() - 10
end

local function ShowFeatureDetail(split, feature, tabName, selectedRow)
    local dsc = split.detailScrollChild
    OneWoW_GUI:ClearFrame(dsc)

    local yOffset = -10

    local enableBtn = OneWoW_GUI:CreateFeatureHeaderToggle(dsc, {
        selectedRow = selectedRow,
        isEnabled = function()
            return OneWoW.SettingsFeatureRegistry:IsEnabled(tabName, feature.id)
        end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled(tabName, feature.id, newState)
        end,
    })
    enableBtn:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)

    local titleLabel = OneWoW_GUI:CreateFS(dsc, 16)
    titleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", enableBtn, "TOPLEFT", -8, 0)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetWordWrap(false)
    titleLabel:SetText(L[feature.title])
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local headerHeight = math.max(titleLabel:GetStringHeight(), enableBtn:GetHeight())
    yOffset = yOffset - headerHeight - 8

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local headerBottom = yOffset
    local cardsHost

    local function updateDetailHeight()
        local cardsH = cardsHost and cardsHost:GetHeight() or 0
        dsc:SetHeight(math.abs(headerBottom) + cardsH + 20)
        split.UpdateDetailThumb()
    end

    local useCards = feature.id == "general"
        or feature.id == "detectiontypes"
        or feature.id == "notealerts"
        or feature.id == "upgrades"

    if useCards then
        cardsHost = CreateFrame("Frame", nil, dsc)
        cardsHost:SetPoint("TOPLEFT", dsc, "TOPLEFT", 0, headerBottom)
        cardsHost:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", 0, headerBottom)

        local stack = OneWoW_GUI:CreateCardStack(cardsHost, {
            getCollapsed = function(key) return collapsedToastCards[key] end,
            setCollapsed = function(key, collapsed) collapsedToastCards[key] = collapsed end,
        })
        stack.OnRelayout = updateDetailHeight

        if feature.id == "general" then
            AddGeneralCards(stack)
        elseif feature.id == "detectiontypes" then
            AddDetectionCards(stack)
        elseif feature.id == "notealerts" then
            AddItemAlertsCards(stack)
        elseif feature.id == "upgrades" then
            AddUpgradeCards(stack)
        end

        stack:Finish()
        updateDetailHeight()
    elseif feature.id == "instances" then
        yOffset = AddInstanceNote(dsc, yOffset)
        dsc:SetHeight(math.abs(yOffset) + 40)
        split.UpdateDetailThumb()
    else
        dsc:SetHeight(math.abs(yOffset) + 40)
        split.UpdateDetailThumb()
    end

    OneWoW_GUI:ApplyFontToFrame(dsc)
end

local function BuildFeatureList(split, tabName)
    local lsc = split.listScrollChild
    local features = OneWoW.SettingsFeatureRegistry:GetByTab(tabName)
    local selectedRow = nil
    local allRows = {}

    local function RenderRows(filterText)
        OneWoW_GUI:ClearFrame(lsc)
        selectedRow = nil
        allRows = {}
        local yOffset = -5
        local filter = (filterText or ""):lower()

        for _, feature in ipairs(features) do
            local displayName = L[feature.title]
            if filter == "" or displayName:lower():find(filter, 1, true) then
                local capturedFeature = feature
                local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled(tabName, feature.id)

                local row = OneWoW_GUI:CreateListRowBasic(lsc, {
                    height = 30,
                    label = displayName,
                    showDot = true,
                    dotEnabled = isEnabled,
                    onClick = function(self)
                        if selectedRow and selectedRow ~= self then
                            selectedRow:SetActive(false)
                        end
                        selectedRow = self
                        self:SetActive(true)
                        ShowFeatureDetail(split, capturedFeature, tabName, self)
                    end,
                })
                row:SetPoint("TOPLEFT", lsc, "TOPLEFT", 4, yOffset)
                row:SetPoint("TOPRIGHT", lsc, "TOPRIGHT", -4, yOffset)

                tinsert(allRows, row)
                yOffset = yOffset - 34
            end
        end

        lsc:SetHeight(math.abs(yOffset) + 10)

        if #allRows > 0 and not selectedRow then
            allRows[1]:Click()
        end
    end

    RenderRows("")

    if split.searchBox then
        split.searchBox:SetScript("OnTextChanged", function(self)
            local text = self:GetSearchText()
            RenderRows(text)
        end)
    end

    local enabledCount = 0
    for _, f in ipairs(features) do
        if OneWoW.SettingsFeatureRegistry:IsEnabled(tabName, f.id) then
            enabledCount = enabledCount + 1
        end
    end
    split.leftStatusText:SetText(string.format("Features: %d/%d", enabledCount, #features))
end

function ns.UI.CreateToastAlertsTab(parent)
    local split = OneWoW_GUI:CreateSplitPanel(parent, {
        showSearch = true,
        searchPlaceholder = L["SEARCH_HINT"],
        hideTitles = true,
    })

    C_Timer.After(0.1, function()
        BuildFeatureList(split, "toastalerts")
        OneWoW_GUI:ApplyFontToFrame(parent)
    end)
end
