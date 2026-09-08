## Current

- **Status**: Draft

### Home
- Catalog data stores on Home and in Manage Features are Zone Database, NPC Database, Item Database, Quest Database, Quest Archive Database, and TradeSkill Database.
- Home, Manage Features, and first-run cards use OneWoW feature icons instead of borrowed game art. Ringless sits on the card, not a black square.

---

### Catalog
#### Data
- Catalog data packs are smaller, so those tabs open with less hitching. Item icons and types come from the game when you look at a row. Quest Archive no longer carries a second copy of the same generated tables.

#### Item Search
- Item Search lists items Catalog already has a source for: a drop, a vendor, a quest, a recipe, or an achievement. Typing a name no longer fills the list with items we have nothing to show.
- Opening Item Search loads the Items pack so the list can fill. Choosing Drops, Vendors, Crafted, Quests, or Owned loads that pack the same way.
- Collectible details can show achievements for an item when that item is a reward or a criterion.

#### Collectibles and Housing
- Catalog has Collectibles and Housing tabs next to Item Search. Collectibles lists transmog, mounts, pets, and toys with live collected status. Housing lists decor and owned, stored, and placed counts when the game reports them.
- Opening those tabs does not stall. The list stops at 50 rows, or 100 when you filter or search, then asks you to narrow it.
- Details show journal source text plus vendors, drops, quests, and a world rare when we know one. Those extra lines appear when that pack is already loaded. Click a vendor, instance, or quest to open that Catalog tab (that click loads the pack if needed). Achievements appear only when we have an id.
- Collectibles and Housing can show Collected Only or Not Collected Only. Housing uses owned decor for that.

#### NPCs
- The NPCs tab lists shops, trainers, innkeepers, repair, stables, flight masters, bankers, barbers, quest givers, rares, and bosses. Encounter cards show type, kill quest, related quests, loot, Adventure Guide text when the game has it, and location. Click a quest, View loot, or a location to open Quests, Zones, or the map. Search by name, encounter name, NPC id, encounter id, or quest id. Filter by Encounters or a boss type.
- Encounter NPCs use the instance or zone from that encounter instead of Unknown Location. Current Zone Only lists bosses in this instance or map. Click the location to open that map.
- Opening an NPC card asks the game for the name and remembers it. The list can still show an id until you open that card.

#### Fixes
- Opening the NPCs tab inside a dungeon or other instance no longer errors.
- Opening a quest or NPC card no longer errors when the creature name is restricted, or on the location pin row.
- View loot on an NPC opens that encounter on Zones. It no longer jumps to a city the NPC also visits.

#### Journal
- Extra drops that come from a quest or an achievement sit in their own groups again. Click the quest link to open that quest.
- Encounter rows have See NPC and See Map after the source icon when we know that NPC or a pin.
- Opening a dungeon or raid card shows the Adventure Guide overview. Expanding a Guide boss shows that encounter's text and abilities.

#### Quests
- Show on Map uses the NPC database pin for the giver or turn-in, including object starters.
- Talking to a quest giver fills missing Catalog quest text and rewards again.
- Click the giver or turn-in name to open that person in Catalog NPCs. A quest you pick up that we did not ship is saved.
- Opening a quest asks the game for the giver and turn-in names and remembers them.

---

### AltTracker
#### Data
- Quest completion from the old Catalog Quests pack is copied into the Quest Database. Vendor categories you set are copied into the NPC Database.

---

### DevTool
#### Errors
- When DevTools catches a Lua error, the DevTools icon on Home and in the collector row turns red. Click it to open the Errors tab.

#### Textures
- Double-click a region on a texture sheet to add its name to a collected list. Copy the whole list when you are ready, or Clear it. Double-click the same region again to take that name off the list.

---

### QoL
#### Minimap Button Collector
- The enhanced OneWoW row uses the suite feature icons. In collector settings, pick With ring or Ringless. Home and Manage Features follow the same choice. Ringless sits on the panel, not a black square.

#### ESC Menu
- ESC now has three pieces: Character Card, Zone Card, and Portals. Features only turns those three on or off. Features settings include a picture of each card.
- Character Card keeps mail and durability on the top right. Hover either for details; click mail to open Mail, or durability to open the character screen. A shopping-cart icon appears when auctions are expiring, expired, or gold is waiting. Hover it for the list; click it to open Alt Tracker auctions.
- The separate Alerts card is gone. Auction attention and alt mail sit on those Character Card icons.
- Zone Card keeps collections and Item Alert icons. Hover Notes for the zone note and OneWay Pins; click Shopping List, Notes, Trackers, or Farming to open that window. The extra zone-notes block under the card is gone.
- Click the Character Card to open the character screen, or the Zone Card to open this place in Catalog. Left-click still opens that zone when Catalog Journal is not loaded. The card says so, and right-click loads it and refreshes the card.

#### AFK Panel
- The AFK overlay uses the same Character Card and Zone Card as the ESC menu, including the portrait with a faction badge, weekly bars, and Item Alert icons. Hover an icon for the list or note; keys and mouse still clear AFK the same way (no click-to-open). If Zones Catalog is not loaded, the Zone Card says so.
- Character Card sits on the bottom left. Zone Card and Info stack on the right. Alerts (auctions expiring or expired, gold waiting, and alts with mail) sit on Info, not a center card.
- Info also shows weekly and daily reset timers, profession weeklies, rested XP, bag space, Hearthstone cooldown, and this week's bonus event. When there are no auction or mail alerts, each AFK session can add one extra line: session time, a collectible count, or a short tip.
- Info matches Character and Zone: accent title, a summary strip for weekly reset, daily reset, and bag space, then icon rows with progress bars for profession weeklies and rested XP.
- Daily and Weekly notes stay in Notes. They no longer appear on AFK. You can hide the gold dock behind the cards. Character, Zone, and Info cards grow with the game window and leave space in the middle for your character.
- Character Card fills the dock. If Zone and Info are taller, Character grows to that height so there is no empty space above it.

#### Portals
- Mage Teleports and Mage Portals are separate ESC flyouts. Show or hide each set in Portals settings. Class & Racial Abilities uses the same split.
- ESC portal icons use short destination labels (HoV, SoB, SW). You can enlarge just that text, or hide it and use the tooltip. The suite font size no longer changes those labels. The ESC and Portals text sliders now change that label size.
- ESC hearthstone can be random, your Hearthstone, a specific toy, hidden, or shown disabled. Seasonal-only mode hides older Hero's Path expansion flyouts. Live dungeon teleports (on by default) pick up new Path spells from the game. A Group Finder teleport prompt is off unless you turn it on.
- The Group Finder teleport prompt no longer errors at login when that option is on.
- Added Mycomancer's Hearthspore, The Schools of Arcane Magic - Mastery, Nature's Beacon, and Dundun's Abundant Travel Method.

#### Instance Toast
- Zoning into a dungeon or raid shows collectable counts on the instance toast when that expansion's Zones data is loaded. If it is not, the toast says Zones Catalog not loaded.

#### Fixes
- ESC and AFK no longer load Catalog Journal data just to name this place. That data stays unloaded until you open Catalog Zones (or another tab that needs it), so open-world memory and hitching stay down.

#### Auto Open
- Auto Open now opens Torn Sack of Pet Supplies from the Crysa's Flyers daily.

#### Tooltips
- Item Tracker on item tooltips now has two blocks: Where it is (your copies) and Where to get it (quest, vendor, instance, profession). Those source lines appear when that Catalog pack is already loaded.

#### Toggles
- Toggles matches current Options. Colorblind UI is a checkbox; the color filter and its strength are separate. Anti-aliasing names match the game (None, FXAA Low, FXAA High, CMAA, CMAA 2). Unlimited FPS is Limit Foreground / Background FPS, not 0 on the slider (8 to 200). UI scale goes from 0.65 to 1.15. Particle density is Disabled through Ultra. Friendly nameplates are friendly players.
- New rows from current Options: press-and-hold casting, mouseover cast, combined bags, arachnophobia mode, assisted highlight, spell-alert opacity, silhouette when obscured, loss of control alerts, always-on nameplates, minion and minor plates, names-only friendly plates, class color on friendly names, realm names, offscreen plates, raid chat bubbles, ambience and dialog volume, and self-highlight circle, outline, and icon.
- Quest Progress Popups is gone. The game no longer uses that setting.

---

### Trackers
#### Fixes
- Editing a step inside a dungeon or other instance no longer errors.
- Kill a Dungeon or Raid Boss now shows Fill from current encounter when you add a new step. The first time, start the fight or fill just after the kill.

---

### Mail
#### Shipments
- Top-up restock now counts the recipient's Warband Bank by default (along with their bags and bank). Uncheck Warband Bank if you still want items mailed into that character's bags when the warband already has enough.
- Checkboxes under restock choose where to look on the recipient. You still send from your bags. Mail already on the way still counts.

---

### Notes
#### Add Note
- Add Note opens the create panel. Set the type there: Standard, Daily, or Weekly. Item notes stay on the Items tab. Farming is no longer created from this dialog.

---

### Shopping List
#### Farming List
- The Shopping List window has a Farming tab: one account-wide list grouped by where to get the item.
- Select a row for item info, where you already have copies, where to get it (when Catalog packs are already loaded), a note, and a quantity. A vendor line and Auction House search show when you can buy instead of farming.
- Send a farm row to a shopping list. Right-click a shopping-list item to send it to Farm.
- Notes Collectibles Farming intent adds that item to the Farming List when we can resolve an item id. Want stays on the Notes record.

---

*No user-facing changes this release for Bags.*

---

- **Last Updated**: Sep 8, 2026

## R6.2609.0106

Released Sep 1, 2026. Pin Packs, hub search, Mail WoW UI / One UI, Trackers hide-when-done and Midnight rares, Catalog location data, slash command updates, and Crafting Orders compact view.

[Read full release notes](Release-Notes-R6.2609.0106)

## R6.2608.2902

Released Aug 29, 2026. Home version check, hub Back and Forward, list sorting and row stripe, OneWay Pins, Crafting Orders, Portals consumable, and DEVMODE Copy All.

[Read full release notes](Release-Notes-R6.2608.2902)

## R6.2608.2707

Released Aug 27, 2026. Catalog tradeskills and quests through Midnight 12.1, Crafting Orders One UI, Shopping List bag overlay, and Bags shopping-list search.

[Read full release notes](Release-Notes-R6.2608.2707)

## R6.2608.2507

Released Aug 25, 2026. Tracker editor and list polish, Catalog quest, Journal, and vendor work, plus Home website and waypoint fixes.

[Read full release notes](Release-Notes-R6.2608.2507)

## R6.2608.1804

Released Aug 18, 2026. Midnight Season 2 across Portals, Journal, AltTracker Progress, and Trackers, plus Icon Browser search, Bags replacement toggles, and Mail language/font fixes.

[Read full release notes](Release-Notes-R6.2608.1804)

## R6.2608.1105

Released Aug 11, 2026. Home attention filtering, suite On/Off settings chrome, Portals and Catalog Tradeskills/Quests polish, plus Mail shipment and AH receipt fixes.

[Read full release notes](Release-Notes-R6.2608.1105)

## R6.2608.0406

Released Aug 4, 2026. Home hub cards and What’s New, slash cleanup path, Mail AH invoice breakdown, Catalog Journal/Vendors work, AltTracker auctions, and Notes list polish.

[Read full release notes](Release-Notes-R6.2608.0406)

## Related

* [Home](Home)
* [Slash commands](Slash-Commands)
* [Getting started](Getting-Started)

### Sources

* [CHANGELOG.md](https://github.com/kellewic/OneWoW_Suite/blob/main/CHANGELOG.md)
* In-game: Home → What’s New (highlights only)
