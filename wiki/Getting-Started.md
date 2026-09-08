After [Install](Install), use this path to get a working setup quickly.

## Open the hub

In chat, type:

* `/1w`

That toggles the OneWoW hub window: portals, settings, and a section menu for every feature you have enabled.

## First-run wizard

On a fresh install, OneWoW can open a **feature picker** so you choose which modules to load. The same panel lives under hub settings as **Manage Features**.

* Re-open Manage Features anytime from the Home section link, or **Settings → Manage Features**
* You can change your mind later — enabling or disabling modules is normal

## Manage Features

Open **Manage Features** from the hub (Home link or Settings):

* Turn on only what you use (Bags, QoL, AltTracker, Catalog, and so on)
* A disabled module is **unloaded**, not merely hidden — less overhead, cleaner UI
* For **Catalog** and **AltTracker**, keep their companion `OneWoW_CatDB_*` / `AltTracker_*` folders installed; they feed the parent feature and have no separate player UI of their own. Catalog packs load when you open that tab, not at login. Catalog data is the CatDB packs (Zones, NPCs, Items, Quests, Tradeskills).
* **Notes** lists **OneWay Pins** under Notes so you can turn that feature off without unloading Notes.

Configure each enabled addon from its hub tab or its [slash command](Slash-Commands).

## What the core hub already does

Even with no optional modules, **OneWoW** includes:

* **Portal hub** — teleports, portals, and hearthstones in one place (favorites, filters, one-click use)
* **Item status on hover** — collections, item level, junk, protected, quest, crafting, transmog, bind type, and more
* **Collection toasts** — alerts when you loot an uncollected collectible (and when you learn mounts, pets, or toys), plus gear-upgrade toasts when those features are on
* **Enhanced tooltips** — collection status, notes, tracking hints, recipe status, categories. Vendor price and Item Tracker (where it is / where to get it) are configurable under tooltip settings. Source lines show when that Catalog pack is already loaded.
* **Title-bar search** — type a setting name or a short question in the hub search box to jump to that page (for example popup pins)
* **Shared themes** across OneWoW windows
* **Eleven locales** — in-game text follows your WoW client language
* **Update notice** — if someone near you has a newer OneWoW, chat, a popup, and Home Needs attention tell you. Update via [CurseForge](Install) or [onewow.net](https://onewow.net/).
* **Back and Forward** — title-bar arrows remember the last few sections and tabs you opened this session, plus the quest, NPC, or vendor you were on. Closing the window starts a fresh trail.

## Suggested first session

1. Run the wizard / Manage Features and enable the modules you care about.
2. Glance at hub settings for theme and tooltip preferences.
3. If you use Bags, open them and try a simple search (full guide: [Bags](Bags), [Search syntax](Bags-Search-Syntax)).
4. Bookmark [Slash commands](Slash-Commands) for quick opens later.

## Related

* [Slash commands](Slash-Commands)
* [Release notes](Release-Notes)
* [FAQ](FAQ)
* Feature pages in the sidebar

### Sources

* [README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/README.md) — suite overview and Manage Features model
* [OneWoW/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/README.md) — hub features (portals, tooltips, toasts, search)
* [suitecommands.md](https://github.com/kellewic/OneWoW_Suite/blob/main/suitecommands.md) — slash command inventory (full registry; Home cards + Command Options show the canonical subset)
