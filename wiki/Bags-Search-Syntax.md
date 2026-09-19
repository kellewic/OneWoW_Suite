One expression language powers the **Bags search bar**, **custom category search rules**, and other OneWoW search UIs (Mail shipments, overlays, AltTracker search, and more). Learn it once; reuse it everywhere those fields appear.

> **Keywords are English-only.** Tokens like `#armor` and `#epic` stay English even if your client is another language. If you paste rules from another addon that used localized keywords, use Bags **Import from…** so they convert to OneWoW’s form.

In search and category edit boxes, prefer single-character operators: `|` `&` `!` (word forms `or` / `and` / `not` also work).

---

## Contents

* [Quick start](#quick-start)
* [Saved searches](#saved-searches)
* [Category shortcuts](#category-shortcuts)
* [Text search](#text-search)
* [Operators](#operators)
* [Keywords](#keywords)
* [Property comparisons](#property-comparisons)
* [Item level shorthand](#item-level-shorthand)
* [Combining examples](#combining-examples)

---

## Quick start

| You type | What it finds |
|---|---|
| `sword` | Items with “sword” in the name |
| `#weapon` | All weapons |
| `#epic` | Epic-quality items |
| `#armor & #epic` | Epic armor |
| `#food or #potion` | Food or potions |
| `ilvl>=600` | Item level 600+ |
| `>600` | Same (ilvl shorthand) |
| `200-300` | Item level between 200 and 300 |
| `#haste & ilvl>=600` | Haste gear at ilvl 600+ |
| `haste>=200` | 200+ haste rating |
| `vendorprice>100g` | Vendor price over 100 gold |
| `>50s` | Vendor price over 50 silver (shorthand) |
| `#knowledge` | Profession knowledge study items |
| `SAVED(Collected Toys)` | Your saved search named “Collected Toys” |
| `CATEGORY(My Decks)` | Expands that custom category’s **search** rule |

There is **no** implicit AND between words — write `#armor & #epic`, not `#armor #epic`.

---

## Saved searches

Reuse a named expression anywhere suite search runs:

```text
SAVED(Collected Toys)
```

Manage shortcuts in **OneWoW Settings → Search Shortcuts**. Bags also has a **Save** control on the search bar.

* Names may use letters, numbers, spaces, `-`, `_`, and `+`
* Lookup is case-insensitive
* Nested `SAVED(...)` is allowed (with a recursion limit)
* Missing or cyclic names match **nothing** (safe fail)

---

## Category shortcuts

Reference a **custom** category’s search expression by display name:

```text
CATEGORY(My Decks)
```

* Matches items that satisfy that category’s **search rule** — not “would this item land in that category in the bag layout” (pins, priority, and overlays still affect layout separately)
* Only custom categories with a non-empty **search** filter; builtins / type-only / pin-only categories do not expand
* `!CATEGORY(My Decks)` negates that rule
* Requires Bags loaded; otherwise `CATEGORY(...)` matches nothing

---

## Text search

Bare words that are not keywords or operators match the **item name** (substring, case-insensitive).

| Example | Matches |
|---|---|
| `sword` | Names containing “sword” |
| `name~sword` | Same, explicit |
| `name~"two words"` | Name contains that phrase |
| `~"two words"` | Shorthand for `name~"two words"` |
| `name=Hearthstone` | Exact name |
| `name!=Hearthstone` | Everything except that exact name |

Bare numbers like `623` or `>600` are **item level** shorthands, not item IDs. Use `id=6948` or `itemid=6948` for IDs.

---

## Operators

| Operator | Meaning | Example |
|---|---|---|
| `!` or `not` | NOT | `!#junk` |
| `&` or `and` | AND | `#armor & #epic` |
| `\|` or `or` | OR | `#food \| #potion` |
| `( )` | Grouping | `#hearthstone \| (#armor & #junk)` |

Precedence: `!` tightest, then `&`, then `|`. Use parentheses when unsure.

| Expression | Means |
|---|---|
| `#armor & #epic \| #legendary` | `(#armor & #epic) \| #legendary` |
| `#armor & (#epic \| #legendary)` | Armor that is epic or legendary |

---

## Keywords

Keywords start with `#` and are case-insensitive. Below are the ones most players use; the engine registers more (including profession subclasses, glyph class subtypes, and gem stat subtypes).

### Quality

| Keyword | Aliases |
|---|---|
| `#poor` | `#grey`, `#gray` |
| `#common` | `#white` |
| `#uncommon` | `#green` |
| `#rare` | `#blue` |
| `#epic` | `#purple` |
| `#legendary` | `#orange` |
| `#artifact` | |
| `#heirloom` | |

### Junk

| Keyword | Aliases | Matches |
|---|---|---|
| `#junk` | `#trash` | Poor quality **or** items OneWoW marked as junk |

For gray quality only, use `#poor` / `#grey` / `#gray`.

### Item type

| Keyword | Aliases |
|---|---|
| `#weapon` | |
| `#armor` | |
| `#consumable` | |
| `#container` | `#bag` |
| `#gem` | |
| `#reagent` | |
| `#tradegoods` | `#tradegood` |
| `#enhancement` | `#itemenhancement` |
| `#recipe` | |
| `#tradeskill` | `#profession` |
| `#key` | |
| `#miscellaneous` | `#misc` |
| `#quest` | `#questitem` |
| `#housing` | |
| `#housingdecor` | `#itemdecor` |
| `#dye` | `#housingdye` |
| `#glyph` | |
| `#wowtoken` | |

### Consumables

`#potion` · `#food` (`#drink`) · `#flask` · `#elixir` · `#bandage` · `#scroll` · `#vantusrune` · `#curio` · `#utilitycurio` · `#combatcurio` · `#explosive` · `#knowledge`

### Equipment

| Keyword | Aliases | Matches |
|---|---|---|
| `#gear` | `#equipment`, `#equippable` | Any equippable item |
| `#set` | `#equipmentset` | In an equipment set |
| `#myclass` | | Usable by your class (gear or Classes: tokens) |
| `#myspec` | | Usable by your current spec |
| `#needsrepair` | | Damaged (needs bag slot context) |
| `#broken` | | Zero durability (needs bag slot context) |

Armor: `#cloth` `#leather` `#mail` `#plate` `#shield` `#cosmetic` …

Weapons: `#axe` `#sword` `#mace` `#dagger` `#staff` `#polearm` `#bow` `#gun` `#crossbow` `#warglaive` `#fist` `#1h` `#2h` … (plus 1H/2H-specific forms like `#2hsword`)

Slots: `#head` `#neck` `#shoulder` `#chest` `#waist` `#legs` `#feet` `#wrist` `#hands` `#finger` `#trinket` `#back` `#mainhand` `#offhand` `#ranged` `#wand` …

### Binding

| Keyword | Aliases | Matches |
|---|---|---|
| `#soulbound` | `#bound`, `#bop` | Character-bound (not account-bound) |
| `#boe` | `#bindonequip` | Bind on Equip (not yet bound) |
| `#boa` | `#accountbound`, `#warbound` | Account / Warband bound |
| `#bou` | `#bindonuse` | Bind on Use (not yet bound) |
| `#wue` | `#warbounduntilequip` | Warbound until equipped |

These follow the **tooltip’s current bind line** (so something that was BoE and you equipped will match `#soulbound`, not `#boe`).

### Expansion and source

* Expansions: `#currentexpansion`, `#classic`, `#tbc`, `#wotlk`, `#cata`, `#mop`, `#wod`, `#legion`, `#bfa`, `#shadowlands`, `#dragonflight`, `#warwithin` (`#tww`), `#midnight`, …
* Source (from item link creation context, when available): `#raid` `#dungeon` `#delves` `#worldquest` `#pvp` `#store`

### Season

* `#currentseason` (`#activeseason`) — gear and tokens for **whatever PvE season is live now**. Last season’s leftover track gear does not match.
* `#midnights1` (`#midnightseason1`) — Midnight Season 1. Stays Season 1 after Season 2/3 start.
* `#midnights2` (`#midnightseason2`) — Midnight Season 2. While S2 is live this overlaps `#currentseason` on that season’s track gear; it is not the same keyword.

### Collectibles and transmog

| Keyword | Matches |
|---|---|
| `#toy` `#mount` `#pet` | Collectible types (`#battlepet` = `#pet`) |
| `#collected` | You already own/learned it (`#collectionknown`) |
| `#uncollected` | Collectible you are missing (`#collectionmissing`) — not random non-collectibles |
| `#alreadyknown` | Tooltip “Already known” (different from `#collected`) |
| `#transmog` | Has a wardrobe appearance you can collect |
| `#knowntransmog` / `#unknowntransmog` | Appearance collected or not |
| `#ensemble` | Teaches a transmog set |

Tip: missing toys → `#toy & #uncollected`, not bare `!#collected`.

### Stats and sockets

* Primaries: `#intellect` `#agility` `#strength` `#stamina` (and short aliases)
* Secondaries: `#crit` `#haste` `#mastery` `#versatility`
* Tertiaries: `#speed` `#leech` `#avoidance`
* Any socket: `#socket` · typed: `#prismatic` `#metasocket` `#redsocket` …

For thresholds use properties: `haste>=200`.

### Item state and value

| Keyword | Matches |
|---|---|
| `#usable` / `#unusable` | Whether you can use it |
| `#combinable` | Combine/craft-with-reagents style item |
| `#combineready` | `#combinable & #usable` |
| `#onuse` | Tooltip has a Use: effect |
| `#new` | Blizzard “new” bag flag |
| `#equipped` | Currently equipped |
| `#sellable` / `#unsellable` | Vendor price or not |
| `#disenchantable` (`#de`) | Can be disenchanted (no profession required) |
| `#recent` | Same idea as Bags **Recent Items** (Bags-specific) |
| `#shoppinglist` (`#shoplist`) | On a Shopping List (Shopping List must be enabled) |
| `#shoppinglistneeded` | On a list and you still need more |
| `#hearthstone` `#keystone` `#tierset` `#geartoken` `#currency` | Specials |

### Crafting and professions

* `#craftingreagent` `#crafted` `#professionequipment` `#myprofs`
* Profession reagent keywords: `#blacksmithing` `#tailoring` `#alchemy` … (Profession class)
* Recipe flavors: `#alchemyrecipe` `#blacksmithingrecipe` …

---

## Property comparisons

Compare a property to a value:

```text
ilvl>=600
quality>=4
vendorprice>100g
haste>=200
name~sword
ilvl:200-300
```

### Useful numeric properties

| Property | Aliases | Meaning |
|---|---|---|
| `ilvl` | `itemlevel`, `level` | Item level |
| `id` | `itemid` | Item ID |
| `quality` | | 0 Poor … 4 Epic … |
| `count` | `stacks` | Stack size in the slot |
| `vendorprice` | `price`, `unitvalue` | Vendor price per unit |
| `totalvalue` | | Price × stack |
| `reqlevel` | `minlevel` | Required level |
| `mylevel` | | Your level |
| `expansion` | `expac` | Expansion ID |
| `sockets` | | Socket count |
| `haste` `crit` `mastery` … | | Stat ratings |
| `craftedquality` / `reagentquality` | | Profession tier stars/diamonds |
| `durability` / `durabilitypct` | | Durability (needs bag slot) |

Money on `vendorprice` / `totalvalue`: `100g`, `2g50s`, `50s`, `1.5g`.

You can compare two properties: `ilvl>=reqlevel`, `reqlevel<=mylevel`.

### String properties

| Property | Operators | Notes |
|---|---|---|
| `name` | `=` `!=` `~` (contains) `~~` (Lua pattern) | Case-insensitive |
| `tooltip` | same | Searches tooltip text |
| `equiploc` | exact | e.g. `INVTYPE_HEAD` |

### Spec / class eligibility

`forspec=269` / `forclass=9` test whether an item is **loot-eligible** for that spec or class (independent of who you are logged in as). `forclass` / `#myclass` also match non-equippable items with a Classes: tooltip line (e.g. Baleful tokens). Only `=` / `!=` — no ranges. Prefer `#myspec` / `#myclass` when you mean “for me right now.”

---

## Item level shorthand

These bind to **item level**, not item ID:

| Shorthand | Same as |
|---|---|
| `623` | `ilvl=623` |
| `200-300` | `ilvl:200-300` |
| `>600` | `ilvl>600` |
| `>=600` | `ilvl>=600` |
| `<200` | `ilvl<200` |

Bare money like `>100g` or `10s-50s` routes to **vendor price** instead.

---

## Combining examples

```text
#weapon & #epic & ilvl>=620
```

```text
#pet & (#pethumanoid | #petbeast)
```

```text
#armor & #tww & !#set & #boe
```

```text
(#potion | #food | #flask) & count>5
```

```text
#gear & #unknowntransmog & !#cosmetic
```

```text
#2hsword & #epic & ilvl>=620
```

```text
#haste & #vers & #gear
```

```text
SAVED(Collected Toys) & #epic
```

---

## Related

* [Bags](Bags) — UI overview
* [Shopping List](Shopping-List) — `#shoppinglist` / `#shoppinglistneeded`
* Hub **Search Shortcuts** and Bags category editor for saving rules
* In-game help: the search help icon (keyword / search-help dialog) on Bags and related search UIs

### Sources

* [OneWoW_Bags/Docs/SEARCH_SYNTAX.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Bags/Docs/SEARCH_SYNTAX.md) — full expression reference (this page is the player-facing subset)
