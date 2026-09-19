local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

-- Public, cross-addon read surface for the AltTracker hub. Endgame (RequiredDeps:
-- OneWoW_AltTracker) and hub UI call these dot-functions; ns stays private.
-- Most other AltTracker stores no longer TOC-depend on this hub.
OneWoW_AltTracker_API = {}

--- Effective progress override list. trackedCurrencyIDs is season defaults
--- minus player offs, plus extras (empty is allowed). Other keys: user copy
--- when non-empty, else the static baseline.
---@param key string "trackedCurrencyIDs" | "worldBossQuestIDs" | "weeklyActivityQuests"
---@return table|nil list
function OneWoW_AltTracker_API.GetProgressList(key)
    return ns:GetProgressList(key)
end

--- Shared season definition (raids, dungeons, difficulties) from Data/d-season.lua.
---@return table seasonData
function OneWoW_AltTracker_API.GetSeasonData()
    return ns.SeasonData
end

--- Every character known to any OneWoW database, with the stores each was found
--- in. Drives the core Roles & Alts tab's character list + purge. Sorted by last
--- login (most recent first), then name.
---@return table[] characters
function OneWoW_AltTracker_API.CollectAllCharacters()
    return ns.CharacterCleanup:CollectAll()
end

--- Permanently remove a character from every OneWoW database. A UI reload should
--- follow so stale in-memory views are dropped.
---@param charKey string
---@return string[] purgedFrom labels of stores the character was removed from
function OneWoW_AltTracker_API.PurgeCharacter(charKey)
    return ns.CharacterCleanup:Purge(charKey)
end

--- Toggle the AltTracker module in the suite hub (keybinding entry).
function OneWoW_AltTracker_API.Toggle()
    local mw = OneWoW.UI:GetMainWindow()
    local global = OneWoW:GetCoreGlobal()
    if mw and mw:IsShown() and global.lastModuleTab == "alttracker" then
        OneWoW.UI:Hide()
    else
        OneWoW.UI:Show("alttracker")
    end
end

--- Open Roles & Alts setup in suite settings (keybinding entry; former standalone setup).
function OneWoW_AltTracker_API.OpenSetup()
    OneWoW.UI:Show("settings")
    OneWoW.UI:SelectSubTab("settings", "rolesandalts")
end

local SOLD_PREFIX = (AUCTION_HOUSE_AUCTION_SOLD_PREFIX or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
local EXPIRED_PATTERN = (AUCTION_EXPIRED_MAIL_SUBJECT or ""):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"):gsub("%%%%s", ".*")
local REMOVED_PATTERN = (AUCTION_REMOVED_MAIL_SUBJECT or ""):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"):gsub("%%%%s", ".*")

local function MailLooksLikeAuction(mailData)
    if mailData.invoiceType == "seller" or mailData.invoiceType == "seller_temp_invoice" then
        return true
    end
    local subject = mailData.subject
    if type(subject) ~= "string" or subject == "" then
        return false
    end
    if SOLD_PREFIX ~= "" and subject:find(SOLD_PREFIX, 1, true) then
        return true
    end
    if EXPIRED_PATTERN ~= "" and subject:find(EXPIRED_PATTERN) then
        return true
    end
    if REMOVED_PATTERN ~= "" and subject:find(REMOVED_PATTERN) then
        return true
    end
    return false
end

local function MailLooksLikeExpired(mailData)
    local subject = mailData.subject
    if type(subject) ~= "string" or subject == "" or EXPIRED_PATTERN == "" then
        return false
    end
    return subject:find(EXPIRED_PATTERN) ~= nil
end

local function MailHasItems(mailData)
    if mailData.hasItem then
        return true
    end
    local items = mailData.items
    return type(items) == "table" and next(items) ~= nil
end

--- Roster auction / mail attention for ESC and AFK alert cards.
--- Expired is outstanding pickups only (ended listings still on the AH, or
--- expired return mail), not the lifetime auctionHistory ledger.
---@return { expiring: number, expired: number, goldWaiting: number, altsWithMail: number }
function OneWoW_AltTracker_API.GetAttentionSummary()
    local summary = { expiring = 0, expired = 0, goldWaiting = 0, altsWithMail = 0 }
    if OneWoW:IsAddonEnabled("OneWoW_AltTracker_Auctions") then
        OneWoW:BringUp("OneWoW_AltTracker_Auctions")
    end
    if OneWoW:IsAddonEnabled("OneWoW_AltTracker_Storage") then
        OneWoW:BringUp("OneWoW_AltTracker_Storage")
    end

    local auctionsAPI = OneWoW_AltTracker_Auctions_API
    if auctionsAPI and auctionsAPI.GetCharacters then
        local serverTime = GetServerTime()
        local twoHours = 7200
        for _, auctionData in pairs(auctionsAPI.GetCharacters()) do
            for _, auction in ipairs(auctionData.activeAuctions or {}) do
                if auction.endsAt then
                    local timeLeft = auction.endsAt - serverTime
                    if timeLeft <= 0 then
                        summary.expired = summary.expired + 1
                    elseif timeLeft < twoHours then
                        summary.expiring = summary.expiring + 1
                    end
                end
            end
        end
    end

    local storageAPI = OneWoW_AltTracker_Storage_API
    if storageAPI and storageAPI.GetCharacters then
        local selfKey = OneWoW_GUI:GetCharacterKey() or ""
        for charKey, storageData in pairs(storageAPI.GetCharacters()) do
            local mail = storageData.mail
            if mail and mail.mails then
                local hasMail = false
                for _, mailData in pairs(mail.mails) do
                    if type(mailData) == "table" then
                        hasMail = true
                        if (mailData.money or 0) > 0 and MailLooksLikeAuction(mailData) then
                            summary.goldWaiting = summary.goldWaiting + mailData.money
                        end
                        if MailLooksLikeExpired(mailData) and MailHasItems(mailData) then
                            summary.expired = summary.expired + 1
                        end
                    end
                end
                if hasMail and charKey ~= selfKey then
                    summary.altsWithMail = summary.altsWithMail + 1
                end
            end
        end
    end
    return summary
end
