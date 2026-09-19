# OneWoW - Bags

**A complete bag organization and inventory management system. Replace or enhance the default bag interface with powerful organization tools.**

---

## Features

### Unified Bag Interface
- Single window shows all your bags at once
- See your backpack, individual bags, and reagent bag together
- Color-coded by item rarity (common, uncommon, rare, epic, legendary)
- Resize and customize the layout to fit your screen

### Multiple View Modes
- **List View** - Simple list format, easy to scan
- **Category View** - Items grouped by type (consumables, gear, crafting materials, etc.)
- **Bag View** - See items organized by which bag they're in

### Smart Categorization
- Items automatically sorted by type (equipment, consumables, reagents, trade goods, tradeskill items, recipes, gems, quest items, cosmetics, toys, pets/mounts, keys, junk, other)
- Custom categories - create your own groups for special items
- Drag-and-drop items into custom categories
- Add items by ID to your custom categories

### Search & Filter
- Search items by name
- Filter by which bag you're looking in
- Optional header expansion filter (one or more expansions)
- Quick access to specific item types
- Shows free slot count

### Tracking & Monitoring
- Track specific currencies or items
- See how much you have at a glance
- Rarity color indicators on items
- Highlight new items that came into your bags

### Customization Options
- Adjust icon size (small, medium, large, extra large)
- Adjust number of columns
- Scale bags, personal bank, warband bank, and guild bank independently
- Suite color themes (via **OneWoW** settings)

### Convenience Features
- Auto-open when you visit vendors
- Auto-close when you leave a vendor
- Lock window position to prevent accidental movement
- Show bags bar for quick switching
- Integrate with Shopping List to track what you need
- Enable Bags, Bank (personal and warband together), and Guild Bank replacement from Bags settings → General

### Settings & Organization
- Sort by priority or alphabetically
- Rarity color intensity adjustment
- Recent items tracking (highlights items picked up recently)
- Customizable highlight duration

---

## Installation

1. Extract the `OneWoW_Bags` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory
2. Extract the `OneWoW` folder (required dependency) to the same directory
3. Restart World of Warcraft or type `/reload` in-game
4. Type `/1wbags` to open the addon

## Requirements

- **OneWoW** — Core hub addon (required; includes the shared UI toolkit)

## Documentation

Contributor and integrator docs live in [`Docs/`](Docs/README.md):

- [Architecture](Docs/ARCHITECTURE.md) — load order, data flow, DB schema
- [Categorization](Docs/CATEGORIZATION.md) — category assignment and layout
- [Search syntax](Docs/SEARCH_SYNTAX.md) — predicate expression reference
- [Import/export](Docs/IMPORT_EXPORT.md) — sharing category profiles
- [Item-button API](Docs/ITEM_BUTTON.md) — overlay callbacks for third-party addons

Addon authors: start with [`API/INTEGRATION_GUIDE.md`](API/INTEGRATION_GUIDE.md).

## Slash Commands

- `/1wbags` — Open Bags

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
