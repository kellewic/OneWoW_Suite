local _, ns = ...

-- ============================================================================
-- QuestDB loader
-- ============================================================================
-- Emit agents call ns:RegisterQuestData{ [questID] = { ... } } from Data/ shards.
--   ns.ExternalQuestDB              [questID] = quest record
--   ns.ExternalQuestDBByExpansion   [expansionID][questID] = quest record
--   ns.QuestsByNPC                  [npcID] = { quest, ... }
--   ns.QuestsByRewardItem           [itemID] = { questID, ... }
-- ============================================================================

local pairs = pairs
local tinsert = tinsert

ns.ExternalQuestDB = ns.ExternalQuestDB or {}
ns.ExternalQuestDBByExpansion = ns.ExternalQuestDBByExpansion or {}
ns.QuestsByNPC = ns.QuestsByNPC or {}
ns.QuestsByRewardItem = ns.QuestsByRewardItem or {}

local db = ns.ExternalQuestDB
local byExpansion = ns.ExternalQuestDBByExpansion
local byNPC = ns.QuestsByNPC
local byReward = ns.QuestsByRewardItem

local function IndexNPC(npcID, quest)
    if type(npcID) ~= "number" then return end
    local list = byNPC[npcID]
    if not list then
        list = {}
        byNPC[npcID] = list
    end
    tinsert(list, quest)
end

local function RewardItemID(entry)
    if type(entry) == "number" then
        return entry
    end
    if type(entry) == "table" then
        return entry.itemID or entry.id
    end
    return nil
end

local function IndexRewardItem(itemID, questID)
    itemID = tonumber(itemID)
    if not itemID then
        return
    end
    local list = byReward[itemID]
    if not list then
        list = {}
        byReward[itemID] = list
    end
    for i = 1, #list do
        if list[i] == questID then
            return
        end
    end
    tinsert(list, questID)
end

local function IndexRewardList(list, questID)
    if type(list) ~= "table" then
        return
    end
    for _, entry in pairs(list) do
        IndexRewardItem(RewardItemID(entry), questID)
    end
end

--- Merge quest rows keyed by questID.
---@param source table<number, table>
function ns:RegisterQuestData(source)
    if type(source) ~= "table" then return end

    for questID, questData in pairs(source) do
        if type(questID) == "number" and type(questData) == "table" then
            db[questID] = questData

            local expansionID = questData.expansion
            if type(expansionID) == "number" then
                byExpansion[expansionID] = byExpansion[expansionID] or {}
                byExpansion[expansionID][questID] = questData
            end

            if questData.starts then
                for _, start in pairs(questData.starts) do
                    if type(start) == "table" then
                        IndexNPC(start.npcID, questData)
                    elseif type(start) == "number" then
                        IndexNPC(start, questData)
                    end
                end
            end
            if questData.ends then
                for _, finish in pairs(questData.ends) do
                    if type(finish) == "table" then
                        IndexNPC(finish.npcID, questData)
                    elseif type(finish) == "number" then
                        IndexNPC(finish, questData)
                    end
                end
            end

            IndexRewardList(questData.rewardItems, questID)
            IndexRewardList(questData.rewardChoices, questID)
            IndexRewardList(questData.packageItems, questID)
        end
    end
end
