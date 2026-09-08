**OneWoW Shopping List** tracks what you need to buy, craft, or farm — and shows what you already own on this character or across your account. One window has two tabs: **Shopping** (named lists) and **Farming** (one account-wide list grouped by where to get the item).

**Requires:** [OneWoW](Home) core. Enable **Shopping List** under [Manage Features](Getting-Started).

**Open:** `/1wsl` (see [Slash commands](Slash-Commands))

---

## Lists and status colors

* Multiple lists (pinned **Main List** plus your own); favorites, rename, import/export
* Add items by ID, drag from bags, or paste a list (unresolved names can be fixed with **Scan All**)
* Per-item quantities plus a list multiplier that scales everything
* Status colors: **green** (this character covers it), **blue** (warband / alts cover it), **yellow** (partial), **red** (none)
* Hover status for exact locations; right-click to move items or start a craft order

Slash extras: `show` / `hide` / `help` / `add <itemID>` / `farm` on any Shopping List alias.

---

## Farming List

One account-wide list (not multiple named lists). The left side groups rows by where to get the item. Click a row to select it.

The right side shows item info, a **Buy instead** notice when a vendor is already loaded, **Where it is** (owned copies, same colors as Shopping), **Where to get it** when a Catalog pack is already loaded this session, a short note, and a quantity. Search Auction House from the detail pane when the house is open.

* Send a farm row to a shopping list you pick (adds that quantity)
* Right-click a Shopping row and choose **Send to Farm**
* Notes Collectibles **Farming** intent adds that item here when we can resolve an item id. **Want** stays on the Notes record

---

## Crafting

On the profession craft page:

* **Make List** / **Add to Active** / **Add to List** — push recipe reagents into a list (**Shift-click** to set craft count)
* Green **Craft** on a row creates a `Craft: …` sub-list of reagents (merges if you craft-order again)

With **OneWoW_CatDB_TradeSkillDB** installed, Craft can pick recipes and show which characters know them; quality-tier reagents are treated as interchangeable when scanning. Crafting **Orders** get similar “push reagents to list” buttons. The QoL **Crafting Orders** overlay can add missing crafter reagents from the browse list (active list, Make List, or pick a list).

---

## Bags, tooltips, and alts

* Cart icon on items that are on a list (bags, bank, and other item buttons). Configure it under QoL >> Overlays (icon, position, vendor, Auction House). Optional: only when you still need more.
* Optional AH search and "open Shopping List" bag buttons (toggleable in Shopping List settings)
* Tooltips show needed vs owned when the item is listed
* **Search Alts** (per list) counts alts' bags/banks and known guild banks; warband bank always counts
* Without AltTracker **Storage**, scanning is limited to this character’s bags + warband bank
* Chat loot alert when a listed item drops (short per-item cooldown)

---

## Tips

* Enable Shopping List in Manage Features even if you leave the AltTracker hub off — Storage can still load for alt scanning.
* Keep Catalog on, and keep the **Tradeskills** pack (`OneWoW_CatDB_TradeSkillDB`), if you rely on Craft / recipe picker. You do not have to open Catalog tabs.

## Related

* [Bags](Bags)
* [Catalog](Catalog)
* [AltTracker](AltTracker)
* [QoL](QoL)
* [Slash commands](Slash-Commands)

### Sources

* [OneWoW_ShoppingList/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_ShoppingList/README.md)
* [suitecommands.md](https://github.com/kellewic/OneWoW_Suite/blob/main/suitecommands.md)
