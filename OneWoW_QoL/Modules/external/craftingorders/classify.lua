local _, ns = ...
local M, L = ns.ModuleRegistry:Current()
if not M then return end

-- ============================================================================
-- Classify crafter orders into Craftable now, Missing mats, and Recipe Unlearned.
-- ============================================================================
-- Craftable now: recipe learned and every required crafter-provided reagent is
-- in bags, character bank, reagent bank, or warband bank (same bags Blizzard
-- crafts from). Fully customer-supplied counts as now. Unlearned is never now
-- or missing: it is Recipe Unlearned. Public buckets are learned -> now,
-- unlearned -> Recipe Unlearned (mats unknown).
--
-- Reagent split (same rule Blizzard OrderView uses when filling the form):
--   order.reagents is the set already allocated on the order. Every entry
--   covers that slotIndex, regardless of source. source is who *may* fill
--   the slot (Any / Customer / Crafter), not "still needed from the crafter".
--   You Provide = required schematic slots with no cover.
--   Customer Provides = covered slots, using the allocated item (not the
--   schematic default). reagentState == All is a coarse UI flag, not a
--   per-slot dump of the recipe into Customer.
--   Recraft: slots already on the item (GetItemSlotModificationsForOrder)
--   count as covered, same as Blizzard OrderView AllocateModification.
-- ============================================================================

local GetItemCount = C_Item.GetItemCount

local REAGENT_ALL = Enum.CraftingOrderReagentsType.All

local function RecipeInfo(spellID, skillLineAbilityID)
    local info
    if skillLineAbilityID then
        info = C_TradeSkillUI.GetRecipeInfoForSkillLineAbility(skillLineAbilityID)
    end
    if not info and spellID then
        info = C_TradeSkillUI.GetRecipeInfo(spellID)
    end
    return info
end

local function OwnedCount(itemID)
    if not itemID then return 0 end
    -- includeBank, includeUses, includeReagentBank, includeAccountBank
    return GetItemCount(itemID, true, false, true, true)
end

local function SlotIconItem(slot)
    local slotReagents = slot and slot.reagents
    if not slotReagents then return nil end
    for r = 1, #slotReagents do
        local itemID = slotReagents[r].itemID
        if itemID then return itemID end
    end
end

-- CraftingOrderReagentInfo.reagentInfo is CraftingReagentInfo:
-- { reagent = { itemID }, dataSlotIndex, quantity }.
local function ProvidedItem(entry)
    local info = entry and entry.reagentInfo
    if not info then return nil, 1 end
    local reagent = info.reagent
    local itemID = (reagent and reagent.itemID) or info.itemID
    return itemID, info.quantity or 1
end

-- Every order.reagents row covers its slot. Same slotIndex can appear more
-- than once (quality splits); keep the first item, sum quantity.
local function CoveredByOrder(order)
    local covered = {}
    local reagents = order.reagents
    if not reagents then return covered end
    for i = 1, #reagents do
        local entry = reagents[i]
        local slotIndex = entry.slotIndex
        if slotIndex then
            local itemID, qty = ProvidedItem(entry)
            local row = covered[slotIndex]
            if row then
                row.need = row.need + qty
                if not row.itemID and itemID then
                    row.itemID = itemID
                end
            else
                covered[slotIndex] = { itemID = itemID, need = qty }
            end
        end
    end
    return covered
end

-- Recraft items already carry finishing/modified reagents (spark, etc.).
-- Keyed by schematic dataSlotIndex, matching Blizzard's modification table.
---@param order CraftingOrderInfo
---@return table<number, number>|nil
local function RecraftModsByDataSlot(order)
    if order.isRecraft ~= true or not order.orderID then
        return nil
    end
    local mods = C_TradeSkillUI.GetItemSlotModificationsForOrder(order.orderID)
    if not mods then
        return nil
    end
    local byDataSlot = {}
    local found = false
    for key, mod in pairs(mods) do
        if type(mod) == "table" then
            local reagent = mod.reagent
            local itemID = reagent and reagent.itemID
            if itemID and itemID > 0 then
                local dataSlotIndex = mod.dataSlotIndex
                if not dataSlotIndex and type(key) == "number" then
                    dataSlotIndex = key
                end
                if dataSlotIndex then
                    byDataSlot[dataSlotIndex] = itemID
                    found = true
                end
            end
        end
    end
    if not found then
        return nil
    end
    return byDataSlot
end

local function CustomerIcon(provided, slot)
    return {
        itemID = (provided and provided.itemID) or SlotIconItem(slot),
        need = (provided and provided.need) or (slot and slot.quantityRequired) or 1,
        have = (provided and provided.need) or (slot and slot.quantityRequired) or 1,
        short = 0,
    }
end

--- You-provide vs customer-provide reagent icons, plus missing { itemID, quantity }.
---@param order CraftingOrderInfo
---@return table youOut
---@return table customerOut
---@return table missing
---@return boolean allCovered
local function ClassifyReagents(order)
    local youOut = {}
    local customerOut = {}
    local missing = {}
    local allCovered = true
    local covered = CoveredByOrder(order)
    local recraftMods = RecraftModsByDataSlot(order)
    local seenCover = {}

    local schematic = C_TradeSkillUI.GetRecipeSchematic(order.spellID, order.isRecraft == true)
    local slots = schematic and schematic.reagentSlotSchematics
    if slots then
        for i = 1, #slots do
            local slot = slots[i]
            local provided = covered[slot.slotIndex]
            if not provided and recraftMods and slot.dataSlotIndex then
                local itemID = recraftMods[slot.dataSlotIndex]
                if itemID then
                    provided = { itemID = itemID, need = slot.quantityRequired or 1 }
                    covered[slot.slotIndex] = provided
                end
            end
            if provided then
                seenCover[slot.slotIndex] = true
                customerOut[#customerOut + 1] = CustomerIcon(provided, slot)
            elseif slot.required then
                local itemID = SlotIconItem(slot)
                local need = slot.quantityRequired or 1
                local have = 0
                local slotReagents = slot.reagents
                if slotReagents then
                    for r = 1, #slotReagents do
                        local id = slotReagents[r].itemID
                        if id then
                            if not itemID then itemID = id end
                            have = have + OwnedCount(id)
                        end
                    end
                end
                local short = need - have
                if short < 0 then short = 0 end
                local itemLink = itemID and select(2, C_Item.GetItemInfo(itemID)) or nil
                youOut[#youOut + 1] = {
                    itemID = itemID,
                    itemLink = itemLink,
                    need = need,
                    have = have,
                    short = short,
                }
                if short > 0 then
                    allCovered = false
                    if itemID then
                        missing[#missing + 1] = { itemID = itemID, quantity = short }
                    end
                end
            end
        end
    end

    -- Allocations whose slotIndex is not on this schematic still belong in
    -- Customer Provides (wrong schematic, or extra finishing).
    for slotIndex, provided in pairs(covered) do
        if not seenCover[slotIndex] then
            customerOut[#customerOut + 1] = CustomerIcon(provided, nil)
        end
    end

    return youOut, customerOut, missing, allCovered
end

local function RemainingTime(order)
    if not order.expirationTime then return 0 end
    return Professions.GetCraftingOrderRemainingTime(order.expirationTime)
end

function M:ClassifyBucket(bucket)
    local info = RecipeInfo(bucket.spellID, bucket.skillLineAbilityID)
    local learned = info and info.learned == true
    local kp, acuity = 0, 0
    local gold = bucket.tipAmountMax or 0
    return {
        kind = "bucket",
        section = learned and "ready" or "unknown",
        raw = bucket,
        spellID = bucket.spellID,
        skillLineAbilityID = bucket.skillLineAbilityID,
        itemID = bucket.itemID,
        name = info and info.name or "",
        icon = (info and info.icon) or C_Item.GetItemIconByID(bucket.itemID),
        quality = info and info.quality,
        learned = learned,
        numAvailable = bucket.numAvailable or 0,
        tipAvg = bucket.tipAmountAvg or 0,
        tipMax = gold,
        youReagents = {},
        customerReagents = {},
        missingReagents = {},
        rewardIcons = M:BuildRewardIcons(nil, {
            gold = gold,
            tipAvg = bucket.tipAmountAvg or 0,
            tipMax = gold,
        }),
        kp = kp,
        acuity = acuity,
        gold = gold,
        isRecraft = false,
    }
end

function M:ClassifyOrder(order)
    local info = RecipeInfo(order.spellID, order.skillLineAbilityID)
    local learned = info and info.learned == true
    local youReagents, customerReagents, missing, allCovered = ClassifyReagents(order)
    local section = "unknown"
    if learned then
        section = allCovered and "ready" or "missing"
    end
    local kp, acuity, gold = 0, 0, order.tipAmount or 0
    if order.orderType == Enum.CraftingOrderType.Npc then
        kp, acuity, gold = M:ScoreNpcRewards(order)
    end
    local name = info and info.name or ""
    if name == "" then
        name = C_Item.GetItemNameByID(order.itemID) or ""
    end
    return {
        kind = "order",
        section = section,
        raw = order,
        orderID = order.orderID,
        spellID = order.spellID,
        skillLineAbilityID = order.skillLineAbilityID,
        itemID = order.itemID,
        name = name,
        icon = (info and info.icon) or C_Item.GetItemIconByID(order.itemID),
        quality = info and info.quality or order.minQuality,
        learned = learned,
        isRecraft = order.isRecraft == true,
        minQuality = order.minQuality,
        customerName = order.customerName,
        youReagents = youReagents,
        customerReagents = customerReagents,
        missingReagents = missing,
        rewardIcons = M:BuildRewardIcons(order, { gold = gold }),
        customerProvidedAll = order.reagentState == REAGENT_ALL,
        kp = kp,
        acuity = acuity,
        gold = gold,
        consortiumCut = order.consortiumCut or 0,
        remaining = RemainingTime(order),
        expirationTime = order.expirationTime,
        orderType = order.orderType,
    }
end

local function SortNpc(a, b)
    if a.kp ~= b.kp then return a.kp > b.kp end
    if a.acuity ~= b.acuity then return a.acuity > b.acuity end
    if a.gold ~= b.gold then return a.gold > b.gold end
    return (a.name or "") < (b.name or "")
end

local function SortTipThenTime(a, b)
    if a.gold ~= b.gold then return a.gold > b.gold end
    local ar = a.remaining or 0
    local br = b.remaining or 0
    if ar ~= br then return ar < br end
    return (a.name or "") < (b.name or "")
end

local function SortBuckets(a, b)
    if a.learned ~= b.learned then return a.learned end
    if a.numAvailable ~= b.numAvailable then return a.numAvailable > b.numAvailable end
    if a.gold ~= b.gold then return a.gold > b.gold end
    return (a.name or "") < (b.name or "")
end

local function AppendSection(entries, list, section)
    if #list == 0 then return end
    entries[#entries + 1] = { kind = "header", section = section, count = #list }
    for i = 1, #list do
        entries[#entries + 1] = list[i]
    end
end

function M:BuildOverlayEntries(rawList, isBucket, orderType)
    local ready, missing, unknown = {}, {}, {}
    local hideUnlearned = ns.ModuleRegistry:GetToggleValue("craftingorders", "hideUnlearned")
    if rawList then
        for i = 1, #rawList do
            local raw = rawList[i]
            local entry
            if isBucket then
                entry = M:ClassifyBucket(raw)
            else
                entry = M:ClassifyOrder(raw)
            end
            if entry.section == "ready" then
                ready[#ready + 1] = entry
            elseif entry.section == "unknown" then
                if not hideUnlearned then
                    unknown[#unknown + 1] = entry
                end
            else
                missing[#missing + 1] = entry
            end
        end
    end

    local sorter
    if isBucket then
        sorter = SortBuckets
    elseif orderType == Enum.CraftingOrderType.Npc then
        sorter = SortNpc
    else
        sorter = SortTipThenTime
    end
    sort(ready, sorter)
    sort(missing, sorter)
    sort(unknown, sorter)

    -- A claimed order drops off the browse snapshot and is the only claim
    -- allowed. Pin it at the top of every tab so Start / Concentration /
    -- Create / Complete and release stay available until it is finished.
    local claimed = C_CraftingOrders.GetClaimedOrder()
    if claimed then
        local claimedID = claimed.orderID
        local function strip(list)
            local i = 1
            while i <= #list do
                if list[i].orderID == claimedID then
                    tremove(list, i)
                else
                    i = i + 1
                end
            end
        end
        strip(ready)
        strip(missing)
        strip(unknown)
        local entry = M:ClassifyOrder(claimed)
        entry.section = "ready"
        tinsert(ready, 1, entry)
    end

    local entries = {}
    AppendSection(entries, ready, "ready")
    AppendSection(entries, missing, "missing")
    AppendSection(entries, unknown, "unknown")
    return entries, #ready, #missing, #unknown
end

function M:GetWeeklyStatus(profession)
    local ids = M:GetWeeklyQuestIDs(profession)
    if not ids then return nil end

    local function objectives(questID)
        local objs = C_QuestLog.GetQuestObjectives(questID)
        local fulfilled, required = 0, 0
        if objs then
            for i = 1, #objs do
                local o = objs[i]
                fulfilled = fulfilled + (o.numFulfilled or 0)
                required = required + (o.numRequired or 0)
            end
        end
        return fulfilled, required
    end

    for i = 1, #ids do
        local qid = ids[i]
        if C_QuestLog.IsQuestFlaggedCompleted(qid) or C_QuestLog.IsComplete(qid) then
            return { state = "complete", questID = qid }
        end
    end
    for i = 1, #ids do
        local qid = ids[i]
        if C_QuestLog.IsOnQuest(qid) then
            local fulfilled, required = objectives(qid)
            local remaining = required - fulfilled
            if remaining < 0 then remaining = 0 end
            return {
                state = "progress",
                questID = qid,
                remaining = remaining,
                fulfilled = fulfilled,
                required = required,
            }
        end
    end
    local current = ids[1]
    if not HaveQuestData(current) then
        C_QuestLog.RequestLoadQuestByID(current)
        return { state = "not_learned", questID = current }
    end
    return { state = "not_accepted", questID = current }
end

function M:FormatWeeklyHeader(profession)
    local status = M:GetWeeklyStatus(profession)
    if not status then return nil end
    if status.state == "complete" then
        return L["CRAFTORDERS_WEEKLY_COMPLETE"]
    end
    if status.state == "progress" then
        return L["CRAFTORDERS_WEEKLY_PROGRESS"]:format(status.fulfilled, status.required)
    end
    if status.state == "not_learned" then
        return L["CRAFTORDERS_WEEKLY_NOT_LEARNED"]
    end
    return L["CRAFTORDERS_WEEKLY_NOT_ACCEPTED"]
end
