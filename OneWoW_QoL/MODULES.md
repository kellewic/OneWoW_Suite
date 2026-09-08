# OneWoW QoL — External Modules

Catalog of toggleable features under `Modules/external/`. Each module is independent — enable only what you want in the QoL Features UI (`/1wqol`).

Module authors: [DEVELOPERS.md](DEVELOPERS.md). Suite docs: [OneWoW/Docs/README.md](../OneWoW/Docs/README.md).
Community credit: [MODULE_CREDITS.md](../MODULE_CREDITS.md) (in-game: each module's Details dialog).

**36 modules** across 5 categories (matches `module.lua` `category` values in the Features UI).

---

## Automation

### Auto Mount

Automatically mounts with the fastest available mount when you stop moving in a mountable area. Re-mounts after gathering.

- **Module id:** `automount` · **Folder:** `Modules/external/automount/`

### Auto Open

Automatically opens bags, boxes, and other container items when they appear in your inventory. Does not open items while at a bank, mailbox, or merchant. Items you cannot open yet (locked lockboxes, wrong level/class/profession, or while the slot is busy) are automatically skipped.

- **Module id:** `autoopen` · **Folder:** `Modules/external/autoopen/`

### Auto Repair

Automatically repairs all your equipment when you visit a merchant that supports repairs. Prints the cost to chat.

- **Module id:** `autorepair` · **Folder:** `Modules/external/autorepair/`

### Fast Forward

Automatically skips in-game movies and cinematics. Hold any modifier key while a movie or cinematic starts to watch it instead.

- **Module id:** `fastforward` · **Folder:** `Modules/external/fastforward/`

### Fast Loot

Automatically loots all items from a corpse or chest the moment the loot window is ready. Works alongside the game's auto-loot setting.

- **Module id:** `fastloot` · **Folder:** `Modules/external/fastloot/`

### Quest Tools

Automates quest acceptance, turn-in, reward highlight, and optional quest-labeled gossip. Hold Shift when opening a quest or gossip dialog to skip auto-accept or auto-gossip.

- **Module id:** `questtools` · **Folder:** `Modules/external/questtools/`

### Screenshot On Achievement

Takes a screenshot a moment after you earn an achievement so the toast is captured. Files are saved as 'WoWScrnShot_*.jpg' in your World of Warcraft\\_retail_\\Screenshots folder.

- **Module id:** `screenshotachievements` · **Folder:** `Modules/external/screenshotachievements/`

### Untrack Completed Achievements

Automatically scans for and untracks already-completed achievements when you log in. Frees up hidden tracking slots that can get stuck after a crash or cross-character completion.

- **Module id:** `achieveuntrack` · **Folder:** `Modules/external/achieveuntrack/`

## Interface

### AFK Panel

Full-screen AFK overlay with the same Character Card and Zone Card as the ESC menu, plus an Info card in the same style (summary strip, icons, and bars for alerts, reset timers, professions, and more). Optional dock background.

- **Module id:** `afkpanel` · **Folder:** `Modules/external/afkpanel/`

### Auto Delete

Skip typing DELETE when destroying items. The confirmation button becomes immediately available without requiring you to type anything.

- **Module id:** `autodelete` · **Folder:** `Modules/external/autodelete/`

### Bag Bar

Shows usable bag items on a movable bar. Items are chosen with a keyword expression (same as Bag search). Equippable gear and quest items are always excluded from the bar (applied automatically, not shown in the editor).

- **Module id:** `bagbar` · **Folder:** `Modules/external/bagbar/`

### Character Info Sheet

Displays a clean info panel next to each equipped item on your character sheet showing item level (colored by quality), enchant status, gem status, and durability percentage.

- **Module id:** `charinfo` · **Folder:** `Modules/external/charinfo/`

### Coords Display

Displays your current map coordinates in a small movable frame near the minimap. Right-click to copy coordinates.

- **Module id:** `coords` · **Folder:** `Modules/external/coords/`

### Cursor Enhancer

Displays a customizable ring around your cursor with optional mouse trail, GCD/cast
swipes, and situation-based visibility (place × combat cards).

- **Module id:** `cursorenhancer` · **Folder:** `Modules/external/cursorenhancer/`
- **Docs:** [Docs/Modules/cursorenhancer.md](Docs/Modules/cursorenhancer.md)

### ESC Menu Panel

Display a Character Card, a Zone Card, and a portal strip alongside the ESC menu. Character Card shows a portrait with a faction badge, mail, durability, auction attention, Great Vault, Trading Post, and Housing Endeavors. Hover mail, durability, or the cart for details; click to open that window. Zone Card has this place's collections and Item Alert icons for Shopping List, notes, Trackers, and Farming. Hits sit left of |, the rest sit right. Hover an icon for details; click to open it. Click the Character Card to open the character screen, or the Zone Card to open that zone in Catalog. If Zones Catalog is not loaded, the card says so; left-click still opens that zone, right-click loads the pack and refreshes the card.

- **Module id:** `escpanel` · **Folder:** `Modules/external/escpanel/`

### Frame Mover

Drag Blizzard UI frames to reposition them. Use Ctrl+Scroll to scale. Positions and scales can persist across sessions.

- **Module id:** `framemover` · **Folder:** `Modules/external/framemover/`

### Hide Combat Error Spam

Hides the most common red error messages (out of mana, out of range, target needs to be in front, spell not ready, etc.) so the center of your screen stays clean during fights.

- **Module id:** `hideerrors` · **Folder:** `Modules/external/hideerrors/`

### Icon Browser

Replaces the default icon picker on macros, bank tabs, guild bank tabs, equipment sets, and transmog outfits with a searchable list and category filters. On by default. Stays off if the IconBrowser addon is also loaded.

- **Module id:** `iconbrowser` · **Folder:** `Modules/external/iconbrowser/`
- **Docs:** [Docs/Modules/iconbrowser.md](Docs/Modules/iconbrowser.md)

### Inspect Gear

Adds a side panel to the inspect window listing the equipped gear of the player you are inspecting. Save the whole list to a OneWoW Notes player note, or Shift-click any item to add it to your Item Notes.

- **Module id:** `inspectmog` · **Folder:** `Modules/external/inspectmog/`

### LFG Lockouts

Shows your current raid and dungeon lockouts in a side panel when the Group Finder is open.

- **Module id:** `lfgpanel` · **Folder:** `Modules/external/lfgpanel/`

### Map (Mini) Tools

Customize your minimap cluster: shape, border, zone text, clock, click actions, zoom controls, element visibility, and more. Theme-aware and fully configurable.

- **Module id:** `map_mini_tools` · **Folder:** `Modules/external/map_mini_tools/`

### Map (World) Tools

World map: reveal unexplored terrain from client data, optional tints, battlefield map tweaks, coordinates, and small comfort/cleanup options.

- **Module id:** `map_world_tools` · **Folder:** `Modules/external/map_world_tools/`

### Minimap Button Collector

Collects minimap addon buttons into a single themed container. Uses the OneWoW brand icon and supports grid layout, auto-close, and an enhanced OneWoW quick-launch row with optional Mail, Settings, and Portals tiles.

- **Module id:** `minimapbuttons` · **Folder:** `Modules/external/minimapbuttons/`

### Player Mounts

Detects and displays the mount or movement form currently being used by other players.

- **Module id:** `playmounts` · **Folder:** `Modules/external/playmounts/`

### Prey Hunt Bar

Shows a movable bar tracking your prey hunt progress (Cold > Warm > Hot > Ready) for the current zone, with the active hunt's boss, difficulty, and affixes. Unlock it to drag it into place.

- **Module id:** `preybar` · **Folder:** `Modules/external/preybar/`

### Professions Panel

Shows a companion panel alongside the profession window with expansion skill breakdowns, recipe counts, and first craft tracking.

- **Module id:** `professionspanel` · **Folder:** `Modules/external/professionspanel/`

### Crafting Orders

Replaces the right-hand crafting orders table with Craftable now, Missing mats, and Recipe Unlearned for Public, Guild, Personal, and Patron orders. On by default. Rows default to You Provide, Cart, Profit / Loss, Time, and Craft; hide, reorder, or set column widths in Features (width sliders only show for columns you have on). Compact View is on by default and matches Blizzard's original row height. Columns shrink together if they do not fit beside the order name. Hide list scrollbar is optional; the mouse wheel still works, and the bar hides when there is nothing to scroll. Cart hides when every row is already craftable. Time Left is abbreviated. A WoW UI / One UI button on the order tabs switches back to Blizzard's table. Hide unlearned recipes from Features. Add missing reagents to a Shopping List. Start, craft, and complete from one button.

- **Module id:** `craftingorders` · **Folder:** `Modules/external/craftingorders/` — [details](Docs/Modules/craftingorders.md)

### Quest Item Bar

Displays a movable bar with clickable buttons for special quest items from your quest log. Shows cooldowns, charges, and supports sorting by quest or item name.

- **Module id:** `questitembar` · **Folder:** `Modules/external/questitembar/` — [details](Modules/external/questitembar/README.md)
- **Author:** Clew

## Social

### Auto-Accept Party Invites

Automatically accepts party invites that come from people you trust. Choose which sources are allowed below.

- **Module id:** `autoinvite` · **Folder:** `Modules/external/autoinvite/`

### Auto-Accept Ready Check

Automatically confirms ready when a ready check is called in your group.

- **Module id:** `autoreadycheck` · **Folder:** `Modules/external/autoreadycheck/`

### Auto-Accept Resurrection

Automatically accepts resurrection requests when someone casts a rez on you. Skipped while you are in combat.

- **Module id:** `autoresurrect` · **Folder:** `Modules/external/autoresurrect/`

### Auto-Accept Summon

Automatically accepts summon requests from warlocks and summoning stones.

- **Module id:** `autosummon` · **Folder:** `Modules/external/autosummon/`

### Auto-Decline Duels

Automatically declines duel requests so the popup never lingers on your screen.

- **Module id:** `declineduel` · **Folder:** `Modules/external/declineduel/`

## Economy

### Auction House - Current Expansion

Automatically filters the Auction House to show only current expansion items when you open it.

- **Module id:** `auctionhouse` · **Folder:** `Modules/external/auctionhouse/`

### Vendor Panel

Adds a junk management panel to vendor windows with item filtering and quick-sell features.

- **Module id:** `vendorpanel` · **Folder:** `Modules/external/vendorpanel/`

## Utility

### Copy Text

Copies visible text from tooltips or UI elements to your clipboard. Use /1wcopytext (or /1wct) to copy what is under your cursor.

- **Module id:** `copytext` · **Folder:** `Modules/external/copytext/`
