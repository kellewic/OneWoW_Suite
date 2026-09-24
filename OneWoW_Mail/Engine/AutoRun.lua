local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

-- ============================================================================
-- AutoRun
-- ============================================================================
-- Orchestrates per-shipment auto-run when the mailbox opens. Two phases:
--
--   Phase A: sends every eligible `mode == "auto"` shipment immediately.
--   Phase B: after A, dry-run plans eligible `mode == "auto_preview"` shipments
--   into display-only Activity intents.
--
-- Frequency:
--   "session" (default) — retry until that shipment succeeds this login/reload;
--     empty plans count as success. Forced close keeps retry state.
--   "visit" — every mailbox open; forced close discards pending (re-plans next).
--
-- Preview shows intent; Process re-plans. Held bag/slot plans are never executed.

ns.AutoRun = {}
local AutoRun = ns.AutoRun

local MT = ns.MailTrace
local function Trace(event, fields)
    if MT.enabled then
        MT:Record("autorun", event, fields)
    end
end

local SETTLE_DELAY = 0.5
local BUSY_RETRY = 1.0

local mailOpen = false
local visitToken = 0
local processing = false
local closing = false
local engineArmedThisVisit = false
local pendingIntents = {} -- display rows
local sessionDone = {} -- [shipmentId] = true (char targets, or role fully complete)
-- Role session successes: [shipmentId] = { [roleId] = { [charKey] = true } }
local sessionTargetDone = {}
local activeJobShipmentIds = {} -- ids touched by the in-flight auto/process run
local closeDialog

local function NotifyActivity()
    if ns.ActivityUI then
        ns.ActivityUI:Refresh()
    end
    if ns.Shell and ns.Shell.UpdateActivityBadge then
        ns.Shell:UpdateActivityBadge()
    end
end

local function IntentMatchesFilter(intent, filter)
    if not filter then
        return true
    end
    if filter.shipmentId and intent.shipmentId ~= filter.shipmentId then
        return false
    end
    if filter.target and intent.target ~= filter.target then
        return false
    end
    return true
end

local function GroupKey(shipmentId, target)
    return tostring(shipmentId or "") .. "\0" .. tostring(target or "")
end

local function LogPlanErrors(result)
    for _, err in ipairs(result.errors) do
        ns.RunLog:Add("warn", nil, nil, err)
    end
end

--- Info lines for eligible shipments that planned nothing (session: once when marked done).
local SKIP_MSG = {
    ["restock-met"] = "LOG_SKIP_RESTOCK_MET",
    ["keep-holds"] = "LOG_SKIP_KEEP_HOLDS",
    ["underfunded"] = "LOG_SKIP_UNDERFUNDED",
    ["cap-zero"] = "LOG_SKIP_CAP_ZERO",
    ["no-match"] = "LOG_SKIP_NO_MATCH",
    ["nothing"] = "LOG_SKIP_NOTHING",
    ["cross-realm-cancel"] = "LOG_SKIP_CROSS_REALM_CANCEL",
    ["cross-realm-warbound"] = "LOG_SKIP_CROSS_REALM_WARBAND",
    ["cross-realm-gold"] = "LOG_SKIP_CROSS_REALM_GOLD",
    ["cross-realm-other"] = "LOG_SKIP_CROSS_REALM_OTHER",
}

local function LogSkippedPlans(result)
    local L = ns.L
    for _, plan in ipairs(result.plans or {}) do
        if not plan.error and #(plan.jobs or {}) == 0 then
            local reason = plan.skipReason or "nothing"
            local key = SKIP_MSG[reason] or "LOG_SKIP_NOTHING"
            local name = plan.shipment and (plan.shipment.name or plan.shipment.id) or nil
            ns.RunLog:Add("info", name, plan.target, L[key], {
                code = reason,
                detail = plan.skipDetail,
            })
        end
        if plan.omitDetail then
            local name = plan.shipment and (plan.shipment.name or plan.shipment.id) or nil
            ns.RunLog:Add("info", name, plan.target, plan.omitDetail, {
                code = "cross-realm-omit",
            })
        end
    end
end

local function GetShipment(id)
    for _, s in ipairs(ns.db.global.mail.shipments or {}) do
        if s.id == id then
            return s
        end
    end
end

local function ShipmentFrequency(shipment)
    return shipment.frequency or "session"
end

local function IsRoleTarget(shipment)
    return (shipment.targetKind or "char") == "role"
end

local function PlanTargetKey(plan)
    local _, charKey = ns.AddressBook:IsSuiteAlt(plan.target)
    return charKey or plan.target
end

--- Whether every current role member has a success this session.
--- Missing/deleted/empty roles stay incomplete so Preview keeps surfacing the plan error.
local function IsRoleSessionComplete(shipment)
    if not IsRoleTarget(shipment) then
        return sessionDone[shipment.id] and true or false
    end
    local roleId = shipment.targetRoleId
    if not roleId or roleId == "" then
        return false
    end
    if not OneWoW.AltScope:GetRole(roleId) then
        return false
    end
    local members = ns.ShipmentEvaluator:GetRoleMembers(shipment)
    if #members == 0 then
        return false
    end
    local byRole = sessionTargetDone[shipment.id]
    local done = byRole and byRole[roleId]
    if not done then
        return false
    end
    for _, charKey in ipairs(members) do
        if not done[charKey] then
            return false
        end
    end
    return true
end

local function MarkTargetSuccess(shipment, targetKey)
    if ShipmentFrequency(shipment) ~= "session" then
        return
    end
    if IsRoleTarget(shipment) then
        local roleId = shipment.targetRoleId
        if not roleId or not targetKey then
            return
        end
        sessionTargetDone[shipment.id] = sessionTargetDone[shipment.id] or {}
        sessionTargetDone[shipment.id][roleId] = sessionTargetDone[shipment.id][roleId] or {}
        sessionTargetDone[shipment.id][roleId][targetKey] = true
        if IsRoleSessionComplete(shipment) then
            sessionDone[shipment.id] = true
        else
            sessionDone[shipment.id] = nil
        end
    else
        sessionDone[shipment.id] = true
    end
end

--- Skip map for evaluator: already-successful role members this session.
local function BuildSkipTargets(ids)
    local skip = {}
    for id in pairs(ids) do
        local shipment = GetShipment(id)
        if shipment and IsRoleTarget(shipment) then
            local roleId = shipment.targetRoleId
            local done = sessionTargetDone[id] and roleId and sessionTargetDone[id][roleId]
            if done then
                skip[id] = done
            end
        end
    end
    return skip
end

--- Eligible for auto-run this open: matching mode, and session not yet done.
local function CollectEligibleIds(mode)
    local ids = {}
    for _, shipment in ipairs(ns.db.global.mail.shipments or {}) do
        if (shipment.mode or "manual") == mode then
            local freq = ShipmentFrequency(shipment)
            if freq == "visit" then
                ids[shipment.id] = true
            elseif IsRoleTarget(shipment) then
                if not IsRoleSessionComplete(shipment) then
                    ids[shipment.id] = true
                else
                    sessionDone[shipment.id] = true
                end
            elseif not sessionDone[shipment.id] then
                ids[shipment.id] = true
            end
        end
    end
    return ids
end

local function MarkSessionResults(result, summary)
    local failedTargets = {} -- [shipmentId] = { [targetKey] = true }
    for _, f in ipairs((summary and summary.failed) or {}) do
        if f.job and f.job.shipmentId then
            local key = f.job.target
            local _, charKey = ns.AddressBook:IsSuiteAlt(key)
            key = charKey or key
            failedTargets[f.job.shipmentId] = failedTargets[f.job.shipmentId] or {}
            if key then
                failedTargets[f.job.shipmentId][key] = true
            end
            sessionDone[f.job.shipmentId] = nil
        end
    end
    for _, plan in ipairs(result.plans or {}) do
        local shipment = plan.shipment
        local id = shipment and shipment.id
        if id and ShipmentFrequency(shipment) == "session" and not plan.error then
            local targetKey = PlanTargetKey(plan)
            local failed = failedTargets[id] and targetKey and failedTargets[id][targetKey]
            if plan.skipReason == "cross-realm-cancel" then
                sessionDone[id] = nil
            elseif not failed then
                -- Success including empty plan / no jobs.
                MarkTargetSuccess(shipment, targetKey)
            end
        end
    end
end

local function MarkActiveIncomplete()
    for id in pairs(activeJobShipmentIds) do
        sessionDone[id] = nil
    end
    wipe(activeJobShipmentIds)
end

local function TrackJobs(jobs)
    wipe(activeJobShipmentIds)
    for _, job in ipairs(jobs or {}) do
        if job.shipmentId then
            activeJobShipmentIds[job.shipmentId] = true
        end
    end
end

local function CaptureIntents(result)
    wipe(pendingIntents)
    for _, plan in ipairs(result.plans) do
        local freq = ShipmentFrequency(plan.shipment)
        for _, entry in ipairs(plan.entries or {}) do
            tinsert(pendingIntents, {
                shipmentId = plan.shipment.id,
                shipmentName = plan.shipment.name or plan.shipment.id,
                target = plan.target,
                itemID = entry.itemID,
                link = entry.slots and entry.slots[1] and entry.slots[1].link,
                quantity = entry.quantity,
                money = entry.money,
                frequency = freq,
            })
        end
    end
    Trace("capture", { pending = #pendingIntents, jobs = #(result.jobs or {}) })
end

function AutoRun:GetPendingIntents()
    return pendingIntents
end

--- Collapse flat pending intents into ordered shipment+target groups.
---@return table[] groups
function AutoRun:GetPendingGroups()
    local groups = {}
    local indexByKey = {}
    for _, intent in ipairs(pendingIntents) do
        local key = GroupKey(intent.shipmentId, intent.target)
        local group = indexByKey[key]
        if not group then
            group = {
                shipmentId = intent.shipmentId,
                shipmentName = intent.shipmentName,
                target = intent.target,
                frequency = intent.frequency,
                intents = {},
            }
            indexByKey[key] = group
            tinsert(groups, group)
        end
        tinsert(group.intents, intent)
    end
    return groups
end

function AutoRun:GetPendingGroupCount()
    return #self:GetPendingGroups()
end

function AutoRun:ClearSessionFlags(shipmentId)
    if shipmentId then
        sessionDone[shipmentId] = nil
        sessionTargetDone[shipmentId] = nil
    end
end

--- Apply forced-close / Exit rules: cancel sends, session keeps retry, visit pending wiped.
function AutoRun:OnMailboxClosing(forced)
    Trace("mail_closed", { forced = forced and true or false })
    if ns.SendQueue:IsRunning() then
        ns.SendQueue:Cancel()
        MarkActiveIncomplete()
    end

    local hadVisitPending = false
    local hadSessionPending = false
    for _, intent in ipairs(pendingIntents) do
        if intent.frequency == "session" then
            hadSessionPending = true
            sessionDone[intent.shipmentId] = nil -- retry next open
        else
            hadVisitPending = true
        end
    end
    wipe(pendingIntents)

    if forced and (hadVisitPending or hadSessionPending) then
        if hadVisitPending and hadSessionPending then
            ns.RunLog:Add("warn", nil, nil, ns.L["LOG_CLOSE_MIXED"])
        elseif hadSessionPending then
            ns.RunLog:Add("warn", nil, nil, ns.L["LOG_CLOSE_SESSION_RETRY"])
        else
            ns.RunLog:Add("warn", nil, nil, ns.L["LOG_CLOSE_VISIT_DISCARD"])
        end
    end

    NotifyActivity()
end

local function PhaseB(token)
    if not mailOpen or token ~= visitToken then
        return
    end
    if ns.Shell and ns.Shell:UsesBlizzardUI() then
        return
    end
    local ids = CollectEligibleIds("auto_preview")
    local idCount = 0
    for _ in pairs(ids) do
        idCount = idCount + 1
    end
    Trace("phase_b_start", { eligible = idCount })
    local result = ns.ShipmentEvaluator:Preview({
        shipmentIds = ids,
        skipTargets = BuildSkipTargets(ids),
    })
    LogPlanErrors(result)
    LogSkippedPlans(result)
    CaptureIntents(result)
    -- Session shipments with nothing to send (and no plan error) mark per-target success.
    for id in pairs(ids) do
        local shipment = GetShipment(id)
        if shipment and ShipmentFrequency(shipment) == "session" then
            for _, plan in ipairs(result.plans) do
                if plan.shipment.id == id and not plan.error then
                    if #(plan.jobs or {}) == 0 then
                        MarkTargetSuccess(shipment, PlanTargetKey(plan))
                    end
                end
            end
        end
    end
    if #result.jobs > 0 then
        ns.RunLog:Add("info", nil, nil, string.format(ns.L["LOG_QUEUED_PREVIEW"], #result.jobs))
    end
    NotifyActivity()
end

local function PhaseA(token)
    if ns.Shell and ns.Shell:UsesBlizzardUI() then
        return
    end
    local ids = CollectEligibleIds("auto")
    local idCount = 0
    for _ in pairs(ids) do
        idCount = idCount + 1
    end
    Trace("phase_a_start", { eligible = idCount })
    local result = ns.ShipmentEvaluator:Preview({
        shipmentIds = ids,
        skipTargets = BuildSkipTargets(ids),
    })
    LogPlanErrors(result)
    LogSkippedPlans(result)
    TrackJobs(result.jobs)
    if #result.jobs == 0 then
        MarkSessionResults(result, { sent = 0, failed = {} })
        wipe(activeJobShipmentIds)
        PhaseB(token)
        return
    end
    ns.SendQueue:Start(result.jobs, function(_, summary)
        if token ~= visitToken then
            return
        end
        MarkSessionResults(result, summary)
        wipe(activeJobShipmentIds)
        if summary.sent > 0 then
            ns.RunLog:Add("info", nil, nil, string.format(ns.L["LOG_AUTO_DONE"], summary.sent))
        end
        PhaseB(token)
    end, { stopOnFailure = false })
end

--- Inbox auto-collect filter from db toggles (nil = off).
local function ResolveAutoCollectFilter()
    local mail = ns.db.global.mail
    local gold = mail.autoCollectGold
    local items = mail.autoCollectItems
    if gold and items then
        return "all"
    end
    if gold then
        return "gold"
    end
    if items then
        return "items"
    end
    return nil
end

--- Kick Collect once when the mailbox opens; AutoRun waits via TryStart busy-retry.
local function MaybeStartAutoCollect()
    if ns.Collect:IsRunning() or ns.SendQueue:IsRunning() then
        return
    end
    local filter = ResolveAutoCollectFilter()
    if not filter then
        return
    end
    ns.Collect:Start(filter, nil)
end

local function TryStart(token)
    if not mailOpen or token ~= visitToken then
        return
    end
    if ns.Shell and ns.Shell:UsesBlizzardUI() then
        return
    end
    if ns.Collect:IsRunning() or ns.SendQueue:IsRunning() then
        Trace("busy_retry", {
            collect = ns.Collect:IsRunning(),
            send = ns.SendQueue:IsRunning(),
        })
        C_Timer.After(BUSY_RETRY, function()
            TryStart(token)
        end)
        return
    end
    PhaseA(token)
end

local function EngineAllowed()
    return mailOpen and not (ns.Shell and ns.Shell:UsesBlizzardUI())
end

local function ArmEngine()
    if engineArmedThisVisit or not EngineAllowed() then
        return
    end
    engineArmedThisVisit = true
    local token = visitToken
    Trace("arm_engine", { token = token })
    C_Timer.After(SETTLE_DELAY, function()
        if not EngineAllowed() or token ~= visitToken then
            return
        end
        MaybeStartAutoCollect()
        TryStart(token)
    end)
end

--- Arm auto-collect / auto-run once per mailbox visit when One UI is showing.
function AutoRun:ArmEngineIfNeeded()
    ArmEngine()
end

--- Cancel in-flight settle/try without mailbox-close session rules.
function AutoRun:StandDownEngine()
    Trace("stand_down", { armed = engineArmedThisVisit })
    visitToken = visitToken + 1
    if ns.Collect and ns.Collect:IsRunning() then
        ns.Collect:Cancel()
    end
end

--- Narrow Preview result to one mail target (role shipments plan every member).
local function FilterResultToTarget(result, target)
    if not target then
        return
    end
    local plans = {}
    for _, plan in ipairs(result.plans or {}) do
        if plan.target == target then
            tinsert(plans, plan)
        end
    end
    result.plans = plans
    local jobs = {}
    for _, job in ipairs(result.jobs or {}) do
        if job.target == target then
            tinsert(jobs, job)
        end
    end
    result.jobs = jobs
end

--- Process held preview intents. Optional filter = { shipmentId=, target= } for one group.
---@param onDone fun(ok: boolean)|nil
---@param filter { shipmentId?: string, target?: string }|nil
function AutoRun:Process(onDone, filter)
    if processing or ns.SendQueue:IsRunning() or ns.Collect:IsRunning() then
        if onDone then onDone(false) end
        return
    end
    if #pendingIntents == 0 then
        if onDone then onDone(true) end
        return
    end

    local ids = {}
    local kept = {}
    local matched = false
    for _, intent in ipairs(pendingIntents) do
        if IntentMatchesFilter(intent, filter) then
            ids[intent.shipmentId] = true
            matched = true
        else
            tinsert(kept, intent)
        end
    end
    if filter and not matched then
        if onDone then onDone(true) end
        return
    end

    Trace("process", {
        filter = filter and true or false,
        shipmentId = filter and filter.shipmentId,
        target = filter and filter.target,
        pendingBefore = #pendingIntents,
    })
    processing = true
    wipe(pendingIntents)
    for _, intent in ipairs(kept) do
        tinsert(pendingIntents, intent)
    end
    NotifyActivity()

    local result = ns.ShipmentEvaluator:Preview({
        shipmentIds = ids,
        skipTargets = BuildSkipTargets(ids),
    })
    if filter and filter.target then
        FilterResultToTarget(result, filter.target)
    end
    TrackJobs(result.jobs)
    if #result.jobs == 0 then
        processing = false
        MarkSessionResults(result, { sent = 0, failed = {} })
        wipe(activeJobShipmentIds)
        LogPlanErrors(result)
        LogSkippedPlans(result)
        NotifyActivity()
        if onDone then onDone(true) end
        return
    end
    ns.SendQueue:Start(result.jobs, function(_, summary)
        processing = false
        LogPlanErrors(result)
        -- Skips among the held set that re-planned empty (e.g. bags changed).
        LogSkippedPlans(result)
        MarkSessionResults(result, summary)
        wipe(activeJobShipmentIds)
        if summary.sent > 0 then
            ns.RunLog:Add("info", nil, nil, string.format(ns.L["LOG_PROCESS_DONE"], summary.sent))
        end
        NotifyActivity()
        if onDone then onDone(#summary.failed == 0) end
    end, { stopOnFailure = false })
end

--- Discard held intents. Optional filter = { shipmentId=, target= } for one group.
---@param filter { shipmentId?: string, target?: string }|nil
function AutoRun:Discard(filter)
    -- Manual discard from Activity: abandon held intents; session shipments
    -- remain eligible (not marked done) so they re-plan next open / Process.
    Trace("discard", {
        filter = filter and true or false,
        shipmentId = filter and filter.shipmentId,
        target = filter and filter.target,
        pendingBefore = #pendingIntents,
    })
    local kept = {}
    local clearedIds = {}
    for _, intent in ipairs(pendingIntents) do
        if IntentMatchesFilter(intent, filter) then
            if intent.frequency == "session" then
                clearedIds[intent.shipmentId] = true
            end
        else
            tinsert(kept, intent)
        end
    end
    for id in pairs(clearedIds) do
        sessionDone[id] = nil
    end
    wipe(pendingIntents)
    for _, intent in ipairs(kept) do
        tinsert(pendingIntents, intent)
    end
    NotifyActivity()
end

function AutoRun:IsProcessing()
    return processing
end

function AutoRun:HasPending()
    return #pendingIntents > 0
end

local function HideCloseDialog()
    if closeDialog and closeDialog.frame then
        closeDialog.frame:Hide()
    end
end

--- Intentional close while pending review: Process / Exit / Go Back.
---@param proceed fun() called to actually close the mailbox
function AutoRun:RequestClose(proceed)
    -- `closing` latches while Exit/Process from the confirm dialog runs. If that
    -- path never got MAIL_CLOSED (shell-only hide), the latch stuck and the X
    -- became a silent no-op — recover when nothing is actually in flight.
    if closing then
        if processing or ns.SendQueue:IsRunning() then
            Trace("request_close_blocked", {
                processing = processing,
                send = ns.SendQueue:IsRunning(),
            })
            return
        end
        Trace("request_close_unstick", {})
        closing = false
    end
    if not self:HasPending() then
        proceed()
        return
    end

    local L = ns.L
    if not closeDialog then
        closeDialog = OneWoW_GUI:CreateDialog({
            name = "OneWoW_MailPendingClose",
            title = L["CLOSE_PENDING_TITLE"],
            width = 420,
            height = 160,
            escClose = false,
            showBrand = false,
            buttons = {
                {
                    text = L["CLOSE_PENDING_BACK"],
                    onClick = function(frame)
                        frame:Hide()
                    end,
                },
                {
                    text = L["CLOSE_PENDING_EXIT"],
                    onClick = function(frame)
                        frame:Hide()
                        closing = true
                        AutoRun:OnMailboxClosing(false)
                        proceed()
                        -- MAIL_CLOSED clears `closing`. If it never fires (shell-only
                        -- hide), RequestClose recovers the latch on the next X click.
                    end,
                },
                {
                    text = L["BTN_PROCESS"],
                    onClick = function(frame)
                        frame:Hide()
                        closing = true
                        AutoRun:Process(function()
                            closing = false
                            proceed()
                        end)
                    end,
                },
            },
        })
        local msg = OneWoW_GUI:CreateFS(closeDialog.contentFrame, 12)
        msg:SetPoint("TOPLEFT", closeDialog.contentFrame, "TOPLEFT", 16, -16)
        msg:SetPoint("TOPRIGHT", closeDialog.contentFrame, "TOPRIGHT", -16, -16)
        msg:SetJustifyH("LEFT")
        msg:SetWordWrap(true)
        closeDialog.message = msg
    end
    closeDialog.message:SetText(L["CLOSE_PENDING_BODY"])
    closeDialog.frame:Show()
    closeDialog.frame:Raise()
end

function AutoRun:Initialize()
    if self._wired then
        return
    end
    self._wired = true

    local f = CreateFrame("Frame")
    f:RegisterEvent("MAIL_SHOW")
    f:RegisterEvent("MAIL_CLOSED")
    f:SetScript("OnEvent", function(_, event)
        if event == "MAIL_SHOW" then
            -- Always accept a new visit. Sticky mailOpen used to block reopens
            -- when MAIL_CLOSED was missed (Escape without CloseMail, etc.).
            HideCloseDialog()
            closing = false
            mailOpen = true
            engineArmedThisVisit = false
            visitToken = visitToken + 1
            Trace("mail_show", { token = visitToken })
            ArmEngine()
        else
            mailOpen = false
            engineArmedThisVisit = false
            visitToken = visitToken + 1 -- invalidate in-flight settle/try
            HideCloseDialog()
            -- Forced path when Shell didn't already run RequestClose/OnMailboxClosing.
            if not closing then
                AutoRun:OnMailboxClosing(true)
            end
            closing = false
        end
    end)
end
