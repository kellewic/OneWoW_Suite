**OneWoW Trackers** lets you build and pin custom lists — guides, dailies, weeklies, todos, repeating chores, and farm-value tracking — with optional auto-complete from game events.

**Requires:** [OneWoW](Home) core. Enable **Trackers** under [Manage Features](Getting-Started).

**Open:** `/1wt` (see [Slash commands](Slash-Commands))

---

## What you can do

### Lists

* Create lists by type: guide, daily, weekly, todo, repeating, or farm value. Repeating lists clear after a custom hour interval you set.
* Organize with categories (topic folders, not daily/weekly cadence), favorites, and filters. Hide Done drops finished lists; Hide completed on an open list (and on its pin) hides finished steps and empty sections. Clear resets search, type, category, and Hide Done.
* Author sections and steps; import, export, and share lists. The step editor covers every shipped step type, including nested objectives. Typing an ID shows the name. Faction, profession, and holiday gates hide steps that do not apply on the pinned window; the Trackers tab still shows every section and step so you can edit them. Required steps must be done before you can check one off.
* Start from bundled presets and examples. Midnight Zone Rares builds a daily list of outdoor rares grouped by zone. Click a rare to set a waypoint when spawn coords are known. That waypoint follows **Waypoint arrow** under QoL → Waypoints. Create the list again if you already have one from before waypoints.

### Auto-tracking

Many step types complete themselves from game events — quests, renown, vault slots, professions, transmog, kills/loot, coordinates, exploration, timers, and more. Open-world rares use Kill a Rare or Boss (Fill from target). Dungeon and raid bosses use Kill a Dungeon or Raid Boss (Fill from current encounter during the fight or just after you win). Rare Quest tracks the hidden loot lock on a zone rare: Fill from target or search by name, or start from the Midnight Zone Rares preset. Click a rare to set a waypoint when spawn coords are known. Choose daily, weekly, repeating (hour interval), or one-time resets; progress can be character- or account-scoped where the list allows.

### Overlays and map

* Pin lists as floating progress windows while you play. Hide pin when done hides the window once every visible step is complete; the list stays pinned and the window comes back after reset (or when something is incomplete again). Edit the list to show that pin only for characters in selected Roles (Settings >> Roles & Alts); the list stays in the hub on every character.
* World-map pins for coordinate steps on pinned lists. Map pins hide with the window when Hide pin when done or a Role filter puts that pin away.
* Minimap pins for those steps stay on the landmark as you walk

### Farm value

* Track unbound bag items with quantity, unit price, and total value
* Session snapshot mode ("count from now") or full bag totals
* Watchlist you curate, or every unbound stack in bags. Sort the watchlist editor by name or item ID.
* Pricing follows QoL > Tooltips > Value (Auction House and optional TradeSkillMaster)

### Settings

* Open **Settings > Trackers** in the hub
* Pinned list scale (50% to 200%) applies to every pinned overlay
* Weekly reset region override (auto-detect or US / EU / Asia)

---

## Tips

* Pin one daily/weekly list while leveling or doing chores so you are not alt-tabbing to the hub. Hide pin when done puts that window away after the last step and brings it back after reset. Edit the list to show the pin only on characters in a Role.
* Dungeon and raid bosses cannot be filled from your target. Blizzard does not let addons read that target inside an instance. Add Kill a Dungeon or Raid Boss. The first time, start the fight or use Fill from current encounter just after you defeat it (still works after you leave, until you reload). Looking at the boss is not enough. After that, the step tracks later kills. A fight with two bosses (for example Twin Fangs) is still one encounter. You can also type the encounter ID.
* Open-world rares still use Kill a Rare or Boss and Fill from target. Rare Quest is the loot lock (once per day or week), not the kill itself.
* Drag a section header or a step to reorder. Drop a step on another section to move it there.
* Hover a section or step for add, edit, and delete. List actions sit under the title.
* Farm value is strongest with Auction House or TSM pricing turned on under QoL > Tooltips > Value.

## Related

* [Slash commands](Slash-Commands)
* [Getting started](Getting-Started)
* [Notes](Notes) — free-form notes vs structured tracker lists

### Sources

* [OneWoW_Trackers/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Trackers/README.md)
* [suitecommands.md](https://github.com/kellewic/OneWoW_Suite/blob/main/suitecommands.md)
