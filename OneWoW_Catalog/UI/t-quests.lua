local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local WOW_QUEST_GOLD = OneWoW_GUI.Constants.WOW_QUEST_GOLD
local QUEST_LIST_ROW_HEIGHT = 60
local QUEST_LIST_ROW_FRAME_HEIGHT = 56
local QUEST_LIST_RIGHT_GUTTER = 28
local QUEST_LIST_TAG_GAP = 8
local QUEST_LIST_TAG_PAD_X = 8
local QUEST_CATEGORY_TAG_MAX = 8

ns.UI = ns.UI or {}

local selectedQuest    = nil
local pinnedChainIDs   = nil -- left list locked to this chain's ordered IDs
local questListAPI     = nil
local detailElements   = {}
local visibleRewardItemRows = {}
local visibleQuestNameRows = {}
local visibleNPCNameRows = {}
local questListGroupExpanded = {}
local questChainGroupExpanded = {}
local searchText       = ""
local expansionFilter  = -1
local zoneFilter       = ""
local npcFilter        = nil
local npcFilterLabel   = nil
local typeFilter       = "all"
local questTypeFilter  = "all"
local completionFilter = "all"
local categoryFilter   = "all"
local flagFilter       = "all"
local professionFilter = "all"
local classFilter      = "all"
local raceFilter       = "all"
local factionFilter    = "all"
local storyFilter      = "all"
local runtimeFilter    = "all"
local advancedOpen     = false
local availableFilterCache = {}
local questRowStatusCache = {}
local questGroupStatusCache = {}
local activeQuestIDsAcrossAlts = {}
local questCompletionJob = nil

local QUEST_STATUS_TEXTURE_CHECK   = "Interface\\Buttons\\UI-CheckBox-Check"
local QUEST_STATUS_ATLAS_BANG      = "SmallQuestBang"
local QUEST_STATUS_ATLAS_BANG_ALT  = "TrivialQuests"
local QUEST_STATUS_ATLAS_WARBAND   = "warband-completed-icon"
local QUEST_STATUS_ATLAS_ACCOUNT   = "questlog-questtypeicon-group"
local QUEST_STATUS_ATLAS_PENDING   = "Islands-QuestBangDisable"

local QUEST_STATUS_ICON_DISPLAY = 12
local QUEST_STATUS_ICON_SLOT = 14
local QUEST_STATUS_MAX_ICONS = 4
local QUEST_STATUS_BOTTOM = 6
local QUEST_STATUS_RIGHT = -8
local QUEST_LIST_STATUS_RESERVE = QUEST_STATUS_MAX_ICONS * QUEST_STATUS_ICON_SLOT + 8

local function IsCompletedByOtherCharacter(questID, tracker)
    if not questID or not tracker then
        return false
    end

    local currentKey = OneWoW_GUI:BuildCharKey()
    for _, charInfo in ipairs(tracker.GetCompletedCharacters(questID)) do
        if charInfo.key ~= currentKey then
            return true
        end
    end

    return false
end

local function IsActiveOnOtherCharacter(questID, tracker)
    if not questID then
        return false
    end

    local currentKey = OneWoW_GUI:BuildCharKey()

    if tracker then
        for _, charInfo in ipairs(tracker.GetActiveCharacters(questID)) do
            if charInfo.key ~= currentKey then
                return true
            end
        end
    end

    -- Warband-mode snapshot fallback. The map also records the current
    -- character, so only trust it when the player is not the one on the quest.
    if activeQuestIDsAcrossAlts[questID] and not C_QuestLog.IsOnQuest(questID) then
        return true
    end

    return false
end

--- Resolves every status fact for a quest row. Multiple facts can be true at
--- once (e.g. active on self while a tracked alt has it completed), so each is
--- reported independently instead of collapsing to a single status.
---@param questID number|nil
---@param tracker table|nil
---@return table flags
local function ResolveQuestStatusFlags(questID, tracker)
    local flags = {}

    if not questID then
        flags.pending = true
        return flags
    end

    if tracker and tracker.IsCompletedByCurrentChar(questID) then
        flags.selfState = "completed_current"
    elseif C_QuestLog.IsOnQuest(questID) then
        flags.selfState = "active_current"
    end

    if IsActiveOnOtherCharacter(questID, tracker) then
        flags.warbandActive = true
    end

    if IsCompletedByOtherCharacter(questID, tracker) then
        flags.warbandCompleted = true
    end

    -- Real account-wide completion via the API. Suppressed when the current
    -- character already completed it, because that completion sets the account
    -- flag anyway and the extra icon would just be redundant noise.
    if flags.selfState ~= "completed_current"
        and C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID)
    then
        flags.accountCompleted = true
    end

    if not flags.selfState
        and not flags.warbandActive
        and not flags.warbandCompleted
        and not flags.accountCompleted
    then
        flags.pending = true
    end

    return flags
end

--- Combines status flags across every quest in a grouped list entry.
---@param groupQuests table|nil
---@param tracker table|nil
---@return table flags
local function ResolveGroupStatusFlags(groupQuests, tracker)
    local flags = {}

    for _, childQuest in ipairs(groupQuests or {}) do
        if childQuest.id then
            local childFlags = ResolveQuestStatusFlags(childQuest.id, tracker)

            if childFlags.selfState == "completed_current" then
                flags.selfState = "completed_current"
            elseif childFlags.selfState == "active_current"
                and flags.selfState ~= "completed_current"
            then
                flags.selfState = "active_current"
            end

            if childFlags.warbandActive then flags.warbandActive = true end
            if childFlags.warbandCompleted then flags.warbandCompleted = true end
            if childFlags.accountCompleted then flags.accountCompleted = true end
        end
    end

    if not flags.selfState
        and not flags.warbandActive
        and not flags.warbandCompleted
        and not flags.accountCompleted
    then
        flags.pending = true
    end

    return flags
end

--- Styles a single status texture for the given icon kind (~12px for vertical stack).
---@param tex table
---@param kind string
local function StyleStatusIcon(tex, kind)
    tex:SetAlpha(1)
    tex:SetSize(QUEST_STATUS_ICON_DISPLAY, QUEST_STATUS_ICON_DISPLAY)

    if kind == "completed_current" then
        tex:SetAtlas("")
        tex:SetTexture(QUEST_STATUS_TEXTURE_CHECK)
        tex:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    elseif kind == "active_current" then
        tex:SetTexture(nil)
        tex:SetAtlas(QUEST_STATUS_ATLAS_BANG)
        tex:SetVertexColor(unpack(WOW_QUEST_GOLD))
    elseif kind == "active_other" then
        tex:SetTexture(nil)
        tex:SetAtlas(QUEST_STATUS_ATLAS_BANG_ALT)
        tex:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    elseif kind == "completed_warband" then
        tex:SetTexture(nil)
        tex:SetAtlas(QUEST_STATUS_ATLAS_WARBAND)
        tex:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    elseif kind == "completed_account" then
        tex:SetTexture(nil)
        tex:SetAtlas(QUEST_STATUS_ATLAS_ACCOUNT)
        tex:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    else
        tex:SetTexture(nil)
        tex:SetAtlas(QUEST_STATUS_ATLAS_PENDING)
        tex:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
end

--- Returns the ordered list of icon kinds present in a status flags table.
--- Order is self, warband-active, warband-completed, account-completed.
---@param flags table
---@return string[] kinds
local function BuildStatusIconKinds(flags)
    local kinds = {}

    if flags.selfState then
        table.insert(kinds, flags.selfState)
    end
    if flags.warbandActive then
        table.insert(kinds, "active_other")
    end
    if flags.warbandCompleted then
        table.insert(kinds, "completed_warband")
    end
    if flags.accountCompleted then
        table.insert(kinds, "completed_account")
    end
    if #kinds == 0 then
        table.insert(kinds, "pending")
    end

    return kinds
end

--- Lays out a button's status icon cluster horizontally from the bottom-right.
---@param btn table
---@param flags table
local function ApplyQuestListStatusIcons(btn, flags)
    local icons = btn.statusIcons
    if not icons then return end

    local kinds = BuildStatusIconKinds(flags)
    local count = #kinds

    for i = 1, #icons do
        local tex = icons[i]
        local kind = kinds[i]
        if kind then
            StyleStatusIcon(tex, kind)
            tex:ClearAllPoints()
            -- Right-aligned: last kind sits at the corner; earlier kinds extend left.
            tex:SetPoint(
                "BOTTOMRIGHT",
                btn,
                "BOTTOMRIGHT",
                QUEST_STATUS_RIGHT - (count - i) * QUEST_STATUS_ICON_SLOT,
                QUEST_STATUS_BOTTOM
            )
            tex:Show()
        else
            tex:Hide()
        end
    end

    return count
end

local function QuestStatusLegendTextureMarkup(displayW, displayH)
    return CreateTextureMarkup(
        QUEST_STATUS_TEXTURE_CHECK,
        32,
        32,
        displayW,
        displayH,
        0,
        1,
        0,
        1
    )
end

local function QuestStatusLegendAtlasMarkup(atlas, width, height)
    return CreateAtlasMarkup(atlas, width, height)
end

local function ShowQuestStatusLegendTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L["QUESTS_STATUS_LEGEND_TITLE"], 1, 0.82, 0)
    GameTooltip:AddLine(L["QUESTS_STATUS_LEGEND_COMBINE"], 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(" ")

    local legendLines = {
        {
            QuestStatusLegendTextureMarkup(14, 14),
            L["QUESTS_STATUS_LEGEND_COMPLETED_CURRENT"],
        },
        {
            QuestStatusLegendAtlasMarkup(QUEST_STATUS_ATLAS_BANG, 16, 16),
            L["QUESTS_STATUS_LEGEND_ACTIVE_CURRENT"],
        },
        {
            QuestStatusLegendAtlasMarkup(QUEST_STATUS_ATLAS_BANG_ALT, 16, 16),
            L["QUESTS_STATUS_LEGEND_ACTIVE_OTHER"],
        },
        {
            QuestStatusLegendAtlasMarkup(QUEST_STATUS_ATLAS_WARBAND, 16, 18),
            L["QUESTS_STATUS_LEGEND_COMPLETED_WARBAND"],
        },
        {
            QuestStatusLegendAtlasMarkup(QUEST_STATUS_ATLAS_ACCOUNT, 16, 16),
            L["QUESTS_STATUS_LEGEND_COMPLETED_ACCOUNT"],
        },
        {
            QuestStatusLegendAtlasMarkup(QUEST_STATUS_ATLAS_PENDING, 16, 16),
            L["QUESTS_STATUS_LEGEND_PENDING"],
        },
    }

    for _, entry in ipairs(legendLines) do
        GameTooltip:AddLine(entry[1] .. " " .. entry[2], 1, 1, 1, true)
    end

    GameTooltip:Show()
end

local RefreshQuestList
local ShowQuestDetail
local OpenQuestByID

local QUEST_TYPE_LABELS = {
    standard = L["QUESTS_TYPE_STANDARD"],
    world = L["WORLD_QUEST"],
    dungeon = L["QUESTS_TYPE_DUNGEON"],
    raid = L["QUESTS_TYPE_RAID"],
    pvp = L["QUESTS_TYPE_PVP"],
    profession = L["QUESTS_TYPE_PROFESSION"],
    scenario = L["QUESTS_TYPE_SCENARIO"],
    group = L["QUESTS_TYPE_GROUP"],
}

local QUEST_CATEGORY_LABELS = {
    campaign = L["CAMPAIGN"],
    seasonal = L["QUESTS_CATEGORY_SEASONAL"],
    legendary = L["QUESTS_CATEGORY_LEGENDARY"],
    emissary = L["QUESTS_CATEGORY_EMISSARY"],
    calling = L["QUESTS_CATEGORY_CALLING"],
    bonusobjective = L["QUESTS_CATEGORY_BONUS_OBJECTIVE"],
    worldboss = L["QUESTS_CATEGORY_WORLD_BOSS"],
    bounty = L["QUESTS_CATEGORY_BOUNTY"],
    paragon = L["QUESTS_CATEGORY_PARAGON"],
    renown = L["QUESTS_CATEGORY_RENOWN"],
    invasion = L["QUESTS_CATEGORY_INVASION"],
    story = L["QUESTS_CATEGORY_STORY"],
    artifact = L["QUESTS_CATEGORY_ARTIFACT"],
    task = L["QUESTS_CATEGORY_TASK"],
    meta = L["QUESTS_CATEGORY_META"],
    threat = L["QUESTS_CATEGORY_THREAT"],
}

-- Distinct hues for standout categories; others fall back to muted text.
local QUEST_CATEGORY_COLORS = {
    campaign = { 0.95, 0.78, 0.20 },
    legendary = { 1.0, 0.50, 0.0 },
    seasonal = { 0.40, 0.85, 1.0 },
    worldboss = { 1.0, 0.35, 0.35 },
    story = { 0.55, 0.80, 1.0 },
    artifact = { 0.90, 0.75, 0.40 },
    renown = { 0.50, 1.0, 0.55 },
    calling = { 0.70, 0.50, 1.0 },
}

local function GetQuestCategoryColor(categoryKey)
    local color = QUEST_CATEGORY_COLORS[categoryKey]
    if color then
        return color[1], color[2], color[3]
    end
    return OneWoW_GUI:GetThemeColor("TEXT_MUTED")
end

local function HideQuestListCategoryTags(btn)
    if not btn.catTexts then
        return
    end
    for _, catText in ipairs(btn.catTexts) do
        catText:Hide()
    end
end

local QUEST_FLAG_LABELS = {
    daily = DAILY,
    weekly = WEEKLY,
    repeatable = L["QUESTS_FLAG_REPEATABLE"],
    loremaster = L["QUESTS_FLAG_LOREMASTER"],
    elite = ELITE,
    rare = L["QUESTS_FLAG_RARE"],
    important = L["QUESTS_FLAG_IMPORTANT"],
    meta = L["QUESTS_FLAG_META"],
    class = L["QUESTS_FLAG_CLASS"],
    timed = L["QUESTS_FLAG_TIMED"],
    escort = L["QUESTS_FLAG_ESCORT"],
    scaling = L["QUESTS_FLAG_SCALING"],
    auto_complete = L["QUESTS_FLAG_AUTO_COMPLETE"],
    local_poi = L["QUESTS_FLAG_LOCAL_POI"],
    on_map = L["QUESTS_FLAG_ON_MAP"],
    start_event = L["QUESTS_FLAG_START_EVENT"],
}

local QUEST_SEARCH_STOP_WORDS = {
    a = true,
    an = true,
    ["and"] = true,
    ["at"] = true,
    ["by"] = true,
    ["for"] = true,
    ["from"] = true,
    ["in"] = true,
    ["of"] = true,
    ["on"] = true,
    ["or"] = true,
    ["the"] = true,
    ["to"] = true,
    ["with"] = true,
}

local function NormalizeQuestSearchText(value)
    value = tostring(value or ""):lower()

    local terms = {}

    for word in value:gmatch("[%w']+") do
        if not QUEST_SEARCH_STOP_WORDS[word] then
            table.insert(terms, word)
        end
    end

    return table.concat(terms, " ")
end

local function IsActiveCurrentMode()
    return completionFilter == "active_current"
end

local function IsActiveAllAltsMode()
    return completionFilter == "active_all"
end

local function IsActiveFilterMode()
    return IsActiveCurrentMode() or IsActiveAllAltsMode()
end

local function IsDatabaseMode()
    return (searchText and NormalizeQuestSearchText(searchText) ~= "")
        or expansionFilter ~= -1
        or zoneFilter ~= ""
        or npcFilter ~= nil
        or (completionFilter ~= "all"
            and completionFilter ~= "active_current"
            and completionFilter ~= "active_all")
        or typeFilter ~= "all"
        or questTypeFilter ~= "all"
        or categoryFilter ~= "all"
        or flagFilter ~= "all"
        or professionFilter ~= "all"
        or classFilter ~= "all"
        or raceFilter ~= "all"
        or factionFilter ~= "all"
        or storyFilter ~= "all"
        or runtimeFilter ~= "all"
end

local function HasQuestListFilters()
    return IsDatabaseMode() or IsActiveFilterMode() or runtimeFilter == "favorite"
end

local function ResetAdvancedFilters()
    typeFilter       = "all"
    questTypeFilter  = "all"
    categoryFilter   = "all"
    flagFilter       = "all"
    professionFilter = "all"
    classFilter      = "all"
    raceFilter       = "all"
    factionFilter    = "all"
    storyFilter      = "all"
    runtimeFilter    = "all"
end

local function BuildAdvancedFilters()
    return {
        groupType  = typeFilter,
        questType  = questTypeFilter,
        category   = categoryFilter,
        flag       = flagFilter,
        profession = professionFilter,
        class      = classFilter,
        race       = raceFilter,
        faction    = factionFilter,
        story      = storyFilter,
        runtime    = runtimeFilter,
        npcID      = npcFilter,
    }
end

local function ClearNpcFilter()
    npcFilter = nil
    npcFilterLabel = nil
end

local function UpdateNpcFilterChip(panels)
    panels = panels or ns.UI.questsPanels
    if not panels or not panels.npcFilterBtn or not panels.searchBox or not panels.clearBtn then
        return
    end

    if npcFilter then
        local label = npcFilterLabel
        if not label or label == "" then
            label = string.format(L["QUESTS_NPC_UNNAMED"], npcFilter)
        end
        panels.npcFilterBtn:SetText(string.format(L["QUESTS_NPC_FILTER"], label))
        panels.npcFilterBtn:Show()
        panels.searchBox:SetPoint("TOPRIGHT", panels.npcFilterBtn, "TOPLEFT", -4, 0)
    else
        panels.npcFilterBtn:Hide()
        panels.searchBox:SetPoint("TOPRIGHT", panels.clearBtn, "TOPLEFT", -4, 0)
    end
end

local function CountAdvancedFilters()
    local count = 0
    local values = {
        typeFilter,
        questTypeFilter,
        categoryFilter,
        flagFilter,
        professionFilter,
        classFilter,
        raceFilter,
        factionFilter,
        storyFilter,
        runtimeFilter,
    }

    for _, value in ipairs(values) do
        if value and value ~= "all" then
            count = count + 1
        end
    end

    return count
end

local function GetAdvancedButtonText()
    local count = CountAdvancedFilters()
    if count > 0 then
        return string.format(L["QUESTS_ADVANCED_COUNT"], count)
    end
    return L["QUESTS_ADVANCED"]
end

local function SetButtonText(button, text)
    if not button then return end
    if button.SetText then
        button:SetText(text)
    elseif button.text and button.text.SetText then
        button.text:SetText(text)
    elseif button.Text and button.Text.SetText then
        button.Text:SetText(text)
    end
end

local function UpdateFavoritesFilterButton(button)
    if not button then return end

    SetButtonText(button, L["QUESTS_DATA_FAVORITES"])

    if button.SetActive then
        button:SetActive(runtimeFilter == "favorite")
    elseif button.SetBackdropColor then
        if runtimeFilter == "favorite" then
            button:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        else
            button:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        end

        if button.SetBackdropBorderColor then
            if runtimeFilter == "favorite" then
                button:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            else
                button:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end
        end
    end
end

local function ContainsAnyLower(text, tokens)
    if not text or text == "" then return false end

    for _, token in ipairs(tokens) do
        if token and token ~= "" and text:find(token, 1, true) then
            return true
        end
    end

    return false
end

local ACTIVE_QUEST_NAME_FILTERS = {
    "capstone",
    "dnt",
    "nth",
    "ph]",
    "(ph)",
    "[nyi]",
    "[removed]",
    "removed]",
    "placeholder",
    "reward test",
    "test case",
    "test quest",
    "test currency",
    "nav test",
    "tracking quest",
    "reward quest",
    "quest start",
    "navigation playtest",
    "event tracking",
    "unused",
    "do not use",
    "vignette",
}

local function IsInternalActiveQuestName(name, questID)
    if not name or name == "" then return true end

    local lowerName = tostring(name):lower()

    if lowerName:match("^level%s+%d+$") then
        return true
    end

    if questID ~= 71153 and lowerName:find("bonus objective", 1, true) then
        return true
    end

    if lowerName:find("%[%s*[%a%s]+%s*%]") then
        return true
    end

    if lowerName:find("%[%[deprecated%]%]") then
        return true
    end

    if lowerName:find("%f[%a]poi%f[%A]") then
        return true
    end

    if lowerName:match("^zz") or lowerName == "test" then
        return true
    end

    return ContainsAnyLower(lowerName, ACTIVE_QUEST_NAME_FILTERS)
end

local function IsVisibleActiveQuestLogInfo(info)
    if not info or info.isHeader or info.isHidden then
        return false
    end

    if info.isTask or info.isBounty then
        return false
    end

    return true
end

local function BuildQuestRecord(addon, questID, title, extras)
    local stored =
        addon
        and addon.GetQuest(questID)

    local quest = {}

    if stored then
        for key, value in pairs(stored) do
            quest[key] = value
        end
    end

    quest.id = questID
    quest.name = title or quest.name

    if extras then
        for key, value in pairs(extras) do
            quest[key] = value
        end
    end

    return quest
end

local function GetActiveQuestLogQuests(addon)
    local quests = {}

    local numEntries = C_QuestLog.GetNumQuestLogEntries()

    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)

        if IsVisibleActiveQuestLogInfo(info) then
            local title = info.title

            if title
                and title ~= ""
            then
                local questID = info.questID

                if questID
                    and C_QuestLog.IsOnQuest(questID)
                    and not IsInternalActiveQuestName(title, questID)
                then
                    table.insert(quests, BuildQuestRecord(addon, questID, title, {
                        level = info.level,
                        campaign = info.campaign,
                        isTask = info.isTask,
                        isBounty = info.isBounty,
                        isStory = info.isStory,
                        frequency = info.frequency,
                    }))
                end
            end
        end
    end

    table.sort(quests, function(a, b)
        return (a.name or "") < (b.name or "")
    end)

    return quests
end

local function GetAllCharactersActiveQuests(addon)
    wipe(activeQuestIDsAcrossAlts)
    local byID = {}

    for _, quest in ipairs(GetActiveQuestLogQuests(addon)) do
        if quest.id then
            byID[quest.id] = quest
            activeQuestIDsAcrossAlts[quest.id] = true
        end
    end

    local altApi = OneWoW_AltTracker_Collections_API
    local currentKey = OneWoW_GUI:BuildCharKey()

    if altApi and altApi.GetAllCharacters then
        local characters = altApi.GetAllCharacters()
        if characters then
            for characterKey in pairs(characters) do
                if characterKey ~= currentKey then
                    local characterData = altApi.GetCharacterData(characterKey)
                    local activeList =
                        characterData
                        and characterData.quests
                        and characterData.quests.active

                    if activeList then
                        for _, activeEntry in ipairs(activeList) do
                            local questID = activeEntry.questID
                            local title = activeEntry.title

                            if questID
                                and not byID[questID]
                                and title
                                and title ~= ""
                                and not IsInternalActiveQuestName(title, questID)
                            then
                                local extras = {}
                                if activeEntry.isDaily then
                                    extras.isDaily = true
                                end
                                if activeEntry.isWeekly then
                                    extras.isWeekly = true
                                end

                                byID[questID] = BuildQuestRecord(addon, questID, title, extras)
                                activeQuestIDsAcrossAlts[questID] = true
                            end
                        end
                    end
                end
            end
        end
    end

    local quests = {}
    for _, quest in pairs(byID) do
        table.insert(quests, quest)
    end

    table.sort(quests, function(a, b)
        return (a.name or "") < (b.name or "")
    end)

    return quests
end

local function GetDataAddon()
    return ns.GetCatalogPackAPI("quests")
end

local function ClearDetailElements()
    for _, element in ipairs(detailElements) do
        if element.Hide then element:Hide() end
        if element.SetParent then element:SetParent(nil) end
    end
    wipe(detailElements)
    wipe(visibleRewardItemRows)
    wipe(visibleQuestNameRows)
    wipe(visibleNPCNameRows)
end

local function GetQuestTypeLabel(quest)
    if not quest then return QUEST_TYPE_LABELS.standard end
    return QUEST_TYPE_LABELS[quest.questType] or QUEST_TYPE_LABELS.standard
end

local function GetCurrencyRewardInfo(rewardCurrency)
    local currencyID
    local quantity = 1
    local icon
    local name

    if type(rewardCurrency) == "number" then
        currencyID = rewardCurrency
    elseif type(rewardCurrency) == "table" then
        currencyID = rewardCurrency.currencyID or rewardCurrency.id
        quantity = rewardCurrency.quantity or rewardCurrency.count or rewardCurrency.amount or 1
        icon = rewardCurrency.icon or rewardCurrency.texture
        name = rewardCurrency.name
    end

    currencyID = tonumber(currencyID)
    quantity = tonumber(quantity) or 1

    if not currencyID or currencyID <= 0 then
        return nil
    end

    local info =
        C_CurrencyInfo
        and C_CurrencyInfo.GetCurrencyInfo
        and C_CurrencyInfo.GetCurrencyInfo(currencyID)

    if info then
        name = info.name
        icon = icon or info.iconFileID
    end

    return currencyID, quantity, icon or 134400, name or ("Currency #" .. tostring(currencyID))
end

local function FormatQuestMetadataValue(value)
    if value == nil or tostring(value) == "" then
        return "-"
    end

    value = tostring(value):lower()

    return QUEST_TYPE_LABELS[value]
        or QUEST_CATEGORY_LABELS[value]
        or QUEST_FLAG_LABELS[value]
        or value:gsub("_", " "):gsub("^%l", string.upper)
end

local function FormatQuestMetadataList(values)
    if type(values) ~= "table" or #values == 0 then
        return "-"
    end

    local labels = {}
    for _, value in ipairs(values) do
        table.insert(labels, FormatQuestMetadataValue(value))
    end

    table.sort(labels)
    return table.concat(labels, ", ")
end

local function FormatQuestListMetaLine(quest, expansionName)
    local expPart = expansionName or ""
    local typePart = GetQuestTypeLabel(quest) or ""
    if expPart ~= "" and typePart ~= "" then
        return expPart .. "  |  " .. typePart
    end
    return expPart ~= "" and expPart or typePart
end

local function BindQuestListCategoryTags(btn, quest)
    if not btn.catTexts then
        return
    end

    local categories = quest and quest.categories
    if type(categories) ~= "table" or #categories == 0 then
        HideQuestListCategoryTags(btn)
        return
    end

    local leftPad = btn.isChild and 28 or QUEST_LIST_TAG_PAD_X
    local availW = (btn:GetWidth() > 0 and btn:GetWidth() or 260)
        - leftPad
        - QUEST_LIST_STATUS_RESERVE
        - 4
    local xPos = leftPad
    local tagIndex = 0

    for _, categoryKey in ipairs(categories) do
        if tagIndex >= QUEST_CATEGORY_TAG_MAX then
            break
        end
        local label = QUEST_CATEGORY_LABELS[categoryKey] or FormatQuestMetadataValue(categoryKey)
        if label and label ~= "" and label ~= "-" then
            local catText = btn.catTexts[tagIndex + 1]
            catText:SetText(label)
            catText:SetTextColor(GetQuestCategoryColor(categoryKey))
            local w = catText:GetStringWidth() or 0
            if xPos > leftPad and (xPos + w) > (leftPad + availW) then
                break
            end
            tagIndex = tagIndex + 1
            catText:ClearAllPoints()
            -- Same bottom inset as status icons so tags share one baseline row.
            catText:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", xPos, QUEST_STATUS_BOTTOM)
            catText:Show()
            xPos = xPos + w + QUEST_LIST_TAG_GAP
        end
    end

    for i = tagIndex + 1, #btn.catTexts do
        btn.catTexts[i]:Hide()
    end
end

local function ResolveQuestZoneName(quest)
    if not quest then
        return UNKNOWN
    end

    if quest.zoneName and quest.zoneName ~= "" then
        return quest.zoneName
    end

    if quest.mapID and quest.mapID ~= 0 then
        local mapInfo = C_Map.GetMapInfo(quest.mapID)
        if mapInfo and mapInfo.name and mapInfo.name ~= "" then
            quest.zoneName = mapInfo.name
            return mapInfo.name
        end
    end

    return UNKNOWN
end

local function CreateSeparatorLine(parent, yOffset)
    return OneWoW_GUI:CreateDivider(parent, { yOffset = yOffset })
end

local npcNameCache = {}
local npcNameRefreshPending = {}
local NPC_NAME_REFRESH_DELAYS = { 0.1, 0.25, 0.5, 1.0 }

local CLASS_NAMES = {
    [1] = "Warrior",
    [2] = "Paladin",
    [3] = "Hunter",
    [4] = "Rogue",
    [5] = "Priest",
    [6] = "Death Knight",
    [7] = "Shaman",
    [8] = "Mage",
    [9] = "Warlock",
    [10] = "Monk",
    [11] = "Druid",
    [12] = "Demon Hunter",
    [13] = "Evoker",
}

local RACE_NAMES = {
    [1] = "Human",
    [2] = "Orc",
    [3] = "Dwarf",
    [4] = "Night Elf",
    [5] = "Undead",
    [6] = "Tauren",
    [7] = "Gnome",
    [8] = "Troll",
    [9] = "Goblin",
    [10] = "Blood Elf",
    [11] = "Draenei",
    [22] = "Worgen",
    [24] = "Pandaren",
    [25] = "Pandaren",
    [26] = "Pandaren",
    [27] = "Nightborne",
    [28] = "Highmountain Tauren",
    [29] = "Void Elf",
    [30] = "Lightforged Draenei",
    [31] = "Zandalari Troll",
    [32] = "Kul Tiran",
    [34] = "Dark Iron Dwarf",
    [35] = "Vulpera",
    [36] = "Mag'har Orc",
    [37] = "Mechagnome",
    [52] = "Dracthyr",
    [70] = "Dracthyr",
    [84] = "Earthen",
    [85] = "Earthen",
}

local detailRenderVersion = 0
local rewardItemSearchWarmQueue = {}
local rewardItemSearchWarmSeen = {}
local rewardItemSearchWarmRunning = false
local rewardItemSearchWarmToken = 0
local rewardItemSearchRefreshQueued = false
local REWARD_ITEM_SEARCH_WARM_PER_TICK = 3
local REWARD_ITEM_SEARCH_WARM_DELAY = 0.1
local REWARD_ITEM_SEARCH_WARM_MAX = 900

local function RememberRewardItemName(itemID, itemName)
    if not itemID or not itemName or itemName == "" then
        return false
    end

    itemName = tostring(itemName)

    -- RETRIEVING_ITEM_INFO is the locale-correct placeholder Blizzard shows
    -- while an item is uncached; never memorize it as a real name.
    if itemName == RETRIEVING_ITEM_INFO then
        return false
    end

    local addon = GetDataAddon()

    if addon then
        addon.RememberItemName(itemID, itemName)
        return true
    end

    return false
end

local function ApplyVisibleRewardItemName(itemID, itemName)
    itemID = tonumber(itemID)
    if not itemID or not itemName or itemName == "" then
        return false
    end

    local rows = visibleRewardItemRows[itemID]
    if not rows then
        return false
    end

    local applied = false
    local remaining = {}

    for _, row in ipairs(rows) do
        if row
            and row.renderVersion == detailRenderVersion
            and row.apply
        then
            row.apply(itemName)
            applied = true
            table.insert(remaining, row)
        end
    end

    if #remaining > 0 then
        visibleRewardItemRows[itemID] = remaining
    else
        visibleRewardItemRows[itemID] = nil
    end

    return applied
end

local function RememberAndApplyRewardItemName(itemID, itemName)
    if not RememberRewardItemName(itemID, itemName) then
        return false
    end

    ApplyVisibleRewardItemName(itemID, itemName)
    return true
end

local function GetVisibleTooltipItemName()
    local tooltipTitle = GameTooltip.TextLeft1
    local text =
        tooltipTitle
        and tooltipTitle.GetText
        and tooltipTitle:GetText()

    if text and text ~= "" and text ~= RETRIEVING_ITEM_INFO then
        return text
    end

    return nil
end

local function GetRewardItemID(entry)
    if type(entry) == "number" then
        return entry
    elseif type(entry) == "table" then
        return entry.itemID or entry.id
    end

    return nil
end

local function CatalogItemCacheHasName(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    local cached = ns.GetItemDataLoader():GetCachedItem(itemID)
    return cached ~= nil and cached.name ~= nil and cached.name ~= ""
end

local function QueueRewardItemSearchRefresh(panels, token)
    if rewardItemSearchRefreshQueued then
        return
    end

    rewardItemSearchRefreshQueued = true

    C_Timer.After(1.5, function()
        rewardItemSearchRefreshQueued = false

        if token ~= rewardItemSearchWarmToken then
            return
        end

        if panels and RefreshQuestList then
            RefreshQuestList(panels)
        end
    end)
end

local function CancelRewardItemSearchWarmup()
    rewardItemSearchWarmToken = rewardItemSearchWarmToken + 1
    rewardItemSearchWarmRunning = false
    rewardItemSearchRefreshQueued = false
    wipe(rewardItemSearchWarmQueue)
    wipe(rewardItemSearchWarmSeen)
end

local function ProcessRewardItemSearchWarmQueue(panels, token)
    if token ~= rewardItemSearchWarmToken then
        return
    end

    local loader = ns.GetItemDataLoader()

    local processed = 0

    while processed < REWARD_ITEM_SEARCH_WARM_PER_TICK and #rewardItemSearchWarmQueue > 0 do
        local itemID = table.remove(rewardItemSearchWarmQueue, 1)

        if itemID and not CatalogItemCacheHasName(itemID) then
            processed = processed + 1

            loader:LoadItemData(itemID, function(_, itemData)
                if token ~= rewardItemSearchWarmToken then
                    return
                end

                if itemData and itemData.name then
                    RememberAndApplyRewardItemName(itemID, itemData.name)
                    QueueRewardItemSearchRefresh(panels, token)
                end
            end)
        end
    end

    if #rewardItemSearchWarmQueue > 0 then
        C_Timer.After(REWARD_ITEM_SEARCH_WARM_DELAY, function()
            ProcessRewardItemSearchWarmQueue(panels, token)
        end)
    else
        rewardItemSearchWarmRunning = false
    end
end

local function LooksLikeItemNameSearch(value)
    value = NormalizeQuestSearchText(value):gsub("^%s+", ""):gsub("%s+$", "")

    if value == "" or #value < 3 then
        return false
    end

    if tonumber(value) then
        return false
    end

    if value:match("^item:%s*%d+$") then
        return false
    end

    return value:match("[%a]") ~= nil
end

local function StartRewardItemSearchWarmup(panels, addon, resultCount)
    if not LooksLikeItemNameSearch(searchText) then
        return
    end

    if resultCount and resultCount > 40 then
        return
    end

    if not addon then
        return
    end

    rewardItemSearchWarmToken = rewardItemSearchWarmToken + 1
    rewardItemSearchWarmRunning = false
    wipe(rewardItemSearchWarmQueue)
    wipe(rewardItemSearchWarmSeen)

    local quests = addon.GetQuestsForExpansion(expansionFilter)
    local queued = 0

    local function addItems(items)
        if queued >= REWARD_ITEM_SEARCH_WARM_MAX or type(items) ~= "table" then
            return
        end

        for _, rewardItem in ipairs(items) do
            local itemID = tonumber(GetRewardItemID(rewardItem))
            if itemID
                and not rewardItemSearchWarmSeen[itemID]
                and not CatalogItemCacheHasName(itemID)
            then
                rewardItemSearchWarmSeen[itemID] = true
                table.insert(rewardItemSearchWarmQueue, itemID)
                queued = queued + 1

                if queued >= REWARD_ITEM_SEARCH_WARM_MAX then
                    return
                end
            end
        end
    end

    for _, quest in pairs(quests or {}) do
        if zoneFilter == ""
            or quest.zoneName == zoneFilter
            or ResolveQuestZoneName(quest) == zoneFilter
        then
            addItems(quest.rewardItems)
            addItems(quest.rewardChoices)
        end

        if queued >= REWARD_ITEM_SEARCH_WARM_MAX then
            break
        end
    end

    if queued == 0 then
        return
    end

    if not rewardItemSearchWarmRunning then
        rewardItemSearchWarmRunning = true
        ProcessRewardItemSearchWarmQueue(panels, rewardItemSearchWarmToken)
    end
end

local function IsGenericNPCName(name, npcID)
    if not name then
        return true
    end
    -- Secret tooltip lines error on any compare, including == "".
    if OneWoW.Restriction.IsSecretValue(name) then
        return true
    end
    if name == "" then
        return true
    end
    if name == RETRIEVING_DATA or name == RETRIEVING_ITEM_INFO then
        return true
    end
    if name == UNKNOWNOBJECT then
        return true
    end
    if name == "???" or name == "?" then
        return true
    end
    if name:find("^NPC #%d") ~= nil or name:find("^NPC %d") ~= nil then
        return true
    end
    if npcID and name == tostring(npcID) then
        return true
    end
    return false
end

local function GetNPCAPI()
    local api = ns.GetCatalogPackAPI("vendors")
    if api then
        return api
    end
    if not OneWoW:IsCatalogPackAvailable("vendors") then
        return nil
    end
    ns.EnsureCatalogPack("vendors")
    return ns.GetCatalogPackAPI("vendors")
end

local function RememberResolvedNPCName(npcID, name)
    if IsGenericNPCName(name, npcID) then
        return
    end
    npcNameCache[npcID] = name
    local api = GetNPCAPI()
    if api then
        api.RememberNPCName(npcID, name)
    end
end

local function PeekStoredNPCName(npcID)
    if npcNameCache[npcID] then
        return npcNameCache[npcID]
    end
    local api = ns.GetCatalogPackAPI("vendors")
    if not api then
        return nil
    end
    local cached = api.GetCachedNPCName(npcID)
    if not IsGenericNPCName(cached, npcID) then
        npcNameCache[npcID] = cached
        return cached
    end
    local npc = api.GetNPC(npcID)
    if npc and not IsGenericNPCName(npc.name, npcID) then
        npcNameCache[npcID] = npc.name
        return npc.name
    end
    return nil
end

local function ResolveNPCName(npcID, knownName, allowLive)
    if not npcID then
        return nil
    end

    if not IsGenericNPCName(knownName, npcID) then
        RememberResolvedNPCName(npcID, knownName)
        return knownName
    end

    local stored = PeekStoredNPCName(npcID)
    if stored then
        return stored
    end

    if not allowLive then
        return nil
    end

    local api = GetNPCAPI()
    if api then
        local live = api.ResolveNPCName(npcID)
        if not IsGenericNPCName(live, npcID) then
            npcNameCache[npcID] = live
            return live
        end
    end

    local hyperlink = ("unit:Creature-0-0-0-0-%d-0000000000"):format(npcID)
    local tooltipData = C_TooltipInfo.GetHyperlink(hyperlink)

    if tooltipData and tooltipData.lines then
        for _, line in ipairs(tooltipData.lines) do
            local text = line.leftText
            if not IsGenericNPCName(text, npcID) then
                RememberResolvedNPCName(npcID, text)
                return text
            end
        end
    end

    return nil
end

local function ApplyVisibleNPCName(npcID, npcName)
    npcID = tonumber(npcID)
    if not npcID or not npcName then
        return false
    end
    if OneWoW.Restriction.IsSecretValue(npcName) or npcName == "" then
        return false
    end

    local rows = visibleNPCNameRows[npcID]
    if not rows then
        return false
    end

    local applied = false
    local remaining = {}

    for _, row in ipairs(rows) do
        if row
            and row.renderVersion == detailRenderVersion
            and row.setName
        then
            row.setName(npcName)
            applied = true
            table.insert(remaining, row)
        end
    end

    if #remaining > 0 then
        visibleNPCNameRows[npcID] = remaining
    else
        visibleNPCNameRows[npcID] = nil
    end

    return applied
end

local function RegisterVisibleNPCName(npcID, setName)
    npcID = tonumber(npcID)
    if not npcID or not setName then
        return
    end

    visibleNPCNameRows[npcID] = visibleNPCNameRows[npcID] or {}
    table.insert(visibleNPCNameRows[npcID], {
        setName = setName,
        renderVersion = detailRenderVersion,
    })
end

local function ScheduleNPCNameRefresh(npcID, questData)
    if not npcID or npcNameRefreshPending[npcID] then
        return
    end

    npcNameRefreshPending[npcID] = true

    local function stillCurrent()
        return selectedQuest
            and questData
            and selectedQuest.id == questData.id
    end

    local function finish(name)
        npcNameRefreshPending[npcID] = nil
        if not stillCurrent() or IsGenericNPCName(name, npcID) then
            return
        end
        RememberResolvedNPCName(npcID, name)
        ApplyVisibleNPCName(npcID, name)
    end

    local function requestFromAPI(api)
        if not stillCurrent() then
            npcNameRefreshPending[npcID] = nil
            return
        end
        local cached = api.GetCachedNPCName(npcID)
        if not IsGenericNPCName(cached, npcID) then
            finish(cached)
            return
        end
        api.RequestNPCName(npcID, function(_, info)
            finish(info and info.name)
        end)
    end

    local api = GetNPCAPI()
    if api then
        requestFromAPI(api)
        return
    end

    local live = ResolveNPCName(npcID, nil, true)
    if live then
        finish(live)
        return
    end

    local state = { attempt = 1 }
    local function retry()
        if not stillCurrent() then
            npcNameRefreshPending[npcID] = nil
            return
        end
        local npcName = ResolveNPCName(npcID, nil, true)
        if npcName then
            finish(npcName)
            return
        end
        state.attempt = state.attempt + 1
        local delay = NPC_NAME_REFRESH_DELAYS[state.attempt]
        if delay then
            C_Timer.After(delay, retry)
        else
            npcNameRefreshPending[npcID] = nil
        end
    end
    C_Timer.After(NPC_NAME_REFRESH_DELAYS[state.attempt], retry)
end

local function ApplyVisibleQuestName(questID, questName)
    questID = tonumber(questID)
    if not questID or not questName or questName == "" then
        return false
    end

    local rows = visibleQuestNameRows[questID]
    if not rows then
        return false
    end

    local applied = false
    local remaining = {}

    for _, row in ipairs(rows) do
        if row
            and row.renderVersion == detailRenderVersion
            and row.text
            and row.text.SetText
        then
            row.text:SetText(
                (row.prefix or "")
                    .. (row.format and row.format(questName) or questName)
                    .. (row.suffix or "")
            )
            applied = true
            table.insert(remaining, row)
        end
    end

    if #remaining > 0 then
        visibleQuestNameRows[questID] = remaining
    else
        visibleQuestNameRows[questID] = nil
    end

    return applied
end

local function RegisterVisibleQuestName(questID, textObject, prefix, suffix, formatter)
    questID = tonumber(questID)
    if not questID or not textObject then
        return
    end

    visibleQuestNameRows[questID] = visibleQuestNameRows[questID] or {}
    table.insert(visibleQuestNameRows[questID], {
        text = textObject,
        prefix = prefix or "",
        suffix = suffix or "",
        format = formatter,
        renderVersion = detailRenderVersion,
    })
end

local function GetQuestDisplayName(questID, _)
    local API = ns.GetCatalogPackAPI("quests")
    local questName = API and API.GetQuestName(questID)
    return questName or ("Quest " .. tostring(questID))
end

local function RequestVisibleChainQuestName(questID)
    questID = tonumber(questID)
    if not questID then
        return
    end
    local API = ns.GetCatalogPackAPI("quests")
    if not API then
        return
    end
    if API.GetQuestName(questID) then
        return
    end
    API.RequestQuestName(questID, function(id, name)
        ApplyVisibleQuestName(id, name)
    end)
end

local function GetClassDisplayName(value)
    local classID = tonumber(value)

    if classID then
        local info = C_CreatureInfo.GetClassInfo(classID)
        if info and info.className then
            return info.className
        end

        if GetClassInfo then
            local className = GetClassInfo(classID)
            if className then
                return className
            end
        end

        return CLASS_NAMES[classID] or ("Class " .. tostring(classID))
    end

    return tostring(value)
end

local function GetRaceDisplayName(value)
    local raceID = tonumber(value)

    if raceID then
        local info = C_CreatureInfo.GetRaceInfo(raceID)
        if info and info.raceName then
            return info.raceName
        end

        return RACE_NAMES[raceID] or ("Race " .. tostring(raceID))
    end

    return tostring(value)
end

local function GetFactionFilterValue(value)
    if value == nil or tostring(value) == "" then
        return nil
    end

    value = tostring(value):lower()

    if value == "none" or value == "both" or value == "neutral" then
        return "neutral"
    end

    return value
end

local function GetFactionDisplayName(value)
    value = GetFactionFilterValue(value)

    if value == "alliance" then
        return "Alliance"
    elseif value == "horde" then
        return "Horde"
    elseif value == "neutral" then
        return "Both / Neutral"
    end

    return value and FormatQuestMetadataValue(value) or "-"
end

local function GetAdvancedValueText(fieldName, value)
    if not value or value == "all" then
        return nil
    end

    if fieldName == "class" then
        return GetClassDisplayName(value)
    elseif fieldName == "race" then
        return GetRaceDisplayName(value)
    elseif fieldName == "faction" then
        return GetFactionDisplayName(value)
    elseif fieldName == "category" or fieldName == "flag" then
        return FormatQuestMetadataValue(value)
    end

    return tostring(value)
end

---@param npcID number|nil
---@param preferMapID number|nil
---@return number|nil mapID
---@return number|nil x
---@return number|nil y
local function NPCDBPin(npcID, preferMapID)
    npcID = tonumber(npcID)
    if not npcID then
        return nil
    end
    if not ns.GetCatalogPackAPI("vendors") then
        ns.EnsureCatalogPack("vendors")
    end
    local npcAPI = ns.GetCatalogPackAPI("vendors")
    if not npcAPI then
        return nil
    end
    local npc = npcAPI.GetNPC(npcID)
    if not npc or not npc.locations then
        return nil
    end
    local loc = preferMapID and npc.locations[preferMapID]
    if loc and loc.x and loc.y then
        return loc.mapID or preferMapID, loc.x, loc.y
    end
    for mapID, row in pairs(npc.locations) do
        if row and row.x and row.y then
            return row.mapID or mapID, row.x, row.y
        end
    end
    return nil
end

---@param pin table|nil
---@param questData table|nil
---@return table|nil
local function FillPinFromNPCDB(pin, questData)
    if not pin or (pin.x and pin.y) then
        return pin
    end
    local mapID, x, y = NPCDBPin(pin.npcID, pin.mapID or (questData and questData.mapID))
    if not x then
        return pin
    end
    return {
        npcID = pin.npcID,
        npcName = pin.npcName or pin.name,
        objectID = pin.objectID,
        mapID = mapID,
        x = x,
        y = y,
    }
end

local function GetQuestStarterData(questData)
    if not questData then return nil end

    if questData.starts and questData.starts[1] then
        return FillPinFromNPCDB(questData.starts[1], questData)
    end

    if questData.startObjects and questData.startObjects[1] then
        return questData.startObjects[1]
    end

    if questData.questGiverID then
        return FillPinFromNPCDB({
            npcID = questData.questGiverID,
            npcName = questData.questGiverName,
        }, questData)
    end

    return nil
end

local function GetQuestEnderData(questData)
    if not questData then return nil end

    if questData.ends and questData.ends[1] then
        return FillPinFromNPCDB(questData.ends[1], questData)
    end

    if questData.endObjects and questData.endObjects[1] then
        return questData.endObjects[1]
    end

    if questData.questTurnInID then
        return FillPinFromNPCDB({
            npcID = questData.questTurnInID,
            npcName = questData.questTurnInName,
        }, questData)
    end

    return nil
end

local function FormatQuestPinLocation(pin, questData)
    if not pin then
        return nil
    end

    local mapID = pin.mapID or (questData and questData.mapID)
    local mapName
    if mapID and mapID ~= 0 then
        local mapInfo = C_Map.GetMapInfo(mapID)
        mapName = mapInfo and mapInfo.name
    end

    local x, y = pin.x, pin.y
    if x and y then
        if x <= 1 then
            x = x * 100
        end
        if y <= 1 then
            y = y * 100
        end
        local coord = string.format("%.1f, %.1f", x, y)
        if mapName then
            return mapName .. " (" .. coord .. ")"
        end
        return coord
    end

    return mapName
end

local function BuildNotesNPCInfo(npcData, questData, npcName)
    local mapID = tonumber(npcData.mapID) or tonumber(questData and questData.mapID)
    local x, y = npcData.x, npcData.y
    if (not x or not y) and npcData.npcID then
        local pinMapID, pinX, pinY = NPCDBPin(npcData.npcID, mapID)
        x = x or pinX
        y = y or pinY
        mapID = mapID or pinMapID
    end
    if (not x or not y) and questData and questData.coords then
        x = x or questData.coords.x
        y = y or questData.coords.y
        mapID = mapID or tonumber(questData.coords.mapID)
    end
    local zone
    if questData then
        zone = ResolveQuestZoneName(questData)
        if zone == UNKNOWN then
            zone = nil
        end
    end
    return {
        name = npcName,
        zone = zone,
        mapID = mapID,
        x = x,
        y = y,
        category = "quest_giver",
        roles = { "quest_giver" },
        questID = questData and (questData.id or questData.questID),
    }
end

local function GetQuestChainIDs(questData)
    local addon = GetDataAddon()
    if not addon then
        return nil
    end
    return addon.GetQuestGuideChain(questData)
end

local function GetQuestMapTarget(questData)
    if not questData then return nil end

    local starterData = GetQuestStarterData(questData)
    if starterData and starterData.mapID and starterData.x and starterData.y then
        return starterData.mapID, starterData.x, starterData.y
    end

    local enderData = GetQuestEnderData(questData)
    if enderData and enderData.mapID and enderData.x and enderData.y then
        return enderData.mapID, enderData.x, enderData.y
    end

    if questData.coords and questData.coords.mapID and questData.coords.x and questData.coords.y then
        return questData.coords.mapID, questData.coords.x, questData.coords.y
    end

    return questData.mapID, nil, nil
end

local function HandleItemPreviewClick(itemID, itemLink)
    if not IsControlKeyDown or not IsControlKeyDown() then
        return false
    end

    itemLink = itemLink
        or select(2, C_Item.GetItemInfo(itemID))
        or ("item:" .. tostring(itemID))

    if HandleModifiedItemClick and HandleModifiedItemClick(itemLink) then
        return true
    end

    if DressUpItemLink then
        DressUpItemLink(itemLink)
        return true
    end

    return false
end

local function AddRewardItemToNotes(itemID, itemName, itemLink, itemTexture, itemQuality)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    if ns.Navigation and ns.Navigation.OpenItemNote then
        return ns.Navigation:OpenItemNote(itemID, {
            name = itemName,
            link = itemLink,
            icon = itemTexture,
            quality = itemQuality,
            category = "Quest",
            storage = "account",
        })
    end

    return false
end

local function OpenRewardItemInItemSearch(itemID, itemName)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    OneWoW.UI:Show("catalog")
    OneWoW.UI:SelectSubTab("catalog", "itemsearch")
    OneWoW.UI:CommitNavEntity("item", itemID)

    C_Timer.After(0.05, function()
        if ns.UI and ns.UI.OpenItemSearch then
            ns.UI.OpenItemSearch(itemID, itemName)
        end
    end)

    return true
end

function ShowQuestDetail(panels, questData)
    detailRenderVersion = detailRenderVersion + 1

    selectedQuest = questData
    ClearDetailElements()

    if not questData then
        if panels.emptyDetail then
            panels.emptyDetail:SetText(L["QUESTS_SELECT"])
            panels.emptyDetail:Show()
        end
        panels.detailScrollChild:SetHeight(100)
        return
    end

    if panels.emptyDetail then panels.emptyDetail:Hide() end

    local parent  = panels.detailScrollChild
    local addon   = GetDataAddon()
    if not addon then return end
    local tracker = addon

    local contentWidth = parent:GetWidth()
    if contentWidth < 50 then
        C_Timer.After(0.05, function()
            if selectedQuest
                and questData
                and selectedQuest.id == questData.id
            then
                ShowQuestDetail(panels, questData)
            end
        end)
        return
    end

    if not questData.mapID then
        local liveMapID = GetQuestUiMapID(questData.id)
        if liveMapID and liveMapID ~= 0 then
            local mapInfo = C_Map.GetMapInfo(liveMapID)
            questData.mapID    = liveMapID
            questData.zoneName = mapInfo and mapInfo.name or questData.zoneName

            addon.StoreQuestInfoQuiet(questData.id, {
                mapID = liveMapID,
                zoneName = questData.zoneName
            })
        end
    end

    if not questData.classification then
        local cls = C_QuestInfoSystem.GetQuestClassification(questData.id)

        if cls then
            questData.classification = cls

            addon.StoreQuestInfoQuiet(questData.id, {
                classification = cls
            })
        end
    end

    if not questData.tagName then
        local tagInfo = C_QuestLog.GetQuestTagInfo(questData.id)

        if tagInfo and tagInfo.tagName then
            questData.tagName = tagInfo.tagName
            questData.isElite = tagInfo.isElite

            addon.StoreQuestInfoQuiet(questData.id, {
                tagName = tagInfo.tagName,
                isElite = tagInfo.isElite
            })
        end
    end

    local yOffset = -12
    local PAD     = 10
    local W       = contentWidth - PAD * 2

    local function track(elem)
        table.insert(detailElements, elem)
        return elem
    end

    local function addSep()
        local sep = CreateSeparatorLine(parent, yOffset - 6)
        track(sep)
        yOffset = yOffset - 20
    end

    local function addVSpace(h)
        yOffset = yOffset - (h or 8)
    end

    local function FormatQuestText(text)
        if not text or text == "" then
            return text
        end

        local playerName = UnitName("player") or "Player"

        -- Blizzard-style quest tokens
        text = text:gsub("%$p", playerName)

        -- Legacy/custom tokens seen in some quest text
        text = text:gsub("<name>", playerName)

        return text
    end

    local function ParseDetailSearchTerms()
        local terms = {}
        local text = tostring(searchText or "")
        local length = #text
        local index = 1

        while index <= length do
            while index <= length and text:sub(index, index):match("%s") do
                index = index + 1
            end

            if index > length then
                break
            end

            local quoted = false
            local value

            if text:sub(index, index) == "\"" then
                quoted = true
                local closeIndex = text:find("\"", index + 1, true)
                if closeIndex then
                    value = text:sub(index + 1, closeIndex - 1)
                    index = closeIndex + 1
                else
                    value = text:sub(index + 1)
                    index = length + 1
                end
            else
                local nextSpace = text:find("%s", index)
                if nextSpace then
                    value = text:sub(index, nextSpace - 1)
                    index = nextSpace + 1
                else
                    value = text:sub(index)
                    index = length + 1
                end
            end

            value = value and value:gsub("^%s+", ""):gsub("%s+$", "")
            local lowerValue = value and value:lower()
            if value
                and #value >= 2
                and not QUEST_SEARCH_STOP_WORDS[lowerValue]
            then
                table.insert(terms, {
                    text = value,
                    lower = lowerValue,
                    quoted = quoted,
                    wordExact = quoted and value:find("%s") == nil and value:match("^%w+$") ~= nil,
                })
            end
        end

        return terms
    end

    local detailSearchTerms = ParseDetailSearchTerms()

    local function FindNextHighlightMatch(lowerText, cursor, terms)
        local bestStart, bestEnd

        for _, term in ipairs(terms) do
            local startIndex, endIndex

            if term.wordExact then
                startIndex, endIndex = lowerText:find("%f[%w]" .. term.lower .. "%f[%W]", cursor)
            else
                startIndex, endIndex = lowerText:find(term.lower, cursor, true)
            end

            if startIndex
                and (
                    not bestStart
                    or startIndex < bestStart
                    or (startIndex == bestStart and endIndex > bestEnd)
                )
            then
                bestStart = startIndex
                bestEnd = endIndex
            end
        end

        return bestStart, bestEnd
    end

    local function HighlightSearchText(text)
        if not text or text == "" then
            return text
        end

        text = tostring(text)

        if #detailSearchTerms == 0 then
            return text
        end

        local lowerText = text:lower()
        local pieces = {}
        local cursor = 1

        while cursor <= #text do
            local startIndex, endIndex = FindNextHighlightMatch(lowerText, cursor, detailSearchTerms)
            if not startIndex then
                table.insert(pieces, text:sub(cursor))
                break
            end

            if startIndex > cursor then
                table.insert(pieces, text:sub(cursor, startIndex - 1))
            end

            table.insert(pieces, "|cffffff00" .. text:sub(startIndex, endIndex) .. "|r")
            cursor = endIndex + 1
        end

        return table.concat(pieces)
    end

    local function FormatAndHighlightQuestText(text)
        return HighlightSearchText(FormatQuestText(text))
    end

    local function addWrappedText(text, fontSize, color)
        local fs = track(OneWoW_GUI:CreateFS(parent, fontSize or 12))

        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
        fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)

        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetText(FormatAndHighlightQuestText(text))
        fs:SetWidth(W)

        if color then
            local r, g, b, a = table.unpack(color)
            fs:SetTextColor(r, g, b, a or 1)
        else
            fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        yOffset = yOffset - fs:GetStringHeight() - 8

        return fs
    end

    local function FormatNamedRecords(records, nameField, orderField, formatKey)
        local labels = {}

        for _, record in ipairs(records or {}) do
            local name = record[nameField]
            if name and name ~= "" then
                local order = orderField and tonumber(record[orderField])
                if order and formatKey then
                    table.insert(labels, string.format(L[formatKey], name, order + 1))
                else
                    table.insert(labels, name)
                end
            end
        end

        return #labels > 0 and table.concat(labels, ", ") or nil
    end

    local titleFrame = track(CreateFrame("Frame", nil, parent))
    titleFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
    titleFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)
    titleFrame:SetHeight(24)

    local titleText = OneWoW_GUI:CreateFS(titleFrame, 16)
    titleText:SetPoint("TOPLEFT", titleFrame, "TOPLEFT", 0, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(true)
    titleText:SetWidth(W)
    titleText:SetText(
        FormatAndHighlightQuestText(
            questData.name
            or string.format(L["QUESTS_UNNAMED"], questData.id or 0)
        )
    )
    titleText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    if questData.id then
        RegisterVisibleQuestName(
            questData.id,
            titleText,
            nil,
            nil,
            FormatAndHighlightQuestText
        )
        if not questData.name or questData.name == "" then
            RequestVisibleChainQuestName(questData.id)
        end
    end

    local titleHeight = math.max(titleText:GetStringHeight() or 18, 18)
    titleFrame:SetHeight(titleHeight)
    yOffset = yOffset - titleHeight - 8

    local zoneName = ResolveQuestZoneName(questData)
    local categoryName = FormatQuestMetadataList(questData.categories)
    local factionName = GetFactionDisplayName(questData.faction)
    local flagName = FormatQuestMetadataList(questData.flags)
    local mapID    = questData.mapID or 0
    local questID  = questData.id or 0
    local pinMapID, pinX, pinY = GetQuestMapTarget(questData)
    local displayMapID = pinMapID or mapID

    local function addNPCNavigationRow(label, npcData)
        if not npcData then return end

        local npcID = tonumber(npcData.npcID)
        local objectID = tonumber(npcData.objectID)
        local locationText = FormatQuestPinLocation(npcData, questData)
        if not npcID and not objectID and not locationText then
            return
        end

        local fallbackNPCName = npcID and string.format(L["QUESTS_NPC_UNNAMED"], npcID) or locationText
        local npcName =
            (npcID and ResolveNPCName(npcID, npcData.npcName or npcData.name, false))
            or (npcID and npcNameCache[npcID])
            or fallbackNPCName

        if npcID and IsGenericNPCName(npcName, npcID) then
            ScheduleNPCNameRefresh(npcID, questData)
        end

        local npcBtn = track(CreateFrame("Button", nil, parent))

        npcBtn:RegisterForClicks("LeftButtonUp")
        npcBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset + 2)
        npcBtn:SetSize(W, 16)

        local npcText = OneWoW_GUI:CreateFS(npcBtn, 11)

        npcText:SetAllPoints()
        npcText:SetJustifyH("LEFT")
        npcText:SetWordWrap(true)

        local function setLinkText(color)
            local suffix = ""
            if locationText and npcName ~= locationText then
                suffix = "|cff888888  " .. locationText
            end
            npcText:SetText(
                "|cff888888"
                .. label
                .. ": |cff"
                .. color
                .. (npcName or "")
                .. suffix
            )
        end

        setLinkText("4dbfff")
        npcBtn:SetHeight(math.max(16, npcText:GetStringHeight() or 16))

        if npcID and IsGenericNPCName(npcName, npcID) then
            RegisterVisibleNPCName(npcID, function(resolvedName)
                if resolvedName and resolvedName ~= npcName then
                    npcName = resolvedName
                    setLinkText("4dbfff")
                end
            end)
        end

        npcBtn:SetScript("OnEnter", function(self)
            local resolvedName =
                (npcID and ResolveNPCName(npcID, npcData.npcName or npcData.name, true))
                or (npcID and npcNameCache[npcID])

            if resolvedName and resolvedName ~= npcName then
                npcName = resolvedName
                setLinkText("ffd100")
            end

            setLinkText("ffd100")

            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

            GameTooltip:AddLine(
                npcName,
                1,
                0.82,
                0
            )

            GameTooltip:AddLine(
                locationText or npcName,
                0.6,
                0.6,
                0.6
            )

            if npcID then
                GameTooltip:AddLine(
                    "NPC ID: " .. tostring(npcData.npcID),
                    0.6,
                    0.6,
                    0.6
                )
            end

            GameTooltip:AddLine(" ")

            if npcID then
                GameTooltip:AddLine(
                    L["QUESTS_NPC_OPEN_CATALOG"],
                    0,
                    1,
                    0
                )
            end

            GameTooltip:Show()
        end)

        npcBtn:SetScript("OnLeave", function()
            setLinkText("4dbfff")
            GameTooltip:Hide()
        end)

        npcBtn:SetScript("OnClick", function()
            if not npcID or not ns.Navigation or not ns.Navigation.OpenNPC then
                return
            end
            local resolvedName =
                ResolveNPCName(npcID, npcData.npcName or npcData.name, true)
                or npcNameCache[npcID]

            ns.Navigation:OpenNPC(npcData.npcID, BuildNotesNPCInfo(
                npcData,
                questData,
                resolvedName or npcName
            ))
        end)

        yOffset = yOffset - math.max(20, (npcText:GetStringHeight() or 16) + 4)
    end

    local starterData = GetQuestStarterData(questData)
    local enderData = GetQuestEnderData(questData)

    addNPCNavigationRow(L["QUESTS_QUEST_GIVER"], starterData)
    addNPCNavigationRow(L["QUESTS_TURN_IN"], enderData)

    local metaFrame = track(CreateFrame("Frame", nil, parent))

    metaFrame:SetPoint(
        "TOPLEFT",
        parent,
        "TOPLEFT",
        PAD,
        yOffset
    )

    metaFrame:SetSize(W, 38)

    local metaY = 0
    local META_LINE_GAP = 2
    local function AddMetaLine(parts)
        if not parts or #parts == 0 then
            return
        end
        local line = OneWoW_GUI:CreateFS(metaFrame, 10)
        line:SetPoint("TOPLEFT", metaFrame, "TOPLEFT", 0, metaY)
        line:SetPoint("TOPRIGHT", metaFrame, "TOPRIGHT", 0, metaY)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(true)
        line:SetWidth(W)
        line:SetText(table.concat(parts, "  |  "))
        line:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        metaY = metaY - math.max(line:GetStringHeight() or 12, 12) - META_LINE_GAP
    end

    AddMetaLine({
        string.format("%s: %s", ZONE, zoneName),
        string.format("%s: %s", FACTION, factionName),
    })

    local categoryTraitParts = {}
    if categoryName ~= "-" then
        table.insert(
            categoryTraitParts,
            string.format("%s: %s", CATEGORIES, categoryName)
        )
    end
    if flagName ~= "-" then
        table.insert(
            categoryTraitParts,
            string.format("%s: %s", L["QUESTS_TRAITS"], flagName)
        )
    end
    AddMetaLine(categoryTraitParts)

    local idMapFrame = track(CreateFrame("Frame", nil, metaFrame))
    idMapFrame:SetPoint("TOPLEFT", metaFrame, "TOPLEFT", 0, metaY)
    idMapFrame:SetSize(W, 12)

    local questIDText = OneWoW_GUI:CreateFS(idMapFrame, 10)
    questIDText:SetPoint("TOPLEFT", idMapFrame, "TOPLEFT", 0, 0)
    questIDText:SetText(HighlightSearchText(string.format("%s: %d  |  ", L["QUESTS_QUESTID"], questID)))
    questIDText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local mapBtn = track(CreateFrame("Button", nil, idMapFrame))
    mapBtn:SetPoint("TOPLEFT", questIDText, "TOPRIGHT", 0, 0)

    local mapText = OneWoW_GUI:CreateFS(mapBtn, 10)
    mapText:SetPoint("TOPLEFT", mapBtn, "TOPLEFT", 0, 0)
    mapText:SetText(string.format("%s: %d", L["QUESTS_MAPID"], displayMapID or 0))
    mapText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    mapBtn:SetSize((mapText:GetStringWidth() or 0) + 4, 12)

    metaY = metaY - 12 - META_LINE_GAP
    metaFrame:SetHeight(math.abs(metaY))

    mapBtn:SetScript("OnEnter", function(self)
        mapText:SetTextColor(unpack(WOW_QUEST_GOLD))

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        GameTooltip:AddLine(
            zoneName,
            1,
            0.82,
            0
        )

        GameTooltip:AddLine(
            "Map ID: " .. tostring(displayMapID or 0),
            0.6,
            0.6,
            0.6
        )

        if pinX and pinY then
            GameTooltip:AddLine(
                string.format("Pin: %.1f, %.1f", pinX <= 1 and pinX * 100 or pinX, pinY <= 1 and pinY * 100 or pinY),
                0.6,
                0.6,
                0.6
            )
        end

        GameTooltip:AddLine(" ")

        GameTooltip:AddLine(
            pinX and pinY and "Click to open map and add quest giver pin" or "Click to open map",
            0,
            1,
            0
        )
        if pinX and pinY then
            if ns.Navigation:IsWayPinsEnabled() then
                GameTooltip:AddLine(L["JOURNAL_MAP_PIN_SAVE_TT"], 0.8, 0.8, 0.8, true)
            end
        end

        GameTooltip:Show()
    end)

    mapBtn:SetScript("OnLeave", function()
        mapText:SetTextColor(
            OneWoW_GUI:GetThemeColor("TEXT_ACCENT")
        )

        GameTooltip:Hide()
    end)

    mapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mapBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if pinX and pinY and ns.Navigation and ns.Navigation:IsWayPinsEnabled() then
                ns.Navigation:SaveOneWayPin(
                    questData.name or (L["QUESTS_QUESTID"] .. " " .. tostring(questID)),
                    displayMapID,
                    pinX,
                    pinY,
                    "quest",
                    questID
                )
            end
            return
        end

        if ns.Navigation and ns.Navigation.OpenMapPin then
            ns.Navigation:OpenMapPin(
                displayMapID,
                pinX,
                pinY,
                questData.name or ("Quest " .. tostring(questID))
            )
        end
    end)

    yOffset = yOffset - metaFrame:GetHeight() - 8

    local relationshipRows = {}
    local questLineText = FormatNamedRecords(
        questData.questLines,
        "name",
        "orderIndex",
        "QUESTS_STEP_FORMAT"
    )
    local campaignText = FormatNamedRecords(
        questData.campaigns,
        "title",
        "questLineOrder",
        "QUESTS_CHAPTER_FORMAT"
    )
    local activityLabels = {}
    for _, scenario in ipairs(questData.activities and questData.activities.scenarios or {}) do
        if scenario.name and scenario.name ~= "" then
            table.insert(activityLabels, scenario.name)
        end
    end
    for _, activity in ipairs(questData.activities and questData.activities.groupFinder or {}) do
        if activity.name and activity.name ~= "" then
            table.insert(activityLabels, activity.name)
        end
    end
    if #activityLabels > 0 then
        table.insert(
            relationshipRows,
            L["QUESTS_ACTIVITIES"] .. ": " .. table.concat(activityLabels, ", ")
        )
    end

    local worldLabels = {}
    for _, worldBoss in ipairs(questData.worldSystems and questData.worldSystems.worldBosses or {}) do
        if worldBoss.name and worldBoss.name ~= "" then
            table.insert(worldLabels, worldBoss.name)
        end
    end
    for _, invasion in ipairs(questData.worldSystems and questData.worldSystems.invasions or {}) do
        if invasion.name and invasion.name ~= "" then
            table.insert(worldLabels, invasion.name)
        end
    end
    for _, reward in ipairs(questData.worldSystems and questData.worldSystems.renownRewards or {}) do
        if reward.name and reward.name ~= "" then
            local rewardName = reward.name
            if reward.level then
                rewardName = string.format(L["QUESTS_RENOWN_FORMAT"], rewardName, reward.level)
            end
            table.insert(worldLabels, rewardName)
        end
    end
    if #worldLabels > 0 then
        table.insert(
            relationshipRows,
            L["QUESTS_WORLD_SYSTEMS"] .. ": " .. table.concat(worldLabels, ", ")
        )
    end

    local startItemLabels = {}
    for _, itemID in ipairs(questData.startItems or {}) do
        table.insert(
            startItemLabels,
            C_Item.GetItemNameByID(itemID) or string.format(L["QUESTS_ITEM_UNNAMED"], itemID)
        )
    end
    if #startItemLabels > 0 then
        table.insert(
            relationshipRows,
            L["QUESTS_START_ITEMS"] .. ": " .. table.concat(startItemLabels, ", ")
        )
    end

    if #relationshipRows > 0 then
        addSep()
        for _, relationship in ipairs(relationshipRows) do
            addWrappedText(relationship, 11)
        end
    end

    addSep()

    local descLabel = track(OneWoW_GUI:CreateFS(parent, 10))

    descLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
    descLabel:SetText(DESCRIPTION)

    descLabel:SetTextColor(
        OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
    )

    yOffset = yOffset - 18

    -- Description Section

    local function HasDisplayQuestText(text)
        if not text then
            return false
        end

        text = tostring(text):gsub("^%s+", ""):gsub("%s+$", "")

        if text == "" then
            return false
        end

        if text == "Accept this quest to record its description and rewards." then
            return false
        end

        return true
    end

    if HasDisplayQuestText(questData.description) then
        addWrappedText(
            questData.description,
            12
        )
    else
        local noDescFs = track(OneWoW_GUI:CreateFS(parent, 12))

        noDescFs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
        noDescFs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)

        noDescFs:SetJustifyH("LEFT")
        noDescFs:SetWordWrap(true)

        noDescFs:SetText(L["QUESTS_NO_DESCRIPTION"])
        noDescFs:SetWidth(W)

        noDescFs:SetTextColor(
            OneWoW_GUI:GetThemeColor("TEXT_MUTED")
        )

        yOffset = yOffset - noDescFs:GetStringHeight() - 8
    end

    -- Objectives Section

    local staticObjectives = questData.db2Objectives
    if (not staticObjectives or #staticObjectives == 0) and questData.objectiveDetails then
        staticObjectives = questData.objectiveDetails
    end
    if (not staticObjectives or #staticObjectives == 0) and questData.objectives then
        staticObjectives = {}
        for _, objectiveText in ipairs(questData.objectives) do
            table.insert(staticObjectives, { text = objectiveText })
        end
    end

    local liveObjectives
    if questData.id and C_QuestLog.IsOnQuest(questData.id) then
        liveObjectives = C_QuestLog.GetQuestObjectives(questData.id)
    end

    local hasObjectiveText = HasDisplayQuestText(questData.objectivesText)
    local hasObjectiveSteps = staticObjectives and #staticObjectives > 0
    if hasObjectiveText or hasObjectiveSteps then
        addVSpace(4)

        local objLabel = track(
            OneWoW_GUI:CreateFS(parent, 10)
        )

        objLabel:SetPoint(
            "TOPLEFT",
            parent,
            "TOPLEFT",
            PAD,
            yOffset
        )

        objLabel:SetText(L["QUESTS_OBJECTIVES"])

        objLabel:SetTextColor(
            OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
        )

        yOffset = yOffset - 16

        if hasObjectiveText then
            local objFs = track(
                OneWoW_GUI:CreateFS(parent, 12)
            )

            objFs:SetPoint(
                "TOPLEFT",
                parent,
                "TOPLEFT",
                PAD + 8,
                yOffset
            )

            objFs:SetPoint(
                "TOPRIGHT",
                parent,
                "TOPRIGHT",
                -PAD,
                yOffset
            )

            objFs:SetJustifyH("LEFT")
            objFs:SetWordWrap(true)

            objFs:SetText(
                FormatAndHighlightQuestText(questData.objectivesText)
            )

            objFs:SetWidth(W - 8)

            objFs:SetTextColor(
                OneWoW_GUI:GetThemeColor("TEXT_MUTED")
            )

            yOffset = yOffset - objFs:GetStringHeight() - 8
        end

        if hasObjectiveSteps then
            for index, objective in ipairs(staticObjectives) do
                local live = liveObjectives and liveObjectives[index]
                local stepText
                if live and live.text and live.text ~= "" then
                    stepText = live.text
                else
                    stepText = objective.text
                end
                if HasDisplayQuestText(stepText) then
                    local stepFs = track(OneWoW_GUI:CreateFS(parent, 12))
                    stepFs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
                    stepFs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)
                    stepFs:SetJustifyH("LEFT")
                    stepFs:SetWordWrap(true)
                    stepFs:SetWidth(W - 8)
                    stepFs:SetText(FormatAndHighlightQuestText(stepText))
                    stepFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    yOffset = yOffset - stepFs:GetStringHeight() - 6
                end
            end
        end
    end

    -- Rewards Section

    local hasRewards =
        (questData.rewardGold and questData.rewardGold > 0)
        or (questData.rewardXP and questData.rewardXP > 0)
        or (questData.rewardItems and #questData.rewardItems > 0)
        or (questData.rewardChoices and #questData.rewardChoices > 0)
        or (questData.rewardCurrencies and #questData.rewardCurrencies > 0)

    if hasRewards then

        addSep()

        local rwdLabel = track(
            OneWoW_GUI:CreateFS(parent, 10)
        )

        rwdLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
        rwdLabel:SetText(REWARDS)

        rwdLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        yOffset = yOffset - 18

        if questData.rewardGold and questData.rewardGold > 0 then
            local goldText = track(OneWoW_GUI:CreateFS(parent, 12))

            goldText:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
            goldText:SetText(L["QUESTS_GOLD"] .. ": " .. OneWoW.Format.FormatGold(questData.rewardGold))
            goldText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            yOffset = yOffset - 18
        end

        if questData.rewardXP and questData.rewardXP > 0 then
            local xpText = track(OneWoW_GUI:CreateFS(parent, 12))

            xpText:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
            xpText:SetText(L["QUESTS_XP"] .. ": " .. OneWoW.Format.FormatNumber(questData.rewardXP))
            xpText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            yOffset = yOffset - 18
        end

        if questData.rewardCurrencies and #questData.rewardCurrencies > 0 then
            local currHdr = track(OneWoW_GUI:CreateFS(parent, 10))

            currHdr:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
            currHdr:SetText(CURRENCY .. ":")

            currHdr:SetTextColor(
                OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
            )

            yOffset = yOffset - 18

            for _, rewardCurrency in ipairs(questData.rewardCurrencies) do
                local currencyID, quantity, iconTexture, currencyName =
                    GetCurrencyRewardInfo(rewardCurrency)

                if currencyID then
                    local currencyFrame = track(CreateFrame("Button", nil, parent))
                    currencyFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 16, yOffset)
                    currencyFrame:SetSize(W - 24, 18)

                    local icon = currencyFrame:CreateTexture(nil, "ARTWORK")
                    icon:SetSize(14, 14)
                    icon:SetPoint("LEFT", currencyFrame, "LEFT", 0, 0)
                    icon:SetTexture(iconTexture)

                    local currencyText = OneWoW_GUI:CreateFS(currencyFrame, 12)
                    currencyText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
                    currencyText:SetPoint("RIGHT", currencyFrame, "RIGHT", -2, 0)
                    currencyText:SetJustifyH("LEFT")
                    currencyText:SetWordWrap(false)
                    currencyText:SetText(
                        currencyName
                        .. (
                            quantity and quantity > 1
                            and (" x" .. tostring(quantity))
                            or ""
                        )
                    )
                    currencyText:SetTextColor(
                        OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
                    )

                    currencyFrame:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

                        GameTooltip:SetCurrencyByID(currencyID, quantity)

                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("Currency ID: " .. tostring(currencyID), 0.6, 0.6, 0.6)
                        GameTooltip:Show()
                    end)

                    currencyFrame:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)

                    yOffset = yOffset - 20
                end
            end
        end

        local function addRewardItemGrid(items, headerText)
            if not items or #items == 0 then
                return
            end

            local itemHdr = track(OneWoW_GUI:CreateFS(parent, 10))

            itemHdr:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)

            itemHdr:SetText(headerText)

            itemHdr:SetTextColor(
                OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
            )

            yOffset = yOffset - 18

            local gridGap = 8
            local rowHeight = 22
            local gridWidth = W - 16
            local itemColumns = math.max(1, math.min(5, math.floor((gridWidth + gridGap) / 190)))
            local itemColumnWidth = math.floor((gridWidth - (gridGap * (itemColumns - 1))) / itemColumns)
            local rewardItemEntries = {}

            for _, rewardItem in ipairs(items) do
                local itemID
                local itemCount = 1

                if type(rewardItem) == "number" then
                    itemID = rewardItem
                elseif type(rewardItem) == "table" then
                    itemID = rewardItem.itemID
                    itemCount = rewardItem.count or 1
                end

                if itemID then
                    table.insert(rewardItemEntries, {
                        itemID = itemID,
                        itemCount = itemCount,
                    })
                end
            end

            local function renderRewardItem(entry, itemIndex)
                local itemID = entry.itemID
                local itemCount = entry.itemCount or 1

                if itemID then
                    local cachedName = addon.GetCachedItemName(itemID)
                    local itemName =
                        cachedName
                        or string.format(L["QUESTS_ITEM_UNNAMED"], itemID)
                    local itemNameUnresolved = not cachedName
                    local itemLink
                    local itemQuality
                    local itemTexture =
                        select(5, C_Item.GetItemInfoInstant(itemID))
                        or 134400

                    local itemFrame = track(
                        CreateFrame("Button", nil, parent)
                    )

                    local columnIndex = ((itemIndex - 1) % itemColumns)
                    local rowIndex = math.floor((itemIndex - 1) / itemColumns)
                    local itemX = PAD + 16 + (columnIndex * (itemColumnWidth + gridGap))
                    local itemY = yOffset - (rowIndex * rowHeight)

                    itemFrame:SetPoint(
                        "TOPLEFT",
                        parent,
                        "TOPLEFT",
                        itemX,
                        itemY
                    )

                    itemFrame:SetSize(itemColumnWidth, 18)

                    local icon = itemFrame:CreateTexture(
                        nil,
                        "ARTWORK"
                    )

                    icon:SetSize(14, 14)
                    icon:SetPoint("LEFT", itemFrame, "LEFT", 0, 0)
                    icon:SetTexture(itemTexture)

                    local itemText = OneWoW_GUI:CreateFS(
                        itemFrame,
                        12
                    )

                    itemText:SetPoint(
                        "LEFT",
                        icon,
                        "RIGHT",
                        6,
                        0
                    )

                    itemText:SetPoint(
                        "RIGHT",
                        itemFrame,
                        "RIGHT",
                        -2,
                        0
                    )

                    itemText:SetJustifyH("LEFT")
                    itemText:SetWordWrap(false)

                    local countStr =
                        (itemCount and itemCount > 1)
                        and (" x" .. itemCount)
                        or ""

                    itemText:SetText(HighlightSearchText(itemName) .. countStr)
                    itemText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

                    local function paintRewardName(resolvedName, quality, iconFile)
                        if resolvedName and resolvedName ~= "" then
                            itemName = resolvedName
                            itemNameUnresolved = false
                            itemText:SetText(HighlightSearchText(itemName) .. countStr)
                        end
                        if quality ~= nil then
                            itemQuality = quality
                            itemText:SetTextColor(OneWoW_GUI:GetItemQualityColor(quality))
                        end
                        if iconFile then
                            itemTexture = iconFile
                            icon:SetTexture(iconFile)
                        end
                    end

                    if itemNameUnresolved then
                        visibleRewardItemRows[itemID] = visibleRewardItemRows[itemID] or {}
                        table.insert(visibleRewardItemRows[itemID], {
                            renderVersion = detailRenderVersion,
                            apply = function(resolvedName)
                                paintRewardName(resolvedName, nil, nil)
                            end,
                        })
                    end

                    local loader = ns.GetItemDataLoader()
                    ns.FillVisibleItem(itemFrame, itemID, {
                        getCached = function(id)
                            return loader:GetCachedItem(id)
                        end,
                        load = function(id, cb)
                            loader:LoadItemData(id, cb)
                        end,
                        apply = function(result, paintWidgets)
                            if result.name then
                                RememberRewardItemName(itemID, result.name)
                            end
                            if result.link then
                                itemLink = result.link
                            end
                            if not paintWidgets then
                                return
                            end
                            paintRewardName(result.name, result.quality, result.icon)
                        end,
                    })

                    itemFrame:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(
                            self,
                            "ANCHOR_RIGHT"
                        )

                        GameTooltip:SetItemByID(itemID)

                        local tooltipName =
                            GetVisibleTooltipItemName()
                            or ns.GetItemDataLoader():GetTooltipItemName(itemID)

                        if tooltipName
                            and tooltipName ~= itemName
                            and RememberAndApplyRewardItemName(itemID, tooltipName)
                        then
                            itemName = tooltipName
                            itemText:SetText(HighlightSearchText(itemName) .. countStr)
                        end

                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(L["QUESTS_TT_ITEM_OPEN_SEARCH"], 0, 1, 0)
                        GameTooltip:AddLine(L["QUESTS_TT_ITEM_PREVIEW"], 0, 1, 0)
                        GameTooltip:AddLine(L["QUESTS_TT_ITEM_ADD_NOTES"], 0, 1, 0)
                        GameTooltip:Show()
                    end)

                    itemFrame:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)

                    itemFrame:SetScript("OnClick", function()
                        if HandleItemPreviewClick(itemID, itemLink) then
                            return
                        end

                        -- Pass nil rather than the localized "Item #N"
                        -- placeholder when the real name never resolved.
                        local resolvedName = not itemNameUnresolved and itemName or nil

                        if IsShiftKeyDown and IsShiftKeyDown() then
                            AddRewardItemToNotes(
                                itemID,
                                resolvedName,
                                itemLink,
                                itemTexture,
                                itemQuality
                            )
                            return
                        end

                        OpenRewardItemInItemSearch(itemID, resolvedName)
                    end)
                end
            end

            for itemIndex = 1, #rewardItemEntries do
                renderRewardItem(rewardItemEntries[itemIndex], itemIndex)
            end

            local itemIndex = #rewardItemEntries

            if itemIndex > 0 then
                yOffset = yOffset - (math.ceil(itemIndex / itemColumns) * rowHeight)
            end
        end

        addRewardItemGrid(questData.rewardItems, ITEMS .. ":")
        addRewardItemGrid(questData.rewardChoices, REWARD_CHOOSE)

        addVSpace(4)
    end

    addSep()

    local compLabel = track(OneWoW_GUI:CreateFS(parent, 10))

    compLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
    compLabel:SetText(L["QUESTS_COMPLETION"])

    compLabel:SetTextColor(
        OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
    )

    yOffset = yOffset - 18

    local completedChars =
        tracker and tracker.GetCompletedCharacters(questData.id)
        or {}

    if #completedChars == 0 then
        local noCharText = track(OneWoW_GUI:CreateFS(parent, 12))

        noCharText:SetPoint(
            "TOPLEFT",
            parent,
            "TOPLEFT",
            PAD + 8,
            yOffset
        )

        if C_QuestLog.IsQuestFlaggedCompletedOnAccount(questData.id) then
            noCharText:SetText(L["QUESTS_ACCOUNT_COMPLETED_NO_ALTS"])
        else
            noCharText:SetText(L["QUESTS_NOT_COMPLETED"])
        end

        noCharText:SetTextColor(
            OneWoW_GUI:GetThemeColor("TEXT_MUTED")
        )

        yOffset = yOffset - 18
    else
        for _, charInfo in ipairs(completedChars) do
            local rowFrame = track(CreateFrame("Frame", nil, parent))

            rowFrame:SetHeight(18)

            rowFrame:SetPoint(
                "TOPLEFT",
                parent,
                "TOPLEFT",
                PAD + 8,
                yOffset
            )

            rowFrame:SetPoint(
                "TOPRIGHT",
                parent,
                "TOPRIGHT",
                -PAD,
                yOffset
            )

            local checkTex = rowFrame:CreateTexture(nil, "ARTWORK")

            checkTex:SetSize(14, 14)
            checkTex:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)

            checkTex:SetTexture(
                "Interface\\Buttons\\UI-CheckBox-Check"
            )

            checkTex:SetVertexColor(
                OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED")
            )

            local charText = OneWoW_GUI:CreateFS(rowFrame, 12)

            charText:SetPoint("LEFT", checkTex, "RIGHT", 4, 0)
            charText:SetText(charInfo.name)

            charText:SetTextColor(
                OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED")
            )

            yOffset = yOffset - 20
        end
    end

    addVSpace(4)

    addSep()

    local activeLabel = track(OneWoW_GUI:CreateFS(parent, 10))
    activeLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
    activeLabel:SetText(L["QUESTS_ACTIVE_ON"])
    activeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    yOffset = yOffset - 18

    local activeCharacters =
        tracker and tracker.GetActiveCharacters(questData.id)
        or {}

    if #activeCharacters == 0 then
        local noActiveText = track(OneWoW_GUI:CreateFS(parent, 12))
        noActiveText:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
        noActiveText:SetText(L["QUESTS_NOT_ACTIVE"])
        noActiveText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        yOffset = yOffset - 18
    else
        for _, characterInfo in ipairs(activeCharacters) do
            local rowFrame = track(OneWoW_GUI:CreateLayoutFrame(parent, {
                height = 18,
            }))
            rowFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
            rowFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)

            local activeTexture = rowFrame:CreateTexture(nil, "ARTWORK")
            activeTexture:SetSize(14, 14)
            activeTexture:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)
            activeTexture:SetTexture(QUEST_STATUS_TEXTURE_CHECK)
            activeTexture:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))

            local characterText = OneWoW_GUI:CreateFS(rowFrame, 12)
            characterText:SetPoint("LEFT", activeTexture, "RIGHT", 4, 0)
            characterText:SetText(characterInfo.name)
            characterText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))

            yOffset = yOffset - 20
        end
    end

    addVSpace(4)

    local chainIDs = GetQuestChainIDs(questData)
    if questLineText or campaignText or chainIDs then
        addSep()

        if questLineText then
            addWrappedText(L["QUESTS_QUEST_LINES"] .. ": " .. questLineText, 11)
        end

        if campaignText then
            addWrappedText(L["QUESTS_CAMPAIGNS"] .. ": " .. campaignText, 11)
        end
    end

    if chainIDs then
        local chainLabel = track(OneWoW_GUI:CreateFS(parent, 10))
        chainLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
        chainLabel:SetText(L["QUESTS_CHAIN"])
        chainLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        yOffset = yOffset - 20

        local currentQuestID = tonumber(questData.id)
        local chainRowWidth = W - 8

        local function chainRowColor(isCurrent, isHover)
            if isCurrent then
                return OneWoW_GUI:GetThemeColor("TEXT_WARNING")
            end
            if isHover then
                return OneWoW_GUI:GetThemeColor("LINK_HOVER")
            end
            return OneWoW_GUI:GetThemeColor("LINK_IDLE")
        end

        local function getChainName(chainQuestID)
            local chainQuest =
                addon.GetQuest(chainQuestID)

            if chainQuest and chainQuest.name and chainQuest.name ~= "" then
                return chainQuest.name
            end
            return GetQuestDisplayName(chainQuestID, questData)
        end

        local function groupContainsCurrent(ids)
            for i = 1, #ids do
                if tonumber(ids[i]) == currentQuestID then
                    return true
                end
            end
            return false
        end

        local segments = {}
        local index = 1
        while index <= #chainIDs do
            local chainQuestID = chainIDs[index]
            local chainName = getChainName(chainQuestID)
            local run = { chainQuestID }
            local nextIndex = index + 1

            while nextIndex <= #chainIDs
                and getChainName(chainIDs[nextIndex]) == chainName
            do
                table.insert(run, chainIDs[nextIndex])
                nextIndex = nextIndex + 1
            end

            if #run >= 3 then
                table.insert(segments, {
                    type = "group",
                    name = chainName,
                    ids = run,
                    key = tostring(questData.id or 0) .. ":" .. tostring(index) .. ":" .. chainName,
                })
            else
                for _, runQuestID in ipairs(run) do
                    table.insert(segments, {
                        type = "quest",
                        id = runQuestID,
                        name = getChainName(runQuestID),
                    })
                end
            end

            index = nextIndex
        end

        local function addChainRow(label, isCurrent, chainQuestID, namePrefix, onClick, onEnter, indent)
            indent = indent or 8
            local questBtn = track(CreateFrame("Button", nil, parent))
            questBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + indent, yOffset)
            questBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)

            local questText = OneWoW_GUI:CreateFS(questBtn, 12)
            questText:SetPoint("TOPLEFT", questBtn, "TOPLEFT", 0, 0)
            questText:SetPoint("TOPRIGHT", questBtn, "TOPRIGHT", 0, 0)
            questText:SetJustifyH("LEFT")
            questText:SetWordWrap(true)
            questText:SetWidth(chainRowWidth - indent + 8)
            questText:SetText(HighlightSearchText(label))
            questText:SetTextColor(chainRowColor(isCurrent, false))
            RegisterVisibleQuestName(chainQuestID, questText, namePrefix, nil, HighlightSearchText)
            RequestVisibleChainQuestName(chainQuestID)

            local rowHeight = math.max(18, (questText:GetStringHeight() or 12) + 2)
            questBtn:SetHeight(rowHeight)

            if onClick then
                questBtn:SetScript("OnClick", onClick)
            end
            questBtn:SetScript("OnEnter", function(self)
                questText:SetTextColor(chainRowColor(isCurrent, true))
                if onEnter then
                    onEnter(self)
                end
            end)
            questBtn:SetScript("OnLeave", function()
                questText:SetTextColor(chainRowColor(isCurrent, false))
                GameTooltip:Hide()
            end)

            yOffset = yOffset - rowHeight - 2
        end

        for segmentIndex, segment in ipairs(segments) do
            local stepPrefix = tostring(segmentIndex) .. ". "
            if segment.type == "group" then
                local isCurrent = groupContainsCurrent(segment.ids)
                local groupText = segment.name .. " x" .. tostring(#segment.ids)
                addChainRow(
                    stepPrefix .. groupText,
                    isCurrent,
                    nil,
                    stepPrefix,
                    function()
                        questChainGroupExpanded[segment.key] =
                            not questChainGroupExpanded[segment.key]
                        ShowQuestDetail(panels, questData)
                    end,
                    function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(groupText, 1, 0.82, 0)
                        GameTooltip:AddLine(tostring(#segment.ids) .. " quests grouped by shared name", 0.6, 0.6, 0.6)
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(
                            questChainGroupExpanded[segment.key] and "Click to collapse" or "Click to expand",
                            0,
                            1,
                            0
                        )
                        GameTooltip:Show()
                    end
                )
            else
                local isCurrent = tonumber(segment.id) == currentQuestID
                addChainRow(
                    stepPrefix .. segment.name,
                    isCurrent,
                    segment.id,
                    stepPrefix,
                    isCurrent and nil or function()
                        if OpenQuestByID then
                            OpenQuestByID(segment.id, panels)
                        end
                    end,
                    function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(segment.name, 1, 0.82, 0)
                        GameTooltip:AddLine("Quest ID: " .. tostring(segment.id), 0.6, 0.6, 0.6)
                        if not isCurrent then
                            GameTooltip:AddLine(" ")
                            GameTooltip:AddLine("Click to open this quest", 0, 1, 0)
                        end
                        GameTooltip:Show()
                    end
                )
            end
        end

        yOffset = yOffset - 2

        for _, segment in ipairs(segments) do
            if segment.type == "group" and questChainGroupExpanded[segment.key] then
                local groupLabel = track(OneWoW_GUI:CreateFS(parent, 10))
                groupLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 16, yOffset)
                groupLabel:SetText(HighlightSearchText(segment.name) .. " (" .. tostring(#segment.ids) .. ")")
                groupLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                yOffset = yOffset - 18

                for _, groupQuestID in ipairs(segment.ids) do
                    local groupQuestName = getChainName(groupQuestID)
                    local isCurrent = tonumber(groupQuestID) == currentQuestID
                    local childPrefix = tostring(groupQuestID) .. " - "
                    addChainRow(
                        childPrefix .. groupQuestName,
                        isCurrent,
                        groupQuestID,
                        childPrefix,
                        isCurrent and nil or function()
                            if OpenQuestByID then
                                OpenQuestByID(groupQuestID, panels)
                            end
                        end,
                        function(self)
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:AddLine(groupQuestName, 1, 0.82, 0)
                            GameTooltip:AddLine("Quest ID: " .. tostring(groupQuestID), 0.6, 0.6, 0.6)
                            if not isCurrent then
                                GameTooltip:AddLine(" ")
                                GameTooltip:AddLine("Click to open this quest", 0, 1, 0)
                            end
                            GameTooltip:Show()
                        end,
                        24
                    )
                end

                yOffset = yOffset - 4
            end
        end
    end

    panels.detailScrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- Journal / Vendors card fill + border. Selection is chrome only; title color
-- stays type-based (group gold, otherwise primary).
local function ApplyQuestRowChrome(row, selected, hover)
    ns.CardChrome.ApplyRowChrome(row, {
        selected = selected,
        hover = hover,
        borderKey = row._borderKey,
        fillTheme = row._chromeFill,
    })
end

local function UpdateQuestListEntry(btn, entry, state)
    local addon   = GetDataAddon()
    if not addon then return end
    local tracker = addon

    local quest = entry and entry.quest or entry

    btn.entry = entry
    btn.quest = quest
    btn.isGroup = entry and entry.type == "group"
    btn.isChild = entry and entry.type == "child"
    btn.isSection = entry and entry.type == "section"
    btn._rowSelected = state and state.selected and true or false

    if btn.isSection then
        if btn.groupToggle then btn.groupToggle:Hide() end
        if btn.statusIcons then
            for _, tex in ipairs(btn.statusIcons) do tex:Hide() end
        end
        if btn.checkHit then btn.checkHit:Hide() end
        if btn.favBtn then btn.favBtn:Hide() end
        if btn.subText then btn.subText:SetText("") end
        HideQuestListCategoryTags(btn)

        if btn.nameText then
            btn.nameText:ClearAllPoints()
            btn.nameText:SetPoint("LEFT", btn, "LEFT", 8, 0)
            btn.nameText:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
            btn.nameText:SetText(entry.label or L["QUESTS_DATA_FAVORITES"])
            btn.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        end

        ns.CardChrome.ApplyBackground(btn.bgTex, nil)
        btn._borderKey = "default"
        btn._chromeFill = "QUEST_ROW_SECTION"
        ApplyQuestRowChrome(btn, false, false)
        return
    end

    if btn.groupToggle then
        if btn.isGroup then
            if btn.groupToggleText then
                btn.groupToggleText:SetText(questListGroupExpanded[entry.key] and "v" or ">")
            end
            btn.groupToggle:Show()
        else
            btn.groupToggle:Hide()
        end
    end

    local statusFlags
    if btn.isGroup then
        local groupStatus = questGroupStatusCache[entry.key]
        if not groupStatus then
            groupStatus = { flags = ResolveGroupStatusFlags(entry.quests, tracker) }
            questGroupStatusCache[entry.key] = groupStatus
        end
        statusFlags = groupStatus.flags
    elseif quest and quest.id then
        local rowStatus = questRowStatusCache[quest.id]
        if not rowStatus then
            rowStatus = {
                flags = ResolveQuestStatusFlags(quest.id, tracker),
                isFavorite =
                    ns.Favorites
                    and ns.Favorites:IsFavorite("quests", quest.id),
            }
            questRowStatusCache[quest.id] = rowStatus
        end
        statusFlags = rowStatus.flags
    end
    statusFlags = statusFlags or { pending = true }

    local leftPad = btn.isChild and 28 or 8
    local rightGutter = -QUEST_LIST_RIGHT_GUTTER

    if btn.nameText then
        local nameText =
            btn.isGroup
            and ((entry.name or "Grouped Quests") .. " x" .. tostring(entry.count or 0))
            or (
                quest.name
                or string.format(L["QUESTS_UNNAMED"], quest.id or 0)
            )

        btn.nameText:ClearAllPoints()
        btn.nameText:SetPoint("TOPLEFT", btn, "TOPLEFT", leftPad, -6)
        btn.nameText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", rightGutter, -6)
        btn.nameText:SetText(nameText)
        if not btn.isGroup and quest and quest.id and (not quest.name or quest.name == "") then
            local liveName = addon.GetQuestName and addon.GetQuestName(quest.id)
            if liveName and liveName ~= "" then
                quest.name = liveName
                btn.nameText:SetText(liveName)
            else
                addon.RequestQuestName(quest.id, function(id, name)
                    if not name or name == "" then
                        return
                    end
                    if btn.quest and btn.quest.id == id then
                        btn.quest.name = name
                        if btn.nameText then
                            btn.nameText:SetText(name)
                        end
                    end
                    local stored = addon.GetQuest(id)
                    if stored then
                        stored.name = name
                    end
                end)
            end
        end

        if btn.isGroup then
            btn.nameText:SetTextColor(unpack(WOW_QUEST_GOLD))
        else
            btn.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end

    local expName = ""
    if btn.isGroup and entry.expansionName then
        expName = entry.expansionName
    elseif quest and quest.expansion ~= nil then
        expName = addon.GetExpansionName(quest.expansion) or ""
    end

    if btn.subText then
        btn.subText:ClearAllPoints()
        btn.subText:SetPoint("TOPLEFT", btn.nameText, "BOTTOMLEFT", 0, -2)
        btn.subText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", rightGutter, 0)
        btn.subText:SetText(FormatQuestListMetaLine(quest, expName))
    end

    if btn.isGroup then
        HideQuestListCategoryTags(btn)
    else
        BindQuestListCategoryTags(btn, quest)
    end

    local statusCount = ApplyQuestListStatusIcons(btn, statusFlags) or 0

    if btn.checkHit then
        btn.checkHit:ClearAllPoints()
        btn.checkHit:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -4, QUEST_STATUS_BOTTOM - 2)
        btn.checkHit:SetSize(
            math.max(statusCount, 1) * QUEST_STATUS_ICON_SLOT + 8,
            QUEST_STATUS_ICON_DISPLAY + 8
        )
        btn.checkHit:Show()
    end

    if btn.favBtn and ns.Favorites then
        if btn.isGroup then
            btn.favBtn:Hide()
        else
            btn.favBtn:Show()
            local rowStatus =
                quest
                and quest.id
                and questRowStatusCache[quest.id]
            btn.favBtn:SetFavorite(rowStatus and rowStatus.isFavorite)
        end
    end

    local expLevel = quest and quest.expansion
    ns.CardChrome.ApplyBackground(
        btn.bgTex,
        ns.CardChrome.ResolveExpansionBackground(expLevel, "level")
    )
    btn._borderKey = ns.CardChrome.QuestBorderKey(quest)
    if btn.isChild then
        btn._chromeFill = "QUEST_ROW_CHILD"
    else
        btn._chromeFill = nil
    end
    ApplyQuestRowChrome(btn, btn._rowSelected, false)
end

local function GetQuestListGroupName(quest)
    return quest
        and (
            quest.name
            or string.format(L["QUESTS_UNNAMED"], quest.id or 0)
        )
        or ""
end

local function GetQuestListGroupKey(quest)
    return table.concat({
        GetQuestListGroupName(quest),
        tostring(quest and quest.expansion or ""),
    }, "\031")
end

local function BuildQuestListEntries(quests)
    local addon = GetDataAddon()
    local entries = {}
    local index = 1

    while index <= #quests do
        local quest = quests[index]
        local groupKey = GetQuestListGroupKey(quest)
        local groupName = GetQuestListGroupName(quest)
        local groupQuests = { quest }
        local nextIndex = index + 1

        while nextIndex <= #quests
            and GetQuestListGroupKey(quests[nextIndex]) == groupKey
        do
            table.insert(groupQuests, quests[nextIndex])
            nextIndex = nextIndex + 1
        end

        if #groupQuests >= 3 then
            local expansionName = ""
            if addon and quest.expansion ~= nil then
                expansionName = addon.GetExpansionName(quest.expansion) or ""
            end

            table.insert(entries, {
                type = "group",
                key = groupKey,
                name = groupName,
                expansionName = expansionName,
                count = #groupQuests,
                quests = groupQuests,
                quest = groupQuests[1],
            })

            if questListGroupExpanded[groupKey] then
                for _, childQuest in ipairs(groupQuests) do
                    table.insert(entries, {
                        type = "child",
                        key = groupKey .. ":" .. tostring(childQuest.id),
                        parentKey = groupKey,
                        quest = childQuest,
                    })
                end
            end
        else
            for _, runQuest in ipairs(groupQuests) do
                table.insert(entries, {
                    type = "quest",
                    quest = runQuest,
                })
            end
        end

        index = nextIndex
    end

    return entries
end

local function BuildPlainQuestListEntries(quests)
    local entries = {}
    for i = 1, #(quests or {}) do
        local quest = quests[i]
        if quest then
            table.insert(entries, {
                type = "quest",
                quest = quest,
            })
        end
    end
    return entries
end

local function GetFavoriteQuestsOutsideActiveList(addon, activeQuests)
    if not (addon and ns.Favorites) then
        return {}
    end

    local activeIDs = {}
    for _, quest in ipairs(activeQuests or {}) do
        if quest and quest.id then
            activeIDs[quest.id] = true
        end
    end

    local favorites = {}
    local favBucket = ns.db.global.favorites.quests

    for questID in pairs(favBucket) do
        questID = tonumber(questID)
        local quest =
            questID
            and not activeIDs[questID]
            and addon.GetQuest(questID)

        if quest and quest.id then
            table.insert(favorites, quest)
        end
    end

    table.sort(favorites, function(a, b)
        local aName = a.name or ""
        local bName = b.name or ""
        if aName ~= bName then
            return aName < bName
        end
        return (a.id or 0) < (b.id or 0)
    end)

    return favorites
end

local function BuildQuestListDisplayEntries(quests, favoriteQuests)
    local entries = BuildQuestListEntries(quests or {})

    if favoriteQuests and #favoriteQuests > 0 then
        table.insert(entries, {
            type = "section",
            key = "favorites-section",
            label = L["QUESTS_DATA_FAVORITES"],
        })

        local favoriteEntries = BuildQuestListEntries(favoriteQuests)
        for _, entry in ipairs(favoriteEntries) do
            table.insert(entries, entry)
        end
    end

    return entries
end

local function QuestListEntryIsSelectable(entry)
    return entry and entry.type ~= "group" and entry.type ~= "section" and entry.quest
end

local function FindSelectableQuestListIndex(entries, questID)
    if not entries or not questID then
        return nil
    end
    for i, entry in ipairs(entries) do
        if QuestListEntryIsSelectable(entry) and entry.quest.id == questID then
            return i
        end
    end
    return nil
end

local function ToggleQuestListGroup(entry, api)
    local panels = ns.UI.questsPanels
    if not panels or not entry or entry.type ~= "group" or not api then
        return
    end

    panels._questKeyboardNavActive = true
    questListGroupExpanded[entry.key] = not questListGroupExpanded[entry.key]

    -- Rebuild after this click so the virtualizer select hook still sees the
    -- group at entryIndex and isSelectable can skip it.
    C_Timer.After(0, function()
        if ns.UI.questsPanels ~= panels then
            return
        end
        panels._questListEntries = BuildQuestListDisplayEntries(
            panels._questResults or {},
            panels._favoriteQuestResults or {}
        )
        if panels._questListWasCapped then
            ns.AppendCatalogListCapNotice(panels._questListEntries)
        end
        api.Refresh()
        if selectedQuest then
            local keepIndex = FindSelectableQuestListIndex(
                panels._questListEntries,
                selectedQuest.id
            )
            if keepIndex then
                api.SetSelectedIndex(keepIndex)
            end
        end
    end)
end

local function CreateQuestListRow(parent, api)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(QUEST_LIST_ROW_FRAME_HEIGHT)
    btn:SetClipsChildren(true)
    btn:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    ns.CardChrome.Attach(btn)
    btn._borderKey = "quest.standard"
    btn._chromeFill = nil
    btn._rowSelected = false
    ApplyQuestRowChrome(btn, false, false)

    local nameText = OneWoW_GUI:CreateFS(btn, 12)
    nameText:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, -6)
    nameText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -QUEST_LIST_RIGHT_GUTTER, -6)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    btn.nameText = nameText

    local subText = OneWoW_GUI:CreateFS(btn, 10)
    subText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
    subText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -QUEST_LIST_RIGHT_GUTTER, 0)
    subText:SetJustifyH("LEFT")
    subText:SetWordWrap(false)
    subText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    btn.subText = subText

    btn.catTexts = {}
    for i = 1, QUEST_CATEGORY_TAG_MAX do
        local catText = OneWoW_GUI:CreateFS(btn, 10)
        catText:Hide()
        btn.catTexts[i] = catText
    end

    btn.statusIcons = {}
    for i = 1, QUEST_STATUS_MAX_ICONS do
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:Hide()
        btn.statusIcons[i] = tex
    end

    local checkHit = OneWoW_GUI:CreateLayoutFrame(btn, {
        width = 28,
        height = 24,
    })
    checkHit:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -4, QUEST_STATUS_BOTTOM - 2)
    checkHit:EnableMouseMotion(true)
    checkHit:SetScript("OnEnter", function(self)
        ShowQuestStatusLegendTooltip(self)
    end)
    checkHit:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    checkHit:Hide()
    btn.checkHit = checkHit

    local groupToggle = CreateFrame("Button", nil, btn, "BackdropTemplate")
    groupToggle:SetSize(18, 18)
    groupToggle:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -4, -6)
    groupToggle:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    groupToggle:SetBackdropColor(OneWoW_GUI:GetThemeColor("QUEST_ROW_GROUP_TOGGLE"))
    groupToggle:SetBackdropBorderColor(unpack(WOW_QUEST_GOLD))

    local groupToggleText = OneWoW_GUI:CreateFS(groupToggle, 16)
    groupToggleText:SetAllPoints()
    groupToggleText:SetJustifyH("CENTER")
    groupToggleText:SetJustifyV("MIDDLE")
    groupToggleText:SetTextColor(unpack(WOW_QUEST_GOLD))

    groupToggle:SetScript("OnClick", function()
        ToggleQuestListGroup(btn.entry, api)
    end)
    groupToggle:Hide()
    btn.groupToggle = groupToggle
    btn.groupToggleText = groupToggleText

    if ns.Favorites then
        local favBtn = OneWoW_GUI:CreateFavoriteToggleButton(btn, {
            size = 18,
            favorite = false,
            tooltipTitle = L["CATALOG_FAVORITE"],
            tooltipText = L["CATALOG_FAVORITE_TT"],
            onClick = function(_, on)
                if not btn.quest then
                    return
                end
                ns.Favorites:SetFavorite("quests", btn.quest.id, on)
                local panels = ns.UI.questsPanels
                if panels then
                    RefreshQuestList(panels)
                end
            end,
        })
        favBtn:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -4, -6)
        btn.favBtn = favBtn
    end

    btn:SetScript("OnEnter", function(myself)
        ApplyQuestRowChrome(myself, myself._rowSelected, true)
    end)
    btn:SetScript("OnLeave", function(myself)
        ApplyQuestRowChrome(myself, myself._rowSelected, false)
    end)
    -- Groups expand here. Quest rows use the virtualizer selectOnClick hook.
    btn:SetScript("OnClick", function(myself)
        if myself.isGroup then
            ToggleQuestListGroup(myself.entry, api)
        end
    end)

    return btn
end

local function BindQuestListRow(row, index, entry, state)
    if ns.BindCatalogListCapRow(row, entry) then
        return
    end
    row._zebraIndex = index
    UpdateQuestListEntry(row, entry, state)
end

local function SelectQuestFromList(panels, quest, questIndex)
    if not panels or not quest then
        return
    end

    selectedQuest = quest
    if questListAPI and questIndex then
        questListAPI.SetSelectedIndex(questIndex)
        return
    end

    ShowQuestDetail(panels, quest)
    if questListAPI then
        questListAPI.Refresh()
    end
end

local function MoveQuestSelection(panels, delta)
    local entries = panels and (panels._questListEntries or panels._questResults)
    if not entries or #entries == 0 then
        return
    end

    local selectedID = selectedQuest and selectedQuest.id
    local selectedIndex = FindSelectableQuestListIndex(entries, selectedID)

    selectedIndex = selectedIndex or (delta > 0 and 0 or #entries + 1)

    local nextIndex = selectedIndex + delta
    while nextIndex >= 1 and nextIndex <= #entries do
        local entry = entries[nextIndex]
        if QuestListEntryIsSelectable(entry) then
            SelectQuestFromList(panels, entry.quest, nextIndex)
            return
        end

        nextIndex = nextIndex + delta
    end

    if nextIndex < 1 then
        for i = 1, #entries do
            local entry = entries[i]
            if QuestListEntryIsSelectable(entry) then
                SelectQuestFromList(panels, entry.quest, i)
                return
            end
        end
    elseif nextIndex > #entries then
        for i = #entries, 1, -1 do
            local entry = entries[i]
            if QuestListEntryIsSelectable(entry) then
                SelectQuestFromList(panels, entry.quest, i)
                return
            end
        end
    end
end

local function CopyQuestResultArray(source)
    local copy = {}
    for i = 1, #(source or {}) do
        copy[i] = source[i]
    end
    return copy
end

local function NeedsCompletionFilter()
    return completionFilter ~= "all" and not IsActiveFilterMode()
end

local function QuestMatchesCompletion(quest)
    if not quest or not quest.id then
        return false
    end
    if completionFilter == "completed" then
        return C_QuestLog.IsQuestFlaggedCompleted(quest.id)
    end
    if completionFilter == "not_completed" then
        return not C_QuestLog.IsQuestFlaggedCompleted(quest.id)
    end
    if completionFilter == "warband" then
        return C_QuestLog.IsQuestFlaggedCompletedOnAccount(quest.id)
    end
    return true
end

local function ApplyPostQueryQuestFilters(quests, databaseMode, skipCompletion)
    if not skipCompletion and NeedsCompletionFilter() then
        local filtered = {}
        for _, quest in ipairs(quests) do
            if QuestMatchesCompletion(quest) then
                table.insert(filtered, quest)
            end
        end
        quests = filtered
    end

    if runtimeFilter == "favorite" and ns.Favorites then
        local filtered = {}
        for _, quest in ipairs(quests) do
            if ns.Favorites:IsFavorite("quests", quest.id) then
                table.insert(filtered, quest)
            end
        end
        quests = filtered
    end

    if databaseMode and ns.Favorites and #quests > 0 then
        local origOrder = {}
        for i, q in ipairs(quests) do
            origOrder[q.id] = i
        end
        table.sort(quests, function(a, b)
            local fa = ns.Favorites:IsFavorite("quests", a.id)
            local fb = ns.Favorites:IsFavorite("quests", b.id)
            if fa ~= fb then return fa end
            return (origOrder[a.id] or 0) < (origOrder[b.id] or 0)
        end)
    end

    return quests
end

local function PublishQuestListResults(panels, addon, quests, favoriteQuests, previousScroll, loading, refreshDetail)
    favoriteQuests = favoriteQuests or {}

    if selectedQuest then
        local selectedQuestVisible = false

        for _, quest in ipairs(quests) do
            if quest.id == selectedQuest.id then
                selectedQuestVisible = true
                break
            end
        end

        if not selectedQuestVisible then
            for _, quest in ipairs(favoriteQuests) do
                if quest.id == selectedQuest.id then
                    selectedQuestVisible = true
                    break
                end
            end
        end

        if not selectedQuestVisible and not loading then
            selectedQuest = nil
            ClearDetailElements()

            if panels.emptyDetail then
                panels.emptyDetail:Show()
            end

            if panels.detailScrollChild then
                panels.detailScrollChild:SetHeight(100)
            end
        end
    end

    local matchTotal = #quests + #favoriteQuests
    local listCap = ns.GetCatalogListCap(HasQuestListFilters())
    local wasCapped = false
    quests, favoriteQuests, matchTotal, wasCapped = ns.CapCatalogListPair(
        quests,
        favoriteQuests,
        HasQuestListFilters()
    )

    if #quests == 0 and #favoriteQuests == 0 then
        panels._questResults = {}
        panels._favoriteQuestResults = {}
        panels._questListWasCapped = nil
        panels._questListEntries = {}
        if panels.emptyList then
            if loading then
                panels.emptyList:SetText(string.format(L["QUESTS_LOADING"], 0))
                panels.emptyList:Show()
            else
                panels.emptyList:SetText(
                    (addon.GetCapturedQuestCount() == 0)
                    and L["QUESTS_NONE_YET"]
                    or L["QUESTS_EMPTY"]
                )
                panels.emptyList:Show()
            end
        end
        if questListAPI then
            questListAPI.SetSelectedIndex(nil)
        else
            panels.listScrollChild:SetHeight(100)
        end
        if panels.leftStatusText then
            panels._questListCapTip = nil
            if loading then
                panels.leftStatusText:SetText(string.format(L["QUESTS_LOADING"], 0))
            else
                panels.leftStatusText:SetText(string.format(L["QUESTS_STATUS_COUNT"], 0))
            end
        end
        return
    end

    if panels.emptyList then
        panels.emptyList:Hide()
    end

    panels._questResults = quests
    panels._favoriteQuestResults = favoriteQuests
    panels._questListWasCapped = wasCapped
    panels._questListEntries = BuildQuestListDisplayEntries(quests, favoriteQuests)
    if wasCapped then
        ns.AppendCatalogListCapNotice(panels._questListEntries)
    end

    local keepIndex
    if selectedQuest then
        keepIndex = FindSelectableQuestListIndex(panels._questListEntries, selectedQuest.id)
    end

    local didSelect = false
    if questListAPI then
        if keepIndex then
            if questListAPI.GetSelectedIndex() == keepIndex then
                questListAPI.Refresh()
            else
                questListAPI.SetSelectedIndex(keepIndex)
                didSelect = true
            end
        else
            questListAPI.Refresh()
        end

        local sf = panels.listScrollFrame
        if sf and sf.SetVerticalScroll then
            local frameHeight = sf.GetHeight and sf:GetHeight() or 0
            local childHeight =
                panels.listScrollChild
                and panels.listScrollChild.GetHeight
                and panels.listScrollChild:GetHeight()
                or 0
            local maxScroll = math.max(0, childHeight - frameHeight)
            sf:SetVerticalScroll(math.max(0, math.min(previousScroll or 0, maxScroll)))
        end
    end

    if panels.leftStatusText then
        local n = #quests + #favoriteQuests
        if loading then
            panels._questListCapTip = nil
            panels.leftStatusText:SetText(string.format(L["QUESTS_LOADING"], n))
        elseif wasCapped then
            panels._questListCapTip = string.format(L["QUESTS_STATUS_CAPPED_TT"], listCap)
            panels.leftStatusText:SetText(
                string.format(L["QUESTS_STATUS_CAPPED"], n, matchTotal, listCap)
            )
        else
            panels._questListCapTip = nil
            panels.leftStatusText:SetText(string.format(L["QUESTS_STATUS_COUNT"], n))
        end
    end

    if selectedQuest and not loading and refreshDetail and not didSelect then
        ShowQuestDetail(panels, addon.GetQuest(selectedQuest.id))
    end
end

local function CancelCompletionFilter()
    if questCompletionJob then
        questCompletionJob:Cancel()
        questCompletionJob = nil
    end
end

local function QuestChainIDsEqual(a, b)
    if a == b then
        return true
    end
    if not a or not b or #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

local function ClearPinnedQuestChain()
    pinnedChainIDs = nil
end

local function InvalidateQuestListQuery(panels)
    local addon = GetDataAddon()
    if addon then
        addon.CancelSortedQuery()
    end
    CancelCompletionFilter()
    if panels then
        panels._questListGeneration = (panels._questListGeneration or 0) + 1
    end
end

local function BuildPinnedChainQuests(addon, chainIDs)
    local quests = {}
    for i = 1, #chainIDs do
        local quest = addon.GetQuest(chainIDs[i])
        if quest then
            table.insert(quests, quest)
        else
            local name = addon.GetQuestName and addon.GetQuestName(chainIDs[i]) or nil
            table.insert(quests, { id = chainIDs[i], name = name })
        end
    end
    return quests
end

local function PublishPinnedChainList(panels, addon, chainIDs)
    local quests = BuildPinnedChainQuests(addon, chainIDs)

    if panels.emptyList then
        panels.emptyList:Hide()
    end

    panels._questResults = quests
    panels._favoriteQuestResults = {}
    panels._questListEntries = BuildPlainQuestListEntries(quests)

    local keepIndex
    if selectedQuest then
        keepIndex = FindSelectableQuestListIndex(panels._questListEntries, selectedQuest.id)
    end

    local didSelect = false
    if questListAPI then
        if keepIndex then
            if questListAPI.GetSelectedIndex() == keepIndex then
                questListAPI.Refresh()
            else
                questListAPI.SetSelectedIndex(keepIndex)
                didSelect = true
            end
        else
            questListAPI.Refresh()
        end
    end

    if panels.leftStatusText then
        panels._questListCapTip = nil
        panels.leftStatusText:SetText(string.format(L["QUESTS_STATUS_CHAIN"], #quests))
    end

    if selectedQuest and not didSelect then
        ShowQuestDetail(panels, addon.GetQuest(selectedQuest.id) or selectedQuest)
    end
end

--- Pin the left list to this quest's chain. Returns true when the list was rebuilt.
---@param panels table
---@param quest table
---@return boolean
local function PinQuestChainIfNeeded(panels, quest)
    local addon = GetDataAddon()
    if not (panels and addon and quest) then
        return false
    end

    local chainIDs = addon.GetQuestGuideChain(quest)
    if not chainIDs then
        return false
    end
    if QuestChainIDsEqual(pinnedChainIDs, chainIDs) then
        return false
    end

    InvalidateQuestListQuery(panels)
    pinnedChainIDs = chainIDs
    PublishPinnedChainList(panels, addon, chainIDs)
    return true
end

local function RefreshQuestListFromFilters(panels, invalidateStatus)
    ClearPinnedQuestChain()
    RefreshQuestList(panels, invalidateStatus)
end

local function StartCompletionFilter(panels, addon, rawQuests, previousScroll, listGeneration, refreshDetail)
    local matches = {}

    if panels.emptyList then
        panels.emptyList:SetText(string.format(L["QUESTS_LOADING"], 0))
        panels.emptyList:Show()
    end

    questCompletionJob = OneWoW.ChunkedJob.Start({
        run = function(shouldYield)
            for i = 1, #rawQuests do
                if QuestMatchesCompletion(rawQuests[i]) then
                    matches[#matches + 1] = rawQuests[i]
                end
                OneWoW.ChunkedJob.YieldIfNeeded(shouldYield)
            end
        end,
        onProgress = function()
            if not panels or panels._questListGeneration ~= listGeneration then
                return
            end
            if panels.leftStatusText then
                panels.leftStatusText:SetText(
                    string.format(L["QUESTS_LOADING"], #matches)
                )
            end
        end,
        onComplete = function()
            questCompletionJob = nil
            if not panels or panels._questListGeneration ~= listGeneration then
                return
            end
            local quests = ApplyPostQueryQuestFilters(matches, true, true)
            PublishQuestListResults(
                panels,
                addon,
                quests,
                {},
                previousScroll,
                false,
                refreshDetail
            )
        end,
        onCancel = function()
            questCompletionJob = nil
        end,
    })
end

function RefreshQuestList(panels, invalidateStatus)
    ns.EnsureCatalogRoleShardsForFilter("quests", expansionFilter, function()
        RefreshQuestList(panels, invalidateStatus)
    end)

    local previousScroll = 0
    if panels
        and panels.listScrollFrame
        and panels.listScrollFrame.GetVerticalScroll
    then
        previousScroll = panels.listScrollFrame:GetVerticalScroll() or 0
    end

    if invalidateStatus then
        wipe(questRowStatusCache)
        wipe(questGroupStatusCache)
    end

    if pinnedChainIDs then
        local chainAddon = GetDataAddon()
        if chainAddon then
            PublishPinnedChainList(panels, chainAddon, pinnedChainIDs)
        end
        return
    end

    local addon = GetDataAddon()
    if addon then
        addon.CancelSortedQuery()
    end
    CancelCompletionFilter()

    panels._questListGeneration = (panels._questListGeneration or 0) + 1
    local listGeneration = panels._questListGeneration

    if not addon then
        panels._questResults = {}
        panels._favoriteQuestResults = {}
        panels._questListWasCapped = nil
        panels._questListEntries = {}
        if panels.emptyList then
            panels.emptyList:SetText(L["QUESTS_NO_DATA"])
            panels.emptyList:Show()
        end
        if questListAPI then
            questListAPI.SetSelectedIndex(nil)
        else
            panels.listScrollChild:SetHeight(100)
        end
        return
    end

    local databaseMode = IsDatabaseMode()
    local activeCurrentMode = IsActiveCurrentMode()
    local activeAllAltsMode = IsActiveAllAltsMode()

    if databaseMode then
        panels._questQueryResults = panels._questQueryResults or {}
        wipe(panels._questQueryResults)

        if panels.leftStatusText then
            panels.leftStatusText:SetText(string.format(L["QUESTS_LOADING"], 0))
        end
        if panels.emptyList then
            panels.emptyList:SetText(string.format(L["QUESTS_LOADING"], 0))
            panels.emptyList:Show()
        end
        if questListAPI then
            panels._questListEntries = {}
            questListAPI.SetSelectedIndex(nil)
        end

        addon.StartSortedQuests(
            expansionFilter,
            zoneFilter,
            "all",
            "all",
            searchText,
            BuildAdvancedFilters(),
            panels._questQueryResults,
            {
                onProgress = function()
                    if not panels or panels._questListGeneration ~= listGeneration then
                        return
                    end
                    -- Status only: regrouping/flatten on every slice is too costly.
                    if panels.leftStatusText then
                        panels.leftStatusText:SetText(
                            string.format(L["QUESTS_LOADING"], #panels._questQueryResults)
                        )
                    end
                end,
                onComplete = function(rawResults)
                    if not panels or panels._questListGeneration ~= listGeneration then
                        return
                    end
                    StartRewardItemSearchWarmup(panels, addon, #rawResults)
                    local rawCopy = CopyQuestResultArray(rawResults)
                    if NeedsCompletionFilter() then
                        StartCompletionFilter(
                            panels,
                            addon,
                            rawCopy,
                            previousScroll,
                            listGeneration,
                            invalidateStatus
                        )
                        return
                    end
                    local quests = ApplyPostQueryQuestFilters(rawCopy, true, true)
                    PublishQuestListResults(
                        panels,
                        addon,
                        quests,
                        {},
                        previousScroll,
                        false,
                        invalidateStatus
                    )
                end,
            }
        )
        return
    end

    local quests
    local favoriteQuests = {}

    if activeAllAltsMode then
        quests = GetAllCharactersActiveQuests(addon)
        favoriteQuests = {}
    elseif activeCurrentMode then
        quests = GetActiveQuestLogQuests(addon)
        favoriteQuests = {}
    else
        quests = GetActiveQuestLogQuests(addon)
        favoriteQuests = GetFavoriteQuestsOutsideActiveList(addon, quests)
    end

    quests = ApplyPostQueryQuestFilters(quests, false)
    PublishQuestListResults(
        panels,
        addon,
        quests,
        favoriteQuests,
        previousScroll,
        false,
        invalidateStatus
    )
end

function OpenQuestByID(questID, panels, fromArchive)
    questID = tonumber(questID)
    if not questID then return false end

    OneWoW.UI:Show("catalog")
    OneWoW.UI:SelectSubTab("catalog", "quests")
    OneWoW.UI:CommitNavEntity("quest", questID)

    panels = panels or ns.UI.questsPanels

    local addon = GetDataAddon()
    local quest =
        addon
        and addon.GetQuest(questID)

    if not quest then
        if fromArchive or not (addon and addon.EnsureArchiveThen) then
            return false
        end
        addon.EnsureArchiveThen(function()
            OpenQuestByID(questID, panels, true)
        end)
        return true
    end

    selectedQuest = quest

    if panels then
        local chainIDs = addon.GetQuestGuideChain(quest)
        if chainIDs then
            if not PinQuestChainIfNeeded(panels, quest) then
                local keepIndex = FindSelectableQuestListIndex(
                    panels._questListEntries,
                    quest.id
                )
                if keepIndex and questListAPI then
                    questListAPI.SetSelectedIndex(keepIndex)
                else
                    ShowQuestDetail(panels, quest)
                end
            end
            return true
        end

        searchText = "\"" .. tostring(questID) .. "\""
        expansionFilter = -1
        zoneFilter = ""
        ClearNpcFilter()
        completionFilter = "all"
        ResetAdvancedFilters()

        if panels.searchBox then
            panels.searchBox:SetText(searchText)
            panels.searchBox:ClearFocus()
        end

        if panels.expText then panels.expText:SetText(L["QUESTS_EXPANSION_ALL"]) end
        if panels.zoneText then panels.zoneText:SetText(L["QUESTS_ZONE_ALL"]) end
        if panels.progText then panels.progText:SetText(L["QUESTS_PROGRESS_ALL"]) end
        if panels.UpdateAdvancedTexts then panels.UpdateAdvancedTexts() end
        UpdateNpcFilterChip(panels)

        RefreshQuestListFromFilters(panels)
        ShowQuestDetail(panels, quest)
    end

    return true
end

ns.UI.OpenQuest = function(questID)
    return OpenQuestByID(questID, ns.UI.questsPanels)
end

--- Open Catalog Quests with zone and/or NPC filters applied.
---@param opts { zoneName?: string, npcID?: number, npcName?: string }
function ns.UI.OpenQuestsFiltered(opts)
    opts = opts or {}

    OneWoW.UI:Show("catalog")
    OneWoW.UI:SelectSubTab("catalog", "quests")

    local function applyFilters()
        local panels = ns.UI.questsPanels
        if not panels then
            return false
        end

        searchText = ""
        expansionFilter = -1
        completionFilter = "all"
        ResetAdvancedFilters()
        ClearNpcFilter()
        zoneFilter = ""

        if type(opts.zoneName) == "string" and opts.zoneName ~= "" then
            zoneFilter = opts.zoneName
        end

        local npcID = tonumber(opts.npcID)
        if npcID then
            npcFilter = npcID
            if type(opts.npcName) == "string" and opts.npcName ~= "" then
                npcFilterLabel = opts.npcName
            end
        end

        if panels.searchBox then
            panels.searchBox:SetText("")
            panels.searchBox:ClearFocus()
        end
        if panels.expText then panels.expText:SetText(L["QUESTS_EXPANSION_ALL"]) end
        if panels.zoneText then
            panels.zoneText:SetText(zoneFilter ~= "" and zoneFilter or L["QUESTS_ZONE_ALL"])
        end
        if panels.progText then panels.progText:SetText(L["QUESTS_PROGRESS_ALL"]) end
        if panels.UpdateAdvancedTexts then panels.UpdateAdvancedTexts() end
        UpdateNpcFilterChip(panels)
        RefreshQuestListFromFilters(panels)
        return true
    end

    if not applyFilters() then
        C_Timer.After(0.15, applyFilters)
        C_Timer.After(0.35, applyFilters)
    end
end

local PopulateZoneDropdown = function(panels)
    local addon = GetDataAddon()
    if not addon then return end

    OneWoW_GUI:AttachFilterMenu(panels.zoneDropdown, {
        searchable = true,
        getActiveValue = function() return zoneFilter end,
        buildItems = function()
            local zones = addon.GetAvailableZones(expansionFilter ~= -1 and expansionFilter or nil)
            local items = { { value = "", text = L["QUESTS_ZONE_ALL"] } }
            for _, zoneName in ipairs(zones) do
                table.insert(items, {
                    value   = zoneName,
                    text    = zoneName,
                })
            end
            return items
        end,
        onSelect = function(value, text)
            zoneFilter = value
            panels.zoneText:SetText(value == "" and L["QUESTS_ZONE_ALL"] or text)
            RefreshQuestListFromFilters(panels)
        end,
    })
end

local function PopulateExpansionDropdown(panels)
    local addon = GetDataAddon()
    if not addon then return end

    OneWoW_GUI:AttachFilterMenu(panels.expDropdown, {
        searchable = false,
        getActiveValue = function() return expansionFilter end,
        buildItems = function()
            local items = { { value = -1, text = L["QUESTS_EXPANSION_ALL"] } }
            local expansions = ns.GetWantedCatalogExpansions("quests", true)
            for _, exp in ipairs(expansions) do
                table.insert(items, {
                    value   = exp.id,
                    text    = exp.name,
                })
            end
            return items
        end,
        onSelect = function(value, text)
            expansionFilter = value
            panels.expText:SetText(value == -1 and L["QUESTS_EXPANSION_ALL"] or text)
            zoneFilter = ""
            panels.zoneText:SetText(L["QUESTS_ZONE_ALL"])
            PopulateZoneDropdown(panels)
            RefreshQuestListFromFilters(panels)
        end,
    })
end

local function SetupProgressDropdown(panels)
    OneWoW_GUI:AttachFilterMenu(panels.progDropdown, {
        searchable = false,
        getActiveValue = function() return completionFilter end,
        buildItems = function()
            return {
                { value = "all",           text = L["QUESTS_PROGRESS_ALL"]           },
                { value = "completed",     text = L["QUESTS_PROGRESS_COMPLETED"]     },
                { value = "not_completed", text = L["QUESTS_PROGRESS_NOT_COMPLETED"] },
                { value = "active_current", text = L["QUESTS_PROGRESS_ACTIVE_CURRENT"] },
                { value = "active_all",     text = L["QUESTS_PROGRESS_ACTIVE_ALL"]     },
                { value = "warband",          text = L["QUESTS_PROGRESS_WARBAND"]          },
            }
        end,
        onSelect = function(value, text)
            completionFilter = value
            panels.progText:SetText(value == "all" and L["QUESTS_PROGRESS_ALL"] or text)
            RefreshQuestListFromFilters(panels)
        end,
    })
end

local function GetAvailableFilterValues(fieldName)
    local addon = GetDataAddon()
    if not addon then return {} end

    local cacheKey =
        expansionFilter ~= -1
        and tostring(expansionFilter)
        or "all"

    if not availableFilterCache[cacheKey] then
        availableFilterCache[cacheKey] = {
            category = {},
            flag = {},
            profession = {},
            class = {},
            race = {},
            faction = {},
        }

        local function addValue(field, value)
            if value ~= nil and tostring(value) ~= "" then
                availableFilterCache[cacheKey][field][tostring(value)] = true
            end
        end

        local source = addon.GetQuestsForExpansion(expansionFilter)

        for _, quest in pairs(source) do
            for _, value in ipairs(quest.categories or {}) do
                addValue("category", value)
            end

            for _, value in ipairs(quest.flags or {}) do
                addValue("flag", value)
            end

            for _, value in ipairs(quest.requiredProfessions or {}) do
                addValue("profession", value)
            end

            for _, value in ipairs(quest.requiredClasses or {}) do
                addValue("class", value)
            end

            for _, value in ipairs(quest.requiredRaces or {}) do
                addValue("race", value)
            end

            addValue("faction", GetFactionFilterValue(quest.faction))
        end
    end

    local found = availableFilterCache[cacheKey][fieldName] or {}
    local results = {}
    for value in pairs(found) do
        table.insert(results, value)
    end

    table.sort(results)
    return results
end

local function CreateAdvancedDropdown(parent, label, defaultText)
    local labelText = OneWoW_GUI:CreateFS(parent, 10)
    labelText:SetText(label)
    labelText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local dropdown, text = OneWoW_GUI:CreateDropdown(parent, {
        width = 10,
        text = defaultText,
    })

    return {
        label = labelText,
        dropdown = dropdown,
        text = text,
    }
end

local function SetupSimpleAdvancedDropdown(def)
    OneWoW_GUI:AttachFilterMenu(def.dropdown, {
        searchable = def.searchable == true,
        getActiveValue = def.getValue,
        buildItems = def.buildItems,
        onSelect = function(value, text)
            def.setValue(value)
            def.text:SetText(value == "all" and def.allText or text)
            if def.panels.UpdateAdvancedTexts then
                def.panels.UpdateAdvancedTexts()
            end
            RefreshQuestListFromFilters(def.panels)
        end,
    })
end

local function SetupAdvancedDropdowns(panels)
    OneWoW_GUI:AttachFilterMenu(panels.advGroup.dropdown, {
        searchable = false,
        getActiveValue = function() return typeFilter end,
        buildItems = function()
            return {
                { value = "all",   text = L["QUESTS_TYPE_ALL"]   },
                { value = "solo",  text = SOLO  },
                { value = "group", text = GROUP },
                { value = "raid",  text = RAID  },
            }
        end,
        onSelect = function(value, text)
            typeFilter = value
            panels.advGroup.text:SetText(value == "all" and L["QUESTS_TYPE_ALL"] or text)
            panels.UpdateAdvancedTexts()
            RefreshQuestListFromFilters(panels)
        end,
    })

    OneWoW_GUI:AttachFilterMenu(panels.advQuestType.dropdown, {
        searchable = false,
        getActiveValue = function() return questTypeFilter end,
        buildItems = function()
            return {
                { value = "all",        text = L["QUESTS_QTYPE_ALL"]       },
                { value = "standard",   text = QUEST_TYPE_LABELS.standard   },
                { value = "world",      text = QUEST_TYPE_LABELS.world      },
                { value = "dungeon",    text = QUEST_TYPE_LABELS.dungeon    },
                { value = "raid",       text = QUEST_TYPE_LABELS.raid       },
                { value = "pvp",        text = QUEST_TYPE_LABELS.pvp        },
                { value = "profession", text = QUEST_TYPE_LABELS.profession },
                { value = "scenario",   text = QUEST_TYPE_LABELS.scenario   },
                { value = "group",      text = QUEST_TYPE_LABELS.group      },
            }
        end,
        onSelect = function(value, text)
            questTypeFilter = value
            panels.advQuestType.text:SetText(value == "all" and L["QUESTS_QTYPE_ALL"] or text)
            panels.UpdateAdvancedTexts()
            RefreshQuestListFromFilters(panels)
        end,
    })

    local dynamicDefs = {
        { frame = panels.advCategory,   field = "category",   allText = L["QUESTS_FILTER_CATEGORY_ALL"], get = function() return categoryFilter end,   set = function(v) categoryFilter = v end },
        { frame = panels.advFlag,       field = "flag",       allText = L["QUESTS_FILTER_TRAIT_ALL"],    get = function() return flagFilter end,       set = function(v) flagFilter = v end },
        { frame = panels.advProfession, field = "profession", allText = L["QUESTS_FILTER_PROFESSION_ALL"], get = function() return professionFilter end, set = function(v) professionFilter = v end },
        { frame = panels.advClass,      field = "class",      allText = L["QUESTS_FILTER_CLASS_ALL"],   get = function() return classFilter end,   set = function(v) classFilter = v end },
        { frame = panels.advRace,       field = "race",       allText = L["QUESTS_FILTER_RACE_ALL"],    get = function() return raceFilter end,    set = function(v) raceFilter = v end },
        { frame = panels.advFaction,    field = "faction",    allText = L["QUESTS_FILTER_FACTION_ALL"], get = function() return factionFilter end, set = function(v) factionFilter = v end },
    }

    for _, dynamic in ipairs(dynamicDefs) do
        local frame = dynamic.frame
        local field = dynamic.field
        local allText = dynamic.allText
        local getValue = dynamic.get
        local setValue = dynamic.set

        SetupSimpleAdvancedDropdown({
            panels = panels,
            dropdown = frame.dropdown,
            text = frame.text,
            allText = allText,
            searchable = true,
            getValue = getValue,
            setValue = setValue,
            buildItems = function()
                local items = { { value = "all", text = allText } }
                for _, value in ipairs(GetAvailableFilterValues(field)) do
                    table.insert(items, {
                        value = value,
                        text = GetAdvancedValueText(field, value) or value,
                    })
                end
                return items
            end,
        })
    end

    OneWoW_GUI:AttachFilterMenu(panels.advStory.dropdown, {
        searchable = false,
        getActiveValue = function() return storyFilter end,
        buildItems = function()
            return {
                { value = "all",        text = L["QUESTS_FILTER_STORY_ALL"] },
                { value = "campaign",   text = L["CAMPAIGN"] },
                { value = "storyline",  text = L["QUESTS_STORY_QUESTLINE"] },
                { value = "chain",      text = L["QUESTS_STORY_CHAIN"] },
                { value = "standalone", text = L["QUESTS_STORY_STANDALONE"] },
            }
        end,
        onSelect = function(value, text)
            storyFilter = value
            panels.advStory.text:SetText(value == "all" and L["QUESTS_FILTER_STORY_ALL"] or text)
            panels.UpdateAdvancedTexts()
            RefreshQuestListFromFilters(panels)
        end,
    })

    OneWoW_GUI:AttachFilterMenu(panels.advRuntime.dropdown, {
        searchable = false,
        getActiveValue = function() return runtimeFilter end,
        buildItems = function()
            return {
                { value = "all",              text = L["QUESTS_FILTER_DATA_ALL"] },
                { value = "favorite",           text = L["QUESTS_DATA_FAVORITES"] },
                { value = "has_location",       text = L["QUESTS_DATA_HAS_LOCATION"] },
                { value = "missing_location",   text = L["QUESTS_DATA_MISSING_LOCATION"] },
                { value = "has_quest_giver",    text = L["QUESTS_DATA_HAS_GIVER"] },
                { value = "has_turnin",         text = L["QUESTS_DATA_HAS_TURNIN"] },
                { value = "has_rewards",        text = L["QUESTS_DATA_HAS_REWARDS"] },
                { value = "has_reward_choices", text = L["QUESTS_DATA_HAS_REWARD_CHOICES"] },
            }
        end,
        onSelect = function(value, text)
            runtimeFilter = value
            panels.advRuntime.text:SetText(value == "all" and L["QUESTS_FILTER_DATA_ALL"] or text)
            panels.UpdateAdvancedTexts()
            RefreshQuestListFromFilters(panels)
        end,
    })
end

-- Navigates the Catalog to the quests tab and opens the given quest's detail.
-- Used by Item Search's quest-reward cross-references.
function ns.UI.OpenToQuest(questID)
    questID = tonumber(questID)
    if not questID then return end

    OneWoW.UI:Show("catalog")
    OneWoW.UI:SelectSubTab("catalog", "quests")
    OneWoW.UI:CommitNavEntity("quest", questID)

    C_Timer.After(0.15, function()
        local panels = ns.UI.questsPanels
        if not panels then return end
        local addon = GetDataAddon()
        if not addon then return end

        local function showDetail()
            local quest = addon.GetQuest(questID)
            if quest then
                ShowQuestDetail(panels, quest)
            end
        end

        if addon.GetQuest(questID) then
            showDetail()
            return
        end
        if addon.EnsureArchiveThen then
            addon.EnsureArchiveThen(showDetail)
        end
    end)
end

function ns.UI.CreateQuestsTab(parent)
    if completionFilter == "active" then
        completionFilter = "active_all"
    end

    local LEFT_W = ns.Constants.GUI.LEFT_PANEL_WIDTH
    local GAP    = ns.Constants.GUI.PANEL_GAP
    local HDR_H  = 70
    local DRAWER_H = 132

    local leftHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HDR_H, offset = 0 })
    leftHeader:ClearAllPoints()
    leftHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    leftHeader:SetWidth(LEFT_W)

    local rightHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HDR_H, offset = 0 })
    rightHeader:ClearAllPoints()
    rightHeader:SetPoint("TOPLEFT", leftHeader, "TOPRIGHT", GAP, 0)
    rightHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local advancedDrawer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    advancedDrawer:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 0, -GAP)
    advancedDrawer:SetPoint("TOPRIGHT", rightHeader, "BOTTOMRIGHT", 0, -GAP)
    advancedDrawer:SetHeight(DRAWER_H)
    advancedDrawer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    advancedDrawer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    advancedDrawer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    advancedDrawer:SetShown(advancedOpen)

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local function PositionContentArea()
        contentArea:ClearAllPoints()
        if advancedOpen then
            contentArea:SetPoint("TOPLEFT", advancedDrawer, "BOTTOMLEFT", 0, -GAP)
        else
            contentArea:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 0, -GAP)
        end
        contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
        advancedDrawer:SetShown(advancedOpen)
    end

    PositionContentArea()

    local panels = OneWoW_GUI:CreateSplitPanel(contentArea, { hideTitles = true })

    if panels.leftStatusText then
        panels.leftStatusText:SetPoint("RIGHT", panels.leftStatusBar, "RIGHT", -10, 0)
        panels.leftStatusText:SetJustifyH("LEFT")
    end
    if panels.leftStatusBar then
        panels.leftStatusBar:EnableMouse(true)
        panels.leftStatusBar:SetScript("OnEnter", function(self)
            local tip = panels._questListCapTip
            if not tip then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        panels.leftStatusBar:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    questListAPI = OneWoW_GUI:CreateVirtualizer(panels.listPanel, {
        name = "CatalogQuestsList",
        rowHeight = QUEST_LIST_ROW_HEIGHT,
        numVisibleRows = 10,
        rowInset = 4,
        scrollFrame = panels.listScrollFrame,
        content = panels.listScrollChild,
        getCount = function()
            local entries = panels._questListEntries
            return entries and #entries or 0
        end,
        getEntry = function(index)
            local entries = panels._questListEntries
            return entries and entries[index]
        end,
        isSelectable = function(_, entry)
            return QuestListEntryIsSelectable(entry)
        end,
        onSelect = function(_, entry)
            panels._questKeyboardNavActive = true
            if not QuestListEntryIsSelectable(entry) then
                return
            end
            selectedQuest = entry.quest
            if PinQuestChainIfNeeded(panels, entry.quest) then
                return
            end
            ShowQuestDetail(panels, entry.quest)
        end,
        createRow = CreateQuestListRow,
        bindRow = BindQuestListRow,
    })
    panels.virtualizedList = questListAPI

    contentArea:EnableKeyboard(true)
    if contentArea.SetPropagateKeyboardInput then
        contentArea:SetPropagateKeyboardInput(true)
    end
    contentArea:SetScript("OnKeyDown", function(_, key)
        local isQuestNavKey = key == "DOWN" or key == "UP"

        if not isQuestNavKey or not panels._questKeyboardNavActive then
            if contentArea.SetPropagateKeyboardInput then
                contentArea:SetPropagateKeyboardInput(true)
            end
            return
        end

        if contentArea.SetPropagateKeyboardInput then
            contentArea:SetPropagateKeyboardInput(false)
        end

        if key == "DOWN" then
            MoveQuestSelection(panels, 1)
        elseif key == "UP" then
            MoveQuestSelection(panels, -1)
        end
    end)
    contentArea:SetScript("OnKeyUp", function()
        if contentArea.SetPropagateKeyboardInput then
            contentArea:SetPropagateKeyboardInput(true)
        end
    end)

    if panels.detailScrollFrame then
        panels.detailScrollFrame:HookScript("OnSizeChanged", function(self, width)
            if not selectedQuest then
                return
            end

            width = width or self:GetWidth() or 0
            if math.abs((panels._lastDetailResizeWidth or 0) - width) < 2 then
                return
            end

            panels._lastDetailResizeWidth = width

            if panels._detailResizeTimer then
                panels._detailResizeTimer:Cancel()
            end

            panels._detailResizeTimer = C_Timer.NewTimer(0.05, function()
                if selectedQuest and ShowQuestDetail then
                    local addon = GetDataAddon()
                    local quest =
                        addon
                        and addon.GetQuest(selectedQuest.id)
                        or selectedQuest

                    ShowQuestDetail(panels, quest)
                end
            end)
        end)
    end

    local favFilterBtn = OneWoW_GUI:CreateFitTextButton(leftHeader, { text = L["QUESTS_DATA_FAVORITES"], height = 26, minWidth = 68, toggleable = true })
    favFilterBtn:SetPoint("TOPRIGHT", leftHeader, "TOPRIGHT", -8, -8)

    local clearBtn = OneWoW_GUI:CreateFitTextButton(leftHeader, { text = L["QUESTS_CLEAR"], height = 26, minWidth = 34 })
    clearBtn:SetPoint("TOPRIGHT", favFilterBtn, "TOPLEFT", -4, 0)

    local npcFilterBtn = OneWoW_GUI:CreateFitTextButton(leftHeader, { text = "", height = 26, minWidth = 72 })
    npcFilterBtn:SetPoint("TOPRIGHT", clearBtn, "TOPLEFT", -4, 0)
    npcFilterBtn:Hide()
    npcFilterBtn:SetScript("OnClick", function()
        ClearNpcFilter()
        UpdateNpcFilterChip(panels)
        RefreshQuestListFromFilters(panels)
    end)
    npcFilterBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["QUESTS_NPC_FILTER_CLEAR"], 1, 1, 1)
        GameTooltip:Show()
    end)
    npcFilterBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local searchBox = OneWoW_GUI:CreateEditBox(leftHeader, {
        height = 26,
        placeholderText = L["QUESTS_SEARCH"],
        onTextChanged = function(text)
            searchText = text
            CancelRewardItemSearchWarmup()
            if panels._searchTimer then panels._searchTimer:Cancel() end
            panels._searchTimer = C_Timer.NewTimer(0.3, function()
                RefreshQuestListFromFilters(panels)
            end)
        end,
    })
    searchBox:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -8)
    searchBox:SetPoint("TOPRIGHT", clearBtn, "TOPLEFT", -4, 0)

    local DD_GAP = 4
    local DD_PAD = 8

    local expDropdown, expText = OneWoW_GUI:CreateDropdown(leftHeader, {
        width = LEFT_W - 16,
        text = L["QUESTS_EXPANSION_ALL"],
    })
    expDropdown:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -38)

    local zoneDropdown, zoneText = OneWoW_GUI:CreateDropdown(rightHeader, { width = 10, text = L["QUESTS_ZONE_ALL"] })
    local progDropdown, progText = OneWoW_GUI:CreateDropdown(rightHeader, { width = 10, text = L["QUESTS_PROGRESS_ALL"] })
    local advancedBtn = OneWoW_GUI:CreateFitTextButton(rightHeader, {
        text = GetAdvancedButtonText(),
        height = 22,
        minWidth = 72,
    })

    local drawerTitle = OneWoW_GUI:CreateFS(advancedDrawer, 11)
    drawerTitle:SetPoint("TOPLEFT", advancedDrawer, "TOPLEFT", 10, -8)
    drawerTitle:SetText(L["QUESTS_ADVANCED_FILTERS"])
    drawerTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local drawerClearBtn = OneWoW_GUI:CreateFitTextButton(advancedDrawer, { text = L["QUESTS_CLEAR_ADVANCED"], height = 22, minWidth = 105 })
    drawerClearBtn:SetPoint("TOPRIGHT", advancedDrawer, "TOPRIGHT", -10, -6)

    local advGroup = CreateAdvancedDropdown(advancedDrawer, L["QUESTS_GROUP_SIZE"], L["QUESTS_TYPE_ALL"])
    local advQuestType = CreateAdvancedDropdown(advancedDrawer, L["QUESTS_QUEST_TYPE"], L["QUESTS_QTYPE_ALL"])
    local advCategory = CreateAdvancedDropdown(advancedDrawer, CATEGORY, L["QUESTS_FILTER_CATEGORY_ALL"])
    local advFlag = CreateAdvancedDropdown(advancedDrawer, L["QUESTS_TRAIT"], L["QUESTS_FILTER_TRAIT_ALL"])
    local advProfession = CreateAdvancedDropdown(advancedDrawer, L["TRADESKILLS_PROFESSION"], L["QUESTS_FILTER_PROFESSION_ALL"])
    local advClass = CreateAdvancedDropdown(advancedDrawer, CLASS, L["QUESTS_FILTER_CLASS_ALL"])
    local advRace = CreateAdvancedDropdown(advancedDrawer, RACE, L["QUESTS_FILTER_RACE_ALL"])
    local advFaction = CreateAdvancedDropdown(advancedDrawer, FACTION, L["QUESTS_FILTER_FACTION_ALL"])
    local advStory = CreateAdvancedDropdown(advancedDrawer, L["QUESTS_STORY"], L["QUESTS_FILTER_STORY_ALL"])
    local advRuntime = CreateAdvancedDropdown(advancedDrawer, L["QUESTS_DATA"], L["QUESTS_FILTER_DATA_ALL"])

    local function LayoutFilterDropdowns(w)
        local ddW = math.floor((w - (DD_PAD * 2) - DD_GAP) / 2)
        zoneDropdown:ClearAllPoints()
        zoneDropdown:SetSize(ddW, 26)
        zoneDropdown:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", DD_PAD, -8)

        progDropdown:ClearAllPoints()
        progDropdown:SetSize(ddW, 26)
        progDropdown:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", DD_PAD + ddW + DD_GAP, -8)

        advancedBtn:ClearAllPoints()
        advancedBtn:SetPoint("TOPRIGHT", rightHeader, "TOPRIGHT", -DD_PAD, -38)
    end

    local function LayoutAdvancedDrawer(w)
        local controls = {
            advGroup,
            advQuestType,
            advCategory,
            advFlag,
            advProfession,
            advClass,
            advRace,
            advFaction,
            advStory,
            advRuntime,
        }

        local pad = 10
        local gap = 6
        local cols = 5
        local cellW = math.floor((w - (pad * 2) - (gap * (cols - 1))) / cols)

        for index, control in ipairs(controls) do
            local col = (index - 1) % cols
            local row = math.floor((index - 1) / cols)
            local x = pad + col * (cellW + gap)
            local y = -30 - row * 48

            control.label:ClearAllPoints()
            control.label:SetPoint("TOPLEFT", advancedDrawer, "TOPLEFT", x, y)

            control.dropdown:ClearAllPoints()
            control.dropdown:SetSize(cellW, 24)
            control.dropdown:SetPoint("TOPLEFT", advancedDrawer, "TOPLEFT", x, y - 14)
        end
    end

    rightHeader:SetScript("OnSizeChanged", function(_, w)
        LayoutFilterDropdowns(w)
    end)

    advancedDrawer:SetScript("OnSizeChanged", function(_, w)
        LayoutAdvancedDrawer(w)
    end)

    C_Timer.After(0, function()
        local w = rightHeader:GetWidth()
        if w and w > 0 then LayoutFilterDropdowns(w) end
        local advW = advancedDrawer:GetWidth()
        if advW and advW > 0 then LayoutAdvancedDrawer(advW) end
    end)

    local emptyList = OneWoW_GUI:CreateFS(panels.listScrollFrame, 12)
    emptyList:SetPoint("CENTER", panels.listScrollFrame, "CENTER", 0, 0)
    emptyList:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    panels.emptyList = emptyList

    local emptyDetail = OneWoW_GUI:CreateFS(panels.detailPanel, 12)
    emptyDetail:SetPoint("CENTER", panels.detailPanel, "CENTER", 0, 0)
    emptyDetail:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    panels.emptyDetail = emptyDetail

    panels.expDropdown   = expDropdown
    panels.expText       = expText
    panels.zoneDropdown  = zoneDropdown
    panels.zoneText      = zoneText
    panels.progDropdown  = progDropdown
    panels.progText      = progText
    panels.searchBox     = searchBox
    panels.clearBtn      = clearBtn
    panels.npcFilterBtn  = npcFilterBtn
    panels.favFilterBtn  = favFilterBtn
    panels.advancedBtn   = advancedBtn
    panels.advancedDrawer = advancedDrawer
    panels.advGroup      = advGroup
    panels.advQuestType  = advQuestType
    panels.advCategory   = advCategory
    panels.advFlag       = advFlag
    panels.advProfession = advProfession
    panels.advClass      = advClass
    panels.advRace       = advRace
    panels.advFaction    = advFaction
    panels.advStory      = advStory
    panels.advRuntime    = advRuntime

    panels.UpdateAdvancedTexts = function()
        SetButtonText(advancedBtn, GetAdvancedButtonText())
        UpdateFavoritesFilterButton(favFilterBtn)
        advGroup.text:SetText(typeFilter == "all" and L["QUESTS_TYPE_ALL"] or FormatQuestMetadataValue(typeFilter))
        advQuestType.text:SetText(questTypeFilter == "all" and L["QUESTS_QTYPE_ALL"] or FormatQuestMetadataValue(questTypeFilter))
        advCategory.text:SetText(categoryFilter == "all" and L["QUESTS_FILTER_CATEGORY_ALL"] or FormatQuestMetadataValue(categoryFilter))
        advFlag.text:SetText(flagFilter == "all" and L["QUESTS_FILTER_TRAIT_ALL"] or FormatQuestMetadataValue(flagFilter))
        advProfession.text:SetText(professionFilter == "all" and L["QUESTS_FILTER_PROFESSION_ALL"] or FormatQuestMetadataValue(professionFilter))
        advClass.text:SetText(classFilter == "all" and L["QUESTS_FILTER_CLASS_ALL"] or GetClassDisplayName(classFilter))
        advRace.text:SetText(raceFilter == "all" and L["QUESTS_FILTER_RACE_ALL"] or GetRaceDisplayName(raceFilter))
        advFaction.text:SetText(factionFilter == "all" and L["QUESTS_FILTER_FACTION_ALL"] or GetFactionDisplayName(factionFilter))

        local storyText = L["QUESTS_FILTER_STORY_ALL"]
        if storyFilter == "campaign" then storyText = L["CAMPAIGN"]
        elseif storyFilter == "chain" then storyText = L["QUESTS_STORY_CHAIN"]
        elseif storyFilter == "storyline" then storyText = L["QUESTS_STORY_QUESTLINE"]
        elseif storyFilter == "standalone" then storyText = L["QUESTS_STORY_STANDALONE"] end
        advStory.text:SetText(storyText)

        local runtimeText = L["QUESTS_FILTER_DATA_ALL"]
        if runtimeFilter == "favorite" then runtimeText = L["QUESTS_DATA_FAVORITES"]
        elseif runtimeFilter == "has_location" then runtimeText = L["QUESTS_DATA_HAS_LOCATION"]
        elseif runtimeFilter == "missing_location" then runtimeText = L["QUESTS_DATA_MISSING_LOCATION"]
        elseif runtimeFilter == "has_quest_giver" then runtimeText = L["QUESTS_DATA_HAS_GIVER"]
        elseif runtimeFilter == "has_turnin" then runtimeText = L["QUESTS_DATA_HAS_TURNIN"]
        elseif runtimeFilter == "has_rewards" then runtimeText = L["QUESTS_DATA_HAS_REWARDS"]
        elseif runtimeFilter == "has_reward_choices" then runtimeText = L["QUESTS_DATA_HAS_REWARD_CHOICES"] end
        advRuntime.text:SetText(runtimeText)
    end

    ns.UI.questsPanels = panels

    panels.listScrollChild:SetHeight(100)
    panels.detailScrollChild:SetHeight(100)

    clearBtn:SetScript("OnClick", function()
        searchText      = ""
        expansionFilter = -1
        zoneFilter      = ""
        ClearNpcFilter()
        completionFilter = "all"
        ResetAdvancedFilters()
        selectedQuest = nil
        ClearPinnedQuestChain()
        if questListAPI then
            questListAPI.SetSelectedIndex(nil)
        end
        ClearDetailElements()
        if panels.emptyDetail then
            panels.emptyDetail:SetText(L["QUESTS_SELECT"])
            panels.emptyDetail:Show()
        end
        if panels.detailScrollChild then
            panels.detailScrollChild:SetHeight(100)
        end
        searchBox:SetText("")
        searchBox:ClearFocus()
        searchBox:RestorePlaceholder()
        expText:SetText(L["QUESTS_EXPANSION_ALL"])
        zoneText:SetText(L["QUESTS_ZONE_ALL"])
        progText:SetText(L["QUESTS_PROGRESS_ALL"])
        panels.UpdateAdvancedTexts()
        UpdateNpcFilterChip(panels)
        RefreshQuestListFromFilters(panels)
    end)

    favFilterBtn:SetScript("OnClick", function()
        runtimeFilter = runtimeFilter == "favorite" and "all" or "favorite"
        panels.UpdateAdvancedTexts()
        RefreshQuestListFromFilters(panels)
    end)

    drawerClearBtn:SetScript("OnClick", function()
        ResetAdvancedFilters()
        panels.UpdateAdvancedTexts()
        RefreshQuestListFromFilters(panels)
    end)

    advancedBtn:SetScript("OnClick", function()
        advancedOpen = not advancedOpen
        PositionContentArea()
        panels.UpdateAdvancedTexts()
    end)

    -- Populate the data-backed dropdowns and list once the Quests data unit's data
    -- is queryable (it registers in onLogin, after the load boundary). Catch-up
    -- covers a tab opened after data was already ready; the signal covers a
    -- mid-session load. Ongoing quest-enrichment refreshes still arrive via
    -- QuestData's QueueQuestUIRefresh -> RefreshQuestsList push.
    ns.WatchCatalogDataReady("quests", {
        emptyList = emptyList,
        emptyDetail = emptyDetail,
        noDataText = L["QUESTS_NO_DATA"],
        emptyText = L["QUESTS_EMPTY"],
        selectText = L["QUESTS_SELECT"],
        isReady = function()
            return GetDataAddon() ~= nil
        end,
        onReady = function()
            PopulateExpansionDropdown(panels)
            PopulateZoneDropdown(panels)
            SetupProgressDropdown(panels)
            SetupAdvancedDropdowns(panels)
            panels.UpdateAdvancedTexts()
            RefreshQuestList(panels)
        end,
    })

    ns.UI.RefreshQuestsList = function(invalidateStatus)
        RefreshQuestList(panels, invalidateStatus)
    end

    function parent.GetNavEntity()
        if selectedQuest and selectedQuest.id then
            return "quest", selectedQuest.id
        end
    end

    function parent.RestoreNavEntity(kind, id)
        if kind ~= "quest" then
            return
        end
        id = tonumber(id)
        if not id then
            return
        end
        local addon = GetDataAddon()
        if not addon then
            return
        end
        local quest = addon.GetQuest(id)
        if not quest then
            if addon.EnsureArchiveThen then
                addon.EnsureArchiveThen(function()
                    parent.RestoreNavEntity(kind, id)
                end)
            end
            return
        end
        local entries = panels._questListEntries
        if entries and questListAPI then
            for i, entry in ipairs(entries) do
                if entry.quest and entry.quest.id == id and QuestListEntryIsSelectable(entry) then
                    SelectQuestFromList(panels, entry.quest, i)
                    return
                end
            end
        end
        ShowQuestDetail(panels, quest)
    end
end
