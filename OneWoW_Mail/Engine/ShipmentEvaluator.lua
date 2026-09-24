local _, ns = ...

ns.ShipmentEvaluator = {}
local ShipmentEvaluator = ns.ShipmentEvaluator

local PE = OneWoW.PredicateEngine
local SE = OneWoW.SearchExpand

local MT = ns.MailTrace
local function Trace(event, fields)
    if MT.enabled then
        MT:Record("eval", event, fields)
    end
end

local LinkHasVisibleName = ns.ItemLabel.LinkHasVisibleName

local DISTRIBUTE_FILL = "fill_first"
local DISTRIBUTE_RR = "round_robin"
local DISTRIBUTE_EQUAL = "equal_split"

local function CrossRealmMode(shipment)
    local mode = shipment and shipment.crossRealm
    if mode == "cancel" or mode == "warbound" then
        return mode
    end
    return "send"
end

--- "full" shares this realm group. "warbound" is a known alt outside it.
--- "none" is anyone else outside the group.
local function RealmTier(target)
    if ns.AddressBook:IsSameRealmGroup(target) then
        return "full"
    end
    if ns.AddressBook:IsSuiteAlt(target) then
        return "warbound"
    end
    return "none"
end

local function SlotStackCount(slot)
    return slot.stackCount or slot.count or slot.quantity or 1
end

--- Bags: bags[bagID] = { slots = { [slot] = rec }, numSlots = N }.
local function CountInBagSlots(bags, itemID)
    local total = 0
    if not bags then
        return 0
    end
    for _, bagData in pairs(bags) do
        if type(bagData) == "table" and type(bagData.slots) == "table" then
            for _, slot in pairs(bagData.slots) do
                if type(slot) == "table" and slot.itemID == itemID then
                    total = total + SlotStackCount(slot)
                end
            end
        end
    end
    return total
end

--- Personal / guild / warband-style tabs: *.tabs[n] = { items|slots = { ... } }.
local function CountInBankTabs(bank, itemID)
    local total = 0
    if not bank or type(bank.tabs) ~= "table" then
        return 0
    end
    for _, tab in pairs(bank.tabs) do
        local slots = tab and (tab.items or tab.slots)
        if type(slots) == "table" then
            for _, slot in pairs(slots) do
                if type(slot) == "table" and slot.itemID == itemID then
                    total = total + SlotStackCount(slot)
                end
            end
        end
    end
    return total
end

--- Recipient-owned stock for restock (not sender pull). Missing warband counts as on.
local function SourceEnabled(sources, key, defaultOn)
    if not sources then
        return defaultOn
    end
    local v = sources[key]
    if v == nil then
        return defaultOn
    end
    return v and true or false
end

--- Count recipient inventory for restock (bags/bank/warband/guild + in-transit).
local function CountTargetHave(charKey, itemID, sources)
    local API = OneWoW_AltTracker_Storage_API
    if not API or not charKey then
        return 0
    end
    local total = 0
    if SourceEnabled(sources, "bags", true) then
        total = total + CountInBagSlots(API.GetBags(charKey), itemID)
    end
    if SourceEnabled(sources, "bank", true) then
        total = total + CountInBankTabs(API.GetPersonalBank(charKey), itemID)
    end
    if SourceEnabled(sources, "warband", true) then
        total = total + CountInBankTabs(API.GetWarbandBank(), itemID)
    end
    if SourceEnabled(sources, "guild", false) then
        total = total + CountInBankTabs(API.GetGuildBank(charKey), itemID)
    end
    for _, ship in ipairs(API.GetInTransitShipments(charKey) or {}) do
        for _, it in ipairs(ship.items or {}) do
            if it.itemID == itemID then
                total = total + (it.count or it.stackCount or 1)
            end
        end
    end
    return total
end

--- Scan bags for mailable (non-soulbound) slots matching a compiled predicate.
---@param pred fun(props: table): boolean
---@param blacklist table
---@param exclusions table
---@return table slots
local function ScanMatchingSlots(pred, blacklist, exclusions)
    local out = {}
    local bags = { 0, 1, 2, 3, 4 }
    if Enum.BagIndex and Enum.BagIndex.ReagentBag then
        tinsert(bags, Enum.BagIndex.ReagentBag)
    end

    for _, bag in ipairs(bags) do
        local num = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, num do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not info.isLocked then
                local itemID = info.itemID
                if not blacklist[itemID] and not exclusions[itemID] then
                    local link = info.hyperlink or C_Container.GetContainerItemLink(bag, slot)
                    ns.ItemLabel.RequestLoadIfNeeded(itemID, link)
                    local props = PE:BuildProps(itemID, bag, slot)
                    if props and not props.isSoulbound and pred(props) then
                        local bindKnown = rawget(props, "currentbind") ~= nil
                        tinsert(out, {
                            bag = bag,
                            slot = slot,
                            itemID = itemID,
                            count = info.stackCount or 1,
                            link = link,
                            isWarbound = bindKnown and props.isWarbound and true or false,
                            bindKnown = bindKnown,
                        })
                    end
                end
            end
        end
    end
    return out
end

---@param match string|nil
---@return string
local function BuildMatchExpr(match)
    match = strtrim(match or "")
    if match == "" then
        return match
    end
    return "(" .. match .. ") & !#soulbound"
end

--- Gold on a suite alt for restock: last-login wallet + in-transit mail gold.
local function CountTargetGold(charKey)
    local charAPI = OneWoW_AltTracker_Character_API
    if not charAPI or not charAPI.GetCharacterData or not charKey then
        return 0
    end
    local data = charAPI.GetCharacterData(charKey)
    local total = (data and data.money) or 0
    local storageAPI = OneWoW_AltTracker_Storage_API
    if storageAPI and storageAPI.GetInTransitShipments then
        for _, ship in ipairs(storageAPI.GetInTransitShipments(charKey) or {}) do
            total = total + (ship.money or 0)
        end
    end
    return total
end

local function RoleDistributeMode(shipment)
    local mode = shipment.roleDistribute or DISTRIBUTE_FILL
    if mode == DISTRIBUTE_RR or mode == DISTRIBUTE_EQUAL then
        return mode
    end
    return DISTRIBUTE_FILL
end

--- Expand shipment to mail targets (charKeys or typed names). skipSet keyed by charKey.
---@return table|nil targets
---@return string|nil err
---@return string|nil roleId
local function ExpandTargets(shipment, skipSet)
    skipSet = skipSet or {}
    if (shipment.targetKind or "char") == "role" then
        local roleId = shipment.targetRoleId
        if not roleId or roleId == "" then
            return nil, "no target"
        end
        local role = OneWoW.AltScope:GetRole(roleId)
        if not role then
            return nil, "no target"
        end
        local members = {}
        local anyMember = false
        for charKey in pairs(role.members or {}) do
            if not ns.AddressBook:IsSelfRecipient(charKey) then
                anyMember = true
                if not skipSet[charKey] then
                    tinsert(members, charKey)
                end
            end
        end
        if not anyMember then
            return nil, "empty role"
        end
        sort(members)
        return members, nil, roleId
    end

    local target = shipment.target
    if not target or target == "" then
        return nil, "no target"
    end
    if ns.AddressBook:IsSelfRecipient(target) then
        return nil, "to self"
    end
    local _, charKey = ns.AddressBook:IsSuiteAlt(target)
    local skipKey = charKey or target
    if skipSet[skipKey] or (charKey and skipSet[charKey]) then
        return {}
    end
    return { target }
end

--- How much gold this target still wants this run (0 = satisfied / nothing to send).
local function GoldNeed(shipment, target)
    local _, charKey = ns.AddressBook:IsSuiteAlt(target)
    if not shipment.maxCopperEnabled then
        return math.huge, nil
    end
    local cap = shipment.maxCopper or 0
    if shipment.restock and charKey then
        local have = CountTargetGold(charKey)
        local need = (shipment.restockCopper or 0) - have
        if need < 0 then
            need = 0
        end
        return math.min(need, cap), have
    end
    return cap, nil
end

--- Allocate a shared copper pool across targets.
---@return table alloc [target] = sendCopper
---@return table meta [target] = { have, need, skipReason }
local function AllocateGold(shipment, targets, pool)
    local mode = RoleDistributeMode(shipment)
    local needs = {}
    local meta = {}
    local eligible = {}
    for _, target in ipairs(targets) do
        local need, have = GoldNeed(shipment, target)
        needs[target] = need
        meta[target] = { have = have, need = need }
        if need == 0 and shipment.restock and have ~= nil then
            meta[target].skipReason = "restock-met"
        elseif need > 0 then
            tinsert(eligible, target)
        elseif shipment.maxCopperEnabled and (shipment.maxCopper or 0) == 0 then
            meta[target].skipReason = "cap-zero"
        end
    end

    local alloc = {}
    for _, target in ipairs(targets) do
        alloc[target] = 0
    end

    if #eligible == 0 or pool <= 0 then
        return alloc, meta
    end

    if mode == DISTRIBUTE_EQUAL then
        local share = math.floor(pool / #eligible)
        for _, target in ipairs(eligible) do
            local take = math.min(share, needs[target])
            if take == math.huge then
                take = share
            end
            alloc[target] = take
        end
    elseif mode == DISTRIBUTE_RR then
        local remaining = {}
        for _, target in ipairs(eligible) do
            remaining[target] = needs[target]
        end
        local left = pool
        local progress = true
        while left > 0 and progress do
            progress = false
            for _, target in ipairs(eligible) do
                local want = remaining[target]
                if want and want > 0 and left > 0 then
                    local sliceCap = shipment.maxCopperEnabled and (shipment.maxCopper or 0) or want
                    if sliceCap <= 0 or sliceCap == math.huge then
                        sliceCap = want
                    end
                    local take = math.min(sliceCap, want, left)
                    if take > 0 and take ~= math.huge then
                        alloc[target] = alloc[target] + take
                        remaining[target] = want - take
                        left = left - take
                        progress = true
                    end
                end
            end
        end
    else
        -- fill_first
        local left = pool
        for _, target in ipairs(eligible) do
            local want = needs[target]
            local take = math.min(want, left)
            if take == math.huge then
                take = left
            end
            if take > 0 then
                alloc[target] = take
                left = left - take
            end
            if left <= 0 then
                break
            end
        end
    end

    return alloc, meta
end

local function EmptyPlan(shipment, target, skipReason, skipDetail)
    return {
        shipment = shipment,
        target = target,
        entries = {},
        jobs = {},
        error = nil,
        skipReason = skipReason,
        skipDetail = skipDetail,
    }
end

local function PlanGoldShipment(shipment, skipSet)
    local targets, err = ExpandTargets(shipment, skipSet)
    if err then
        return { {
            shipment = shipment,
            target = shipment.target,
            entries = {},
            jobs = {},
            error = err,
        } }
    end
    if #targets == 0 then
        return {}
    end

    local keep = shipment.keepCopper or 0
    local postage = GetSendMailPrice() or 30
    local pool = GetMoney() - keep
    if pool < 0 then
        pool = 0
    end

    -- Reserve postage per eventual mail from the pool up-front for equal/RR fairness:
    -- allocate send amounts from (pool - postage * potential), then create jobs.
    local plans = {}
    local sendPool = pool
    local goldTargets = targets
    if CrossRealmMode(shipment) == "warbound" then
        goldTargets = {}
        for _, target in ipairs(targets) do
            if RealmTier(target) == "full" then
                tinsert(goldTargets, target)
            end
        end
    end
    local alloc, meta = AllocateGold(shipment, goldTargets, sendPool)

    -- Re-walk: each successful send costs postage; shrink later if pool can't cover.
    local remainingPool = pool
    for _, target in ipairs(targets) do
        if CrossRealmMode(shipment) == "warbound" and RealmTier(target) ~= "full" then
            local need, have = GoldNeed(shipment, target)
            local reason = "cross-realm-gold"
            local detail
            if RealmTier(target) == "none" then
                reason = "cross-realm-other"
            end
            if need == 0 and shipment.restock and have ~= nil then
                reason = "restock-met"
                detail = string.format(
                    ns.L["LOG_SKIP_RESTOCK_DETAIL"],
                    OneWoW.Format.FormatGold(have),
                    OneWoW.Format.FormatGold(shipment.restockCopper or 0)
                )
            elseif shipment.maxCopperEnabled and (shipment.maxCopper or 0) == 0 then
                reason = "cap-zero"
            elseif need == 0 then
                reason = "nothing"
            end
            tinsert(plans, EmptyPlan(shipment, target, reason, detail))
        else
        local info = meta[target] or {}
        local want = alloc[target] or 0
        if want > 0 then
            local maxSend = remainingPool - postage
            if maxSend < 0 then
                maxSend = 0
            end
            local send = math.min(want, maxSend)
            if send > 0 then
                local subject = ns.Constants.SUBJECT_PREFIX .. (shipment.name or shipment.id or "gold")
                local plan = {
                    shipment = shipment,
                    target = target,
                    entries = { { money = send, quantity = nil, slots = {} } },
                    jobs = { {
                        target = target,
                        subject = subject,
                        money = send,
                        slots = {},
                        shipmentId = shipment.id,
                    } },
                    error = nil,
                }
                tinsert(plans, plan)
                remainingPool = remainingPool - send - postage
            elseif info.skipReason then
                local detail
                if info.skipReason == "restock-met" and info.have ~= nil then
                    detail = string.format(
                        ns.L["LOG_SKIP_RESTOCK_DETAIL"],
                        OneWoW.Format.FormatGold(info.have),
                        OneWoW.Format.FormatGold(shipment.restockCopper or 0)
                    )
                end
                tinsert(plans, EmptyPlan(shipment, target, info.skipReason, detail))
            else
                -- Postage ate the remainder, or equal-split share was below 1c.
                tinsert(plans, EmptyPlan(shipment, target, "underfunded"))
            end
        elseif info.skipReason then
            local detail
            if info.skipReason == "restock-met" and info.have ~= nil then
                detail = string.format(
                    ns.L["LOG_SKIP_RESTOCK_DETAIL"],
                    OneWoW.Format.FormatGold(info.have),
                    OneWoW.Format.FormatGold(shipment.restockCopper or 0)
                )
            end
            tinsert(plans, EmptyPlan(shipment, target, info.skipReason, detail))
        else
            local reason = "underfunded"
            if pool == 0 and keep > 0 then
                reason = "keep-holds"
            elseif shipment.maxCopperEnabled and (shipment.maxCopper or 0) == 0 then
                reason = "cap-zero"
            elseif (info.need or 0) == 0 and not shipment.restock then
                reason = "nothing"
            end
            tinsert(plans, EmptyPlan(shipment, target, reason))
        end
        end
    end

    return plans
end

--- Per-target item need for one itemID.
local function ItemNeed(shipment, target, itemID, restockSources)
    local _, charKey = ns.AddressBook:IsSuiteAlt(target)
    if not shipment.maxQtyEnabled then
        return math.huge
    end
    local maxQty = shipment.maxQty or 0
    if shipment.restock and charKey then
        local have = CountTargetHave(charKey, itemID, restockSources)
        local need = maxQty - have
        if need < 0 then
            need = 0
        end
        return need
    end
    return maxQty
end

local function AllocateItem(shipment, targets, available, itemID, restockSources)
    local mode = RoleDistributeMode(shipment)
    local needs = {}
    local eligible = {}
    for _, target in ipairs(targets) do
        local need = ItemNeed(shipment, target, itemID, restockSources)
        needs[target] = need
        if need > 0 then
            tinsert(eligible, target)
        end
    end

    local alloc = {}
    for _, target in ipairs(targets) do
        alloc[target] = 0
    end
    if #eligible == 0 or available <= 0 then
        return alloc
    end

    if mode == DISTRIBUTE_EQUAL then
        local share = math.floor(available / #eligible)
        for _, target in ipairs(eligible) do
            local want = needs[target]
            local take = math.min(share, want == math.huge and share or want)
            alloc[target] = take
        end
    elseif mode == DISTRIBUTE_RR then
        local remaining = {}
        for _, target in ipairs(eligible) do
            remaining[target] = needs[target]
        end
        local left = available
        local progress = true
        while left > 0 and progress do
            progress = false
            for _, target in ipairs(eligible) do
                local want = remaining[target]
                if want and want > 0 and left > 0 then
                    local sliceCap = shipment.maxQtyEnabled and (shipment.maxQty or 0) or want
                    if sliceCap <= 0 then
                        sliceCap = want
                    end
                    local take = math.min(sliceCap, want == math.huge and left or want, left)
                    if take > 0 then
                        alloc[target] = alloc[target] + take
                        if want ~= math.huge then
                            remaining[target] = want - take
                        else
                            remaining[target] = 0
                        end
                        left = left - take
                        progress = true
                    end
                end
            end
        end
    else
        local left = available
        for _, target in ipairs(eligible) do
            local want = needs[target]
            local take = math.min(want == math.huge and left or want, left)
            if take > 0 then
                alloc[target] = take
                left = left - take
            end
            if left <= 0 then
                break
            end
        end
    end
    return alloc
end

local function PackItemJobs(shipment, target, entries)
    local jobs = {}
    local subject = ns.Constants.SUBJECT_PREFIX .. (shipment.name or shipment.id or "shipment")
    local current = { target = target, subject = subject, slots = {}, shipmentId = shipment.id }
    local function flush()
        if #current.slots > 0 then
            tinsert(jobs, current)
            current = { target = target, subject = subject, slots = {}, shipmentId = shipment.id }
        end
    end
    local maxSlots = ns.Constants.SEND_ATTACH_SLOTS
    for _, entry in ipairs(entries) do
        for _, loc in ipairs(entry.slots) do
            if #current.slots >= maxSlots then
                flush()
            end
            tinsert(current.slots, loc)
        end
    end
    flush()
    return jobs
end

local function PlanItemsShipment(shipment, reserved, skipSet)
    local targets, err = ExpandTargets(shipment, skipSet)
    if err then
        return { {
            shipment = shipment,
            target = shipment.target,
            entries = {},
            jobs = {},
            error = err,
        } }
    end
    if #targets == 0 then
        return {}
    end

    local matchExpr = BuildMatchExpr(shipment.match)
    local pred, compileErr = SE:Compile(matchExpr)
    if not pred then
        return { {
            shipment = shipment,
            target = targets[1],
            entries = {},
            jobs = {},
            error = compileErr or "bad match",
        } }
    end

    local blacklist = ns.db.global.mail.blacklistItemIDs or {}
    local exclusions = shipment.exclusions or {}
    local slots = ScanMatchingSlots(pred, blacklist, exclusions)

    local byItem = {}
    for _, loc in ipairs(slots) do
        local row = byItem[loc.itemID]
        if not row then
            row = { itemID = loc.itemID, total = 0, slots = {}, isWarbound = true, bindKnown = true }
            byItem[loc.itemID] = row
        end
        if not loc.bindKnown then
            row.bindKnown = false
            row.isWarbound = false
        elseif not loc.isWarbound then
            row.isWarbound = false
        end
        row.total = row.total + loc.count
        tinsert(row.slots, loc)
    end

    local keepQty = shipment.keepQty or 0
    local restockSources = ns:NormalizeRestockSources(shipment.restockSources)

    -- perTarget[target] = { entries = {} }
    local perTarget = {}
    for _, target in ipairs(targets) do
        perTarget[target] = { entries = {} }
    end

    local anyMatch = next(byItem) ~= nil

    for itemID, row in pairs(byItem) do
        reserved[itemID] = reserved[itemID] or 0
        local available = row.total - reserved[itemID] - keepQty
        if available < 0 then
            available = 0
        end

        local allocTargets = targets
        if CrossRealmMode(shipment) == "warbound" then
            allocTargets = {}
            local deliverable = row.bindKnown and row.isWarbound
            for _, target in ipairs(targets) do
                local tier = RealmTier(target)
                if tier == "full" or (tier == "warbound" and deliverable) then
                    tinsert(allocTargets, target)
                elseif tier == "warbound" and available > 0 and ItemNeed(shipment, target, itemID, restockSources) > 0 then
                    local held = perTarget[target].held
                    if not held then
                        held = {}
                        perTarget[target].held = held
                    end
                    if not row.bindKnown then
                        held.unknown = true
                    else
                        held.item = true
                    end
                end
            end
        end

        local alloc = AllocateItem(shipment, allocTargets, available, itemID, restockSources)
        local usedSlots = {}
        for _, loc in ipairs(row.slots) do
            usedSlots[loc] = loc.count
        end

        for _, target in ipairs(targets) do
            local sendQty = alloc[target] or 0
            if sendQty > 0 then
                reserved[itemID] = reserved[itemID] + sendQty
                local left = sendQty
                local used = {}
                for _, loc in ipairs(row.slots) do
                    if left <= 0 then
                        break
                    end
                    local remain = usedSlots[loc] or 0
                    if remain > 0 then
                        local take = math.min(remain, left)
                        tinsert(used, {
                            bag = loc.bag,
                            slot = loc.slot,
                            count = take,
                            itemID = itemID,
                            link = loc.link,
                            isWarbound = loc.isWarbound,
                            bindKnown = loc.bindKnown,
                        })
                        usedSlots[loc] = remain - take
                        left = left - take
                    end
                end
                tinsert(perTarget[target].entries, { itemID = itemID, quantity = sendQty, slots = used })
            end
        end
    end

    local plans = {}
    for _, target in ipairs(targets) do
        local bucket = perTarget[target]
        local jobs = PackItemJobs(shipment, target, bucket.entries)
        local plan = {
            shipment = shipment,
            target = target,
            entries = bucket.entries,
            jobs = jobs,
            error = nil,
        }
        if #jobs == 0 then
            if not anyMatch then
                plan.skipReason = "no-match"
            elseif shipment.maxQtyEnabled and (shipment.maxQty or 0) == 0 then
                plan.skipReason = "cap-zero"
            elseif shipment.restock then
                local stillNeeds = false
                for itemID in pairs(byItem) do
                    if ItemNeed(shipment, target, itemID, restockSources) > 0 then
                        stillNeeds = true
                        break
                    end
                end
                if not stillNeeds then
                    plan.skipReason = "restock-met"
                else
                    -- Matched items exist and this target still needs some, but got
                    -- nothing (keep ate the pool, or distribute share floored to 0).
                    local anyAfterKeep = false
                    for _, row in pairs(byItem) do
                        if (row.total - keepQty) > 0 then
                            anyAfterKeep = true
                            break
                        end
                    end
                    if not anyAfterKeep and keepQty > 0 then
                        plan.skipReason = "keep-holds"
                    else
                        plan.skipReason = "underfunded"
                    end
                end
            else
                local anyAfterKeep = false
                for _, row in pairs(byItem) do
                    if (row.total - keepQty) > 0 then
                        anyAfterKeep = true
                        break
                    end
                end
                if not anyAfterKeep and keepQty > 0 then
                    plan.skipReason = "keep-holds"
                else
                    plan.skipReason = "underfunded"
                end
            end
        end
        if CrossRealmMode(shipment) == "warbound" then
            local tier = RealmTier(target)
            local held = bucket.held
            if #jobs == 0 and (plan.skipReason == "underfunded" or plan.skipReason == "nothing") then
                if tier == "none" then
                    plan.skipReason = "cross-realm-other"
                elseif tier == "warbound" and held then
                    plan.skipReason = "cross-realm-warbound"
                end
            elseif #jobs > 0 and held then
                plan.omitDetail = ns.L["LOG_OMIT_CROSS_REALM_ITEMS"]
                if held.unknown then
                    plan.omitDetail = ns.L["LOG_OMIT_CROSS_REALM_UNKNOWN"]
                end
            end
        end
        tinsert(plans, plan)
    end
    return plans
end

local function BlockerBits(plan)
    local gold, item, unknown = false, false, false
    for _, job in ipairs(plan.jobs or {}) do
        if (job.money or 0) > 0 then
            gold = true
        end
        for _, loc in ipairs(job.slots or {}) do
            if not loc.bindKnown then
                unknown = true
            elseif not loc.isWarbound then
                item = true
            end
        end
    end
    return gold, item, unknown
end

local function FormatBlocker(target, gold, item, unknown)
    local why = {}
    if gold then
        tinsert(why, ns.L["CROSS_REALM_BLOCK_GOLD"])
    end
    if item then
        tinsert(why, ns.L["CROSS_REALM_BLOCK_ITEM"])
    end
    if unknown then
        tinsert(why, ns.L["CROSS_REALM_BLOCK_UNKNOWN"])
    end
    local name = target or "?"
    return string.format("%s (%s)", name, table.concat(why, ", "))
end

--- Cancel mode: if any off-group recipient would get gold, a non-Warbound
--- item, or an unread bind, drop every job and leave one skip for Activity.
local function ApplyCrossRealmCancel(shipment, plans, reserved)
    if CrossRealmMode(shipment) ~= "cancel" then
        return plans
    end
    local lines = {}
    local firstTarget
    for _, plan in ipairs(plans) do
        if #(plan.jobs or {}) > 0 and not ns.AddressBook:IsSameRealmGroup(plan.target) then
            local gold, item, unknown = BlockerBits(plan)
            if gold or item or unknown then
                if not firstTarget then
                    firstTarget = plan.target
                end
                tinsert(lines, FormatBlocker(plan.target, gold, item, unknown))
            end
        end
    end
    if #lines == 0 then
        return plans
    end
    if reserved then
        for _, plan in ipairs(plans) do
            for _, entry in ipairs(plan.entries or {}) do
                if entry.itemID and entry.quantity then
                    local left = (reserved[entry.itemID] or 0) - entry.quantity
                    if left < 0 then
                        left = 0
                    end
                    reserved[entry.itemID] = left
                end
            end
        end
    end
    return { EmptyPlan(shipment, firstTarget, "cross-realm-cancel", table.concat(lines, "\n")) }
end

--- Build plan(s) for one shipment. Role targets yield one plan per member.
---@param shipment table
---@param reserved table
---@param skipSet table|nil
---@return table plans
local function PlanShipment(shipment, reserved, skipSet)
    local plans
    if (shipment.kind or "items") == "gold" then
        plans = PlanGoldShipment(shipment, skipSet)
    else
        plans = PlanItemsShipment(shipment, reserved, skipSet)
    end
    return ApplyCrossRealmCancel(shipment, plans, reserved)
end

--- Dry-run plan for a selection of shipments.
---@param filter string|{ shipmentId?: string, shipmentIds?: table, mode?: string, skipTargets?: table }|nil
---@return table { plans = {}, jobs = {}, errors = {} }
function ShipmentEvaluator:Preview(filter)
    if type(filter) == "string" then
        filter = { shipmentId = filter }
    end
    filter = filter or {}

    local function selected(shipment)
        if filter.shipmentId then
            return shipment.id == filter.shipmentId
        end
        if filter.shipmentIds then
            return filter.shipmentIds[shipment.id] and true or false
        end
        if filter.mode then
            return (shipment.mode or "manual") == filter.mode
        end
        return false
    end

    local reserved = {}
    local result = { plans = {}, jobs = {}, errors = {} }
    local skipAll = filter.skipTargets or {}

    Trace("preview_start", {
        shipmentId = filter.shipmentId,
        mode = filter.mode,
        hasIds = filter.shipmentIds and true or false,
    })

    for _, shipment in ipairs(ns.db.global.mail.shipments or {}) do
        if selected(shipment) then
            local skipSet = skipAll[shipment.id]
            local plans = PlanShipment(shipment, reserved, skipSet)
            for _, plan in ipairs(plans) do
                tinsert(result.plans, plan)
                Trace("plan", {
                    shipmentId = shipment.id,
                    target = plan.target,
                    jobs = #(plan.jobs or {}),
                    skipReason = plan.skipReason,
                    error = plan.error,
                })
                if plan.error then
                    local err = plan.error
                    if err == "no target" then
                        err = ns.L["ERR_NO_TARGET"]
                    elseif err == "empty role" then
                        err = ns.L["ERR_EMPTY_ROLE"]
                    elseif err == "to self" then
                        err = ERR_MAIL_TO_SELF
                    end
                    tinsert(result.errors, (shipment.name or shipment.id) .. ": " .. err)
                end
                for _, job in ipairs(plan.jobs) do
                    tinsert(result.jobs, job)
                    if MT.enabled then
                        for _, loc in ipairs(job.slots or {}) do
                            MT:Record("eval", "slot", {
                                bag = loc.bag,
                                slot = loc.slot,
                                itemID = loc.itemID,
                                count = loc.count,
                                hasLink = LinkHasVisibleName(loc.link),
                                target = job.target,
                                shipmentId = job.shipmentId or shipment.id,
                            })
                        end
                    end
                end
            end
        end
    end
    return result
end

--- Evaluate and send.
---@param opts { dryRun?: boolean, shipmentId?: string, mode?: string, stopOnFailure?: boolean }
---@param onDone fun(ok: boolean, result: table, summary: table)|nil
function ShipmentEvaluator:Run(opts, onDone)
    opts = opts or {}
    local result = self:Preview({ shipmentId = opts.shipmentId, mode = opts.mode })
    if opts.dryRun or #result.jobs == 0 then
        if onDone then onDone(true, result, { sent = 0, failed = {} }) end
        return result
    end
    ns.SendQueue:Start(result.jobs, function(ok, summary)
        if onDone then onDone(ok, result, summary) end
    end, { stopOnFailure = opts.stopOnFailure })
    return result
end

--- Current role members excluding self (stable charKey order). Public for AutoRun.
---@param shipment table
---@return table charKeys
function ShipmentEvaluator:GetRoleMembers(shipment)
    local roleId = shipment and shipment.targetRoleId
    if not roleId or roleId == "" then
        return {}
    end
    local role = OneWoW.AltScope:GetRole(roleId)
    if not role then
        return {}
    end
    local members = {}
    for charKey in pairs(role.members or {}) do
        if not ns.AddressBook:IsSelfRecipient(charKey) then
            tinsert(members, charKey)
        end
    end
    sort(members)
    return members
end
