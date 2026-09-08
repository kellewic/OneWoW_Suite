## Current

- **Status**: Draft

### Home
- Catalog data on Home and in Manage Features is one addon per expansion, plus Other and Tradeskills. Turn expansions and topics on or off.
- Home, Manage Features, and first-run cards use OneWoW feature icons instead of borrowed game art. Ringless sits on the card, not a black square.

---

### Catalog
#### Data
- Catalog is the encyclopedia for the suite, not only the Catalog window. Turning it off in Manage Features also stops expansion packs, Other, and Tradeskills from loading. ESC and AFK Zone Cards lose zone data, item tooltips lose sources, and profession extras in Shopping List and AltTracker go empty. Use What's affected? on the Catalog row. Apply & Reload drops Catalog from memory if it already loaded this session. After you update, delete a leftover `OneWoW_CatDB` folder in AddOns if Curse left one; keep the expansion folders (Classic, Other, Tradeskills, and the rest).
- Catalog data is per expansion. Only the expansions and topics you turn on load, so Journal and other tabs use less memory. Other holds rows that are not assigned to an expansion yet.
- Opening Zones does not walk every completed quest or saved vendor overlay. Those load when you use Quests or NPCs.
- Catalog data packs are per expansion, so those tabs open with less hitching. Item icons and types come from the game when you look at a row.
- Items use the expansion from the game files. If that field is empty, Catalog uses the first drop or vendor we know. Other is only items we still cannot place.

#### Item Search
- Item Search lists items Catalog already has a source for: a drop, a vendor, a quest, a recipe, or an achievement. Typing a name no longer fills the list with items we have nothing to show.
- Opening Item Search loads item data for the expansions you have turned on so the list can fill. Choosing Drops, Vendors, Crafted, Quests, or Owned loads that role the same way.
- Empty drop, vendor, quest, or crafted lines say Catalog not enabled when that data is not loaded.
- Collectible details can show achievements for an item when that item is a reward or a criterion.

#### Collectibles and Housing
- Catalog has Collectibles and Housing tabs next to Item Search. Collectibles lists transmog, mounts, pets, and toys with live collected status. Housing lists decor and owned, stored, and placed counts when the game reports them.
- Opening those tabs does not stall. The list stops at 50 rows, or 100 when you filter or search, then asks you to narrow it.
- Details show journal source text plus vendors, drops, quests, and a world rare when we know one. Extra lines say Catalog not enabled when Catalog or that expansion data is not loaded. Click a vendor, instance, or quest to open that Catalog tab (that click loads the pack if needed). Achievements appear only when we have an id.
- Collectibles and Housing can show Collected Only or Not Collected Only. Housing uses owned decor for that.

#### NPCs
- The NPCs tab lists shops, trainers, innkeepers, repair, stables, flight masters, bankers, barbers, quest givers, rares, and bosses. Encounter cards show type, kill quest, related quests, loot, Adventure Guide text in a readable inset when the game has it, and location. Click a quest, View loot, or a location to open Quests, Zones, or the map. Search by name, encounter name, NPC id, encounter id, or quest id. Filter by Encounters or a boss type.
- Encounter NPCs use the instance or zone from that encounter instead of Unknown Location. Current Zone Only lists bosses in this instance or map. Click the location to open that map.
- Opening an NPC card asks the game for the name and remembers it. The list can still show an id until you open that card.

#### Fixes
- Opening the NPCs tab inside a dungeon or other instance no longer errors.
- Opening a quest or NPC card no longer errors when the creature name is restricted, or on the location pin row.
- View loot on an NPC opens that encounter on Zones. It no longer jumps to a city the NPC also visits.
- Looking up a Battle for Azeroth item no longer errors when that expansion's Journal data loads. Journal cards and drop lines for that expansion work again.

#### Journal
- Standing in an older dungeon or raid (Skyreach, Timewalking, and the rest) shows that place. Extra floors in the instance load with that expansion.
- Extra drops that come from a quest or an achievement sit in their own groups again. Click the quest link to open that quest.
- Opening Zones loads this expansion first so the tab does not hitch. Pick All to load the rest in the background.
- Encounter rows have See NPC and See Map after the source icon when we know that NPC or a pin.
- Opening a dungeon or raid card shows the Adventure Guide overview in a readable inset. Expanding a Guide boss shows that encounter's text and abilities the same way. Ability titles sit below the wrapped text, including when you change font size.
- Zone achievement rows no longer show a Difficulty column, so the name has more room.

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
- ESC now has three pieces: Character Card, Zone Card, and a Travel card. Features only turns those three on or off. Features settings include a picture of each card.
- Portals sit on a Travel card that matches the other cards, not a floating icon strip. Open Portal Hub is a text button on that card. Icon size still lives in Features.
- Optional Suite theme paints the Game Menu and wraps the columns in one panel. Turn it off in Features if another UI already skins the Game Menu.
- When Character/Zone cards and Portals share a side, they stack in that column (cards above Travel).
- Character Card keeps mail and durability on the top right. Hover either for details; click mail to open Mail, or durability to open the character screen. A shopping-cart icon appears when auctions are expiring, expired, or gold is waiting. Hover it for the list; click it to open Alt Tracker auctions.
- The separate Alerts card is gone. Auction attention and alt mail sit on those Character Card icons.
- Zone Card keeps collections and Item Alert icons. Hover Notes for the zone note and OneWay Pins; click Shopping List, Notes, Trackers, or Farming to open that window. The extra zone-notes block under the card is gone.
- Click the Character Card to open the character screen, or the Zone Card to open this place in Catalog. Left-click still opens that zone when Catalog Journal is not loaded. The card says so, and right-click loads it and refreshes the card. If Catalog is off, the card says Catalog not enabled.
- Zone Card collection rows stay on the card. Extra rows scroll when this zone has more types than fit.
- The Zone Card loads the dungeon or zone you are standing in, including older expansions.

#### AFK Panel
- The AFK overlay uses the same Character Card and Zone Card as the ESC menu, including the portrait with a faction badge, weekly bars, and Item Alert icons. Hover an icon for the list or note; keys and mouse still clear AFK the same way (no click-to-open).
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
- Zoning into a dungeon or raid shows collectable counts on the instance toast when Catalog Journal data is already loaded. If Catalog is off or that expansion is not loaded, the toast says Catalog not enabled.

#### Toast Alerts
- New Collections toasts when you loot an uncollected collectible, using the same collected status as Catalog, including housing decor and heirlooms. Mounts, pets, and toys still toast when you learn them, without a second popup for the same unlock.
- Upgrade Alerts now toasts when a gear upgrade for this character appears in your bags, using the same item-level or Pawn rules as the Upgrade overlay.

#### Fixes
- Instance toasts and Item Tracker still use Catalog Journal only when that data is already loaded. If it is not, they say Catalog not enabled. The Zone Card and AFK load the dungeon or zone you are standing in.

#### Auto Open
- Auto Open now opens Torn Sack of Pet Supplies from the Crysa's Flyers daily.

#### Tooltips
- Item Tracker on item tooltips now has two blocks: Where it is (your copies) and Where to get it (quest, vendor, instance, profession). If Catalog or that expansion data is not loaded, Where to get it says Catalog not enabled.

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
- Select a row for item info, where you already have copies, where to get it (Catalog not enabled if Catalog or that expansion data is not loaded), a note, and a quantity. A vendor line and Auction House search show when you can buy instead of farming.
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
