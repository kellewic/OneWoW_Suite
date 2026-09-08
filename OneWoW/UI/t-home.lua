local _, ns = ...

local UI = ns.UI

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local STATUS_TEX_OK  = "Interface\\RaidFrame\\ReadyCheck-Ready"
local STATUS_TEX_BAD = "Interface\\RaidFrame\\ReadyCheck-NotReady"

-- Affordance glyphs beside the card title:
--   common-icon-forwardarrow = hub tab (UI:Show)
--   common-icon-exit         = standalone window (SlashCmdList toggle).
-- "exit" here means "opens outside the hub," not leave UI.
local ATLAS_HUB_TAB    = "common-icon-forwardarrow"
local ATLAS_STANDALONE = "common-icon-exit"

local COLS = 3
local CARD_HEIGHT = 118
local CARD_GAP = 8
local ICON_SIZE = 36

-- Standalone open via each addon's existing slash handler (empty msg = toggle).
local STANDALONE_SLASH = {
    OneWoW_Bags            = "ONEWOW_BAGS",
    OneWoW_DirectDeposit   = "ONEWOW_DD_TOGGLE",
    OneWoW_ShoppingList    = "ONEWOW_SHOPPINGLIST",
    OneWoW_Mail            = "ONEWOW_MAIL",
    OneWoW_Utility_DevTool = "ONEWOW_DEVTOOL",
}

-- The Home tab is read-only: it mirrors effective feature state (Blizzard enable
-- flags + OneWoW soft opt-out via ns:GetFeatureUnitState). Enabling/disabling
-- lives in Settings > Manage Features.
--   all / some / pending_disable -> green check (pending_disable is loaded *now*)
--   notloaded                    -> amber check
--   none (disabled)              -> red X
--   missing                      -> muted grey X
local STATE_ALL, STATE_SOME, STATE_NOTLOADED, STATE_PENDING_DISABLE, STATE_NONE, STATE_MISSING =
    "all", "some", "notloaded", "pendingdisable", "none", "missing"

local function MapFeatureUnitState(unitState)
    if unitState == "all" then return STATE_ALL
    elseif unitState == "some" then return STATE_SOME
    elseif unitState == "not_loaded" then return STATE_NOTLOADED
    elseif unitState == "pending_disable" then return STATE_PENDING_DISABLE
    elseif unitState == "disabled" then return STATE_NONE
    else return STATE_MISSING end
end

local function IsOpenableState(state)
    return state == STATE_ALL or state == STATE_SOME or state == STATE_PENDING_DISABLE
end

function UI:CreateHomeTab(parent)
    local L = ns.L
    local _, content = OneWoW_GUI:CreateScrollFrame(parent, { name = "OneWoW_HomeScroll" })

    -- Each card + the summary bar register ApplyState() here so RefreshAll()
    -- (OnShow + ns.FeatureStateChanged) can re-query live state without rebuild.
    local rowRefreshers = {}

    -- The suite ships as one bundle: every addon's TOC Version bumps together, so
    -- core's version is the canonical one. A per-addon mismatch means the user has
    -- a stale/partial install. DevTool is excluded (separate cadence).
    local coreVersion = ns:GetAddonVersion("OneWoW")
    local catalog = ns.FirstRun.CATALOG

    ---@param addonName string
    ---@param skipParity boolean?
    ---@return boolean
    local function IsVersionMismatch(addonName, skipParity)
        if skipParity or addonName == "OneWoW" or not coreVersion then return false end
        local ver = ns:GetAddonVersion(addonName)
        return ver ~= nil and ver ~= coreVersion
    end

    content:SetHeight(1200)
    local yOffset = -30

    local logo = content:CreateTexture(nil, "ARTWORK")
    logo:SetSize(128, 128)
    logo:SetPoint("TOP", content, "TOP", 0, yOffset)
    logo:SetTexture("Interface\\AddOns\\OneWoW\\Media\\neutral-large.png")
    yOffset = yOffset - 140

    -- What's New (Home-only); Discord / OneWoW Home match former Settings labels+URLs.
    local DISCORD_URL = "https://discord.gg/6vnabDVnDu"
    local WEBSITE_URL = "https://onewow.net/"

    local linksRow = CreateFrame("Frame", nil, content)
    linksRow:SetHeight(24)
    linksRow:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    linksRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)

    local whatsNewLink = OneWoW_GUI:CreateTextLink(linksRow, {
        text = L["HOME_WHATS_NEW"],
        fontSize = 14,
        onClick = function()
            if ns.WhatsNew then
                ns.WhatsNew:Show(true)
            end
        end,
    })
    whatsNewLink:SetPoint("LEFT", linksRow, "LEFT", 5, 0)

    local websiteBtn = OneWoW_GUI:CreateTextLink(linksRow, {
        text = L["LINK_ONEWOW_HOME"],
        fontSize = 14,
        onClick = function()
            OneWoW_GUI:ShowCopyURLDialog(L["LINK_ONEWOW_HOME"], WEBSITE_URL)
        end,
    })
    websiteBtn:SetPoint("RIGHT", linksRow, "RIGHT", -5, 0)

    local discordBtn = OneWoW_GUI:CreateTextLink(linksRow, {
        text = L["DISCORD"],
        fontSize = 14,
        onClick = function()
            OneWoW_GUI:ShowCopyURLDialog(L["DISCORD"], DISCORD_URL)
        end,
    })
    discordBtn:SetPoint("RIGHT", websiteBtn, "LEFT", -20, 0)

    yOffset = yOffset - 28

    local thanksRow = CreateFrame("Frame", nil, content)
    thanksRow:SetHeight(20)
    thanksRow:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    thanksRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)

    local thanksTitle = OneWoW_GUI:CreateFS(thanksRow, 11)
    thanksTitle:SetPoint("LEFT", thanksRow, "LEFT", 5, 0)
    thanksTitle:SetText(L["HOME_SPECIAL_THANKS"])
    thanksTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local thanksNames = OneWoW_GUI:CreateFS(thanksRow, 11)
    thanksNames:SetPoint("LEFT", thanksTitle, "RIGHT", 10, 0)
    thanksNames:SetText(L["HOME_THANKS_NAMES"])
    thanksNames:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    yOffset = yOffset - 24

    local divider2 = content:CreateTexture(nil, "ARTWORK")
    divider2:SetHeight(1)
    divider2:SetPoint("TOPLEFT", content, "TOPLEFT", 40, yOffset)
    divider2:SetPoint("TOPRIGHT", content, "TOPRIGHT", -40, yOffset)
    divider2:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 16

    -- ---- Summary bar: status | version | Manage Features ----
    local summaryBar = CreateFrame("Frame", nil, content, "BackdropTemplate")
    summaryBar:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    summaryBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    summaryBar:SetHeight(28)
    summaryBar:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    summaryBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    summaryBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local summaryLight = summaryBar:CreateTexture(nil, "ARTWORK")
    summaryLight:SetSize(14, 14)
    summaryLight:SetPoint("LEFT", summaryBar, "LEFT", 12, 0)
    summaryLight:SetTexture(STATUS_TEX_OK)

    local summaryText = OneWoW_GUI:CreateFS(summaryBar, 12)
    summaryText:SetPoint("LEFT", summaryLight, "RIGHT", 8, 0)
    summaryText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local summaryVersion = OneWoW_GUI:CreateFS(summaryBar, 12)
    summaryVersion:SetPoint("CENTER", summaryBar, "CENTER", 0, 0)
    summaryVersion:SetText(coreVersion or "")
    summaryVersion:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local manageLink = OneWoW_GUI:CreateTextLink(summaryBar, {
        text = L["HOME_MANAGE_LINK"],
        fontSize = 12,
        nav = true,
        onClick = function()
            UI:OpenManageFeatures()
        end,
    })
    manageLink:SetPoint("RIGHT", summaryBar, "RIGHT", -12, 0)

    yOffset = yOffset - 36

    local gridHost = CreateFrame("Frame", nil, content)
    gridHost:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    gridHost:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)

    local cards = {}

    ---@param entry table FirstRun.CATALOG entry
    ---@return Frame card
    local function CreateAddonCard(entry)
        local addonName = entry.addonName
        local manifest = ns:GetManifestByAddon(addonName)
        local isHub = manifest and manifest.module ~= nil
        local skipParity = addonName == "OneWoW_Utility_DevTool"
        local state

        local card = CreateFrame("Button", nil, gridHost, "BackdropTemplate")
        card:SetHeight(CARD_HEIGHT)
        card:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        card:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        card:RegisterForClicks("LeftButtonUp")
        card:EnableMouse(true)
        card._mismatch = false
        card._hoverable = false

        local function ApplyCardChrome(hovered)
            if hovered and card._hoverable then
                card:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                if card._mismatch then
                    card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
                else
                    card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
                end
                SetCursor("Interface\\CURSOR\\Point")
            else
                card:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                if card._mismatch then
                    card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
                else
                    card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                end
                ResetCursor()
            end
        end

        local light = card:CreateTexture(nil, "ARTWORK")
        light:SetSize(14, 14)
        light:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)

        local lightHit = CreateFrame("Frame", nil, card)
        lightHit:SetSize(16, 16)
        lightHit:SetPoint("CENTER", light, "CENTER")
        lightHit:EnableMouse(true)
        lightHit:SetScript("OnEnter", function(myself)
            ApplyCardChrome(true)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            if state == STATE_ALL or state == STATE_PENDING_DISABLE then
                GameTooltip:SetText(L["HOME_STATUS_ALL"], 0.2, 0.8, 0.2)
            elseif state == STATE_SOME then
                GameTooltip:SetText(L["HOME_STATUS_SOME"], 0.7, 0.7, 0.7)
            elseif state == STATE_NOTLOADED then
                GameTooltip:SetText(L["HOME_STATUS_NOTLOADED"], 1, 0.82, 0, 1, true)
            elseif state == STATE_NONE then
                GameTooltip:SetText(L["HOME_STATUS_NONE"], 1, 0.4, 0.4)
            else
                GameTooltip:SetText(L["HOME_STATUS_NOT_FOUND"], 0.6, 0.6, 0.6)
            end
            GameTooltip:Show()
        end)
        lightHit:SetScript("OnLeave", function()
            GameTooltip:Hide()
            if not card:IsMouseOver() then
                ApplyCardChrome(false)
            end
        end)

        local iconInfo = OneWoW:GetFeatureIcon(entry.addonName)
        local iconFrame
        if iconInfo and iconInfo.plate == false then
            iconFrame = OneWoW_GUI:CreateLayoutFrame(card, {
                width = ICON_SIZE + 6,
                height = ICON_SIZE + 6,
            })
        else
            iconFrame = OneWoW_GUI:CreateFrame(card, {
                width = ICON_SIZE + 6,
                height = ICON_SIZE + 6,
                backdrop = BACKDROP_INNER_NO_INSETS,
                bgColor = "BG_TERTIARY",
                borderColor = "BORDER_SUBTLE",
            })
        end
        iconFrame:SetPoint("TOPLEFT", light, "BOTTOMLEFT", 0, -6)

        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
        if iconInfo and iconInfo.atlas then
            icon:SetAtlas(iconInfo.atlas, false)
        else
            icon:SetTexture((iconInfo and iconInfo.texture) or OneWoW_GUI:GetBrandIcon())
        end
        if iconInfo and iconInfo.texCoords then
            icon:SetTexCoord(unpack(iconInfo.texCoords))
        end

        local title = OneWoW_GUI:CreateFS(card, 13)
        title:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 8, -2)
        title:SetJustifyH("LEFT")
        title:SetText(L[entry.labelKey])
        title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        local afford = card:CreateTexture(nil, "ARTWORK")
        afford:SetSize(12, 12)
        afford:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -10)
        -- exit = opens outside the hub; forwardarrow = hub tab
        afford:SetAtlas(isHub and ATLAS_HUB_TAB or ATLAS_STANDALONE, false)
        title:SetPoint("RIGHT", afford, "LEFT", -4, 0)

        local summary = OneWoW_GUI:CreateFS(card, 11)
        summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        summary:SetPoint("RIGHT", card, "RIGHT", -10, 0)
        summary:SetJustifyH("LEFT")
        summary:SetJustifyV("TOP")
        summary:SetWordWrap(true)
        summary:SetText(L[entry.summaryKey])
        summary:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        summary:SetHeight(44)

        local footerLeft = OneWoW_GUI:CreateFS(card, 11)
        footerLeft:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 8)
        footerLeft:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local footerRight = OneWoW_GUI:CreateFS(card, 11)
        footerRight:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -10, 8)
        footerRight:SetJustifyH("RIGHT")
        footerRight:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))

        local enableBtn = OneWoW_GUI:CreateFitTextButton(card, {
            text = ENABLE,
            height = 18,
            minWidth = 48,
            paddingX = 12,
        })
        enableBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, 6)
        enableBtn:SetScript("OnClick", function()
            UI:OpenManageFeatures()
        end)
        enableBtn:Hide()

        local function OpenFeature()
            local function fallback()
                if isHub then
                    UI:Show(manifest.module)
                    return
                end
                local slashKey = STANDALONE_SLASH[addonName]
                local handler = slashKey and SlashCmdList[slashKey]
                if handler then
                    handler("")
                end
            end
            local click = OneWoW:ResolveFeatureIconClick(addonName, fallback)
            click()
        end

        card:SetScript("OnClick", function()
            if IsOpenableState(state) then
                OpenFeature()
            end
        end)
        card:SetScript("OnEnter", function()
            ApplyCardChrome(true)
        end)
        card:SetScript("OnLeave", function()
            if not lightHit:IsMouseOver() then
                ApplyCardChrome(false)
            end
        end)

        local function ApplyState()
            state = MapFeatureUnitState(ns:GetFeatureUnitState(addonName))
            local mismatch = IsVersionMismatch(addonName, skipParity)
            local openable = IsOpenableState(state)
            local inactive = state == STATE_MISSING or state == STATE_NONE or state == STATE_NOTLOADED
            card._mismatch = mismatch
            -- Openable cards and Enable-target cards react to hover; missing does not.
            card._hoverable = openable or state == STATE_NONE or state == STATE_NOTLOADED

            if state == STATE_ALL or state == STATE_PENDING_DISABLE then
                light:SetTexture(STATUS_TEX_OK)
                light:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            elseif state == STATE_SOME then
                light:SetTexture(STATUS_TEX_OK)
                light:SetVertexColor(0.5, 0.5, 0.5, 1)
            elseif state == STATE_NOTLOADED then
                light:SetTexture(STATUS_TEX_OK)
                light:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            elseif state == STATE_NONE then
                light:SetTexture(STATUS_TEX_BAD)
                light:SetVertexColor(1, 1, 1, 1)
            else
                light:SetTexture(STATUS_TEX_BAD)
                light:SetVertexColor(0.45, 0.45, 0.45, 0.8)
            end

            if inactive then
                title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                summary:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                afford:SetVertexColor(0.45, 0.45, 0.45, 0.7)
                icon:SetDesaturated(true)
                icon:SetVertexColor(0.55, 0.55, 0.55, 1)
            else
                title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                summary:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                afford:SetVertexColor(1, 1, 1, 1)
                icon:SetDesaturated(false)
                icon:SetVertexColor(1, 1, 1, 1)
                OneWoW:ApplyFeatureIconAlert(icon, addonName)
            end

            if mismatch then
                footerRight:SetText(ns:GetAddonVersion(addonName) or "")
                footerRight:Show()
            else
                footerRight:SetText("")
                footerRight:Hide()
            end

            -- Footer-left / Enable share the bottom edge; Enable replaces the
            -- right-slot peer when the card is soft/hard disabled (not missing).
            if state == STATE_MISSING then
                footerLeft:SetText(L["HOME_NOT_INSTALLED"])
                footerLeft:Show()
                enableBtn:Hide()
                afford:Hide()
                title:SetPoint("RIGHT", card, "RIGHT", -10, 0)
            elseif state == STATE_NONE or state == STATE_NOTLOADED then
                footerLeft:SetText(manifest and manifest.cmd or "")
                if footerLeft:GetText() == "" then
                    footerLeft:Hide()
                else
                    footerLeft:Show()
                end
                enableBtn:Show()
                -- Keep version stamp visible beside Enable when mismatched.
                if mismatch then
                    footerRight:ClearAllPoints()
                    footerRight:SetPoint("RIGHT", enableBtn, "LEFT", -8, 0)
                    footerRight:Show()
                end
                afford:Hide()
                title:SetPoint("RIGHT", card, "RIGHT", -10, 0)
            else
                footerLeft:SetText(manifest and manifest.cmd or "")
                footerLeft:Show()
                enableBtn:Hide()
                afford:Show()
                title:SetPoint("RIGHT", afford, "LEFT", -4, 0)
                footerRight:ClearAllPoints()
                footerRight:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -10, 8)
            end

            card._openable = openable
            ApplyCardChrome(card:IsMouseOver() or lightHit:IsMouseOver())
        end

        ApplyState()
        rowRefreshers[#rowRefreshers + 1] = ApplyState
        return card
    end

    for _, entry in ipairs(catalog) do
        cards[#cards + 1] = CreateAddonCard(entry)
    end

    local function LayoutGrid()
        local w = gridHost:GetWidth()
        if not w or w <= 0 then return end
        local colW = math.floor((w - CARD_GAP * (COLS - 1)) / COLS)
        local rows = math.ceil(#cards / COLS)
        for i, card in ipairs(cards) do
            local col = (i - 1) % COLS
            local row = math.floor((i - 1) / COLS)
            card:ClearAllPoints()
            card:SetWidth(colW)
            card:SetPoint(
                "TOPLEFT",
                gridHost,
                "TOPLEFT",
                col * (colW + CARD_GAP),
                -row * (CARD_HEIGHT + CARD_GAP)
            )
        end
        local gridH = rows * CARD_HEIGHT + math.max(0, rows - 1) * CARD_GAP
        gridHost:SetHeight(gridH)
    end

    gridHost:HookScript("OnSizeChanged", LayoutGrid)
    C_Timer.After(0, LayoutGrid)

    local gridRows = math.ceil(#catalog / COLS)
    local gridH = gridRows * CARD_HEIGHT + math.max(0, gridRows - 1) * CARD_GAP
    gridHost:SetHeight(gridH)
    yOffset = yOffset - gridH - 12

    -- Attention list from FeatureHealth (version / broken / diminished / load_pending).
    local attentionHost = CreateFrame("Frame", nil, content)
    attentionHost:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    attentionHost:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    attentionHost:SetHeight(1)

    local attentionRowPool = {}

    -- ---- Command Options (DD + Shopping List subcommands only) ----
    local cmdContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    cmdContainer:SetPoint("TOPLEFT", attentionHost, "BOTTOMLEFT", 0, -12)
    cmdContainer:SetPoint("TOPRIGHT", attentionHost, "BOTTOMRIGHT", 0, -12)
    cmdContainer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    cmdContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    cmdContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local cmdTitle = OneWoW_GUI:CreateFS(cmdContainer, 16)
    cmdTitle:SetPoint("TOPLEFT", cmdContainer, "TOPLEFT", 15, -12)
    cmdTitle:SetText(L["HOME_COMMAND_OPTIONS"])
    cmdTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local cmdHDiv = cmdContainer:CreateTexture(nil, "ARTWORK")
    cmdHDiv:SetHeight(1)
    cmdHDiv:SetPoint("TOPLEFT",  cmdContainer, "TOPLEFT",  8, -36)
    cmdHDiv:SetPoint("TOPRIGHT", cmdContainer, "TOPRIGHT", -8, -36)
    cmdHDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local cmdVDiv = cmdContainer:CreateTexture(nil, "ARTWORK")
    cmdVDiv:SetWidth(1)
    cmdVDiv:SetPoint("TOP",    cmdContainer, "TOP",    0, -40)
    cmdVDiv:SetPoint("BOTTOM", cmdContainer, "BOTTOM", 0, 8)
    cmdVDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local cmdLeft = CreateFrame("Frame", nil, cmdContainer)
    cmdLeft:SetPoint("TOPLEFT",     cmdContainer, "TOPLEFT", 0, -40)
    cmdLeft:SetPoint("BOTTOMRIGHT", cmdContainer, "BOTTOM",  0, 0)

    local cmdRight = CreateFrame("Frame", nil, cmdContainer)
    cmdRight:SetPoint("TOPLEFT",     cmdContainer, "TOP",         0, -40)
    cmdRight:SetPoint("BOTTOMRIGHT", cmdContainer, "BOTTOMRIGHT", 0, 0)

    local function RenderSets(panel, sets)
        local pY = -8
        for _, set in ipairs(sets) do
            local show = set.always or (_G[set.global] ~= nil)
            if show then
                local hdr = OneWoW_GUI:CreateFS(panel, 10)
                hdr:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, pY)
                hdr:SetText(set.header)
                hdr:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                pY = pY - 18
                for _, cmdInfo in ipairs(set.commands) do
                    local cmdText = OneWoW_GUI:CreateFS(panel, 12)
                    cmdText:SetPoint("TOPLEFT", panel, "TOPLEFT", 30, pY)
                    cmdText:SetText("|cFFFFFFFF" .. cmdInfo.cmd .. "|r")
                    cmdText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                    local descText = OneWoW_GUI:CreateFS(panel, 12)
                    descText:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, pY)
                    descText:SetText("- " .. cmdInfo.desc)
                    descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                    pY = pY - 20
                end
                pY = pY - 8
            end
        end
        return pY
    end

    local leftEndY = RenderSets(cmdLeft, {
        {
            global = "OneWoW_DirectDeposit",
            header = "Direct Deposit",
            commands = {
                { cmd = "/1wdd",              desc = L["CMD_OPEN_DD"] },
                { cmd = "  /1wdd deposit",    desc = L["CMD_MANUAL_DEPOSIT"] },
                { cmd = "  /1wdd pause|stop", desc = L["CMD_DEPOSIT_PAUSE"] },
            },
        },
    })

    local rightEndY = RenderSets(cmdRight, {
        {
            global = "OneWoW_ShoppingList",
            header = "Shopping List",
            commands = {
                { cmd = "/1wsl",            desc = L["CMD_OPEN_SL"] },
                { cmd = "  /1wsl add <id>", desc = L["CMD_SL_ADD"] },
            },
        },
    })

    local cmdHeight = 40 + math.max(math.abs(leftEndY), math.abs(rightEndY), 24) + 15
    cmdContainer:SetHeight(cmdHeight)

    local function UpdateContentHeight()
        local top = math.abs(select(5, attentionHost:GetPoint(1)) or yOffset)
        local attH = attentionHost:GetHeight() or 0
        content:SetHeight(top + attH + 12 + cmdHeight + 50)
    end

    local function RefreshSummary()
        local items, loaded = ns:EvaluateSuiteAttention()
        local attention = #items
        local fmt = (attention == 1) and L["HOME_SUMMARY_FORMAT_ONE"] or L["HOME_SUMMARY_FORMAT"]
        summaryText:SetText(string.format(fmt, loaded, attention))
        if attention > 0 then
            summaryLight:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
        else
            summaryLight:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        end

        for _, row in ipairs(attentionRowPool) do
            row:Hide()
        end

        local rowY = 0
        local ROW_H = 36
        local ROW_GAP = 8
        for i, item in ipairs(items) do
            local row = attentionRowPool[i]
            if not row then
                row = CreateFrame("Frame", nil, attentionHost, "BackdropTemplate")
                row:SetHeight(ROW_H)
                row:SetBackdrop(BACKDROP_INNER_NO_INSETS)
                row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))

                local warnIcon = row:CreateTexture(nil, "ARTWORK")
                warnIcon:SetSize(16, 16)
                warnIcon:SetPoint("LEFT", row, "LEFT", 10, 0)
                warnIcon:SetAtlas("transmog-icon-warning", false)
                warnIcon:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
                row.warnIcon = warnIcon

                local dismissLink = OneWoW_GUI:CreateTextLink(row, {
                    text = L["HOME_ATTENTION_DISMISS"],
                    fontSize = 11,
                    onClick = function()
                        if row._attentionId then
                            ns:DismissFeatureAttention(row._attentionId)
                        end
                    end,
                })
                dismissLink:SetPoint("RIGHT", row, "RIGHT", -12, 0)
                row.dismissLink = dismissLink

                local footerText = OneWoW_GUI:CreateFS(row, 12)
                footerText:SetPoint("LEFT", warnIcon, "RIGHT", 8, 0)
                footerText:SetPoint("RIGHT", dismissLink, "LEFT", -8, 0)
                footerText:SetJustifyH("LEFT")
                footerText:SetWordWrap(true)
                footerText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
                row.footerText = footerText

                attentionRowPool[i] = row
            end

            row._attentionId = item.id
            row.footerText:SetText(item.text)
            row.footerText:ClearAllPoints()
            row.footerText:SetPoint("LEFT", row.warnIcon, "RIGHT", 8, 0)
            if item.dismissable then
                row.dismissLink:Show()
                row.footerText:SetPoint("RIGHT", row.dismissLink, "LEFT", -8, 0)
            else
                row.dismissLink:Hide()
                row.footerText:SetPoint("RIGHT", row, "RIGHT", -10, 0)
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", attentionHost, "TOPLEFT", 0, -rowY)
            row:SetPoint("TOPRIGHT", attentionHost, "TOPRIGHT", 0, -rowY)
            row:Show()
            rowY = rowY + ROW_H + (i < #items and ROW_GAP or 0)
        end

        attentionHost:SetHeight(math.max(rowY, 1))
        UpdateContentHeight()
    end

    rowRefreshers[#rowRefreshers + 1] = RefreshSummary
    RefreshSummary()

    local function RefreshAll()
        for _, fn in ipairs(rowRefreshers) do fn() end
    end
    parent.RefreshStatus = RefreshAll
    parent:HookScript("OnShow", RefreshAll)
    EventRegistry:UnregisterCallback(OneWoW:GetFeatureIconAlertEvent(), UI)
    EventRegistry:RegisterCallback(OneWoW:GetFeatureIconAlertEvent(), RefreshAll, UI)
end
