local _, ns = ...

local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetServerTime = GetServerTime
local GetTime = GetTime
local math = math
local pairs = pairs
local tinsert = tinsert
local C_AuctionHouse = C_AuctionHouse
local C_Item = C_Item

ns.AHReplicateScanner = ns.AHReplicateScanner or {}
local Scanner = ns.AHReplicateScanner

local AHItemKeys = OneWoW.AHItemKeys
local BATCH_SIZE = 250
local EMPTY_REPLICATE_TIMEOUT = 90

local scanState = nil
local scanFrame = nil

local pendingItemLoads = {}
local itemLoadFrame = CreateFrame("Frame")
itemLoadFrame.elapsed = 0
itemLoadFrame:SetScript("OnEvent", function(_, _, itemID)
    local callbacks = pendingItemLoads[itemID]
    if callbacks then
        pendingItemLoads[itemID] = nil
        for _, fn in ipairs(callbacks) do
            fn()
        end
    end
end)

local function RequestItemData(itemID, callback)
    pendingItemLoads[itemID] = pendingItemLoads[itemID] or {}
    tinsert(pendingItemLoads[itemID], callback)
    itemLoadFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    itemLoadFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed > 0.4 then
            for id in pairs(pendingItemLoads) do
                C_Item.RequestLoadItemDataByID(id)
            end
            self.elapsed = 0
        end
        if not next(pendingItemLoads) then
            self.elapsed = 0
            self:SetScript("OnUpdate", nil)
            self:UnregisterEvent("ITEM_DATA_LOAD_RESULT")
        end
    end)
    C_Item.RequestLoadItemDataByID(itemID)
end

local function GetOrCreateScanFrame()
    if scanFrame then return scanFrame end
    -- Do not parent this to AuctionHouseFrame: children of that secure frame
    -- can miss REPLICATE_ITEM_LIST_UPDATE. The wait ticker also polls
    -- GetNumReplicateItems so a scan still starts if another addon already
    -- filled the replicate buffer (event already fired).
    scanFrame = CreateFrame("Frame", "OneWoW_AHReplicateScanFrame")
    scanFrame:SetScript("OnEvent", function(_, event, ...)
        Scanner:HandleEvent(event, ...)
    end)
    return scanFrame
end

function Scanner:Initialize()
end

function Scanner:HandleEvent(event)
    if event == "REPLICATE_ITEM_LIST_UPDATE" then
        if C_AuctionHouse.GetNumReplicateItems() > 0 then
            self:BeginCache()
        end
    elseif event == "AUCTION_HOUSE_CLOSED" or event == "AUCTION_HOUSE_DISABLED" then
        if scanFrame then
            scanFrame:UnregisterEvent("AUCTION_HOUSE_CLOSED")
            scanFrame:UnregisterEvent("AUCTION_HOUSE_DISABLED")
        end
        if scanState and scanState.isScanning then
            self:AbortScan()
        end
        if ns.AHScanCoordinator then
            ns.AHScanCoordinator:OnAuctionHouseClosed()
        end
    end
end

function Scanner:IsScanning()
    return scanState and scanState.isScanning or false
end

function Scanner:BeginCache()
    if not scanState or not scanState.isScanning or scanState.caching then
        return
    end
    scanState.caching = true
    if scanFrame then
        scanFrame:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
    end
    if scanState.waitingTicker then
        scanState.waitingTicker:Cancel()
        scanState.waitingTicker = nil
    end
    self:CacheScanData()
end

function Scanner:StartScan(callback)
    if scanState and scanState.isScanning then return false end
    if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then return false end

    local frame = GetOrCreateScanFrame()

    scanState = {
        isScanning = true,
        caching = false,
        callback = callback,
        newEntries = ns.AHPriceCache:NewEntriesTable(),
        pendingRows = 0,
        waitingTicker = nil,
        waitStartTime = GetTime(),
        realmID = ns.AHPriceCache:GetRealmID(),
    }

    if callback then callback("scanStarted", 0) end

    scanState.waitingTicker = C_Timer.NewTicker(1, function()
        if not scanState or not scanState.isScanning or scanState.caching then return end
        local elapsed = math.floor(GetTime() - scanState.waitStartTime)
        if scanState.callback then
            scanState.callback("scanWaiting", 0.1, elapsed)
        end
        local n = C_AuctionHouse.GetNumReplicateItems()
        if n > 0 or elapsed >= EMPTY_REPLICATE_TIMEOUT then
            Scanner:BeginCache()
        end
    end)

    if callback then callback("scanWaiting", 0.1, 0) end

    frame:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
    frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
    frame:RegisterEvent("AUCTION_HOUSE_DISABLED")
    C_AuctionHouse.ReplicateItems()
    if C_AuctionHouse.GetNumReplicateItems() > 0 then
        self:BeginCache()
    end

    return true
end

function Scanner:StopScan()
    if not scanState then return end
    local cb = scanState.callback
    if scanFrame then
        scanFrame:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
        scanFrame:UnregisterEvent("AUCTION_HOUSE_CLOSED")
        scanFrame:UnregisterEvent("AUCTION_HOUSE_DISABLED")
    end
    if scanState.waitingTicker then
        scanState.waitingTicker:Cancel()
    end
    scanState.isScanning = false
    scanState = nil
    if cb then cb("scanStopped") end
end

function Scanner:AbortScan()
    if not scanState then return end
    local cb = scanState.callback
    if scanFrame then
        scanFrame:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
        scanFrame:UnregisterEvent("AUCTION_HOUSE_CLOSED")
        scanFrame:UnregisterEvent("AUCTION_HOUSE_DISABLED")
    end
    if scanState.waitingTicker then
        scanState.waitingTicker:Cancel()
    end
    scanState.isScanning = false
    scanState = nil
    if cb then cb("scanFailed") end
end

function Scanner:ProcessRowAsync(index, serverTime, onDone)
    local _, _, count, _, _, _, _, _, _, buyoutPrice, _, _, _, _, _, _, itemID, hasAllInfo =
        C_AuctionHouse.GetReplicateItemInfo(index)

    if not itemID or itemID <= 0 or not C_Item.DoesItemExistByID(itemID) then
        onDone()
        return
    end
    if not count or count <= 0 or not buyoutPrice or buyoutPrice <= 0 then
        onDone()
        return
    end

    local unitPrice = math.floor(buyoutPrice / count)

    local function finishRow()
        local storageKey = AHItemKeys:KeysFromReplicateIndex(index)
        if storageKey then
            ns.AHPriceCache:RecordMinPrice(scanState.newEntries, storageKey, unitPrice, serverTime)
        end
        onDone()
    end

    if hasAllInfo then
        finishRow()
    else
        RequestItemData(itemID, finishRow)
    end
end

function Scanner:CacheScanData()
    if not scanState or not scanState.isScanning then return end

    local callback = scanState.callback
    if callback then callback("scanProgress", 0.2) end

    local totalItems = C_AuctionHouse.GetNumReplicateItems()
    if not totalItems or totalItems == 0 then
        self:CompleteScan(0)
        return
    end

    local serverTime = GetServerTime()
    local limit = totalItems
    local processed = 0
    scanState.pendingRows = limit

    local function rowDone()
        if not scanState or not scanState.isScanning then return end
        processed = processed + 1
        scanState.pendingRows = scanState.pendingRows - 1
        local progress = 0.2 + (processed / limit) * 0.8
        if callback then callback("scanProgress", progress, limit) end
        if scanState.pendingRows <= 0 then
            self:CompleteScan(self:CountEntries(scanState.newEntries))
        end
    end

    local function ProcessBatch(startIndex)
        if not scanState or not scanState.isScanning then return end

        local endIndex = math.min(startIndex + BATCH_SIZE - 1, limit - 1)
        for i = startIndex, endIndex do
            self:ProcessRowAsync(i, serverTime, rowDone)
        end

        if endIndex < limit - 1 then
            C_Timer.After(0.01, function()
                ProcessBatch(endIndex + 1)
            end)
        end
    end

    ProcessBatch(0)
end

function Scanner:CountEntries(entries)
    local n = 0
    for _ in pairs(entries) do
        n = n + 1
    end
    return n
end

function Scanner:CompleteScan(pricesFound)
    if not scanState then return end
    local cb = scanState.callback
    local realmID = scanState.realmID
    local newEntries = scanState.newEntries

    if scanState.waitingTicker then
        scanState.waitingTicker:Cancel()
    end
    if scanFrame then
        scanFrame:UnregisterEvent("AUCTION_HOUSE_CLOSED")
        scanFrame:UnregisterEvent("AUCTION_HOUSE_DISABLED")
    end

    ns.AHPriceCache:ReplaceRealmEntries(realmID, newEntries, pricesFound)

    scanState.isScanning = false
    scanState = nil
    if cb then cb("scanCompleted", 1.0, pricesFound) end
end
