# OneWoW - AltTracker

**Comprehensive character management system. Track all your characters' progress, gold, professions, equipment, auctions, and more across your entire account.**

---

## Features

### Summary Tab
Get a quick overview of your entire account at a glance:
- Total gold across all characters
- Number of characters and which factions/servers they're on
- Mount, pet, and achievement collection totals
- Character classes and specializations
- How many characters are rested
- Total playtime on account

### Progress Tab
Track the most important progress across all your characters:
- Quest and campaign progress for each character
- Character levels and advancement
- Which areas/zones you've quested in
- Expansion completion status
- Current objectives and milestones

### Bank Tab
View your bank contents without logging in:
- Personal bank tabs for each character
- Warband bank (shared across faction)
- Guild bank contents
- Inventory/bag contents
- Reagent storage
- Quickly find items across all characters' storage
- Manually update banks to refresh data

### Equipment Tab
Track gear across your characters:
- Current equipped items
- Item levels per character
- Gear quality and rarity
- What gear sets each character has
- Equipment comparisons between characters

### Professions Tab
See all crafting professions at a glance:
- Profession skill levels for each character
- Recipe knowledge (which recipes you've learned)
- Specialization information
- Available crafts by profession
- Track crafting materials you have

### Auctions Tab
Manage auctions across all your characters:
- See all active auctions and bids
- Monitor auction status (selling, bidding, expiring soon)
- Track total gold from auction sales
- Gold waiting in mailboxes from sales
- Filter auctions by character, status, or type
- See how much time is left on auctions
- Sold/expired auction history and success rates

### Financials Tab
Complete financial tracking for your account:
- Total gold balance across all characters
- Daily income and expenses
- Track where gold is coming from (farming, crafting, sales)
- Track where gold is going (repairs, purchases, crafting)
- View profit/loss over time
- Filter by character or income source
- See trends in your gold-making

### Items Tab
Find items across your entire account:
- Search for specific items by name
- See which characters have items
- How many of each item you have across all characters
- Item rarity and type
- Quick reference for farming or crafting material locations

### Profiles Tab
Backup and restore character data:
- Save character action bars (keybindings and ability layouts)
- Save and restore macros
- Save and restore keybinds
- Share profiles between characters or accounts
- Restore action bars when changing specs or rerolling
- Multi-spec profile support

### Lockouts Tab
Track dungeon and raid lockouts:
- See which raid tiers your characters have cleared
- Dungeon completion status
- Mythic+ progress
- Lockout expiration times
- Plans for weekly clears

### Action Bars & Setup
Save and restore your entire setup:
- Save your action bar configuration (skill placement)
- Save all your macros and keybinds
- Restore on a new character or respec
- Switch setups between characters with one click
- Backup to prevent losing customizations

---

## Data Collection

AltTracker receives character data from specialized companion addons:
- **OneWoW_AltTracker_Character** - Basic character info, stats, equipment
- **OneWoW_AltTracker_Auctions** - Active auctions and bids
- **OneWoW_AltTracker_Collections** - Quests, reputations, achievements, pets, mounts
- **OneWoW_AltTracker_Endgame** - Mythic Plus, raids, Great Vault, PVP
- **OneWoW_AltTracker_Professions** - Profession skills, recipes, cooldowns
- **OneWoW_AltTracker_Storage** - Bags, banks (personal, warband, guild), mail
- **OneWoW_AltTracker_Accounting** - Gold and currency balances

---

## Customization

### Theme Options
Suite color themes via **OneWoW** settings. Switch instantly with no reload.

### Multi-Language Support
Supports all 11 suite locales via **OneWoW**.

---

## Installation

1. Extract the `OneWoW_AltTracker` folder and all `OneWoW_AltTracker_*` companion addons to your `World of Warcraft\_retail_\Interface\AddOns\` directory
2. Extract the `OneWoW` folder (required dependency) to the same directory
3. Restart World of Warcraft or type `/reload` in-game
4. Type `/1wat` to open the addon

## Requirements

- **OneWoW** - Core hub addon (required)
- **OneWoW_AltTracker_*** - Companion data stores (recommended for full functionality):
  - [Storage](../OneWoW_AltTracker_Storage/README.md) — bags, banks, guild/warband storage
  - [Professions](../OneWoW_AltTracker_Professions/README.md) — profession skills and recipes
  - [Endgame](../OneWoW_AltTracker_Endgame/README.md) — M+, delves, endgame progress
  - [Collections](../OneWoW_AltTracker_Collections/README.md) — mounts, pets, toys, transmog
  - [Auctions](../OneWoW_AltTracker_Auctions/README.md) — auction house data
  - [Character](../OneWoW_AltTracker_Character/README.md) — character profiles and equipment
  - [Accounting](../OneWoW_AltTracker_Accounting/README.md) — gold and currencies

## Slash Commands

- `/1wat` - Open AltTracker

## Localization

Supports all 11 suite locales — see [LOCALES.md](../OneWoW/Docs/LOCALES.md).

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md).

## Support

**Website:** https://onewow.net/

**Report issues:** Through Discord community or our website

## OneWoW Suite

Part of the [OneWoW Suite](../README.md). See the suite README for the full addon catalog and install guide.

---

**Author:** OneWoW Development Team

**Website:** https://onewow.net/

**License:** See [LICENSE.md](../LICENSE.md). Copyright the OneWoW Development Team. All rights reserved.
