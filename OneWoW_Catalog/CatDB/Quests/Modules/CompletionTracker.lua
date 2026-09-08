local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local pairs, ipairs = pairs, ipairs
local tinsert, sort = tinsert, sort
local C_QuestLog = C_QuestLog

-- Per-character completion: login snapshot,
-- QUEST_TURNED_IN, own SV, then AltTracker for alts that have never logged in
-- with this pack. Catalog reads { key, name } rows via GetCompletedCharacters.
ns.CompletionTracker = {}
local CompletionTracker = ns.CompletionTracker

local completedCache = nil
local cacheBuilt     = false

local function BuildAltTrackerCache()
    if cacheBuilt then return end

    local altApi = OneWoW_AltTracker_Collections_API
    if not altApi or not altApi.GetAllCharacters then
        cacheBuilt = true
        return
    end

    local chars = altApi.GetAllCharacters()
    if not chars then
        cacheBuilt = true
        return
    end

    completedCache = {}
    for charKey, _ in pairs(chars) do
        local charData = altApi.GetCharacterData(charKey)
        if charData and charData.quests and charData.quests.completed then
            completedCache[charKey] = {}
            for _, questID in ipairs(charData.quests.completed) do
                completedCache[charKey][questID] = true
            end
        end
    end
    cacheBuilt = true
end

function CompletionTracker:Initialize()
    local db = ns:GetQuestDB()

    local charKey = OneWoW_GUI:BuildCharKey()
    if not charKey then return end

    if not db.completion[charKey] then
        db.completion[charKey] = {}
    end

    local completedIDs = C_QuestLog.GetAllCompletedQuestIDs()
    if completedIDs then
        for _, questID in ipairs(completedIDs) do
            db.completion[charKey][questID] = true
        end
    end
end

function CompletionTracker:MarkCompleted(questID)
    if not questID then return end

    local db = ns:GetQuestDB()

    local charKey = OneWoW_GUI:BuildCharKey()
    if not charKey then return end

    if not db.completion[charKey] then
        db.completion[charKey] = {}
    end
    db.completion[charKey][questID] = true

    cacheBuilt = false
    completedCache = nil
end

function CompletionTracker:InvalidateCache()
    cacheBuilt = false
    completedCache = nil
end

function CompletionTracker:GetCompletedCharacters(questID)
    if not questID then return {} end

    local result = {}
    local seen   = {}

    local currentKey = OneWoW_GUI:BuildCharKey()
    if currentKey and C_QuestLog.IsQuestFlaggedCompleted(questID) then
        local charName = currentKey:match("^(.-)%-") or currentKey
        tinsert(result, { key = currentKey, name = charName })
        seen[currentKey] = true
    end

    local db = ns:GetQuestDB()
    for charKey, completedMap in pairs(db.completion) do
        if not seen[charKey] and completedMap[questID] then
            local charName = charKey:match("^(.-)%-") or charKey
            tinsert(result, { key = charKey, name = charName })
            seen[charKey] = true
        end
    end

    local altApi = OneWoW_AltTracker_Collections_API
    if altApi and altApi.GetAllCharacters then
        BuildAltTrackerCache()
        if completedCache then
            for charKey, lookup in pairs(completedCache) do
                if not seen[charKey] and lookup[questID] then
                    local charName = charKey:match("^(.-)%-") or charKey
                    tinsert(result, { key = charKey, name = charName })
                    seen[charKey] = true
                end
            end
        end
    end

    sort(result, function(a, b) return a.name < b.name end)
    return result
end

function CompletionTracker:GetTrackedCharacterKeys()
    local keys = {}
    local db = ns:GetQuestDB()
    for charKey, _ in pairs(db.completion) do
        tinsert(keys, charKey)
    end
    return keys
end

function CompletionTracker:PurgeCharacter(charKey)
    local db = ns:GetQuestDB()
    if db.completion[charKey] then
        db.completion[charKey] = nil
        return true
    end
    return false
end

function CompletionTracker:IsCompletedByCurrentChar(questID)
    return C_QuestLog.IsQuestFlaggedCompleted(questID) == true
end

function CompletionTracker:IsCompletedByAny(questID)
    if C_QuestLog.IsQuestFlaggedCompleted(questID) then return true end
    local chars = self:GetCompletedCharacters(questID)
    return #chars > 0
end

function CompletionTracker:GetActiveCharacters(questID)
    if not questID then return {} end

    local result = {}
    local seen   = {}

    local currentKey = OneWoW_GUI:BuildCharKey()
    if currentKey and C_QuestLog.IsOnQuest(questID) then
        local charName = currentKey:match("^(.-)%-") or currentKey
        tinsert(result, { key = currentKey, name = charName })
        seen[currentKey] = true
    end

    local altApi = OneWoW_AltTracker_Collections_API
    if altApi and altApi.GetAllCharacters then
        local chars = altApi.GetAllCharacters()
        if chars then
            for charKey in pairs(chars) do
                if not seen[charKey] then
                    local charData = altApi.GetCharacterData(charKey)
                    local activeList =
                        charData
                        and charData.quests
                        and charData.quests.active

                    if activeList then
                        for _, activeEntry in ipairs(activeList) do
                            if activeEntry.questID == questID then
                                local charName = charKey:match("^(.-)%-") or charKey
                                tinsert(result, { key = charKey, name = charName })
                                seen[charKey] = true
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    sort(result, function(a, b) return a.name < b.name end)
    return result
end

function CompletionTracker:GetAllTrackedCharacters()
    local result = {}
    local seen   = {}

    local currentKey = OneWoW_GUI:BuildCharKey()
    if currentKey then
        local charName = currentKey:match("^(.-)%-") or currentKey
        tinsert(result, { key = currentKey, name = charName })
        seen[currentKey] = true
    end

    local db = ns:GetQuestDB()
    for charKey, _ in pairs(db.completion) do
        if not seen[charKey] then
            local charName = charKey:match("^(.-)%-") or charKey
            tinsert(result, { key = charKey, name = charName })
            seen[charKey] = true
        end
    end

    local altApi = OneWoW_AltTracker_Collections_API
    if altApi and altApi.GetAllCharacters then
        BuildAltTrackerCache()
        if completedCache then
            for charKey, _ in pairs(completedCache) do
                if not seen[charKey] then
                    local charName = charKey:match("^(.-)%-") or charKey
                    tinsert(result, { key = charKey, name = charName })
                    seen[charKey] = true
                end
            end
        end
    end

    sort(result, function(a, b) return a.name < b.name end)
    return result
end

local turnInFrame = CreateFrame("Frame")
turnInFrame:RegisterEvent("QUEST_TURNED_IN")
turnInFrame:SetScript("OnEvent", function(_, _, questID)
    if questID then
        CompletionTracker:MarkCompleted(questID)
    end
end)
