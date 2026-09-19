local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local SE = OneWoW.SearchExpand

ns.UI = ns.UI or {}

local selectedAltKey = nil
local selectedRealm = nil
local itemSearchText = ""
local currentSortColumn = "time"
local currentSortAscending = false
local listEntries = {}
local expandedByKey = {}
local listAPI = nil
local activeAuctionsTab = nil
local historyJob = nil
local AUC_ROW_HEIGHT = 32
local AUC_ROW_GAP = 2
local AUC_DETAIL_HEIGHT = 110
local AUC_TX_STRIDE = AUC_ROW_HEIGHT + AUC_ROW_GAP
local AUC_DETAIL_STRIDE = AUC_DETAIL_HEIGHT + AUC_ROW_GAP

local columnsConfig = {
    {key = "expand", label = "", width = 25, fixed = true, align = "icon", sortable = false, ttTitle = L["TT_COL_EXPAND"], ttDesc = L["TT_COL_EXPAND_DESC"]},
    {key = "item", label = L["ITEM"], width = 150, fixed = false, align = "left", ttTitle = L["ITEM"], ttDesc = L["TT_COL_ITEM_DESC"]},
    {key = "qty", label = L["AUCTIONS_COL_QTY"], width = 40, fixed = true, align = "center", ttTitle = L["TT_COL_QTY"], ttDesc = L["TT_COL_QTY_DESC"]},
    {key = "each", label = L["TT_COL_EACH"], width = 60, fixed = false, align = "left", ttTitle = L["TT_COL_EACH"], ttDesc = L["TT_COL_EACH_DESC"]},
    {key = "total", label = TOTAL, width = 70, fixed = false, align = "left", ttTitle = TOTAL, ttDesc = L["TT_COL_TOTAL_DESC"]},
    {key = "bid", label = BID, width = 60, fixed = false, align = "left", ttTitle = BID, ttDesc = L["TT_COL_BID_DESC"]},
    {key = "time", label = L["TT_COL_TIME"], width = 50, fixed = true, align = "center", ttTitle = L["TT_COL_TIME"], ttDesc = L["TT_COL_TIME_DESC"]},
    {key = "character", label = CHARACTER, width = 100, fixed = false, align = "left", ttTitle = CHARACTER, ttDesc = L["TT_COL_CHARACTER_AUCTION_DESC"]},
    {key = "server", label = L["COL_SERVER"], width = 70, fixed = false, align = "left", ttTitle = L["COL_SERVER"], ttDesc = L["TT_COL_SERVER_DESC"]},
    {key = "faction", label = L["COL_FACTION"], width = 25, fixed = true, align = "icon", sortable = false, ttTitle = FACTION, ttDesc = L["TT_COL_FACTION_DESC"]},
    {key = "status", label = STATUS, width = 60, fixed = false, align = "left", ttTitle = STATUS, ttDesc = L["TT_COL_AUCTION_STATUS_DESC"]},
    {key = "delete", label = L["AUCTIONS_COL_DELETE"], width = 50, fixed = true, align = "center", sortable = false, ttTitle = DELETE, ttDesc = L["TT_COL_DELETE_DESC"]}
}

local onHeaderCreate = function(btn, col, _)
    if col.key == "expand" then
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("CENTER")
        icon:SetAtlas("Gamepad_Rev_Plus_64")
        btn.icon = icon
        if btn.text then btn.text:SetText("") end
    end
end

local function AuctionItemData(entry)
    if not entry then
        return nil
    end
    return entry.auction or entry.bid or entry.history
end

local function AuctionExpandKey(entry)
    local item = AuctionItemData(entry)
    if not entry or not item then
        return ""
    end
    return table.concat({
        entry.type or "",
        entry.charKey or "",
        tostring(item.auctionID or ""),
        tostring(item.timestamp or item.endsAt or 0),
    }, "\031")
end

local function BuildAuctionListEntries(auctions)
    wipe(listEntries)
    for _, entry in ipairs(auctions or {}) do
        tinsert(listEntries, { type = "row", entry = entry })
        local key = AuctionExpandKey(entry)
        if key ~= "" and expandedByKey[key] then
            tinsert(listEntries, { type = "detail", entry = entry, key = key })
        end
    end
end

local function LayoutAuctionCells(row, dt)
    if not (dt and dt.headerRow and dt.headerRow.columnButtons and row.cells) then
        return
    end
    for ci, cell in ipairs(row.cells) do
        local btn = dt.headerRow.columnButtons[ci]
        if btn and btn.columnWidth and btn.columnX then
            local width = btn.columnWidth
            local x = btn.columnX
            local col = columnsConfig[ci]
            cell:ClearAllPoints()
            if col and col.align == "icon" then
                cell:SetSize(width, AUC_ROW_HEIGHT)
                cell:SetPoint("LEFT", row, "LEFT", x, 0)
            elseif col and col.align == "center" then
                cell:SetWidth(width - 6)
                cell:SetPoint("CENTER", row, "LEFT", x + width / 2, 0)
            elseif col and col.align == "right" then
                cell:SetWidth(width - 6)
                cell:SetPoint("RIGHT", row, "LEFT", x + width - 3, 0)
            else
                cell:SetWidth(width - 6)
                cell:SetPoint("LEFT", row, "LEFT", x + 3, 0)
            end
        end
    end
end

local function SetFactionIcon(frame, faction)
    if not (frame and frame.icon) then
        return
    end
    if faction == "Alliance" then
        frame.icon:SetTexture("Interface\\FriendsFrame\\PlusManz-Alliance")
        frame.icon:SetDesaturated(false)
    elseif faction == "Horde" then
        frame.icon:SetTexture("Interface\\FriendsFrame\\PlusManz-Horde")
        frame.icon:SetDesaturated(false)
    else
        frame.icon:SetTexture("Interface\\FriendsFrame\\PlusManz-Alliance")
        frame.icon:SetDesaturated(true)
    end
end

local function FormatStamp(ts)
    if not ts or ts <= 0 then
        return "-"
    end
    return date("%Y-%m-%d %H:%M", ts)
end

local function FormatDurationSecs(secs)
    if not secs or secs < 0 then
        return "-"
    end
    if secs < 60 then
        return math.floor(secs) .. "s"
    elseif secs < 3600 then
        return math.floor(secs / 60) .. "m"
    elseif secs < 86400 then
        local h = math.floor(secs / 3600)
        local m = math.floor((secs % 3600) / 60)
        if m > 0 then
            return h .. "h " .. m .. "m"
        end
        return h .. "h"
    else
        local d = math.floor(secs / 86400)
        local h = math.floor((secs % 86400) / 3600)
        if h > 0 then
            return d .. "d " .. h .. "h"
        end
        return d .. "d"
    end
end

local function DetectionMethodLabel(method)
    if method == "status_field" then
        return L["AUCTIONS_DETECT_STATUS"]
    elseif method == "snapshot_comparison" or method == "snapshot" then
        return L["AUCTIONS_DETECT_SNAPSHOT"]
    elseif method == "notification" then
        return L["AUCTIONS_DETECT_NOTIFICATION"]
    elseif method == "mail" then
        return L["MAIL"]
    end
    return method or "-"
end

local function BidTimeLeftLabel(timeLeft)
    if timeLeft == 0 then
        return AUCTION_TIME_LEFT0
    elseif timeLeft == 1 then
        return AUCTION_TIME_LEFT1
    elseif timeLeft == 2 then
        return AUCTION_TIME_LEFT2
    elseif timeLeft == 3 then
        return AUCTION_TIME_LEFT3
    elseif timeLeft == 4 then
        return AUCTION_TIME_LEFT4
    end
    return "-"
end

local function OutcomeLabel(outcome)
    if outcome == "sold" then
        return L["OUTCOME_SOLD"]
    elseif outcome == "expired" then
        return L["OUTCOME_EXPIRED"]
    elseif outcome == "canceled" then
        return L["OUTCOME_CANCELED"]
    end
    return outcome or "-"
end

local function GetMarketPriceText(itemID, itemLink)
    local info = OneWoW_AltTracker_Auctions_API.GetPrice(itemID, itemLink)
    if info and info.price and info.price > 0 then
        return L["AUCTIONS_EXP_MARKET"] .. " " .. ns.AltTrackerFormatters:FormatGold(info.price)
    end
    return nil
end

local function GetAHMailGoldForItem(charKey, itemName)
    if not OneWoW_AltTracker_Storage_API or not itemName then
        return 0
    end
    local storageData = OneWoW_AltTracker_Storage_API.GetCharacters()[charKey]
    if not (storageData and storageData.mail and storageData.mail.mails) then
        return 0
    end
    local total = 0
    for _, mailData in pairs(storageData.mail.mails) do
        if mailData.sender and (mailData.sender == "Auction House" or mailData.sender == "The Auction House")
            and mailData.money and mailData.money > 0 then
            local subjectItem = mailData.subject and mailData.subject:match("Auction successful: (.+)")
            if subjectItem then
                subjectItem = subjectItem:match("^(.-)%s*%(%d+%)$") or subjectItem
                if subjectItem == itemName then
                    total = total + mailData.money
                end
            end
        end
    end
    return total
end

local function EntryEachAmount(entry)
    local history = entry.history
    local auction = entry.auction
    local bid = entry.bid
    if history then
        local qty = history.quantity or 0
        return qty > 0 and math.floor((history.listPrice or 0) / qty) or 0
    elseif auction then
        local qty = auction.quantity or 0
        return qty > 0 and math.floor((auction.buyoutAmount or 0) / qty) or 0
    elseif bid then
        local qty = bid.quantity or 0
        return qty > 0 and math.floor((bid.bidAmount or 0) / qty) or 0
    end
    return 0
end

local function EntryTotalAmount(entry)
    local history = entry.history
    local auction = entry.auction
    local bid = entry.bid
    if history then
        return history.listPrice or 0
    elseif auction then
        return auction.buyoutAmount or 0
    elseif bid then
        return bid.bidAmount or 0
    end
    return 0
end

local function EntryBidAmount(entry)
    local history = entry.history
    local auction = entry.auction
    local bid = entry.bid
    if history then
        return history.salePrice or 0
    elseif auction then
        return auction.bidAmount or 0
    elseif bid then
        return bid.bidAmount or 0
    end
    return 0
end

local function EntryTimeValue(entry)
    local history = entry.history
    local auction = entry.auction
    local bid = entry.bid
    if history then
        return history.timestamp or 0
    elseif auction then
        return auction.endsAt or 0
    elseif bid then
        return bid.collectedAt or 0
    end
    return 0
end

local function EntryStatusSortKey(entry)
    if entry.type == "history" and entry.history then
        return entry.history.outcome or ""
    elseif entry.type == "auction" then
        return "active"
    elseif entry.type == "bid" then
        return "bidding"
    end
    return ""
end

local function CompareAuctionEntries(a, b)
    local aVal, bVal

    if currentSortColumn == "item" then
        local aItem = AuctionItemData(a)
        local bItem = AuctionItemData(b)
        aVal = (aItem and aItem.itemName) or ""
        bVal = (bItem and bItem.itemName) or ""
    elseif currentSortColumn == "qty" then
        local aItem = AuctionItemData(a)
        local bItem = AuctionItemData(b)
        aVal = (aItem and aItem.quantity) or 0
        bVal = (bItem and bItem.quantity) or 0
    elseif currentSortColumn == "each" then
        aVal = EntryEachAmount(a)
        bVal = EntryEachAmount(b)
    elseif currentSortColumn == "total" then
        aVal = EntryTotalAmount(a)
        bVal = EntryTotalAmount(b)
    elseif currentSortColumn == "bid" then
        aVal = EntryBidAmount(a)
        bVal = EntryBidAmount(b)
    elseif currentSortColumn == "time" then
        aVal = EntryTimeValue(a)
        bVal = EntryTimeValue(b)
    elseif currentSortColumn == "character" then
        aVal = (a.charData and a.charData.name) or a.charKey or ""
        bVal = (b.charData and b.charData.name) or b.charKey or ""
    elseif currentSortColumn == "server" then
        aVal = (a.charData and a.charData.realm) or ""
        bVal = (b.charData and b.charData.realm) or ""
    elseif currentSortColumn == "status" then
        aVal = EntryStatusSortKey(a)
        bVal = EntryStatusSortKey(b)
    else
        aVal = EntryTimeValue(a)
        bVal = EntryTimeValue(b)
    end

    if aVal == bVal then
        return false
    end
    if currentSortAscending then
        return aVal < bVal
    end
    return aVal > bVal
end

-- PredicateEngine + SearchExpand (#tokens / saved shortcuts), matching Items/Bank.
-- Falls back to literal name substring if compile/eval fails.
local function MatchesItemSearch(entry, searchText)
    if not searchText or searchText == "" then
        return true
    end
    local item = AuctionItemData(entry)
    if not item then
        return false
    end
    if item.itemID then
        local itemInfo = {
            hyperlink = item.itemLink,
            count = item.quantity or 1,
            quality = item.itemRarity,
        }
        local ok, matched = pcall(SE.CheckItem, SE, searchText, item.itemID, nil, nil, itemInfo)
        if ok then
            return matched == true
        end
    end
    local name = item.itemName
    return name and name:lower():find(searchText:lower(), 1, true) ~= nil
end

local function ApplyRealmAndSearch(auctions)
    local searchText = itemSearchText or ""
    local filtered = {}
    for _, entry in ipairs(auctions) do
        local realm = entry.charData and entry.charData.realm or ""
        if (not selectedRealm or realm == selectedRealm) and MatchesItemSearch(entry, searchText) then
            tinsert(filtered, entry)
        end
    end
    return filtered
end

local function GatherRealms(auctions)
    local seen = {}
    local realms = {}
    for _, entry in ipairs(auctions) do
        local realm = entry.charData and entry.charData.realm
        if realm and realm ~= "" and not seen[realm] then
            seen[realm] = true
            tinsert(realms, realm)
        end
    end
    sort(realms)
    return realms
end

local function CharDisplayData(charKey)
    local charInfo = OneWoW_AltTracker_Character_API and OneWoW_AltTracker_Character_API.GetCharacterData(charKey)
    return {
        name = (charInfo and charInfo.name) or charKey:match("^([^%-]+)"),
        class = (charInfo and charInfo.class) or "WARRIOR",
        faction = (charInfo and charInfo.faction) or "Alliance",
        realm = (charInfo and charInfo.realm) or charKey:match("-(.+)$") or "",
    }
end

local function CollectTypeFilteredAuctions(currentFilter, shouldYield)
    local allAuctions = {}
    local YieldIfNeeded = OneWoW.ChunkedJob.YieldIfNeeded

    for charKey, auctionData in pairs(OneWoW_AltTracker_Auctions_API.GetCharacters()) do
        if not selectedAltKey or charKey == selectedAltKey then
            local charDisplayData = CharDisplayData(charKey)

            if currentFilter == "history" then
                if auctionData.auctionHistory then
                    for _, historyEvent in ipairs(auctionData.auctionHistory) do
                        tinsert(allAuctions, {
                            charKey = charKey,
                            charData = charDisplayData,
                            history = historyEvent,
                            type = "history",
                        })
                        if shouldYield then
                            YieldIfNeeded(shouldYield)
                        end
                    end
                end
            elseif currentFilter == "expiring" then
                if auctionData.activeAuctions then
                    local serverTime = GetServerTime()
                    local twoHours = 7200
                    for _, auction in ipairs(auctionData.activeAuctions) do
                        if auction.endsAt then
                            local timeLeft = auction.endsAt - serverTime
                            if timeLeft > 0 and timeLeft < twoHours then
                                tinsert(allAuctions, {
                                    charKey = charKey,
                                    charData = charDisplayData,
                                    auction = auction,
                                    type = "auction",
                                    sortValue = timeLeft,
                                })
                            end
                        end
                        if shouldYield then
                            YieldIfNeeded(shouldYield)
                        end
                    end
                end
            else
                if auctionData.activeAuctions and (currentFilter == "all" or currentFilter == "auctions") then
                    for _, auction in ipairs(auctionData.activeAuctions) do
                        tinsert(allAuctions, {
                            charKey = charKey,
                            charData = charDisplayData,
                            auction = auction,
                            type = "auction",
                        })
                        if shouldYield then
                            YieldIfNeeded(shouldYield)
                        end
                    end
                end

                if auctionData.activeBids and (currentFilter == "all" or currentFilter == "bids") then
                    for _, bid in ipairs(auctionData.activeBids) do
                        tinsert(allAuctions, {
                            charKey = charKey,
                            charData = charDisplayData,
                            bid = bid,
                            type = "bid",
                        })
                        if shouldYield then
                            YieldIfNeeded(shouldYield)
                        end
                    end
                end
            end
        end
        if shouldYield then
            YieldIfNeeded(shouldYield)
        end
    end

    return allAuctions
end

local function ToggleAuctionExpand(entry)
    local key = AuctionExpandKey(entry)
    if key == "" then
        return
    end
    expandedByKey[key] = not expandedByKey[key]
    local tab = activeAuctionsTab
    if not tab then
        return
    end
    BuildAuctionListEntries(tab._auctions)
    if listAPI then
        listAPI.Refresh()
    end
end

local function DeleteAuctionEntry(entry)
    local tab = activeAuctionsTab
    if not entry or not OneWoW_AltTracker_Auctions_API then
        return
    end
    local auctionChars = OneWoW_AltTracker_Auctions_API.GetCharacters()
    local charAuctionData = auctionChars and auctionChars[entry.charKey]
    if not charAuctionData then
        return
    end

    local history = entry.history
    local bid = entry.bid
    local auction = entry.auction

    if entry.type == "history" and history then
        if charAuctionData.auctionHistory then
            for idx, event in ipairs(charAuctionData.auctionHistory) do
                if event.auctionID == history.auctionID and event.timestamp == history.timestamp then
                    tremove(charAuctionData.auctionHistory, idx)
                    break
                end
            end
        end
    elseif entry.type == "bid" and bid then
        if charAuctionData.activeBids then
            for idx, b in ipairs(charAuctionData.activeBids) do
                if b.auctionID == bid.auctionID then
                    tremove(charAuctionData.activeBids, idx)
                    charAuctionData.numActiveBids = #charAuctionData.activeBids
                    break
                end
            end
        end
    elseif auction then
        if charAuctionData.activeAuctions then
            for idx, a in ipairs(charAuctionData.activeAuctions) do
                if a.auctionID == auction.auctionID then
                    tremove(charAuctionData.activeAuctions, idx)
                    charAuctionData.numActiveAuctions = #charAuctionData.activeAuctions
                    local totalValue = 0
                    for _, remaining in ipairs(charAuctionData.activeAuctions) do
                        totalValue = totalValue + (remaining.buyoutAmount or 0)
                    end
                    charAuctionData.totalAuctionValue = totalValue
                    break
                end
            end
        end
    end

    if tab and ns.UI.RefreshAuctionsTab then
        ns.UI.RefreshAuctionsTab(tab)
    end
end

local function HideDetailLines(row)
    if row.detailLine1 then row.detailLine1:Hide() end
    if row.detailLine2 then row.detailLine2:Hide() end
    if row.detailLine3 then row.detailLine3:Hide() end
    if row.detailLine4 then row.detailLine4:Hide() end
end

local function ShowDetailLines(row, lines)
    local prev
    for i = 1, 4 do
        local fs = row["detailLine" .. i]
        local text = lines[i]
        if text and text ~= "" then
            fs:ClearAllPoints()
            if prev then
                fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2)
                fs:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, 0)
            else
                fs:SetPoint("TOPLEFT", row, "TOPLEFT", 28, -6)
                fs:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -6)
            end
            fs:SetText(text)
            fs:SetTextColor(OneWoW_GUI:GetThemeColor(i == 1 and "TEXT_SECONDARY" or "TEXT_MUTED"))
            fs:Show()
            prev = fs
        else
            fs:Hide()
        end
    end
end

local function BuildExpandDetailLines(entry)
    local lines = {}
    local history = entry.history
    local auction = entry.auction
    local bid = entry.bid
    local item = AuctionItemData(entry)
    local fmt = ns.AltTrackerFormatters

    if history then
        lines[1] = L["ID"] .. " " .. tostring(history.auctionID or "?")
        lines[2] = table.concat({
            L["AUCTIONS_EXP_POSTED"] .. " " .. FormatStamp(history.postedAt),
            L["AUCTIONS_EXP_ENDED"] .. " " .. FormatStamp(history.timestamp),
            L["AUCTIONS_EXP_DURATION"] .. " " .. FormatDurationSecs(history.duration),
        }, "  |  ")
        local listPrice = history.listPrice or 0
        local salePrice = history.salePrice or 0
        local delta = salePrice - listPrice
        local deltaText = fmt:FormatGold(math.abs(delta))
        if delta > 0 then
            deltaText = "+" .. deltaText
        elseif delta < 0 then
            deltaText = "-" .. deltaText
        end
        lines[3] = table.concat({
            L["AUCTIONS_EXP_LIST"] .. " " .. fmt:FormatGold(listPrice),
            L["AUCTIONS_EXP_SALE"] .. " " .. (salePrice > 0 and fmt:FormatGold(salePrice) or "-"),
            L["AUCTIONS_EXP_DELTA"] .. " " .. deltaText,
        }, "  |  ")

        local parts = {
            OutcomeLabel(history.outcome),
            L["AUCTIONS_EXP_DETECT"] .. " " .. DetectionMethodLabel(history.detectionMethod),
            L["AUCTIONS_EXP_CONFIRMED"] .. " " .. (history.confirmed and YES or NO),
            L["AUCTIONS_COL_QTY"] .. " " .. tostring(history.quantity or 1),
        }
        if history.itemLevel and history.itemLevel > 0 then
            tinsert(parts, ITEM_LEVEL_ABBR .. " " .. tostring(history.itemLevel))
        end
        local mailGold = GetAHMailGoldForItem(entry.charKey, history.itemName)
        if mailGold > 0 then
            tinsert(parts, L["AUCTIONS_EXP_MAIL_GOLD"] .. " " .. fmt:FormatGold(mailGold))
        end
        local market = GetMarketPriceText(history.itemID, history.itemLink)
        if market then
            tinsert(parts, market)
        end
        lines[4] = table.concat(parts, "  |  ")
    elseif auction then
        lines[1] = L["ID"] .. " " .. tostring(auction.auctionID or "?")
        local remaining = auction.endsAt and (auction.endsAt - GetServerTime()) or 0
        lines[2] = table.concat({
            L["TT_COL_TIME"] .. ": " .. FormatStamp(auction.endsAt),
            remaining > 0 and FormatDurationSecs(remaining) or L["AUCTION_TIME_ENDED"],
        }, "  |  ")
        local qty = auction.quantity or 1
        local each = qty > 0 and math.floor((auction.buyoutAmount or 0) / qty) or 0
        lines[3] = table.concat({
            BID .. ": " .. fmt:FormatGold(auction.bidAmount or 0),
            BUYOUT .. ": " .. fmt:FormatGold(auction.buyoutAmount or 0),
            L["TT_COL_EACH"] .. ": " .. fmt:FormatGold(each),
        }, "  |  ")
        local parts = {
            L["AUCTIONS_EXP_BIDDER"] .. " " .. (auction.bidder or "-"),
            STATUS .. ": " .. tostring(auction.status or "-"),
            L["AUCTIONS_EXP_COLLECTED"] .. " " .. FormatStamp(auction.collectedAt),
            L["AUCTIONS_COL_QTY"] .. " " .. tostring(qty),
        }
        if auction.itemLevel and auction.itemLevel > 0 then
            tinsert(parts, ITEM_LEVEL_ABBR .. " " .. tostring(auction.itemLevel))
        end
        local market = GetMarketPriceText(auction.itemID, auction.itemLink)
        if market then
            tinsert(parts, market)
        end
        lines[4] = table.concat(parts, "  |  ")
    elseif bid then
        lines[1] = L["ID"] .. " " .. tostring(bid.auctionID or "?")
        lines[2] = table.concat({
            L["AUCTIONS_EXP_MIN_BID"] .. " " .. fmt:FormatGold(bid.minBid or 0),
            BID .. ": " .. fmt:FormatGold(bid.bidAmount or 0),
            BUYOUT .. ": " .. fmt:FormatGold(bid.buyoutAmount or 0),
        }, "  |  ")
        lines[3] = L["TT_COL_TIME"] .. ": " .. BidTimeLeftLabel(bid.timeLeft)
        local parts = {
            L["AUCTIONS_EXP_BIDDER"] .. " " .. (bid.bidder or "-"),
            L["AUCTIONS_EXP_COLLECTED"] .. " " .. FormatStamp(bid.collectedAt),
        }
        if item and item.quantity then
            tinsert(parts, L["AUCTIONS_COL_QTY"] .. " " .. tostring(item.quantity))
        end
        if item and item.itemLevel and item.itemLevel > 0 then
            tinsert(parts, ITEM_LEVEL_ABBR .. " " .. tostring(item.itemLevel))
        end
        local market = GetMarketPriceText(bid.itemID, bid.itemLink)
        if market then
            tinsert(parts, market)
        end
        lines[4] = table.concat(parts, "  |  ")
    end

    return lines
end

local function CreateAuctionListRow(parent, _)
    local row = CreateFrame("Frame", nil, parent)
    row:EnableMouse(true)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    bg:SetAlpha(0.6)
    row.bg = bg

    local expandBtn = CreateFrame("Button", nil, row)
    expandBtn:SetSize(25, AUC_ROW_HEIGHT)
    local expandIcon = expandBtn:CreateTexture(nil, "ARTWORK")
    expandIcon:SetSize(14, 14)
    expandIcon:SetPoint("CENTER")
    expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
    expandBtn.icon = expandIcon
    row.expandBtn = expandBtn

    expandBtn:SetScript("OnClick", function()
        if row.entry and row.entry.type == "row" then
            ToggleAuctionExpand(row.entry.entry)
        end
    end)

    local itemContainer = CreateFrame("Frame", nil, row)
    itemContainer:SetHeight(AUC_ROW_HEIGHT - 4)
    row.itemContainer = itemContainer

    local iconFrame = OneWoW_GUI:CreateSkinnedIcon(itemContainer, {
        size = AUC_ROW_HEIGHT - 4,
        preset = "clean",
        showIlvl = true,
        itemLevel = 0,
    })
    iconFrame:SetPoint("LEFT", itemContainer, "LEFT", 2, 0)
    row.iconFrame = iconFrame

    local itemLinkFrame = CreateFrame("Button", nil, itemContainer)
    itemLinkFrame:SetPoint("LEFT", iconFrame, "RIGHT", 4, 0)
    itemLinkFrame:SetPoint("RIGHT", itemContainer, "RIGHT", -4, 0)
    itemLinkFrame:SetHeight(AUC_ROW_HEIGHT - 4)
    row.itemLinkFrame = itemLinkFrame

    local itemNameText = OneWoW_GUI:CreateFS(itemLinkFrame, 12)
    itemNameText:SetPoint("LEFT", itemLinkFrame, "LEFT", 0, 0)
    itemNameText:SetPoint("RIGHT", itemLinkFrame, "RIGHT", 0, 0)
    itemNameText:SetJustifyH("LEFT")
    itemNameText:SetWordWrap(false)
    row.itemNameText = itemNameText

    itemLinkFrame:SetScript("OnEnter", function(myself)
        local entry = row.entry and row.entry.entry
        local itemData = AuctionItemData(entry)
        if not itemData then
            return
        end
        itemNameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        if itemData.itemLink then
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemData.itemLink)
            GameTooltip:Show()
        end
    end)
    itemLinkFrame:SetScript("OnLeave", function()
        local entry = row.entry and row.entry.entry
        local itemData = AuctionItemData(entry)
        if itemData and itemData.itemRarity and ITEM_QUALITY_COLORS[itemData.itemRarity] then
            local color = ITEM_QUALITY_COLORS[itemData.itemRarity]
            itemNameText:SetTextColor(color.r, color.g, color.b)
        else
            itemNameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
        GameTooltip:Hide()
    end)
    itemLinkFrame:SetScript("OnClick", function()
        local entry = row.entry and row.entry.entry
        local itemData = AuctionItemData(entry)
        if itemData and itemData.itemLink and IsModifiedClick("CHATLINK") then
            ChatEdit_InsertLink(itemData.itemLink)
        end
    end)

    local qtyText = OneWoW_GUI:CreateFS(row, 12)
    row.qtyText = qtyText

    local eachText = OneWoW_GUI:CreateFS(row, 12)
    eachText:SetJustifyH("LEFT")
    row.eachText = eachText

    local totalText = OneWoW_GUI:CreateFS(row, 12)
    totalText:SetJustifyH("LEFT")
    row.totalText = totalText

    local bidText = OneWoW_GUI:CreateFS(row, 12)
    bidText:SetJustifyH("LEFT")
    row.bidText = bidText

    local timeContainer = CreateFrame("Frame", nil, row)
    timeContainer:SetHeight(AUC_ROW_HEIGHT)
    row.timeContainer = timeContainer

    local timeText = OneWoW_GUI:CreateFS(timeContainer, 12)
    timeText:SetPoint("CENTER")
    row.timeText = timeText

    local warningIcon = timeContainer:CreateTexture(nil, "OVERLAY")
    warningIcon:SetSize(12, 12)
    warningIcon:SetPoint("LEFT", timeText, "RIGHT", 2, 0)
    warningIcon:SetAtlas("Raid-Icon-Evoker")
    warningIcon:Hide()
    row.warningIcon = warningIcon

    timeContainer:EnableMouse(true)
    timeContainer:SetScript("OnEnter", function(myself)
        local entry = row.entry and row.entry.entry
        local auction = entry and entry.auction
        if auction and auction.endsAt then
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText("Expires At", 1, 1, 1)
            GameTooltip:AddLine(date("%Y-%m-%d %H:%M:%S", auction.endsAt), 1, 1, 1)
            local remainingSecs = auction.endsAt - GetServerTime()
            if remainingSecs > 0 then
                GameTooltip:AddLine("Time Remaining: " .. math.floor(remainingSecs / 3600) .. "h " .. math.floor((remainingSecs % 3600) / 60) .. "m", 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end
    end)
    timeContainer:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local charNameText = OneWoW_GUI:CreateFS(row, 12)
    charNameText:SetJustifyH("LEFT")
    row.charNameText = charNameText

    local serverText = OneWoW_GUI:CreateFS(row, 12)
    serverText:SetJustifyH("LEFT")
    row.serverText = serverText

    local factionCell = OneWoW_GUI:CreateFactionIcon(row, { faction = "Alliance" })
    row.factionCell = factionCell

    local statusText = OneWoW_GUI:CreateFS(row, 12)
    statusText:SetJustifyH("LEFT")
    row.statusText = statusText

    local deleteBtn = OneWoW_GUI:CreateFitTextButton(row, { text = L["PLACEHOLDER_DELETE"], height = 22 })
    deleteBtn:SetScript("OnClick", function()
        if row.entry and row.entry.entry then
            DeleteAuctionEntry(row.entry.entry)
        end
    end)
    row.deleteBtn = deleteBtn

    row.cells = {
        expandBtn,
        itemContainer,
        qtyText,
        eachText,
        totalText,
        bidText,
        timeContainer,
        charNameText,
        serverText,
        factionCell,
        statusText,
        deleteBtn,
    }

    for i = 1, 4 do
        local detailLine = OneWoW_GUI:CreateFS(row, 10)
        detailLine:SetJustifyH("LEFT")
        detailLine:SetWordWrap(false)
        detailLine:Hide()
        row["detailLine" .. i] = detailLine
    end

    row:SetScript("OnEnter", function(myself)
        if myself.entry and myself.entry.type == "row" then
            local hR, hG, hB = OneWoW_GUI:GetThemeColor("BG_HOVER")
            myself.bg:SetColorTexture(hR, hG, hB, 0.8)
        end
    end)
    row:SetScript("OnLeave", function(myself)
        if myself.normalBgColor then
            myself.bg:SetColorTexture(unpack(myself.normalBgColor))
        elseif myself.entry and myself.entry.type == "detail" then
            myself.bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            myself.bg:SetAlpha(0.7)
        else
            myself.bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            myself.bg:SetAlpha(0.6)
        end
    end)
    row:SetScript("OnMouseDown", function(myself, button)
        if button == "LeftButton" and myself.entry and myself.entry.type == "row" then
            ToggleAuctionExpand(myself.entry.entry)
        end
    end)

    return row
end

local function BindAuctionListRow(row, _, listEntry, _)
    row.entry = listEntry
    local tab = activeAuctionsTab
    local dt = tab and tab.dataTable
    local entry = listEntry.entry

    if listEntry.type == "detail" then
        for _, cell in ipairs(row.cells) do
            cell:Hide()
        end
        row.normalBgColor = nil
        row.bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        row.bg:SetAlpha(0.7)
        ShowDetailLines(row, BuildExpandDetailLines(entry))
        return
    end

    HideDetailLines(row)
    for _, cell in ipairs(row.cells) do
        cell:Show()
    end

    local charKey = entry.charKey
    local charData = entry.charData
    local auction = entry.auction
    local bid = entry.bid
    local history = entry.history
    local itemData = AuctionItemData(entry)
    local isHistory = (entry.type == "history")
    local key = AuctionExpandKey(entry)

    if row.expandBtn.icon then
        row.expandBtn.icon:SetAtlas(expandedByKey[key] and "Gamepad_Rev_Minus_64" or "Gamepad_Rev_Plus_64")
    end

    row.normalBgColor = nil
    local bgR, bgG, bgB = OneWoW_GUI:GetThemeColor("BG_TERTIARY")
    row.bg:SetColorTexture(bgR, bgG, bgB, 0.6)
    if not isHistory and auction and auction.endsAt then
        local timeLeft = auction.endsAt - GetServerTime()
        if timeLeft > 0 and timeLeft < 1800 then
            local dr, dg, db = OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL")
            row.bg:SetColorTexture(dr, dg, db, 1)
            row.normalBgColor = { dr, dg, db, 1 }
        elseif timeLeft > 0 and timeLeft < 3600 then
            row.bg:SetColorTexture(bgR, bgG, bgB, 1)
            row.normalBgColor = { bgR, bgG, bgB, 1 }
        end
    end

    OneWoW_GUI:UpdateIconTexture(row.iconFrame, itemData.itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    OneWoW_GUI:UpdateIconQuality(row.iconFrame, itemData.itemRarity)
    if row.iconFrame._ilvlText then
        if itemData.itemLevel and itemData.itemLevel > 0 then
            row.iconFrame._ilvlText:SetText(tostring(itemData.itemLevel))
        else
            row.iconFrame._ilvlText:SetText("")
        end
    end

    row.itemNameText:SetText(itemData.itemName or L["AUCTION_UNKNOWN_ITEM"])
    if itemData.itemRarity and ITEM_QUALITY_COLORS[itemData.itemRarity] then
        local color = ITEM_QUALITY_COLORS[itemData.itemRarity]
        row.itemNameText:SetTextColor(color.r, color.g, color.b)
    else
        row.itemNameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
    row.itemLinkFrame:EnableMouse(itemData.itemLink and true or false)

    row.qtyText:SetText(tostring(itemData.quantity or 1))
    row.qtyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    if isHistory then
        local each = history.quantity > 0 and math.floor(history.listPrice / history.quantity) or 0
        row.eachText:SetText(ns.AltTrackerFormatters:FormatGold(each))
    elseif auction then
        local each = auction.quantity > 0 and math.floor(auction.buyoutAmount / auction.quantity) or 0
        row.eachText:SetText(ns.AltTrackerFormatters:FormatGold(each))
    else
        local each = bid.quantity > 0 and math.floor(bid.bidAmount / bid.quantity) or 0
        row.eachText:SetText(ns.AltTrackerFormatters:FormatGold(each))
    end
    row.eachText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    if isHistory then
        row.totalText:SetText(ns.AltTrackerFormatters:FormatGold(history.listPrice or 0))
    else
        local totalAmount = auction and auction.buyoutAmount or (bid and bid.bidAmount or 0)
        row.totalText:SetText(ns.AltTrackerFormatters:FormatGold(totalAmount))
    end
    row.totalText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    if isHistory then
        if history.salePrice and history.salePrice > 0 then
            row.bidText:SetText(ns.AltTrackerFormatters:FormatGold(history.salePrice))
            row.bidText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            row.bidText:SetText("-")
            row.bidText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
    elseif auction then
        if auction.bidAmount > 0 then
            row.bidText:SetText(ns.AltTrackerFormatters:FormatGold(auction.bidAmount))
            row.bidText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        else
            row.bidText:SetText("-")
            row.bidText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
    else
        row.bidText:SetText(ns.AltTrackerFormatters:FormatGold(bid.bidAmount))
        row.bidText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    end

    row.warningIcon:Hide()
    row.timeContainer:EnableMouse(false)
    if isHistory then
        local timeSince = GetServerTime() - (history.timestamp or GetServerTime())
        if timeSince < 3600 then
            row.timeText:SetText(math.floor(timeSince / 60) .. "m ago")
        elseif timeSince < 86400 then
            row.timeText:SetText(math.floor(timeSince / 3600) .. "h ago")
        else
            row.timeText:SetText(math.floor(timeSince / 86400) .. "d ago")
        end
        row.timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    elseif auction then
        local timeLeft = auction.endsAt - GetServerTime()
        row.timeContainer:EnableMouse(true)
        if timeLeft > 0 then
            if timeLeft < 1800 then
                row.timeText:SetText(math.floor(timeLeft / 60) .. "m")
                row.timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
                row.warningIcon:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
                row.warningIcon:Show()
            elseif timeLeft < 3600 then
                row.timeText:SetText(math.floor(timeLeft / 60) .. "m")
                row.timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            elseif timeLeft < 7200 then
                row.timeText:SetText(math.floor(timeLeft / 3600) .. "h")
                row.timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            else
                row.timeText:SetText(math.floor(timeLeft / 3600) .. "h")
                row.timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            end
        else
            row.timeText:SetText(L["AUCTION_TIME_ENDED"])
            row.timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    else
        row.timeText:SetText("-")
        row.timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    end

    row.charNameText:SetText(charData.name or charKey)
    local classColor = RAID_CLASS_COLORS[charData.class]
    if classColor then
        row.charNameText:SetTextColor(classColor.r, classColor.g, classColor.b)
    else
        row.charNameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end

    row.serverText:SetText(charData.realm or "")
    row.serverText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    SetFactionIcon(row.factionCell, charData.faction)

    if isHistory then
        if history.outcome == "sold" then
            row.statusText:SetText(L["OUTCOME_SOLD"])
            row.statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        elseif history.outcome == "expired" then
            row.statusText:SetText(L["OUTCOME_EXPIRED"])
            row.statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
        elseif history.outcome == "canceled" then
            row.statusText:SetText(L["OUTCOME_CANCELED"])
            row.statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        else
            row.statusText:SetText(history.outcome or "-")
            row.statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
    elseif auction then
        row.statusText:SetText(L["STATUS_ACTIVE"])
        row.statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    else
        row.statusText:SetText(L["STATUS_BIDDING"])
        row.statusText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    end

    LayoutAuctionCells(row, dt)
end

local function FinishAuctionsList(auctionsTab, allAuctions)
    auctionsTab._auctions = allAuctions
    BuildAuctionListEntries(allAuctions)
    if listAPI then
        listAPI.Refresh()
    end

    if auctionsTab.statusText then
        if #allAuctions == 0 then
            auctionsTab.statusText:SetText(L["NO_AUCTIONS_FOUND"])
        else
            auctionsTab.statusText:SetText(string.format(L["AUCTIONS_STATUS_COUNT"], #allAuctions))
        end
    end

    ns.UI.RefreshAuctionsStats(auctionsTab)

    if auctionsTab.UpdateMailIcon then
        auctionsTab.UpdateMailIcon()
    end

    OneWoW_GUI:ApplyFontToFrame(auctionsTab)

    C_Timer.After(0.1, function()
        if auctionsTab.headerRow then
            auctionsTab.headerRow:GetScript("OnSizeChanged")(auctionsTab.headerRow)
        end
    end)
end

function ns.UI.CreateAuctionsTab(parent)
    local overview = OneWoW_GUI:CreateOverviewPanel(parent, {
        height = 110,
        columns = 5,
        stats = {
            { label = L["ATTENTION"], value = "0", ttTitle = L["ATTENTION"], ttDesc = L["TT_AUCTIONS_ATTENTION_DESC"] },
            { label = L["AUCTIONS_TOTAL"], value = "0", ttTitle = L["AUCTIONS_TOTAL"], ttDesc = L["TT_AUCTIONS_TOTAL_DESC"] },
            { label = L["AUCTIONS_ACTIVE"], value = "0", ttTitle = L["TT_AUCTIONS_ACTIVE"], ttDesc = L["TT_AUCTIONS_ACTIVE_DESC"] },
            { label = L["AUCTIONS_LIKELY_SOLD"], value = "0", ttTitle = L["AUCTIONS_LIKELY_SOLD"], ttDesc = L["TT_AUCTIONS_LIKELY_SOLD_DESC"] },
            { label = L["AUCTIONS_VALUE"], value = "0g", ttTitle = L["AUCTIONS_VALUE"], ttDesc = L["TT_AUCTIONS_VALUE_DESC"] },
            { label = L["CHARACTERS"], value = "0", ttTitle = L["CHARACTERS"], ttDesc = L["TT_AUCTIONS_CHARACTERS_DESC"] },
            { label = L["AUCTIONS_EXPIRING"], value = "0", ttTitle = L["AUCTIONS_EXPIRING"], ttDesc = L["TT_AUCTIONS_EXPIRING_DESC"] },
            { label = L["AUCTIONS_EXPIRED"], value = "0", ttTitle = L["TT_AUCTIONS_EXPIRED"], ttDesc = L["TT_AUCTIONS_EXPIRED_DESC"] },
            { label = L["MAIL_GOLD_WAITING"], value = "Closed", ttTitle = L["TT_MAIL_GOLD_WAITING"], ttDesc = L["TT_MAIL_GOLD_WAITING_DESC"] },
            { label = L["HISTORY_GOLD_EARNED"], value = "0", ttTitle = L["TT_HISTORY_GOLD_EARNED"], ttDesc = L["TT_HISTORY_GOLD_EARNED_DESC"] },
        },
    })

    local searchBar = OneWoW_GUI:CreateFilterBar(parent, { height = 32, anchorBelow = overview.panel, offset = -8 })

    local searchDebounce
    local searchBox = OneWoW_GUI:CreateEditBox(searchBar, {
        height = 24,
        placeholderText = L["SEARCH_ITEMS"],
        onTextChanged = function(text)
            if searchDebounce then
                searchDebounce:Cancel()
                searchDebounce = nil
            end
            searchDebounce = C_Timer.NewTimer(0.3, function()
                searchDebounce = nil
                itemSearchText = text or ""
                if ns.UI.RefreshAuctionsTab then
                    ns.UI.RefreshAuctionsTab(parent)
                end
            end)
        end,
    })
    searchBox:SetPoint("LEFT", searchBar, "LEFT", 8, 0)
    OneWoW_GUI:AttachSearchTooltip(searchBox)
    local searchHelpBtn = OneWoW_GUI:CreateKeywordHelpButton(searchBar, { editBox = searchBox, size = 20 })
    searchHelpBtn:SetPoint("RIGHT", searchBar, "RIGHT", -8, 0)
    searchBox:SetPoint("RIGHT", searchHelpBtn, "LEFT", -4, 0)

    local filterPanel = OneWoW_GUI:CreateFilterBar(parent, { height = 32, anchorBelow = searchBar, offset = -4 })

    parent.auctionFilter = "all"

    local mailIconButton = OneWoW_GUI:CreateButton(filterPanel, { text = "", width = 32, height = 32 })
    mailIconButton:SetPoint("LEFT", filterPanel, "LEFT", 8, 0)

    local mailIcon = mailIconButton:CreateTexture(nil, "ARTWORK")
    mailIcon:SetSize(24, 24)
    mailIcon:SetPoint("CENTER")
    mailIcon:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")

    local function UpdateMailIcon()
        if not OneWoW_AltTracker_Storage_API then return end

        local totalGold = 0
        for _, storageData in pairs(OneWoW_AltTracker_Storage_API.GetCharacters()) do
            if storageData.mail and storageData.mail.mails then
                for _, mailData in pairs(storageData.mail.mails) do
                    if mailData.sender and (mailData.sender == "Auction House" or mailData.sender == "The Auction House") and mailData.money and mailData.money > 0 then
                        totalGold = totalGold + mailData.money
                    end
                end
            end
        end

        if totalGold > 0 then
            local mr, mg, mb = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
            mailIcon:SetVertexColor(mr, mg, mb, 1)
        else
            local mr, mg, mb = OneWoW_GUI:GetThemeColor("TEXT_MUTED")
            mailIcon:SetVertexColor(mr, mg, mb, 0.5)
        end
    end

    mailIconButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

        if not OneWoW_AltTracker_Storage_API then return end

        local hasAnyMail = false
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["MAIL_PENDING_PICKUP"], 1, 1, 1)

        for charKey, storageData in pairs(OneWoW_AltTracker_Storage_API.GetCharacters()) do
            if storageData.mail and storageData.mail.mails then
                local auctionGold = 0
                local auctionItems = {}

                for _, mailData in pairs(storageData.mail.mails) do
                    if (mailData.sender == "Auction House" or mailData.sender == "The Auction House") and mailData.money and mailData.money > 0 then
                        auctionGold = auctionGold + mailData.money

                        local itemName = mailData.subject and mailData.subject:match("Auction successful: (.+)")
                        if itemName then
                            itemName = itemName:match("^(.-)%s*%(%d+%)$") or itemName
                            tinsert(auctionItems, {
                                name = itemName,
                                gold = mailData.money
                            })
                        end
                    end
                end

                if auctionGold > 0 then
                    hasAnyMail = true
                    local charName = charKey:match("^([^%-]+)")
                    local goldFormatted = ns.AltTrackerFormatters:FormatGold(auctionGold)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(charName .. " - " .. goldFormatted, 1, 0.84, 0)

                    for _, item in ipairs(auctionItems) do
                        local itemGold = ns.AltTrackerFormatters:FormatGold(item.gold)
                        GameTooltip:AddLine("  " .. item.name .. " - " .. itemGold, 0.7, 0.7, 0.7)
                    end
                end
            end
        end

        if not hasAnyMail then
            GameTooltip:AddLine(L["NO_AUCTION_MAIL"], 0.5, 0.5, 0.5)
        end

        GameTooltip:Show()
    end)

    mailIconButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        GameTooltip:Hide()
    end)

    parent.mailIconButton = mailIconButton
    parent.UpdateMailIcon = UpdateMailIcon

    local altDropdown, altDropdownText = OneWoW_GUI:CreateDropdown(filterPanel, {
        width = 150, height = 28, text = L["AUCTIONS_ALL_ALTS"]
    })
    altDropdown:SetPoint("LEFT", mailIconButton, "RIGHT", 4, 0)

    local realmDropdown, realmDropdownText = OneWoW_GUI:CreateDropdown(filterPanel, {
        width = 130, height = 28, text = L["AUCTIONS_ALL_REALMS"]
    })
    realmDropdown:SetPoint("LEFT", altDropdown, "RIGHT", 4, 0)

    local filterButtons = {}
    local filterOptions = {
        {key = "all", label = ALL, tooltip = L["AUCTIONS_FILTER_ALL_DESC"]},
        {key = "auctions", label = L["AUCTIONS_FILTER_AUCTIONS"], tooltip = L["AUCTIONS_FILTER_AUCTIONS_DESC"]},
        {key = "bids", label = L["AUCTIONS_FILTER_BIDS"], tooltip = L["AUCTIONS_FILTER_BIDS_DESC"]},
        {key = "expiring", label = L["AUCTIONS_EXPIRING"], tooltip = L["AUCTIONS_FILTER_EXPIRING_DESC"]},
        {key = "history", label = HISTORY, tooltip = L["AUCTIONS_FILTER_HISTORY_DESC"]},
    }

    for i, option in ipairs(filterOptions) do
        local btn = OneWoW_GUI:CreateFitTextButton(filterPanel, { text = option.label, height = 24 })
        if i == 1 then
            btn:SetPoint("LEFT", realmDropdown, "RIGHT", 4, 0)
        else
            btn:SetPoint("LEFT", filterButtons[i - 1], "RIGHT", 4, 0)
        end

        btn.filterKey = option.key

        btn:SetScript("OnClick", function(self)
            parent.auctionFilter = self.filterKey
            for _, b in ipairs(filterButtons) do
                if b.filterKey == parent.auctionFilter then
                    b:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    b.text:SetTextColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
                else
                    b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                    b.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end
            end
            if ns.UI.RefreshAuctionsTab then
                ns.UI.RefreshAuctionsTab(parent)
            end
        end)

        btn:SetScript("OnEnter", function(self)
            if self.filterKey ~= parent.auctionFilter then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(option.label, 1, 1, 1)
            GameTooltip:AddLine(option.tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function(self)
            if self.filterKey ~= parent.auctionFilter then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
            GameTooltip:Hide()
        end)

        if option.key == "all" then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        tinsert(filterButtons, btn)
    end

    local function InitializeAltDropdown()
        local auctionChars = OneWoW_AltTracker_Auctions_API and OneWoW_AltTracker_Auctions_API.GetCharacters()
        if not auctionChars then
            altDropdownText:SetText(L["AUCTIONS_ALL_ALTS"])
            return
        end

        local altList = {}
        for charKey, auctionData in pairs(auctionChars) do
            local hasData = false
            if auctionData.activeAuctions and #auctionData.activeAuctions > 0 then hasData = true end
            if auctionData.activeBids and #auctionData.activeBids > 0 then hasData = true end
            if auctionData.auctionHistory and #auctionData.auctionHistory > 0 then hasData = true end
            if hasData then
                local charInfo = OneWoW_AltTracker_Character_API and OneWoW_AltTracker_Character_API.GetCharacterData(charKey)
                local charName = (charInfo and charInfo.name) or charKey:match("^([^%-]+)") or charKey
                tinsert(altList, { key = charKey, name = charName })
            end
        end

        sort(altList, function(a, b) return a.name < b.name end)

        if not selectedAltKey then
            altDropdownText:SetText(L["AUCTIONS_ALL_ALTS"])
        else
            local found = false
            for _, alt in ipairs(altList) do
                if alt.key == selectedAltKey then
                    altDropdownText:SetText(alt.name)
                    found = true
                    break
                end
            end
            if not found then
                selectedAltKey = nil
                altDropdownText:SetText(L["AUCTIONS_ALL_ALTS"])
            end
        end

        OneWoW_GUI:AttachFilterMenu(altDropdown, {
            searchable = (#altList > 5),
            menuHeight = 314,
            buildItems = function()
                local items = {}
                tinsert(items, {
                    text = L["AUCTIONS_ALL_ALTS"],
                    value = nil,
                })
                for _, alt in ipairs(altList) do
                    tinsert(items, {
                        text = alt.name,
                        value = alt.key,
                    })
                end
                return items
            end,
            getActiveValue = function()
                return selectedAltKey
            end,
            onSelect = function(value, text)
                selectedAltKey = value
                altDropdown._text:SetText(text)
                if ns.UI.RefreshAuctionsTab then
                    ns.UI.RefreshAuctionsTab(parent)
                end
            end,
        })
    end

    local function RebuildRealmDropdown(realmList)
        local realms = realmList or {}

        if selectedRealm then
            local found = false
            for _, realm in ipairs(realms) do
                if realm == selectedRealm then
                    found = true
                    break
                end
            end
            if not found then
                selectedRealm = nil
            end
        end

        if selectedRealm then
            realmDropdownText:SetText(selectedRealm)
        else
            realmDropdownText:SetText(L["AUCTIONS_ALL_REALMS"])
        end

        OneWoW_GUI:AttachFilterMenu(realmDropdown, {
            searchable = (#realms > 5),
            menuHeight = 314,
            buildItems = function()
                local items = {}
                tinsert(items, {
                    text = L["AUCTIONS_ALL_REALMS"],
                    value = nil,
                })
                for _, realm in ipairs(realms) do
                    tinsert(items, {
                        text = realm,
                        value = realm,
                    })
                end
                return items
            end,
            getActiveValue = function()
                return selectedRealm
            end,
            onSelect = function(value, text)
                selectedRealm = value
                realmDropdown._text:SetText(text)
                if ns.UI.RefreshAuctionsTab then
                    ns.UI.RefreshAuctionsTab(parent)
                end
            end,
        })
    end

    InitializeAltDropdown()
    RebuildRealmDropdown({})
    parent.RebuildAltDropdown = InitializeAltDropdown
    parent.RebuildRealmDropdown = RebuildRealmDropdown
    parent.altDropdown = altDropdown
    parent.realmDropdown = realmDropdown
    parent.searchBox = searchBox

    local rosterPanel = OneWoW_GUI:CreateFrame(parent, {})
    rosterPanel:SetPoint("TOPLEFT", filterPanel, "BOTTOMLEFT", 0, -5)
    rosterPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 30)

    local dt
    dt = OneWoW_GUI:CreateDataTable(rosterPanel, {
        columns = columnsConfig,
        headerHeight = 26,
        onHeaderCreate = onHeaderCreate,
        onSort = function(sortColumn, sortAscending)
            currentSortColumn = sortColumn
            currentSortAscending = sortAscending
            ns.UI.RefreshAuctionsTab(parent)
            C_Timer.After(0.1, function() dt.UpdateSortIndicators() end)
        end,
    })

    listAPI = OneWoW_GUI:CreateVirtualizer(rosterPanel, {
        name = "AltTrackerAuctionsList",
        rowHeight = AUC_TX_STRIDE,
        minRowHeight = AUC_TX_STRIDE,
        numVisibleRows = 16,
        selectOnClick = false,
        scrollFrame = dt.scrollFrame,
        content = dt.scrollContent,
        getCount = function()
            return #listEntries
        end,
        getEntry = function(index)
            return listEntries[index]
        end,
        getRowHeight = function(index)
            local entry = listEntries[index]
            if entry and entry.type == "detail" then
                return AUC_DETAIL_STRIDE
            end
            return AUC_TX_STRIDE
        end,
        createRow = CreateAuctionListRow,
        bindRow = BindAuctionListRow,
    })

    local origUpdateColumnLayout = dt.UpdateColumnLayout
    dt.UpdateColumnLayout = function(...)
        origUpdateColumnLayout(...)
        if listAPI then
            listAPI.Refresh()
        end
    end

    local statusBar = OneWoW_GUI:CreateStatusBar(parent, rosterPanel, {
        text = string.format(L["AUCTIONS_STATUS_COUNT"], 0),
    })

    parent.dataTable = dt
    parent.headerRow = dt.headerRow
    parent.scrollContent = dt.scrollContent
    parent.scrollFrame = dt.scrollFrame
    parent.listAPI = listAPI
    parent.rosterPanel = rosterPanel
    parent.statBoxes = overview.statBoxes
    parent.statusText = statusBar.text
    parent.statusBar = statusBar.bar
    parent.filterPanel = filterPanel
    activeAuctionsTab = parent

    OneWoW_GUI:ApplyFontToFrame(parent)

    local function RefreshAuctions()
        if ns.UI.RefreshAuctionsTab then
            ns.UI.RefreshAuctionsTab(parent)
        end
    end
    OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Auctions", RefreshAuctions)
    OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Storage", RefreshAuctions)
end

function ns.UI.RefreshAuctionsTab(auctionsTab)
    if not auctionsTab then return end

    if historyJob then
        historyJob:Cancel()
        historyJob = nil
    end

    if not OneWoW_AltTracker_Auctions_API then
        wipe(listEntries)
        if listAPI then
            listAPI.Refresh()
        end
        return
    end

    if not auctionsTab.scrollContent then return end

    if auctionsTab.RebuildAltDropdown then
        auctionsTab.RebuildAltDropdown()
    end

    local currentFilter = auctionsTab.auctionFilter or "all"

    if currentFilter == "history" then
        local built = {}
        local realmsForMenu = {}
        local job
        job = OneWoW.ChunkedJob.Start({
            run = function(shouldYield)
                wipe(built)
                wipe(realmsForMenu)
                local typeFiltered = CollectTypeFilteredAuctions(currentFilter, shouldYield)
                for _, realm in ipairs(GatherRealms(typeFiltered)) do
                    tinsert(realmsForMenu, realm)
                end
                if selectedRealm then
                    local found = false
                    for _, realm in ipairs(realmsForMenu) do
                        if realm == selectedRealm then
                            found = true
                            break
                        end
                    end
                    if not found then
                        selectedRealm = nil
                    end
                end
                local filtered = ApplyRealmAndSearch(typeFiltered)
                for _, entry in ipairs(filtered) do
                    tinsert(built, entry)
                    OneWoW.ChunkedJob.YieldIfNeeded(shouldYield)
                end
                OneWoW.ChunkedJob.Sort(built, CompareAuctionEntries, shouldYield)
            end,
            onProgress = function()
                if auctionsTab.statusText then
                    auctionsTab.statusText:SetText(string.format(L["AUCTIONS_STATUS_LOADING"], #built))
                end
            end,
            onComplete = function()
                if historyJob == job then
                    historyJob = nil
                end
                if auctionsTab.RebuildRealmDropdown then
                    auctionsTab.RebuildRealmDropdown(realmsForMenu)
                end
                FinishAuctionsList(auctionsTab, built)
            end,
            onCancel = function()
                if historyJob == job then
                    historyJob = nil
                end
            end,
        })
        historyJob = job
        if auctionsTab.statusText then
            auctionsTab.statusText:SetText(string.format(L["AUCTIONS_STATUS_LOADING"], 0))
        end
        return
    end

    local typeFiltered = CollectTypeFilteredAuctions(currentFilter, nil)
    if auctionsTab.RebuildRealmDropdown then
        auctionsTab.RebuildRealmDropdown(GatherRealms(typeFiltered))
    end
    local allAuctions = ApplyRealmAndSearch(typeFiltered)
    sort(allAuctions, CompareAuctionEntries)
    FinishAuctionsList(auctionsTab, allAuctions)
end

function ns.UI.RefreshAuctionsStats(auctionsTab)
    if not auctionsTab or not auctionsTab.statBoxes then return end
    if not OneWoW_AltTracker_Auctions_API then return end

    local stats = {
        attention = 0,
        total = 0,
        active = 0,
        likelySold = 0,
        value = 0,
        characters = 0,
        expiring = 0,
        expired = 0,
        ahStatus = L["AUCTION_AH_CLOSED"],
        bids = 0,
        goldEarned = 0,
        successRate = 0,
        goldWaiting = 0,
    }

    local charactersWithAuctions = {}
    local totalSold = 0
    local totalPosted = 0

    local attention = OneWoW_AltTracker_API.GetAttentionSummary()
    stats.expiring = attention.expiring
    stats.expired = attention.expired
    stats.goldWaiting = attention.goldWaiting

    for charKey, auctionData in pairs(OneWoW_AltTracker_Auctions_API.GetCharacters()) do
        local hasAuctions = false

        if auctionData.activeAuctions and #auctionData.activeAuctions > 0 then
            hasAuctions = true
            stats.active = stats.active + #auctionData.activeAuctions
            stats.value = stats.value + (auctionData.totalAuctionValue or 0)
        end

        if auctionData.activeBids and #auctionData.activeBids > 0 then
            hasAuctions = true
            stats.bids = stats.bids + #auctionData.activeBids
        end

        if auctionData.auctionHistory then
            for _, event in ipairs(auctionData.auctionHistory) do
                if event.outcome == "sold" then
                    totalSold = totalSold + 1
                    stats.goldEarned = stats.goldEarned + (event.salePrice or 0)
                    stats.likelySold = stats.likelySold + 1
                end
                totalPosted = totalPosted + 1
            end
        end

        if hasAuctions then
            charactersWithAuctions[charKey] = true
        end
    end

    stats.total = stats.active + stats.bids
    stats.characters = 0
    for _ in pairs(charactersWithAuctions) do
        stats.characters = stats.characters + 1
    end

    if totalPosted > 0 then
        stats.successRate = math.floor((totalSold / totalPosted) * 100)
    end

    stats.attention = stats.expiring + stats.expired

    if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
        stats.ahStatus = L["AUCTION_AH_OPEN"]
    end

    local statBoxes = auctionsTab.statBoxes
    if statBoxes then
        if statBoxes[1] then statBoxes[1].value:SetText(tostring(stats.attention)) end
        if statBoxes[2] then statBoxes[2].value:SetText(tostring(stats.total)) end
        if statBoxes[3] then statBoxes[3].value:SetText(tostring(stats.active)) end
        if statBoxes[4] then
            local displayText = tostring(stats.likelySold)
            if stats.successRate > 0 then
                displayText = displayText .. " (" .. stats.successRate .. "%)"
            end
            statBoxes[4].value:SetText(displayText)
        end
        if statBoxes[5] then
            local goldFormatted = ns.AltTrackerFormatters:FormatGold(stats.value)
            statBoxes[5].value:SetText(goldFormatted)
        end
        if statBoxes[6] then statBoxes[6].value:SetText(tostring(stats.characters)) end
        if statBoxes[7] then statBoxes[7].value:SetText(tostring(stats.expiring)) end
        if statBoxes[8] then statBoxes[8].value:SetText(tostring(stats.expired)) end
        if statBoxes[9] then
            local goldWaitingFormatted = ns.AltTrackerFormatters:FormatGold(stats.goldWaiting)
            statBoxes[9].value:SetText(goldWaitingFormatted)
            if stats.goldWaiting > 0 then
                statBoxes[9].value:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                statBoxes[9].value:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end
        if statBoxes[10] then
            local goldEarnedFormatted = ns.AltTrackerFormatters:FormatGold(stats.goldEarned)
            statBoxes[10].value:SetText(goldEarnedFormatted)
        end
    end
end
