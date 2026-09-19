# OneWoW AltTracker: Storage

> **See also:** [OneWoW/Docs/ARCHITECTURE.md](../../OneWoW/Docs/ARCHITECTURE.md) §6 (store access rules)

A specialized datastore addon that tracks all storage-related data for World of Warcraft characters including bags, banks, guild banks, warband banks, and mail.

## Overview

This addon automatically collects and stores detailed inventory data across all characters. The data is stored per-character and can be accessed by other addons through the provided API.

## What Data is Collected

### Shared scanner & canonical slot record

The Bags, Personal Bank, Warband Bank, and Guild Bank modules all scan the same
kind of slot, so the slot iteration and the record builder live in one place:
`Modules/ContainerScan.lua` (`ns.ContainerScan`).

- `ContainerScan:BagSlots(bagID)` scans any `C_Container` bag (a backpack bag, a
  personal-bank tab bag, or a warband tab bag — all the same API) and returns the
  slot map (keyed by slotID), the used-slot count, and the bag's slot count.
- `ContainerScan:GuildTabSlots(tabID)` scans a guild tab (the guild API; quality
  is recovered from the link's color code, which the guild API doesn't expose).

Both emit the **canonical slot record** — one uniform shape across every container:

```lua
{
    itemID     = number,
    itemLink   = string,
    itemName   = string,
    quality    = number,
    itemLevel  = number,
    texture    = number,
    sellPrice  = number,   -- 0 if none
    stackCount = number,
    isLocked   = boolean,
    isBound    = boolean,  -- nil for guild slots (the guild API can't report bind)
}
```

Each container module keeps only its own outer structure — flat bags vs. tabs,
per-tab slot accounting, money totals, and where it writes — and calls the shared
scanner for the slots. Mail is the exception: its expiry math and accounting hooks
mean it keeps its own write path and record shape (see the Mail module below).

### 1. Bags Module
**File:** `Modules/Bags.lua`

**Collects:**
- Bag IDs 0-5 (backpack + 4 bag slots + reagent bag)
- Each slot contains:
  - Item ID, Link, Name
  - Quality, Item Level
  - Texture icon
  - Stack count
  - Lock status (if currently being moved)
  - Bind status (isBound)
- Number of slots per bag
- Last update timestamp

**Event Triggers:**
- `OneWoW.Inventory` delayed channel (`BAG_UPDATE_DELAYED`) — automatically tracks when bag contents change

**Stored In:** `charData.bags`

### 2. Personal Bank Module
**File:** `Modules/PersonalBank.lua`

**Collects:**
- Bank bag ID -1 (main bank slots)
- Bank bags 1-7 (purchasable bank bag slots)
- Each slot contains:
  - Item ID, Link, Name
  - Quality, Item Level
  - Texture icon
  - Stack count
  - Lock status
  - Bind status
- Number of slots per bag
- Last update timestamp

**Event Triggers:**
- `OneWoW.Inventory` bank-open channel (`BANKFRAME_OPENED`, 0.5s delay) and delayed channel while the character bank is usable

**Stored In:** `charData.personalBank`

### 3. Warband Bank Module
**File:** `Modules/WarbandBank.lua`

**Collects:**
- Warband Bank tabs 1-5
- Total account money stored in warband bank
- For each tab:
  - Tab name and icon
  - Up to 98 slots per tab
  - Each slot contains:
    - Item ID, Link, Name
    - Quality, Item Level
    - Texture icon
    - Stack count
    - Lock status
    - Bind status
- Last update timestamp

**Event Triggers:**
- `OneWoW.Inventory` bank-open / delayed channels when `C_Bank.CanUseBank(Account)`
- Uses `C_Bank.FetchDepositedMoney` and `C_Bank.FetchPurchasedBankTabData`

**Stored In:** `OneWoW_AltTracker_Storage_DB.warbandBank` (account-level, not per-character)

### 4. Guild Bank Module
**File:** `Modules/GuildBank.lua`

**Collects:**
- Guild name
- Total guild bank money
- Guild bank tabs 1-8
- For each viewable tab:
  - Tab name, icon
  - Deposit permissions
  - Up to 98 slots per tab
  - Each slot contains:
    - Item ID, Link, Name
    - Quality, Item Level
    - Texture icon
    - Stack count
    - Lock status
- Last update timestamp

**Event Triggers:**
- `OneWoW.Inventory` guild-open channel (0.5s delay) → `CollectGuildBank`
- `OneWoW.Inventory` guild-tabs channel (0.2s delay)
- `OneWoW.Inventory` guild-slots channel (~0.1s after Inventory's ~0.2s coalesce)

**Stored In:** `OneWoW_AltTracker_Storage_DB.guildBanks[guildName]` (account-level, keyed by guild)

**Special Behavior:**
- Returns early without writing if the character is not in a guild

### 5. Mail Module
**File:** `Modules/Mail.lua`

**Collects:**
- Total number of mail items
- Up to 20 most recent mail items
- For each mail:
  - Sender name
  - Subject line
  - Money amount
  - COD amount
  - Days left until expiration
  - Read status
  - Return status
  - Reply capability
  - GM mail flag
  - Attached items (up to `ATTACHMENTS_MAX_RECEIVE`)
  - For each attachment:
    - Item name, link, ID
    - Texture icon
    - Stack count
    - Quality
    - Usability flag
- Last update timestamp

**Event Triggers:**
- `MAIL_SHOW` - collected when mailbox opened (0.5s delay)
- `MAIL_INBOX_UPDATE` - updates when mail changes (0.2s delay)
- `UPDATE_PENDING_MAIL` - updates when pending mail indicator changes (0.2s delay)

**Stored In:** `charData.mail`

## Database Structure

### Saved Variable
**Name:** `OneWoW_AltTracker_Storage_DB`

**Root Structure:**
```lua
OneWoW_AltTracker_Storage_DB = {
    characters = {
        ["CharName-RealmName"] = { --[[ per-character data, below ]] },
    },
    warbandBank = { --[[ account-wide, below ]] },     -- shared across all characters
    guildBanks = {
        ["GuildName"] = { --[[ per-guild data, below ]] },
    },
    settings = {
        enableDataCollection = true,
        trackBags = true,
        trackPersonalBank = true,
        trackWarbandBank = true,
        trackGuildBank = true,
        trackMail = true,
    },
    version = 1,
}
```

Each occupied slot holds the **canonical slot record** (see
[Shared scanner & canonical slot record](#shared-scanner--canonical-slot-record)
above); `SLOT` below is that shape.

### Per-Character Data
**Character Key Format:** `"CharacterName-RealmName"`

```lua
characters["CharName-RealmName"] = {
    -- Backpack + bags 0-5, flat (each bag is its own unit, keyed by bagID).
    bags = {
        [bagID] = {
            numSlots = number,
            slots = { [slotID] = SLOT },
        },
    },
    bagsLastUpdate = timestamp,

    -- Character bank, tabbed (tab N lives in container bag 5+N).
    personalBank = {
        tabs = {
            [tabIndex] = {
                items = { [slotID] = SLOT },
                totalSlots = number,
                usedSlots = number,
                freeSlots = number,
            },
        },
    },
    personalBankLastUpdate = timestamp,

    -- Mail keeps its own (non-canonical) attachment shape.
    mail = {
        numMails = number,
        hasAnyMail = boolean,
        hasNewMail = boolean,
        mails = {
            [mailID] = {
                sender = string,
                subject = string,
                money = number,
                CODAmount = number,
                daysLeft = number,
                hasItem = boolean,
                wasRead = boolean,
                wasReturned = boolean,
                canReply = boolean,
                isGM = boolean,
                collectedAt = timestamp,
                items = {
                    [attachmentIndex] = {
                        name = string,
                        itemLink = string,
                        itemID = number,
                        itemName = string,
                        texture = number,
                        sellPrice = number,
                        count = number,
                        quality = number,
                        canUse = boolean,
                    },
                },
            },
        },
    },
    mailLastUpdate = timestamp,
}
```

### Account-Wide Data (DB root, not per-character)

```lua
-- Warband bank: shared across the whole account, written by whichever character
-- last scanned it. Tabbed (up to 5; tab N lives in container bag 11+N).
OneWoW_AltTracker_Storage_DB.warbandBank = {
    money = number,
    tabs = {
        [tabIndex] = {
            items = { [slotID] = SLOT },
            totalSlots = number,
            usedSlots = number,
            freeSlots = number,
        },
    },
    totalSlots = number,
    totalFree = number,
    totalUsed = number,
    lastUpdateTime = timestamp,
    lastUpdatedBy = "CharName-RealmName",
}

-- Guild banks: one entry per guild, keyed by guild name (up to 8 viewable tabs).
OneWoW_AltTracker_Storage_DB.guildBanks["GuildName"] = {
    guildName = string,
    money = number,
    tabs = {
        [tabID] = {
            slots = { [slotID] = SLOT },
            name = string,
            icon = number,
            canDeposit = boolean,
        },
    },
    lastUpdateTime = timestamp,
    lastUpdatedBy = "CharName-RealmName",
}
```

## Data Collection Orchestration

### DataManager (Modules/DataManager.lua)
The DataManager orchestrates all data collection:

1. **Initialization** - Arms Inventory callbacks (bag/bank/guild) + local mail events
2. **Event Handling** - Routes triggers to appropriate collection modules
3. **Module Coordination** - Calls individual module collection functions
4. **Settings Respect** - Only collects data if tracking is enabled for that module

Bag/bank/guild *WoW* events are owned by
[`OneWoW.Inventory`](../../OneWoW/Docs/INVENTORY.md); DataManager subscribes via
`RegisterDelayedCallback` / `RegisterBankOpenCallback` /
`RegisterGuildOpenCallback` / `RegisterGuildTabsCallback` /
`RegisterGuildSlotsCallback`. Mail and `PLAYER_LOGOUT` stay on DataManager's
local frame (not Inventory-owned yet).

DataManager remains the **single owner of the post-write signal** — after a
`Collect*` writes to SavedVariables it fires `NotifyStorageChanged(scope, charKey)`
(`scope = "bags"|"personal"|"warband"|"guild"|"mail"`). Subscribe with
`RegisterStorageChanged(fn)` (also exposed on the public API); each listener is
called in a `pcall` so one failure can't stop the rest. Every other piece of the
unit reacts to that signal rather than registering its own bag/bank/guild/mail
copies for UI refresh.

Two listeners use this today:

- **ItemIndex** rebuilds its inverted index on the signal, so it reads
  SavedVariables after the scanner has written them. (It keeps only its own
  `PLAYER_EQUIPMENT_CHANGED` handler, since equipment is collected by the Character
  unit, not the DataManager.)
- The **AltTracker Items tab** re-renders on the signal (debounced, visibility-gated).

### Event Flow
```
Bag / bank / guild change
    ↓
OneWoW.Inventory (delayed / bank-open / guild-* channels)
    ↓
DataManager:OnInventoryDelayed / OnBankOpened /
    OnGuildBankOpened / OnGuildBankTabsUpdated / OnGuildBankSlotsChanged
    ↓
Adds delay for data loading (0.1-0.5s) where needed
    ↓
Calls appropriate module CollectData()
    ↓
Module stores data in character / guild table
    ↓
NotifyStorageChanged → ItemIndex / UI

Mail / logout
    ↓
DataManager local frame → HandleEvent → Collect* (same write path)
```

## How To Access The Data

### Accessing Data from Other Addons

Other addons must read storage data through `OneWoW_AltTracker_Storage_API` — **not**
by touching `OneWoW_AltTracker_Storage_DB` directly (see
[OneWoW/Docs/ARCHITECTURE.md](../../OneWoW/Docs/ARCHITECTURE.md) §6, enforced by the
`no-data-manager-bypass` pre-commit hook):

```lua
local API = OneWoW_AltTracker_Storage_API
if API then
    local charKey = "CharName-RealmName"

    -- Bags
    local bags = API.GetBags(charKey)
    if bags then
        for bagID, bagData in pairs(bags) do
            print("Bag " .. bagID .. " has " .. bagData.numSlots .. " slots")
            if bagData.slots then
                for slotID, itemData in pairs(bagData.slots) do
                    print("  " .. itemData.itemName .. " x" .. itemData.stackCount)
                end
            end
        end
    end

    -- Personal Bank (tabbed)
    local personalBank = API.GetPersonalBank(charKey)
    if personalBank and personalBank.tabs then
        for tabIndex, tabData in pairs(personalBank.tabs) do
            print("Bank tab " .. tabIndex .. ": " .. tabData.usedSlots .. "/" .. tabData.totalSlots)
        end
    end

    -- Mail
    local mail = API.GetMail(charKey)
    if mail and mail.mails then
        print("Total mail items:", mail.numMails)
        for mailID, mailData in ipairs(mail.mails) do
            print("From:", mailData.sender, "Subject:", mailData.subject)
        end
    end

    -- Guild Bank (current player's guild)
    local guildBank = API.GetGuildBank(charKey)
    if guildBank then
        print("Guild:", guildBank.guildName)
        print("Guild Bank Money:", guildBank.money)
    end
end
```

### Search for Items Across All Characters

Use `GetItemIndex()` for inverted lookups, or iterate `GetCharacters()`:

```lua
local API = OneWoW_AltTracker_Storage_API
local searchItemID = 12345
if API then
  local locations = API.GetItemIndex():GetFamilyLocations(searchItemID)
  -- locations is a structured rollup across bags, banks, mail, etc.
end
```

## Query Layer (cross-alt gather / filter / group / duplicates)

`Modules/Query.lua` is the read-side counterpart to the scanners. A container
descriptor registry (bags / personal / warband / guild / mail, plus an `auction`
descriptor that reads the Auctions sibling unit's API) drives a single `Gather`
that normalizes every stored slot — whatever its on-disk shape — into a uniform
`OneWoWItemInstance` list. Filtering, grouping, and the duplicate finder are passes
on top, so callers gather once and filter cheaply.

```lua
local API = OneWoW_AltTracker_Storage_API

-- Gather (expensive, scope-driven): normalized instances for the chosen sources.
local insts = API.Gather({
    chars = "all",                       -- "all" | "Char-Realm" | { keys... }
    containers = { bags = true, personal = true, warband = true,
                   guild = true, mail = true, auction = true },
    guilds = nil,                        -- optional guild-name filter
})

-- Filter (cheap, predicate-driven): compiles a PredicateEngine expression once.
local gear = API.Filter(insts, "#gear & ilvl>=600")

-- Group by a key function (or "itemID" / "none").
local groups = API.Group(insts, function(i) return "id:" .. i.itemID end)

-- One-shot Gather -> Filter -> Group for non-interactive callers.
local rollup = API.Query({ chars = "all", containers = { bags = true }, group = "itemID" })

-- Duplicate finder: groups holding more than one copy under a "what counts as a
-- duplicate" spec. Presets seed the spec; GetDefaultDupeSpec is the starting point.
local dupes = API.FindDuplicates({
    chars = "all",
    containers = { bags = true, personal = true, warband = true, guild = true, mail = true },
    dupe = API.GetDefaultDupeSpec(),
})
```

Related API surface:

| Function | Purpose |
|---|---|
| `API.Gather(scope) -> instances[]` | Normalize every occupied slot in scope into `OneWoWItemInstance`. |
| `API.Filter(instances, predicate) -> instances[]` | Keep instances matching a PredicateEngine expression (compiled once). |
| `API.Group(instances, keyFn) -> groups[]` | Bucket instances by a key function (nil key skips the instance). |
| `API.Query(opts) -> instances[]\|groups[]` | One-shot gather → filter → group. |
| `API.FindDuplicates(opts) -> groups[]` | Groups with ≥ `minCount` copies under a dupe spec, with the ilvl within-bucket pass. |
| `API.GetEffectiveILvl(instance) -> number` | Effective item level for an instance (lazy, memoized on the record). |
| `API.GetDupePresets()` / `API.GetDefaultDupeSpec()` | Named dupe specs / a fresh copy of the default spec. |
| `API.RegisterStorageChanged(fn)` | Subscribe to the post-write `{ scope, charKey }` signal (see DataManager above). |

## When Data is Collected

### Automatic Collection
- **Bags:** Every time bag contents change (`OneWoW.Inventory` delayed channel ← `BAG_UPDATE_DELAYED`)
- **Personal Bank:** When bank is opened (`OneWoW.Inventory` bank-open channel ← `BANKFRAME_OPENED`) and on bag changes while the character bank is usable
- **Warband Bank:** Same Inventory bank-open / delayed path when the account bank is usable
- **Guild Bank:** When guild bank is opened, tabs switch, or slots change (`OneWoW.Inventory` guild channels)
- **Mail:** When mailbox is opened or inbox updates (`MAIL_SHOW`, `MAIL_INBOX_UPDATE` — still owned by DataManager)

### Login Collection
- Automatically collects bag data on `PLAYER_LOGIN`

## Settings

Collection toggles live in `OneWoW_AltTracker_Storage_DB.settings` and are owned by this
store unit (defaults/init bridges in `Core/Database.lua`). They are **not** part of the
cross-unit `_API` contract.

## Integration with Other Addons

This addon is designed to be used by:
- **OneWoW_AltTracker** - Main UI and display addon
- Any other addon that needs storage data across characters

## Dependencies
- **Required:** OneWoW (Inventory funnel + suite hub)
- **Optional:** OneWoW_AltTracker (for UI integration)
- **Required:** World of Warcraft interface 120000+

## File Structure
```
OneWoW_AltTracker_Storage/
├── Core/
│   ├── Database.lua       - Database structure and access functions
│   ├── API.lua            - Public API (global OneWoW_AltTracker_Storage_API)
│   └── Core.lua           - Addon initialization and event handling
├── Modules/
│   ├── ContainerScan.lua - Shared slot scanner + canonical record builder
│   ├── Bags.lua          - Bag data collection
│   ├── PersonalBank.lua  - Personal bank data collection
│   ├── WarbandBank.lua   - Warband bank data collection
│   ├── GuildBank.lua     - Guild bank data collection
│   ├── Mail.lua          - Mail data collection
│   ├── ItemIndex.lua     - Inverted item -> location index (tooltips)
│   ├── Query.lua         - Cross-alt gather / filter / group / duplicate finder
│   └── DataManager.lua   - Orchestrates collection; Inventory for bag/bank/guild;
│                           local frame for mail; post-write signal
├── Locales/
│   └── enUS.lua          - English localization
├── OneWoW_AltTracker_Storage.lua  - Main addon file (no public globals; API lives in Core/API.lua)
└── OneWoW_AltTracker_Storage.toc  - Addon manifest
```

## Version
**Current Version:** B6.2602.1600

## Author
OneWoW Development Team

## Website
https://onewow.net/
