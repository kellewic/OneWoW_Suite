**OneWoW Mail** replaces the default mailbox UI with a OneWoW-styled shell and adds **Shipments** — planned sends to characters or roles using the same search language as Bags.

**Requires:** [OneWoW](Home) core. Enable **Mail** under [Manage Features](Getting-Started). Storage / Character data (pulled with Mail) helps alt addressing, restock, and in-transit tracking — AltTracker hub not required.

**Open:** at a mailbox, or `/1wmail` (see [Slash commands](Slash-Commands))

---

## What you get

### Mailbox shell

* **Inbox** — filtered collect, selection, Shift-click collect / Ctrl-click return; expandable details
* Richer Auction House invoice breakdown when recognized
* **Compose** — address suggestions for alts across realms
* **Activity** — session log; pending auto-run shipment reviews (Process / Discard)
* **WoW UI / One UI** — switch to the default WoW mailbox and back without turning Mail off. Auto-collect and shipment auto-run do not run while WoW UI is on. `/1wmail` or the minimap while WoW UI is showing returns to One UI.

### Shipments

Reusable plans:

* Target a **character** or a **role** (Settings → Roles & Alts)
* **Match** bag items with [search expressions](Bags-Search-Syntax) (soulbound always excluded)
* Keep / cap / top-up rules for items and gold; in-transit mail always counts toward restock targets
* When topping up, choose whether the recipient's bags, bank, Warband Bank, and guild bank count as already owned (Warband Bank starts on). You still send from your bags.
* Role distribute: fill first, round-robin, or equal split
* Auto-run can plan on mailbox open and hold for review on Activity

---

## Tips

* Practice a simple character shipment before role-wide distributes.
* Shipment match rules use English `#` keywords like Bags — see [Search syntax](Bags-Search-Syntax).
* Open a mailbox NPC; Mail takes over the Blizzard frame while enabled. Use **WoW UI** on the tab bar if you want the default mailbox back.

## Related

* [Bags search syntax](Bags-Search-Syntax)
* [AltTracker](AltTracker)
* [Slash commands](Slash-Commands)

### Sources

* [OneWoW_Mail/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Mail/README.md) — player overview
* [OneWoW_Mail/Docs/ARCHITECTURE.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Mail/Docs/ARCHITECTURE.md) — engineering reference
* [suitecommands.md](https://github.com/kellewic/OneWoW_Suite/blob/main/suitecommands.md)
