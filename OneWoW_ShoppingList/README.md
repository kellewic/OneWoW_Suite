# OneWoW - Shopping List

**A shopping and crafting list manager. Build lists to track what you need to buy, craft, or farm — and see what you already have, on this character or across your account.**

---

## Features

### Shopping List Management

- Create multiple shopping lists (Main List plus your own).
- Add items by ID, by drag-and-drop from your bags, or by importing a pasted list (name-based imports become "unresolved" entries that can be resolved later by the **Scan All** button).
- Set per-item quantities. Each list also has a multiplier — bumping the list quantity scales every item's required count.
- Status colors at a glance show what you have vs. need:
  - **Green** — owned on this character covers the need.
  - **Blue** — covered when you include the warband bank (or alts, if enabled).
  - **Yellow** — partial coverage.
  - **Red** — none owned.
- Hover an item's status to see exact locations (which character, bank tab, guild bank, etc.).
- Per-item right-click menu: move to another list, send to the Farming List, or create a craft order from the item.

### Farming List

One account-wide list on the **Farming** tab, grouped by where to get the item. Select a row for item info, where you already have copies, where to get it when Catalog packs are already loaded, a buy-instead vendor notice, Auction House search, a note, and a quantity. Send a farm row to a shopping list. Notes Collectibles Farming intent adds the item here when we can resolve an item id. Want stays on the Notes record.

### Multiple Lists

- A pinned **Main List** that cannot be deleted.
- Set any list as the default (loaded on open).
- Favorite lists float to the top of the sidebar.
- Rename, delete, export, and import lists from the right-click menu.
- Auto-generated **Craft Order** sub-lists nest under their parent in the sidebar when you use the green **Craft** button (see Crafting Integration). User-created sub-lists are not exposed in the UI yet — see [TODO.md](TODO.md).

### Crafting Integration

In the in-game Profession crafting page, three buttons appear under the schematic:

- **Make List** — create a new list named after the recipe and populate it with the recipe's reagents.
- **Add to Active** — add the recipe's reagents to the current default/active list.
- **Add to List** — pick any existing list to add the reagents to.
- **Shift-click** any of the three buttons to enter how many crafts to add (materials scale accordingly).

When you click the green **Craft** button on an item row, the addon:

- Creates a `Craft: <item>` sub-list under the current list.
- Pre-fills it with the recipe's reagents.
- Auto-merges quantities if the same item is craft-ordered again under the same parent list.

With **OneWoW_CatDB_TradeSkillDB** also installed, the **Craft** button knows which recipes produce a given item and shows a recipe picker that lists which characters know each recipe. Quality-variant reagents (rank 1/2/3 versions) are recognized as interchangeable when scanning bags.

### Crafting Orders Integration

When the Profession Orders page is open, dedicated buttons on the order details let you push the order's reagents into a list, mirroring the crafting page workflow. The QoL Crafting Orders overlay can also add missing crafter reagents from the browse list (active list, Make List, or pick a list).

### Bag Integration

- A cart icon appears on bag (and other item) slots holding items that are on any list. Configure it under QoL Overlays (icon, position, vendor, Auction House). Optional: only when you still need more.
- Toggleable Auction House quick-search button anchored to the bag UI.
- Toggleable in-bag "open Shopping List" button.
- Extra bag / profession / Auction House buttons can be turned off in Shopping List settings.

### Tooltip Integration

Item tooltips show the needed/owned counts whenever the item is on a list.

### Cross-Character Support (with Storage / Character data)

- Per-list **Search Alts** toggle in the header. When enabled, the addon counts the item across all your alts' bags and personal banks, plus all known guild banks.
- The warband bank is always counted regardless of the toggle, since it's account-wide.
- Without `OneWoW_AltTracker_Storage` (and Character for gold/context), only the current character's bags + warband bank are scanned. Manage Features can enable those stores with Bags/ShoppingList even when the AltTracker hub is off.

### Loot Alerts

A chat alert prints when an item from any of your lists drops into your bags, with a 60-second per-item cooldown to avoid spam.

### Customization

- Suite-wide color themes (managed in **OneWoW** settings — affects all OneWoW addons together).
- Quick-access minimap button (registered through the **OneWoW** hub).
- Optional confirmation dialogs for deletes (item delete, list delete) — both can be silenced via "Don't ask again".
- Optional name wrapping for long item names.

---

## Installation

1. Extract the `OneWoW_ShoppingList` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory.
2. Extract the `OneWoW` folder (required dependency) to the same directory.
3. Restart World of Warcraft or type `/reload` in-game.
4. Type `/1wsl` in-game to open the addon.

## Requirements

- **OneWoW** — Core hub addon (required).
- **OneWoW_AltTracker_Storage** — Optional. Enables alt / personal-bank / guild-bank scanning (pulled when ShoppingList is enabled in Manage Features; AltTracker hub not required).
- **OneWoW_CatDB_TradeSkillDB** — Optional. Enables the **Craft** button on
  item rows, alt-recipe-knowledge lookup, and quality-variant reagent matching.
  Does not require the Catalog hub UI.

## Slash Commands

- `/1wsl` — toggle the main window.
- `/1wsl show` — show the main window.
- `/1wsl hide` — hide the main window.
- `/1wsl add <itemID>` — add an item to the active list.
- `/1wsl farm` — open the Farming tab.
- `/1wsl help` — print the command list.

## Keybindings

Configurable under WoW's **Key Bindings** menu under the **OneWoW** category:

- **Toggle Shopping List Window**
- **Show Shopping List Window**

## Localization

Supports all 11 suite locales — see [LOCALES.md](../OneWoW/Docs/LOCALES.md).

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md).

## Support

**Website:** https://onewow.net/

**Report issues:** Through the Discord community or the website above.

## OneWoW Suite

Part of the [OneWoW Suite](../README.md). See the suite README for the full addon catalog and install guide.

---

**Author:** OneWoW Development Team

**Website:** https://onewow.net/

**License:** See [LICENSE.md](../LICENSE.md). Copyright the OneWoW Development Team. All rights reserved.
