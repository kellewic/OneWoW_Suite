local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local format = string.format
local floor, abs = math.floor, math.abs

-- ============================================================================
-- Format
-- ============================================================================
-- Suite-wide number and money formatting. Money display preferences
-- (moneyDisplay.*) live in OneWoW_DB and are read through
-- OneWoW_GUI:GetSetting at call time so toggles apply immediately.
-- ============================================================================

local Format = {}
ns.Format = Format

--- Format a number with digit grouping. Grouping off returns the raw digits.
--- Regional mode uses FormatLargeNumber (client locale separator). Otherwise
--- US-style commas.
---@param n number|string|nil coerced via tonumber; nil/invalid treated as 0
---@return string
function Format.FormatNumber(n)
    n = floor(tonumber(n) or 0)
    if n < 0 then
        n = abs(n)
    end
    if not OneWoW_GUI:GetSetting("moneyDisplay.useGrouping") then
        return tostring(n)
    end
    if OneWoW_GUI:GetSetting("moneyDisplay.useRegionalNumbers") then
        return FormatLargeNumber(n)
    end
    local s = tostring(n)
    local pos = #s % 3
    if pos == 0 then pos = 3 end
    local parts = { s:sub(1, pos) }
    for i = pos + 1, #s, 3 do
        parts[#parts + 1] = s:sub(i, i + 2)
    end
    return table.concat(parts, ",")
end

local GOLD_DIGIT = "|cFFFFD100"
local SILVER_DIGIT = "|cFFC0C0C0"
local COPPER_DIGIT = "|cFFAD6A24"
local WHITE_DIGIT = "|cFFFFFFFF"

---@param useWhite boolean
---@return string goldColor
---@return string silverColor
---@return string copperColor
local function AmountColors(useWhite)
    if useWhite then
        return WHITE_DIGIT, WHITE_DIGIT, WHITE_DIGIT
    end
    return GOLD_DIGIT, SILVER_DIGIT, COPPER_DIGIT
end

--- Color the amount with a |cAARRGGBB prefix, then append the coin texture from a Blizzard %d texture fmt.
---@param color string
---@param amount number
---@param textureFmt string SILVER_AMOUNT_TEXTURE or COPPER_AMOUNT_TEXTURE
---@return string
local function ColoredCoinTexture(color, amount, textureFmt)
    local icon = textureFmt:format(amount, 0, 0):match("|T.+")
    return color .. amount .. "|r" .. icon
end

---@param gold number
---@param silver number
---@param cop number
---@param useWhite boolean
---@return string
local function CoinTextureString(gold, silver, cop, useWhite)
    local gC, sC, cC = AmountColors(useWhite)
    local goldStr = GOLD_AMOUNT_TEXTURE_STRING:format(gC .. Format.FormatNumber(gold) .. "|r", 0, 0)
    local silverStr = ColoredCoinTexture(sC, silver, SILVER_AMOUNT_TEXTURE)
    local copperStr = ColoredCoinTexture(cC, cop, COPPER_AMOUNT_TEXTURE)
    if gold > 0 then
        return goldStr .. " " .. silverStr .. " " .. copperStr
    elseif silver > 0 then
        return silverStr .. " " .. copperStr
    end
    return copperStr
end

--- Format a copper amount as gold/silver/copper text. Respects the
--- moneyDisplay settings: coin textures vs colored g/s/c letters, and
--- white vs classic gold/silver/copper digits in both modes. Gold amounts
--- always use FormatNumber grouping. goldOnly keeps the gold amount
--- (including 0) and drops silver and copper.
---@param copper number|nil copper amount; nil/non-number treated as 0
---@param goldOnly boolean|nil when true, omit silver and copper
---@return string
function Format.FormatGold(copper, goldOnly)
    if copper == nil or type(copper) ~= "number" then
        copper = 0
    else
        copper = floor(tonumber(copper) or 0)
    end

    local useLetters = OneWoW_GUI:GetSetting("moneyDisplay.useLetters")
    local useWhite = OneWoW_GUI:GetSetting("moneyDisplay.useWhiteValues")
    local isNegative = copper < 0
    local absCopper = abs(copper)
    local gold = floor(absCopper / 10000)
    local silver = floor((absCopper % 10000) / 100)
    local cop = absCopper % 100
    local prefix = isNegative and "-" or ""
    local goldNum = Format.FormatNumber(gold)

    if goldOnly then
        local gC = AmountColors(useWhite)
        if not useLetters then
            return prefix .. GOLD_AMOUNT_TEXTURE_STRING:format(gC .. goldNum .. "|r", 0, 0)
        end
        return prefix .. format("%s%s|r%sg|r", gC, goldNum, GOLD_DIGIT)
    end

    if not useLetters then
        return prefix .. CoinTextureString(gold, silver, cop, useWhite)
    end

    local gC, sC, cC = AmountColors(useWhite)
    if gold > 0 then
        return prefix .. format(
            "%s%s|r%sg|r %s%s|r%ss|r %s%s|r%sc|r",
            gC, goldNum, GOLD_DIGIT, sC, silver, SILVER_DIGIT, cC, cop, COPPER_DIGIT
        )
    elseif silver > 0 then
        return prefix .. format(
            "%s%s|r%ss|r %s%s|r%sc|r",
            sC, silver, SILVER_DIGIT, cC, cop, COPPER_DIGIT
        )
    end
    return prefix .. format("%s%s|r%sc|r", cC, cop, COPPER_DIGIT)
end
