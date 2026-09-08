**OneWoW Catalog** is an in-game reference for instances, NPCs, professions/recipes, quests, item sources, collectibles, and housing decor.

**Requires:** [OneWoW](Home) core. Enable **Catalog** under [Manage Features](Getting-Started). That is the encyclopedia switch for the suite, not only the Catalog window. Companion **CatDB** folders fill Journal, NPCs, Tradeskills, Quests, and Item Search: one addon per expansion you installed, **Other** for unassigned rows, and Tradeskills. Collectibles and Housing list from the game journals.

**Open:** `/1wcat` (see [Slash commands](Slash-Commands))

---

## Tabs (overview)

* **Journal** — dungeons, raids, Delves, and World hubs across expansions; encounters, Adventure Guide loot, additional extras, and achievements when that expansion's Zones topic is on. Details show Adventure Guide overview text. Expanding a Guide boss shows abilities. The pin next to the favorite star opens the map and marks the entrance. Right-click that pin to save a OneWay Pin in Notes.
* **NPCs** — shops, trainers, innkeepers, repair, stables, flight masters, bankers, quest givers, rares, and bosses. Encounter cards show type (Encounter plus rare, world boss, dungeon, raid, or Delve), NPC ID, kill quest ID, related quests, Adventure Guide text when the game has it, and the instance or zone for that encounter. Click a quest to open it on Quests. **View loot** opens that encounter on Zones. Click a location or **Pin** to open the map. **Save Pin** writes a OneWay Pin in Notes; it becomes **Open Pin** once that location is saved. Search by name, encounter name, NPC id, encounter id, or quest id. Filter by expansion, zone, currency, or type (including Encounters). **Current Zone Only** includes bosses in this instance or map. Shops you have not opened yet show Unseen on the details pane. Opening a merchant still updates portrait, live prices, and pins. The list may show an NPC id until you open that card; opening it asks the game for the name and remembers it.
* **Tradeskills** — recipes for Classic through Midnight (patch 12.1), materials, skill ranks, and where to learn a recipe when we know it (trainer, vendor, drop, quest, or Specialization). Learned From uses the NPC name; vendor names open that shop in NPCs.
* **Item Search** — find an item Catalog already has a source for (drop, vendor, quest, recipe, or achievement) and see those sources. Opening the tab loads item data for expansions you have turned on.
* **Collectibles** — transmog, mounts, pets, and toys from the Collections journals, with live collected status. Filter Collected Only or Not Collected Only. Click a vendor, drop, quest, or world rare to open that Catalog tab (or the map). Achievements appear only when we have an id.
* **Housing** — housing decor from the game catalog, with owned, stored, and placed counts when the game reports them. Same Collected / Not Collected filter (owned vs not owned). Same click-through as Collectibles.
* **Quests** — quest database and completion tracking for each expansion you have turned on

Search and filters (expansion, type, and so on) work across the data you have loaded. Collectibles and Housing stop at 50 rows, or 100 when you filter or search, then ask you to narrow the list. Those two tabs read the game journals; they do not need a CatDB folder to list rows. Vendor, drop, and quest lines on a selected item show when those topics are already loaded. A click still opens that Catalog tab and loads the data if needed.

---

## Data packs

Catalog data is the **CatDB** addons. Each expansion folder is optional. Disable expansions or topics you do not need to save memory; Catalog itself still opens.

| Pack | Folder | Fills |
|------|--------|--------|
| **Expansion** (Classic through Midnight) | `OneWoW_CatDB_<Expansion>` | Journal, NPCs, quests, and items for that expansion. In Manage Features, topic toggles choose what loads. |
| **Other** | `OneWoW_CatDB_Other` | Rows not yet assigned to an expansion. Items and achievements are on by default. Distro always includes this folder. |
| **Tradeskills** | `OneWoW_CatDB_TradeSkillDB` | Recipes for Classic through Midnight (patch 12.1), materials, skill ranks, and where to learn a recipe (including Specialization) |

Turning an expansion off empties that expansion from Catalog tabs and related details. Other tabs keep working. Turning **Catalog** off stops the encyclopedia: no APIs, no expansion packs, no Other, no Tradeskills. ESC / AFK zone cards, item sources, and profession extras go empty. Use Apply & Reload if Catalog already loaded this session. After an update, delete a leftover `OneWoW_CatDB` folder in AddOns if Curse left one; keep the expansion folders.

---

## Tips

* For crafting lists, keep the **Tradeskills** pack installed even if you rarely open Catalog — [Shopping List](Shopping-List) uses it for the Craft button and recipe picker.
* On a recipe, Learned From shows the trainer or vendor name. Click a vendor name to open that shop in NPCs.
* On Journal cards, the pin beside the star opens the world map and drops a waypoint at the instance entrance. Right-click it to save a OneWay Pin in Notes. The same pin is on the details side, opposite Difficulty. Gold pins are Wowhead locations used until Blizzard publishes an official door. Hub cards still have no pin. On an encounter row, **See NPC** opens that boss on NPCs. **See Map** opens the map and pins that encounter when we have a location.
* Instance Type includes World (outdoor hubs, plus a World card for Classic through Cataclysm), Zones, Cities, and Delves (The War Within and Midnight). Loot matches the Adventure Guide. World cards split World Bosses and World Rares, each with their own loot, and show a rares count next to bosses. Extra drops include dungeon trash, outdoor rares, world drops, and holiday or world-event items that belong on a zone or World card. Extra drops with a known boss or rare sit on that encounter, including bosses or rares OneWoW did not already list. Unplaced extras stay under General Loot. A drop that comes from several rares is listed on each rare. Source icons on encounters and loot mark Adventure Guide or shipped OneWoW data. When AllTheThings is loaded, a shield sits on the lower right of the Journal filter bar; hover it. Journal can add anything AllTheThings has live. While Delves is selected, **Show Bountiful** sits next to Has uncollected and keeps only this week's bountiful doors. The checkbox clears when you close Catalog or press Clear.
* Zone and City cards are a second complete view of that place. The World hub stays the full rollup. A pin on a World-hub rare, boss, or achievement opens that zone or city when we know the map. Cities and outdoor zones for every expansion ship with that expansion's Catalog data.
* Bountiful delve cards use the bountiful type icon, and a gold border when the filter is off. Delve cards show today's story on the type line. That name uses the Incomplete color only while you still need that variant. They use the official entrance background. Zones, cities, and other cards without their own art use that expansion's Adventure Guide background. Raid, dungeon, world, zone, city, and Delve cards each have their own border color.
* Quests load per expansion you have turned on. Classic through Midnight (patch 12.1) lists have the pins and text we have. Right-click a quest map ID to save a OneWay Pin in Notes. Opening a quest asks the game for the giver and turn-in names and remembers them.
* Quest list cards use that expansion's Adventure Guide background, with a border for Campaign, Story, Legendary, and other quest types.
* Cards show bosses, items, and achievements on one line. World cards also show a rares count. Zone and City cards show rares, items, and achievements (bosses only if that place has one). Delves show remaining Stories progress while that achievement is incomplete, plus the achievement count (no Adventure Guide loot table). World cards include that expansion's exploration achievements (Explore, Adventurer, Treasures).
* Details list achievements above items. Click the Achievement header (same plus/minus as Items) to collapse the table. Status uses a check (this character), a Warband mark, and an X (incomplete). The check is green when you earned it; the Warband icon uses its normal art when the Warband has it and a grey account mark when it does not; the X turns soft orange when it is still incomplete. Click a row to open it in the in-game Achievements window. On a Delve, Stories lists each variant under that achievement until the achievement is complete; today's is highlighted. Click still opens the achievement.
* Dungeons and raids have an Adventure Guide button on the details toolbar. Details show that instance's Adventure Guide overview. Expanding a Guide boss shows its text and abilities. Delves keep the Difficulty dropdown in place so the map pin lines up, but it stays disabled (Delves have no difficulty filter and no Adventure Guide page).
* Collectibles and Housing sit next to Item Search. They read the Collections journals and the housing decor catalog, so opening the tab stays smooth. Filter or search when the list asks you to narrow it. Vendor, drop, and quest lines on a selected item show when that expansion's topics are already loaded. Click one to open that Catalog tab.
* Themes follow suite-wide OneWoW settings.
* If Catalog is missing a quest, NPC, or recipe you just saw, OneWoW can flag it. CompSync **Contribute** (or Cloud with **Also upload Contribute data**) sends those flags for a later release. They do not appear on [app.onewow.net](https://app.onewow.net/). See [About](About).

## Related

* [Shopping List](Shopping-List)
* [AltTracker](AltTracker)
* [About](About)
* [Slash commands](Slash-Commands)

### Sources

* [OneWoW_Catalog/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Catalog/README.md)
* [OneWoW_Catalog/Docs/CATDB.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Catalog/Docs/CATDB.md)
* [suitecommands.md](https://github.com/kellewic/OneWoW_Suite/blob/main/suitecommands.md)
