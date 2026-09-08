# OneWoW - Catalog

**A complete reference database for World of Warcraft content. Look up instances, encounters, vendors, professions, crafting recipes, collectibles, and housing decor.**

---

## Features

### Journal Tab - Instances, Raids, Delves & World
Browse dungeons, raids, Delves, and World hubs from every expansion:
- **All Expansions Covered** - Classic through Midnight (Delves: The War Within and Midnight; World cards for Classic through Cataclysm, outdoor hubs after that; Zone and City cards)
- Loot matches the Adventure Guide; World cards list World Bosses and World Rares with their own loot and a rares count; extra drops with a known boss or rare sit on that encounter; the rest stay under General Loot; a drop from several rares is listed on each rare
- Source icons on encounters and loot: Adventure Guide or shipped OneWoW data. When AllTheThings is loaded, a shield on the lower right of the filter bar marks it; hover the shield. Journal can add anything AllTheThings has live
- See all instances and encounters at a glance
- Pin on a card or the details toolbar opens the world map at that instance's entrance (gold pins are Wowhead locations until official doors ship). Right-click the pin to save a OneWay Pin in Notes
- Encounter rows have See NPC (opens that boss on the NPCs tab) and See Map (pins that encounter when we have a location)
- Instance Type includes World, Zones, Cities, and Delves, with a Show Bountiful checkbox for this week's bountiful doors
- Delve cards show today's story on the type line (Incomplete color only while you still need that variant) and remaining Stories progress until that achievement is complete. Details list each variant under Stories while it is unfinished
- Cities and outdoor zones for every expansion ship with that expansion's Catalog data
- Delve cards use official entrance background art. Zones, cities, and other cards without their own art use that expansion's Adventure Guide background
- Cards use a type-colored border for raid, dungeon, world, zone, city, Delve, and bountiful Delve
- Achievements sit above loot on the details side (collapsible, same header as Items). Cards show bosses, rares (World), items, and the achievement count. World cards include that expansion's exploration achievements. Status is a check / Warband mark / X
- Adventure Guide button on dungeon and raid details. Delves keep a disabled Difficulty dropdown so the map pin lines up
- Details show Adventure Guide overview text. Expanding a Guide boss shows that encounter's text and abilities
- Detailed encounter information (if data addon is installed)
- Look up loot tables and boss mechanics
- Search for specific raids, dungeons, or delves
- Perfect for planning raid nights or preparing for content

### NPCs Tab
Find NPCs, shops, and encounters:
- Browse shops, trainers, services, quest givers, rares, and bosses
- Search by name, encounter name, NPC id, encounter id, or quest id
- Opening a card asks the game for the NPC name and remembers it for later lists
- Encounter cards show type, kill quest, related quests, loot, and location
- Click a quest to open it on the Quests tab; View loot opens the Zones encounter
- Click a location (or Pin) to open that zone on the world map
- Encounter NPCs show the instance or zone for that encounter. Current Zone Only includes bosses in this instance or map
- Filter by expansion, zone, currency, or type (including Encounters)
- **Pin** sets a live waypoint and opens that zone on the world map. **Save Pin** writes a OneWay Pin in Notes; it becomes **Open Pin** once that location is saved

### Tradeskills Tab
Complete profession and recipe database:
- Browse recipes for all professions (Alchemy, Blacksmithing, Cooking, Enchanting, Engineering, Fishing, Herbalism, Housing Dyes, Inscription, Jewelcrafting, Leatherworking, Mining, Skinning, Tailoring)
- Search for specific recipes or crafts
- See what materials each recipe requires
- See skill ranks and where to learn a recipe when we know it, including the trainer or vendor name
- Find recipes that use specific materials
- Perfect for planning crafting projects

### Item Search Tab
Universal search across all item data:
- Search for any item in the game
- See where items come from (vendor, quest, drop, craft)
- Check which vendors sell specific items
- Find recipes that produce items
- Look up loot from dungeons and raids
- Quick reference for item sources

### Collectibles Tab
Browse transmog, mounts, pets, and toys from the Collections journals:
- Filter All, Transmog, Mounts, Pets, or Toys
- Live collected status from the game (not a separate data pack)
- Details show journal source text. Vendor, drop, and quest lines appear when those expansion topics are already loaded
- Click a vendor, instance, or quest to open that Catalog tab (that click loads the data if needed)
- List stops at 50 rows, or 100 when you filter or search

### Housing Tab
Browse housing decor from the game catalog:
- Decor for now, with room to grow
- Owned, stored, and placed counts when the game reports them
- Same click-through sources as Collectibles
- List stops at 50 rows, or 100 when you filter or search

---

## Data Addons (Optional but Recommended)

Catalog data is the **CatDB** addons: one folder per expansion, **Other**, and Tradeskills. Pack map: [CATDB.md](Docs/CATDB.md).

### Expansion data (`OneWoW_CatDB_<Expansion>`)
- Places, NPCs, quests, and items for that expansion
- Topic toggles in Manage Features choose what loads
- Classic through Midnight

### Other (`OneWoW_CatDB_Other`)
- Rows not yet assigned to an expansion
- Distro always includes this folder
- Items and achievements are on by default

### Data: Tradeskills (`OneWoW_CatDB_TradeSkillDB`)
- Complete recipe database for Classic through Midnight (patch 12.1)
- Material requirements
- Crafting costs and yields
- Profession progression guides
- All 14 professions covered

Each expansion folder is optional while Catalog is on. Turn Catalog off in Manage Features to stop every pack from loading.

---

## Disabling Data Modules

Catalog is the parent. Untick **Catalog** in Manage Features and no encyclopedia data loads (expansions, Other, Tradeskills). Use **What's affected?** on that row. Apply stops new loads this session; **Apply & Reload** drops Catalog from memory if it already ran.

While Catalog stays on, turn an expansion off and only that expansion's data disappears. Other Catalog tabs keep working.

This table is the canonical cross-module reference.

| Disabled module | In Catalog | Elsewhere in the suite |
| --- | --- | --- |
| **Catalog** (`OneWoW_Catalog`) | All tabs empty; no expansion, Other, or Tradeskills data loads | ESC and AFK Zone Cards have no zone data; item tooltips lose drop/vendor/quest/recipe sources; QoL Professions Panel has no Catalog recipes; ShoppingList craft detection, orders, and recipe picker are empty; AltTracker profession locations are limited |
| **An expansion** (`OneWoW_CatDB_<Expansion>`) | That expansion missing from Journal, NPCs, Quests, and Item Search | QoL Item Tracker and ESC zone card lose that expansion's lines |
| **Other** (`OneWoW_CatDB_Other`) | Unassigned items drop out of Item Search | Same |
| **Tradeskills** (`OneWoW_CatDB_TradeSkillDB`) | Tradeskills tab empty; Item Search crafted filter and recipe details (including known-by alts) | ShoppingList — no craft detection, craft orders, recipe picker, or crafting-quality inventory rollup; QoL Professions Panel — no supplemental alt recipe data from tradeskill scans |

**Still works with Catalog on and a subset of packs:** Catalog shell, Settings, Item Search (owned items via AltTracker), Collectibles, Housing, and every Catalog tab whose expansion topics remain enabled. Collectibles and Housing list from the game journals without a CatDB folder; vendor, drop, and quest clicks still need those topics on. ShoppingList profession-window hooks that use Blizzard APIs directly are unaffected by disabling Tradeskills.

**Cross-dependencies:** Journal quest-loot links and completion badges need both Zones and Quests topics. ShoppingList recipe features need Catalog on (so Tradeskills can load). You do not have to open Catalog tabs.

---

## Customization

### 14+ Theme Options
Choose from Forest Green, Ocean Blue, Royal Purple, Crimson Red, Sunset Orange, Deep Teal, Golden Amber, Rose Pink, Slate Gray, Earth Brown, Midnight Black, and more.

### Instant Theme Switching
No UI reload required for theme changes. Switch themes on the fly.

### Multi-Language Support
Supports all 11 suite locales via **OneWoW** — see [LOCALES.md](../OneWoW/Docs/LOCALES.md).

### Search & Filter
- Universal search across all data
- Filter by expansion
- Filter by type (dungeon, raid, quest, vendor, etc.)
- Alphabetical sorting

---

## Installation

1. Extract the `OneWoW_Catalog` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory
2. Extract the `OneWoW` folder (required dependency) to the same directory
3. (Optional but recommended) Extract the `OneWoW_CatDB_*` folders for complete data
4. Restart World of Warcraft or type `/reload` in-game
5. Type `/1wcat` to open the addon

## Requirements

- **OneWoW** - Core hub addon (required)
- **OneWoW_CatDB_<Expansion>** - Optional per-expansion Catalog data (Classic through Midnight)
- **OneWoW_CatDB_Other** - Unassigned rows (recommended; Distro always includes it)
- **OneWoW_CatDB_TradeSkillDB** - Recommended for recipe and profession data (optional)

## Slash Commands

- `/1wcat` - Open Catalog

## Localization

Supports all 11 suite locales — see [LOCALES.md](../OneWoW/Docs/LOCALES.md).

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md).

Browse-tab data rules (cheap list, Instant-only detail, chunked live-API filters): [CATDB.md](Docs/CATDB.md)

## Support

**Website:** https://onewow.net/

**Report issues:** Through Discord community or our website

## OneWoW Suite

Part of the [OneWoW Suite](../README.md). See the suite README for the full addon catalog and install guide.

---

**Author:** OneWoW Development Team

**Website:** https://onewow.net/

**License:** See [LICENSE.md](../LICENSE.md). Copyright the OneWoW Development Team. All rights reserved.
